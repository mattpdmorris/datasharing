import Foundation

enum Fmt {
    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_AU")
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    /// A figure in K million exactly as the source prints it: "K16,133.5m".
    static func kinaMillions(_ v: Double?) -> String {
        guard let v else { return "—" }
        let s = grouped.string(from: NSNumber(value: abs(v))) ?? String(format: "%.1f", abs(v))
        return (v < 0 ? "−" : "") + "K" + s + "m"
    }

    /// Compact headline form: "K16.1bn", "K905m".
    static func kinaShort(_ v: Double?) -> String {
        guard let v else { return "—" }
        let sign = v < 0 ? "−" : ""
        let a = abs(v)
        if a >= 1000 { return sign + "K" + String(format: "%.1f", a / 1000) + "bn" }
        if a >= 10 { return sign + "K" + String(format: "%.0f", a) + "m" }
        return sign + "K" + String(format: "%.1f", a) + "m"
    }

    static func lens(_ v: Double?, _ lens: Lens) -> String {
        guard let v else { return "—" }
        switch lens {
        case .gdp: return (v < 0 ? "−" : "") + String(format: "%.1f", abs(v)) + "% of GDP"
        case .nominal, .real: return kinaShort(v)
        }
    }

    static func percent(_ v: Double?, digits: Int = 0) -> String {
        guard let v else { return "—" }
        return String(format: "%.\(digits)f%%", v * 100)
    }

    static func signedKina(_ v: Double) -> String {
        (v > 0 ? "+" : "") + kinaMillions(v)
    }

    /// "2021 — 2021 Budget — Volume 1 - Economic and Development Policies.pdf"
    /// → "2021 Budget, Volume 1"; Final Budget Outcomes → "2021 Final Budget Outcome".
    static func shortDoc(_ doc: String?) -> String {
        guard var d = doc, !d.isEmpty else { return "Unknown document" }
        if d.lowercased().hasSuffix(".pdf") { d.removeLast(4) }
        let lower = d.lowercased()
        let year = d.prefix(4).allSatisfy(\.isNumber) ? String(d.prefix(4)) + " " : ""
        if lower.contains(" fbo ") || lower.contains("final budget outcome") {
            return year + "Final Budget Outcome"
        }
        if let r = lower.range(of: #"volume\s*[0-9]+[a-d]?"#, options: .regularExpression) {
            let num = lower[r].replacingOccurrences(of: "volume", with: "")
                .trimmingCharacters(in: .whitespaces).uppercased()
            return year + "Budget, Volume " + num
        }
        let parts = d.components(separatedBy: " — ")
        return parts.count >= 2 ? parts.dropFirst().joined(separator: " — ") : d
    }
}
