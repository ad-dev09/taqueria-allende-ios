import Foundation
import Combine

@MainActor
final class OrderStore: ObservableObject {
    @Published private(set) var orders: [Order] = []

    private let storageKey: String = "taqueria.allende.orders.v1"

    init() {
        load()
    }

    var todayBusinessDay: String {
        AppDate.businessDay()
    }

    var dailyOrders: [Order] {
        ordersForDay(todayBusinessDay)
    }

    var dailyOrderCount: Int {
        dailyOrders.count
    }

    var nextOrderNumber: Int {
        (dailyOrders.map(\.orderNumber).max() ?? 0) + 1
    }

    var availableBusinessDays: [String] {
        Array(Set(orders.map(\.businessDay))).sorted(by: >)
    }

    func ordersForDay(_ businessDay: String) -> [Order] {
        orders
            .filter { $0.businessDay == businessDay }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func createOrder(lines: [OrderLine], generalNotes: String) -> Order {
        let order: Order = Order(
            id: UUID(),
            orderNumber: nextOrderNumber,
            businessDay: todayBusinessDay,
            createdAt: Date(),
            lines: lines,
            generalNotes: generalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        orders.insert(order, at: 0)
        persist()
        return order
    }

    private func load() {
        guard let data: Data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            orders = try JSONDecoder().decode([Order].self, from: data)
        } catch {
            orders = []
        }
    }

    private func persist() {
        do {
            let data: Data = try JSONEncoder().encode(orders)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Local persistence failures should not prevent the order screen from working.
        }
    }
}
