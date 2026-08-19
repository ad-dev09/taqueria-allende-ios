import SwiftUI

@main
struct TaqueriaAllendeApp: App {
    @StateObject private var orderStore: OrderStore = OrderStore()
    @StateObject private var printerService: PrinterService = PrinterService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(orderStore)
                .environmentObject(printerService)
        }
    }
}
