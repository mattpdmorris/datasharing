import Foundation

/// A single payment from the Global Fund to a grant's principal recipient.
struct Disbursement: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let date: Date
    /// USD at the Global Fund reference rate.
    let amount: Double
    let recipient: String?
}

extension Disbursement {
    init?(record: Record, fallbackIndex: Int) {
        typealias F = APIConfig.Fields
        guard let date = record.date(F.disbursementDate),
              let amount = record.double(F.disbursementAmount) else { return nil }
        self.init(
            id: record.string(F.disbursementID) ?? "\(fallbackIndex)-\(date.timeIntervalSince1970)-\(amount)",
            date: date,
            amount: amount,
            recipient: record.string(F.disbursementRecipient)
        )
    }
}

extension Array where Element == Disbursement {
    /// Running total, for the cumulative line on the grant chart. Expects date order.
    var cumulative: [(date: Date, total: Double)] {
        var total = 0.0
        return map { d in
            total += d.amount
            return (d.date, total)
        }
    }
}
