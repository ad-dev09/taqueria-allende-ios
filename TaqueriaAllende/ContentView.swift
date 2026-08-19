import CoreBluetooth
import SwiftUI

private enum AppTheme {
    static let paper: Color = Color(red: 0.976, green: 0.949, blue: 0.894)
    static let paperDeep: Color = Color(red: 0.935, green: 0.894, blue: 0.812)
    static let ink: Color = Color(red: 0.102, green: 0.184, blue: 0.156)
    static let chile: Color = Color(red: 0.655, green: 0.133, blue: 0.102)
    static let chileDark: Color = Color(red: 0.49, green: 0.075, blue: 0.060)
    static let corn: Color = Color(red: 0.965, green: 0.675, blue: 0.175)
    static let sage: Color = Color(red: 0.31, green: 0.49, blue: 0.36)
}

struct ContentView: View {
    private enum Tab: Hashable {
        case order
        case history
        case printer
    }

    @State private var selectedTab: Tab = .order

    var body: some View {
        TabView(selection: $selectedTab) {
            NewOrderView()
                .tabItem {
                    Label("Nueva orden", systemImage: "fork.knife")
                }
                .tag(Tab.order)

            HistoryView()
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }
                .tag(Tab.history)

            PrinterView()
                .tabItem {
                    Label("Impresora", systemImage: "printer.fill")
                }
                .tag(Tab.printer)
        }
        .tint(AppTheme.chile)
    }
}

struct NewOrderView: View {
    @EnvironmentObject private var store: OrderStore
    @EnvironmentObject private var printer: PrinterService

    @State private var draftLines: [DraftLine] = DraftLine.catalog
    @State private var generalNotes: String = ""
    @State private var message: UserMessage?

    private var selectedItemCount: Int {
        draftLines.reduce(0) { $0 + $1.quantity }
    }

    private var totalCents: Int {
        draftLines.reduce(0) { $0 + $1.totalCents }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    orderHeader
                    menuSection
                    notesSection
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert(item: $message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.body),
                dismissButton: .default(Text("Listo"))
            )
        }
    }

    private var orderHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TAQUERÍA ALLENDE")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.corn)
                    Text("Nueva orden")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 12)
                ZStack {
                    Circle()
                        .fill(AppTheme.corn.opacity(0.20))
                        .frame(width: 58, height: 58)
                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.corn)
                }
            }

            HStack(spacing: 10) {
                MetricPill(title: "Hoy", value: "\(store.dailyOrderCount)", symbol: "chart.bar.fill")
                MetricPill(title: "Siguiente", value: String(format: "#%03d", store.nextOrderNumber), symbol: "number")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.ink
                Circle()
                    .fill(AppTheme.chile.opacity(0.45))
                    .frame(width: 160, height: 160)
                    .offset(x: 55, y: 70)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Elige los productos", subtitle: "Ajusta la cantidad y agrega detalles si hace falta.")
            ForEach($draftLines) { $line in
                ProductCard(line: $line)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Nota general", subtitle: "Algo importante para toda la orden.")
            TextField("Ej. Sin cebolla, pasarán por ella...", text: $generalNotes, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(16)
                .frame(minHeight: 86, alignment: .topLeading)
                .background(Color.white.opacity(0.76))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.10), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedItemCount == 0 ? "Sin productos" : "\(selectedItemCount) producto\(selectedItemCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.64))
                    Text(CurrencyFormatter.string(cents: totalCents))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                Button(action: saveAndPrint) {
                    HStack(spacing: 9) {
                        Image(systemName: printer.isReady ? "printer.fill" : "checkmark")
                        Text(printer.isReady ? "Guardar e imprimir" : "Guardar orden")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(totalCents == 0 ? AppTheme.ink.opacity(0.25) : AppTheme.chile)
                    .clipShape(Capsule())
                }
                .disabled(totalCents == 0)
                .accessibilityLabel(printer.isReady ? "Guardar e imprimir orden" : "Guardar orden")
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.ink.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func saveAndPrint() {
        let lines: [OrderLine] = draftLines.compactMap { line in
            guard line.quantity > 0 else {
                return nil
            }
            return OrderLine(
                id: UUID(),
                productID: line.productID,
                productName: line.productName,
                unitPriceCents: line.unitPriceCents,
                quantity: line.quantity,
                note: line.note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        guard !lines.isEmpty else {
            message = UserMessage(title: "Agrega un producto", body: "Selecciona al menos un producto para crear la orden.")
            return
        }

        let order: Order = store.createOrder(lines: lines, generalNotes: generalNotes)
        let shouldPrint: Bool = printer.isReady
        if shouldPrint {
            printer.print(order: order)
            message = UserMessage(title: "Orden \(order.displayNumber) guardada", body: "El ticket se está enviando a la impresora.")
        } else {
            message = UserMessage(title: "Orden \(order.displayNumber) guardada", body: "Conecta una impresora BLE desde la pestaña Impresora para imprimirla.")
        }

        draftLines = DraftLine.catalog
        generalNotes = ""
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: OrderStore
    @EnvironmentObject private var printer: PrinterService
    @State private var message: UserMessage?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    historyHeader
                    if store.orders.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.availableBusinessDays, id: \.self) { day in
                            daySection(day)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(item: $message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.body),
                dismissButton: .default(Text("Listo"))
            )
        }
    }

    private var historyHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Órdenes guardadas")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Text("Todo queda en este iPhone, organizado por día.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.58))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("HOY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(AppTheme.chile)
                Text("\(store.dailyOrderCount)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.chile)
            }
        }
    }

    private func daySection(_ day: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppDate.displayDay(for: day))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .padding(.leading, 4)

            ForEach(store.ordersForDay(day)) { order in
                HStack(spacing: 12) {
                    NavigationLink {
                        OrderDetailView(order: order)
                    } label: {
                        HistoryRowContent(order: order)
                    }
                    .buttonStyle(.plain)

                    Button {
                        reprint(order)
                    } label: {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(printer.isReady ? AppTheme.chile : AppTheme.ink.opacity(0.25))
                            .frame(width: 44, height: 44)
                            .background(AppTheme.paperDeep.opacity(0.75))
                            .clipShape(Circle())
                    }
                    .disabled(!printer.isReady)
                    .accessibilityLabel("Reimprimir orden \(order.displayNumber)")
                }
                .padding(14)
                .background(Color.white.opacity(0.78))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.chile)
                .frame(width: 70, height: 70)
                .background(AppTheme.chile.opacity(0.10))
                .clipShape(Circle())
            Text("Todavía no hay órdenes")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Text("Las órdenes que guardes aparecerán aquí por fecha.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.58))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private func reprint(_ order: Order) {
        guard printer.isReady else {
            message = UserMessage(title: "Conecta una impresora", body: "Ve a la pestaña Impresora y conecta una impresora BLE ESC/POS.")
            return
        }
        printer.print(order: order)
        message = UserMessage(title: "Ticket enviado", body: "La orden \(order.displayNumber) se está reimprimiendo.")
    }
}

