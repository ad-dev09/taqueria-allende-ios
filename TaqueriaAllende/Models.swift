import Foundation

struct MenuProduct: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let detail: String
    let priceCents: Int
    let symbolName: String

    static let catalog: [MenuProduct] = [
        MenuProduct(
            id: "tacos-bisteck",
            name: "Orden de tacos de bisteck",
            detail: "Tortilla, bisteck y guarnición",
            priceCents: 950,
            symbolName: "fork.knife"
        ),
        MenuProduct(
            id: "coca-cola-500",
            name: "Coca-Cola 500 ml",
            detail: "Fría",
            priceCents: 250,
            symbolName: "wineglass.fill"
        )
    ]

    var formattedPrice: String {
        CurrencyFormatter.string(cents: priceCents)
    }
}

struct DraftLine: Identifiable, Hashable {
    let id: String
    let productID: String
    let productName: String
    let detail: String
    let unitPriceCents: Int
    let symbolName: String
    var quantity: Int
    var note: String

    init(product: MenuProduct) {
        id = product.id
        productID = product.id
        productName = product.name
        detail = product.detail
        unitPriceCents = product.priceCents
        symbolName = product.symbolName
        quantity = 0
        note = ""
    }

    static let catalog: [DraftLine] = MenuProduct.catalog.map(DraftLine.init)

    var totalCents: Int {
        quantity * unitPriceCents
    }
}

struct OrderLine: Identifiable, Codable, Hashable {
    let id: UUID
    let productID: String
    let productName: String
    let unitPriceCents: Int
    let quantity: Int
    let note: String

    var totalCents: Int {
        quantity * unitPriceCents
    }
}

struct Order: Identifiable, Codable, Hashable {
    let id: UUID
    let orderNumber: Int
    let businessDay: String
    let createdAt: Date
    let lines: [OrderLine]
    let generalNotes: String

    var displayNumber: String {
        String(format: "#%03d", orderNumber)
    }

    var totalCents: Int {
        lines.reduce(0) { $0 + $1.totalCents }
    }

    var itemCount: Int {
        lines.reduce(0) { $0 + $1.quantity }
    }
}

enum AppDate {
    static func businessDay(for date: Date = Date()) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func timeString(for date: Date) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func dateTimeString(for date: Date) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func displayDay(for businessDay: String) -> String {
        let parser: DateFormatter = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone.current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date: Date = parser.date(from: businessDay) else {
            return businessDay
        }

        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EEEE d 'de' MMMM"
        return formatter.string(from: date).capitalized
    }
}

enum CurrencyFormatter {
    static func string(cents: Int) -> String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
    }
}
