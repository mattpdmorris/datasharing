import SwiftUI

/// A headline number with a caption and optional footnote.
struct StatTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Where a figure came from: document, page, table and column.
struct SourceLine: View {
    let reading: Reading

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                Text(Fmt.shortDoc(reading.doc))
                if let page = reading.page { Text("· p. \(page)") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let t = reading.table ?? reading.cell {
                Text(t + (reading.column.map { " — \($0)" } ?? ""))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A labelled figure with its full provenance underneath.
struct ReadingRow: View {
    let title: String
    let reading: Reading
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text(Fmt.kinaMillions(reading.value))
                    .font(.body.monospacedDigit().weight(.medium))
            }
            SourceLine(reading: reading)
            HStack(spacing: 6) {
                if reading.isDerivedOnly { FlagBadge(text: "Derived — not printed", style: .caution) }
                if let flag = reading.flag, flag != "OK" { FlagBadge(flag: flag) }
                if let v = reading.verdict { FlagBadge(verdict: v) }
            }
            if let note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct FlagBadge: View {
    enum Style { case ok, info, caution, alert }
    let text: String
    let style: Style

    init(text: String, style: Style) { self.text = text; self.style = style }

    init(flag: String) {
        switch flag.uppercased() {
        case "OK": self.init(text: "Checked", style: .ok)
        case "ROUNDING": self.init(text: "Rounding difference", style: .info)
        case "UNCHECKED": self.init(text: "Not cross-checked", style: .info)
        default: self.init(text: flag.capitalized, style: .caution)
        }
    }

    init(verdict: String) {
        switch verdict {
        case "match": self.init(text: "Matches", style: .ok)
        case "rounding": self.init(text: "Rounding", style: .info)
        case "revised": self.init(text: "Revised later", style: .caution)
        case "sign": self.init(text: "Sign error in source", style: .alert)
        default: self.init(text: verdict.capitalized, style: .caution)
        }
    }

    private var color: Color {
        switch style {
        case .ok: .green
        case .info: .blue
        case .caution: .orange
        case .alert: .red
        }
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// A short explanatory paragraph shown under section headers.
struct Explainer: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
