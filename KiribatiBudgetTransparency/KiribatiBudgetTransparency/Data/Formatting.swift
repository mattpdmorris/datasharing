import Foundation

enum Fmt {
    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_AU")
        f.maximumFractionDigits = 0
        return f
    }()

    /// A whole-dollar figure exactly as printed: "A$402,466,591".
    static func dollars(_ v: Double?) -> String {
        guard let v else { return "—" }
        let s = grouped.string(from: NSNumber(value: abs(v).rounded())) ?? String(format: "%.0f", abs(v))
        return (v < 0 ? "−" : "") + "A$" + s
    }

    /// Compact form: "A$402.5m", "A$845k".
    static func short(_ v: Double?) -> String {
        guard let v else { return "—" }
        let sign = v < 0 ? "−" : ""
        let a = abs(v)
        if a >= 1_000_000_000 { return sign + "A$" + String(format: "%.2f", a / 1e9) + "bn" }
        if a >= 10_000_000 { return sign + "A$" + String(format: "%.0f", a / 1e6) + "m" }
        if a >= 1_000_000 { return sign + "A$" + String(format: "%.1f", a / 1e6) + "m" }
        if a >= 1_000 { return sign + "A$" + String(format: "%.0f", a / 1e3) + "k" }
        return sign + "A$" + String(format: "%.0f", a)
    }

    static func lens(_ v: Double?, _ lens: Lens) -> String {
        guard let v else { return "—" }
        let fmt = abs(v) < 1 ? "%.2f" : (abs(v) < 10 ? "%.1f" : "%.0f")
        let pct = (v < 0 ? "−" : "") + String(format: fmt, abs(v)) + "%"
        switch lens {
        case .gdp: return pct + " of GDP"
        case .share: return pct + " of spending"
        case .nominal, .real: return short(v)
        }
    }

    static func axis(_ v: Double, _ lens: Lens) -> String {
        lens.isPercent ? String(format: "%.0f%%", v) : short(v)
    }

    static func percent(_ v: Double?, digits: Int = 0) -> String {
        guard let v else { return "—" }
        return String(format: "%.\(digits)f%%", v * 100)
    }

    static func signed(_ v: Double) -> String {
        (v > 0 ? "+" : "") + dollars(v)
    }

    /// "L0 — Evidence/Budget & Fiscal/2025/Recurrent Budget — 2025 Recurrent Budget (as approved December 2024).pdf"
    /// → "2025 Recurrent Budget (as approved December 2024)".
    static func shortDoc(_ path: String?) -> String {
        guard var d = path, !d.isEmpty else { return "Budget volume" }
        if let slash = d.lastIndex(of: "/") { d = String(d[d.index(after: slash)...]) }
        if d.lowercased().hasSuffix(".pdf") { d.removeLast(4) }
        let parts = d.components(separatedBy: " — ")
        return parts.count >= 2 ? parts.dropFirst().joined(separator: " — ") : d
    }
}
