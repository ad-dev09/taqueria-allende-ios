import Combine
import CoreBluetooth
import Foundation

struct DiscoveredPrinter: Identifiable {
    let peripheral: CBPeripheral
    let name: String
    let signalStrength: Int

    var id: UUID {
        peripheral.identifier
    }
}

@MainActor
final class PrinterService: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var discoveredPrinters: [DiscoveredPrinter] = []
    @Published private(set) var connectedPrinterName: String?
    @Published private(set) var connectionStatus: String = "Sin conectar"
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var isPrinting: Bool = false
    @Published private(set) var lastPrintDate: Date?
    @Published var lastError: String?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var writeType: CBCharacteristicWriteType = .withoutResponse
    private var writeQueue: [Data] = []
    private var writeIndex: Int = 0

    var isReady: Bool {
        connectedPeripheral != nil && writeCharacteristic != nil
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard bluetoothState == .poweredOn else {
            lastError = bluetoothMessage
            return
        }

        discoveredPrinters = []
        lastError = nil
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        guard isScanning else {
            return
        }
        centralManager.stopScan()
        isScanning = false
    }

    func connect(to printer: DiscoveredPrinter) {
        guard bluetoothState == .poweredOn else {
            lastError = bluetoothMessage
            return
        }

        stopScanning()
        lastError = nil
        writeCharacteristic = nil
        connectedPeripheral = printer.peripheral
        connectedPrinterName = printer.name
        connectionStatus = "Conectando..."
        printer.peripheral.delegate = self
        centralManager.connect(printer.peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral: CBPeripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        connectedPrinterName = nil
        writeCharacteristic = nil
        connectionStatus = "Sin conectar"
        isPrinting = false
    }

    func print(order: Order) {
        guard let peripheral: CBPeripheral = connectedPeripheral,
              let characteristic: CBCharacteristic = writeCharacteristic else {
            lastError = "Conecta una impresora BLE antes de imprimir."
            return
        }

        guard !isPrinting else {
            lastError = "La impresora está terminando el ticket anterior."
            return
        }

        lastError = nil
        writeType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        let maximumLength: Int = max(
            20,
            peripheral.maximumWriteValueLength(for: writeType)
        )
        writeQueue = TicketBuilder.build(order: order).chunked(maxLength: maximumLength)
        writeIndex = 0
        isPrinting = true
        sendNextChunk()
    }

    private var bluetoothMessage: String {
        switch bluetoothState {
        case .poweredOff:
            return "Activa Bluetooth en Ajustes para buscar impresoras."
        case .unauthorized:
            return "Permite Bluetooth para que la app pueda buscar impresoras."
        case .unsupported:
            return "Este iPhone no puede usar Bluetooth para impresoras."
        case .resetting:
            return "Bluetooth se está reiniciando. Intenta de nuevo en un momento."
        case .unknown:
            return "Esperando a que Bluetooth esté disponible."
        case .poweredOn:
            return ""
        @unknown default:
            return "No se pudo consultar el estado de Bluetooth."
        }
    }

    private func sendNextChunk() {
        guard let peripheral: CBPeripheral = connectedPeripheral,
              let characteristic: CBCharacteristic = writeCharacteristic else {
            finishPrinting(with: "La conexión con la impresora se perdió.")
            return
        }

        guard writeIndex < writeQueue.count else {
            finishPrinting(with: nil)
            return
        }

        if writeType == .withoutResponse {
            while writeIndex < writeQueue.count && peripheral.canSendWriteWithoutResponse {
                peripheral.writeValue(writeQueue[writeIndex], for: characteristic, type: .withoutResponse)
                writeIndex += 1
            }

            if writeIndex >= writeQueue.count {
                finishPrinting(with: nil)
            }
        } else {
            peripheral.writeValue(writeQueue[writeIndex], for: characteristic, type: .withResponse)
        }
    }

    private func finishPrinting(with errorMessage: String?) {
        isPrinting = false
        writeQueue = []
        writeIndex = 0
        if let errorMessage: String = errorMessage {
            lastError = errorMessage
        } else {
            lastPrintDate = Date()
        }
    }

    private func handleStateUpdate(_ state: CBManagerState) {
        bluetoothState = state
        if state != .poweredOn {
            stopScanning()
        }
    }

    private func handleDiscovery(_ peripheral: CBPeripheral, rssi: NSNumber) {
        let displayName: String = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Impresora sin nombre"
        guard !displayName.isEmpty else {
            return
        }

        let device: DiscoveredPrinter = DiscoveredPrinter(
            peripheral: peripheral,
            name: displayName,
            signalStrength: rssi.intValue
        )
        if let index: Int = discoveredPrinters.firstIndex(where: { $0.id == device.id }) {
            discoveredPrinters[index] = device
        } else {
            discoveredPrinters.append(device)
            discoveredPrinters.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func handleConnection(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedPrinterName = peripheral.name ?? "Impresora BLE"
        connectionStatus = "Buscando canal de impresión..."
        peripheral.discoverServices(nil)
    }

    private func handleServices(_ peripheral: CBPeripheral, error: Error?) {
        if let error: Error = error {
            connectionStatus = "No se pudieron leer los servicios"
            lastError = error.localizedDescription
            return
        }
        guard let services: [CBService] = peripheral.services else {
            connectionStatus = "La impresora no expuso servicios BLE"
            return
        }
        for service: CBService in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    private func handleCharacteristics(_ peripheral: CBPeripheral, characteristics: [CBCharacteristic]?, error: Error?) {
        if let error: Error = error {
            connectionStatus = "No se pudieron leer los canales"
            lastError = error.localizedDescription
            return
        }
        guard let characteristics: [CBCharacteristic] = characteristics else {
            return
        }

        if let characteristic: CBCharacteristic = characteristics.first(where: {
            $0.properties.contains(.writeWithoutResponse)
        }) ?? characteristics.first(where: { $0.properties.contains(.write) }) {
            writeCharacteristic = characteristic
            connectionStatus = "Lista para imprimir"
            lastError = nil
        }
    }
}

extension PrinterService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            self?.handleStateUpdate(central.state)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor [weak self] in
            self?.handleDiscovery(peripheral, rssi: RSSI)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            self?.handleConnection(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            self?.connectionStatus = "No se pudo conectar"
            self?.lastError = error?.localizedDescription ?? "La impresora rechazó la conexión."
            self?.connectedPeripheral = nil
            self?.connectedPrinterName = nil
            self?.writeCharacteristic = nil
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor [weak self] in
            self?.connectionStatus = "Sin conectar"
            self?.connectedPeripheral = nil
            self?.connectedPrinterName = nil
            self?.writeCharacteristic = nil
            self?.isPrinting = false
            if let error: Error = error {
                self?.lastError = error.localizedDescription
            }
        }
    }
}

extension PrinterService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleServices(peripheral, error: error)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor [weak self] in
            self?.handleCharacteristics(peripheral, characteristics: service.characteristics, error: error)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor [weak self] in
            if let error: Error = error {
                self?.finishPrinting(with: error.localizedDescription)
                return
            }
            self?.writeIndex += 1
            self?.sendNextChunk()
        }
    }

    nonisolated func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            self?.sendNextChunk()
        }
    }
}

