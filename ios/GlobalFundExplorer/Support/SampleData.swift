import Foundation

/// Made-up grants for SwiftUI previews only. Numbers are illustrative, not real Global Fund data.
enum SampleData {
    static let grants: [Grant] = [
        grant("KEN-H-TNT", "Kenya", "HIV/AIDS", "The National Treasury of Kenya", 2024, 2026, 310, 250, 190),
        grant("KEN-M-AMREF", "Kenya", "Malaria", "Amref Health Africa", 2024, 2026, 95, 70, 51),
        grant("KEN-T-TNT", "Kenya", "Tuberculosis", "The National Treasury of Kenya", 2021, 2023, 60, 60, 58),
        grant("MOZ-C-MOH", "Mozambique", "HIV/TB", "Ministry of Health", 2024, 2026, 520, 380, 260),
        grant("MOZ-M-WV", "Mozambique", "Malaria", "World Vision", 2024, 2026, 150, 110, 80),
        grant("IND-T-CTD", "India", "Tuberculosis", "Central TB Division", 2024, 2026, 180, 120, 90),
    ]

    private static func grant(
        _ number: String, _ country: String, _ component: String, _ pr: String,
        _ startYear: Int, _ endYear: Int, _ signedM: Double, _ committedM: Double, _ disbursedM: Double
    ) -> Grant {
        let calendar = Calendar(identifier: .gregorian)
        return Grant(
            id: number,
            number: number,
            country: country,
            countryCode: nil,
            component: component,
            principalRecipient: pr,
            status: endYear >= 2026 ? "Active" : "Closed",
            grantCycle: startYear >= 2024 ? "GC7" : "GC6",
            startDate: calendar.date(from: DateComponents(year: startYear, month: 1, day: 1)),
            endDate: calendar.date(from: DateComponents(year: endYear, month: 12, day: 31)),
            signed: signedM * 1_000_000,
            committed: committedM * 1_000_000,
            disbursed: disbursedM * 1_000_000
        )
    }
}
