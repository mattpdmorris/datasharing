import SwiftUI

/// One rectangle in a treemap.
struct TreemapItem: Identifiable, Hashable {
    let id: String
    let label: String
    let detail: String
    let value: Double
    let color: Color
}

/// A squarified treemap (Bruls, Huizing & van Wijk): tiles are laid out in rows
/// whose aspect ratios stay close to square, largest first. Swift Charts has no
/// treemap mark, so this is drawn directly.
struct Treemap: View {
    let items: [TreemapItem]
    var onTap: (TreemapItem) -> Void = { _ in }

    private struct Placed: Identifiable {
        let item: TreemapItem
        let rect: CGRect
        var id: String { item.id }
    }

    var body: some View {
        GeometryReader { geo in
            let positive = items.filter { $0.value > 0 }.sorted { $0.value > $1.value }
            let rects = Treemap.squarify(positive.map(\.value),
                                         in: CGRect(origin: .zero, size: geo.size))
            let tiles = zip(positive, rects).map { Placed(item: $0.0, rect: $0.1) }
            ZStack(alignment: .topLeading) {
                ForEach(tiles) { t in
                    tile(t.item, t.rect)
                }
            }
        }
    }

    private func tile(_ item: TreemapItem, _ rect: CGRect) -> some View {
        let big = rect.width > 70 && rect.height > 38
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(item.color)
            .overlay(alignment: .topLeading) {
                if big {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.label)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(rect.height > 60 ? 3 : 1)
                        Text(item.detail)
                            .font(.caption2.monospacedDigit())
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(4)
                }
            }
            .frame(width: max(rect.width - 2, 0), height: max(rect.height - 2, 0))
            .offset(x: rect.minX + 1, y: rect.minY + 1)
            .contentShape(Rectangle())
            .onTapGesture { onTap(item) }
            .accessibilityElement()
            .accessibilityLabel("\(item.label), \(item.detail)")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: Squarified layout

    /// Rectangles for `values` (sorted largest first), filling `rect`.
    static func squarify(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else { return values.map { _ in .zero } }
        let scale = Double(rect.width * rect.height) / total
        var areas = values.map { $0 * scale }[...]
        var out: [CGRect] = []
        var remaining = rect
        var row: [Double] = []

        func worst(_ row: [Double], _ side: Double) -> Double {
            guard let mx = row.max(), let mn = row.min(), mn > 0 else { return .infinity }
            let s = row.reduce(0, +)
            return max(side * side * mx / (s * s), (s * s) / (side * side * mn))
        }

        func place(_ row: [Double]) {
            let s = row.reduce(0, +)
            if remaining.width >= remaining.height {
                // Column on the left.
                let w = CGFloat(s / Double(remaining.height))
                var y = remaining.minY
                for a in row {
                    let h = CGFloat(a) / w
                    out.append(CGRect(x: remaining.minX, y: y, width: w, height: h))
                    y += h
                }
                remaining = CGRect(x: remaining.minX + w, y: remaining.minY,
                                   width: remaining.width - w, height: remaining.height)
            } else {
                // Row along the top.
                let h = CGFloat(s / Double(remaining.width))
                var x = remaining.minX
                for a in row {
                    let w = CGFloat(a) / h
                    out.append(CGRect(x: x, y: remaining.minY, width: w, height: h))
                    x += w
                }
                remaining = CGRect(x: remaining.minX, y: remaining.minY + h,
                                   width: remaining.width, height: remaining.height - h)
            }
        }

        while let next = areas.first {
            let side = Double(min(remaining.width, remaining.height))
            if row.isEmpty || worst(row + [next], side) <= worst(row, side) {
                row.append(next)
                areas = areas.dropFirst()
            } else {
                place(row)
                row = []
            }
        }
        if !row.isEmpty { place(row) }
        return out
    }
}