struct OrderDetailView: View {
    @EnvironmentObject private var printer: PrinterService
    let order: Order
    @State private var message: UserMessage?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(order.displayNumber)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(AppDate.dateTimeString(for: order.createdAt))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.54))
                }

                VStack(spacing: 0) {
                    ForEach(order.lines) { line in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(line.quantity)x")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(AppTheme.chile)
                                    .frame(width: 34, alignment: .leading)
                                Text(line.productName)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text(CurrencyFormatter.string(cents: line.totalCents))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink)
                            }
                            if !line.note.isEmpty {
                                Text("Nota: \(line.note)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.ink.opacity(0.58))
                                    .padding(.leading, 34)
                            }
                        }
                        .padding(.vertical, 16)
                        if line.id != order.lines.last?.id {
                            Divider().overlay(AppTheme.ink.opacity(0.08))
                        }
                    }

                    if !order.generalNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nota general")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(AppTheme.chile)
                            Text(order.generalNotes)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                    }

                    Divider().overlay(AppTheme.ink.opacity(0.10))
                        .padding(.top, 14)
                    HStack {
                        Text("Total")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Spacer()
                        Text(CurrencyFormatter.string(cents: order.totalCents))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(AppTheme.ink)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    reprint()
                } label: {
                    HStack {
                        Image(systemName: "printer.fill")
                        Text("Reimprimir ticket")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(printer.isReady ? AppTheme.chile : AppTheme.ink.opacity(0.25))
                    .clipShape(Capsule())
                }
                .disabled(!printer.isReady)
            }
            .padding(16)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.body),
                dismissButton: .default(Text("Listo"))
            )
        }
    }

    private func reprint() {
        guard printer.isReady else {
            message = UserMessage(title: "Conecta una impresora", body: "Ve a la pestaña Impresora para conectar una impresora BLE ESC/POS.")
            return
        }
        printer.print(order: order)
        message = UserMessage(title: "Ticket enviado", body: "La orden \(order.displayNumber) se está reimprimiendo.")
    }
}