enum TicketBuilder {
    static func build(order: Order) -> Data {
        var data: Data = Data()
        data.append(contentsOf: [0x1B, 0x40])
        data.append(contentsOf: [0x1B, 0x61, 0x01])
        data.append(contentsOf: [0x1B, 0x45, 0x01])
        appendLine("TAQUERIA ALLENDE", to: &data)
        data.append(contentsOf: [0x1B, 0x45, 0x00])
        appendLine("C. Allende 512 Fracc. Cuauhtémoc", to: &data)
        appendLine("Río Bravo, Tamaulipas 88950", to: &data)
        appendLine("--------------------------------", to: &data)
        data.append(contentsOf: [0x1B, 0x45, 0x01])
        appendLine("ORDEN \(order.displayNumber)", to: &data)
        data.append(contentsOf: [0x1B, 0x45, 0x00])
        appendLine(AppDate.dateTimeString(for: order.createdAt), to: &data)
        data.append(contentsOf: [0x1B, 0x61, 0x00])
        appendLine("--------------------------------", to: &data)

        for line: OrderLine in order.lines {
            appendLine("\(line.quantity)x  \(line.productName)", to: &data)
            appendLine("     \(CurrencyFormatter.string(cents: line.totalCents))", to: &data)
            if !line.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendLine("     Nota: \(line.note)", to: &data)
            }
        }

        if !order.generalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLine("", to: &data)
            appendLine("Nota general:", to: &data)
            appendLine(order.generalNotes, to: &data)
        }

        appendLine("--------------------------------", to: &data)
        data.append(contentsOf: [0x1B, 0x45, 0x01])
        appendLine("TOTAL  \(CurrencyFormatter.string(cents: order.totalCents))", to: &data)
        data.append(contentsOf: [0x1B, 0x45, 0x00])
        appendLine("Gracias por su compra", to: &data)
        appendLine("", to: &data)
        appendLine("", to: &data)
        data.append(contentsOf: [0x1D, 0x56, 0x00])
        return data
    }

    private static func appendLine(_ text: String, to data: inout Data) {
        data.append(contentsOf: Array((text + "\n").utf8))
    }
}

private extension Data {
    func chunked(maxLength: Int) -> [Data] {
        guard maxLength > 0 else {
            return [self]
        }

        var chunks: [Data] = []
        var offset: Int = 0
        while offset < count {
            let length: Int = Swift.min(maxLength, count - offset)
            chunks.append(subdata(in: offset..<(offset + length)))
            offset += length
        }
        return chunks
    }
}