struct PrinterView: View {
    @EnvironmentObject private var printer: PrinterService

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    connectionCard
                    compatibilityNote
                    scanSection
                    if !printer.discoveredPrinters.isEmpty {
                        discoveredSection
                    }
                    if let error: String = printer.lastError {
                        errorCard(error)
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("Impresora")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(printer.isReady ? AppTheme.sage.opacity(0.16) : AppTheme.paperDeep)
                        .frame(width: 54, height: 54)
                    Image(systemName: printer.isReady ? "checkmark" : "printer.fill")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(printer.isReady ? AppTheme.sage : AppTheme.ink.opacity(0.60))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(printer.isReady ? "Impresora lista" : "Sin impresora conectada")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(printer.connectedPrinterName ?? printer.connectionStatus)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.56))
                }
                Spacer()
            }

            if printer.isReady {
                Button {
                    printer.disconnect()
                } label: {
                    Text("Desconectar")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.chile)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.chile.opacity(0.09))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.80))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(printer.isReady ? AppTheme.sage.opacity(0.34) : AppTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var compatibilityNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppTheme.chile)
            Text("Esta versión busca impresoras térmicas BLE que acepten ESC/POS. Algunas impresoras Bluetooth Classic requieren el SDK del fabricante y podrán conectarse en una versión posterior.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.66))
        }
        .padding(14)
        .background(AppTheme.corn.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Buscar impresoras", subtitle: bluetoothSubtitle)
            Button {
                if printer.isScanning {
                    printer.stopScanning()
                } else {
                    printer.startScanning()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: printer.isScanning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                    Text(printer.isScanning ? "Detener búsqueda" : "Buscar impresoras BLE")
                    Spacer()
                    if printer.isScanning {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 54)
                .background(AppTheme.ink)
                .clipShape(Capsule())
            }
            .disabled(printer.bluetoothState != .poweredOn && !printer.isScanning)
        }
    }

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dispositivos encontrados")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            ForEach(printer.discoveredPrinters) { device in
                Button {
                    printer.connect(to: device)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "printer.fill")
                            .foregroundStyle(AppTheme.chile)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.chile.opacity(0.10))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                            Text("Señal \(device.signalStrength) dBm")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.ink.opacity(0.50))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.ink.opacity(0.35))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func errorCard(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.chile)
            Text(error)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.chileDark)
        }
        .padding(14)
        .background(AppTheme.chile.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var bluetoothSubtitle: String {
        switch printer.bluetoothState {
        case .poweredOn:
            return "Activa la impresora y mantenla cerca del iPhone."
        case .poweredOff:
            return "Bluetooth está apagado en el iPhone."
        case .unauthorized:
            return "Permite el acceso a Bluetooth en Ajustes."
        case .unsupported:
            return "Bluetooth no está disponible en este dispositivo."
        default:
            return "Comprobando el estado de Bluetooth..."
        }
    }
}

private struct ProductCard: View {
    @Binding var line: DraftLine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: line.symbolName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.chile)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.chile.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(line.productName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(line.detail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.52))
                }
                Spacer(minLength: 8)
                Text(CurrencyFormatter.string(cents: line.unitPriceCents))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
            }

            HStack {
                Text("Cantidad")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.54))
                Spacer()
                HStack(spacing: 16) {
                    QuantityButton(symbol: "minus", isEnabled: line.quantity > 0) {
                        line.quantity = max(0, line.quantity - 1)
                    }
                    Text("\(line.quantity)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .frame(minWidth: 22)
                    QuantityButton(symbol: "plus", isEnabled: true) {
                        line.quantity += 1
                    }
                }
            }

            if line.quantity > 0 {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.42))
                        .padding(.top, 5)
                    TextField("Nota para este producto", text: $line.note, axis: .vertical)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1...3)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.80))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(line.quantity > 0 ? AppTheme.chile.opacity(0.30) : AppTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct QuantityButton: View {
    let symbol: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(isEnabled ? .white : AppTheme.ink.opacity(0.25))
                .frame(width: 40, height: 40)
                .background(isEnabled ? AppTheme.ink : AppTheme.paperDeep)
                .clipShape(Circle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(symbol == "plus" ? "Aumentar cantidad" : "Disminuir cantidad")
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.corn)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.58))
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.10))
        .clipShape(Capsule())
    }
}

private struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.55))
        }
    }
}

private struct HistoryRowContent: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.displayNumber)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.chile)
                Text("\(AppDate.timeString(for: order.createdAt)) · \(order.itemCount) producto\(order.itemCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.54))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.string(cents: order.totalCents))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.30))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct UserMessage: Identifiable {
    let id: UUID = UUID()
    let title: String
    let body: String
}
