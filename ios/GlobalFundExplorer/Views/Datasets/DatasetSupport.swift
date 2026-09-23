import SwiftUI
import Charts

/// Loads a value once when the view appears, showing a spinner, the content, or
/// an error with a retry button.
struct AsyncContent<Value, Content: View>: View {
    private let load: () async throws -> Value
    private let content: (Value) -> Content

    @State private var result: Result<Value, Error>?
    @State private var started = false

    init(load: @escaping () async throws -> Value, @ViewBuilder content: @escaping (Value) -> Content) {
        self.load = load
        self.content = content
    }

    var body: some View {
        Group {
            switch result {
            case .none:
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let value)?:
                content(value)
            case .failure(let error)?:
                ContentUnavailableView {
                    Label("Couldn't load data", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try again") { Task { await run() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            guard !started else { return }
            started = true
            await run()
        }
    }

    private func run() async {
        result = nil
        do {
            result = .success(try await load())
        } catch {
            result = .failure(error)
        }
    }
}

extension View {
    /// Y axis labelled "$1.2B" style.
    func usdYAxis() -> some View {
        chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount.usdCompact) }
                }
            }
        }
    }

    /// X axis labelled "$1.2B" style, for horizontal bar charts.
    func usdXAxis() -> some View {
        chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount.usdCompact) }
                }
            }
        }
    }
}

/// Horizontal bar chart plus a list with each row's share of the total.
struct AmountBreakdownList: View {
    let rows: [AmountRow]
    let chartTitle: String
    let footnote: String

    private var total: Double { rows.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            Section {
                Chart(rows.prefix(8)) { row in
                    BarMark(
                        x: .value("USD", row.amount),
                        y: .value("Category", row.label)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .usdXAxis()
                .frame(height: CGFloat(min(rows.count, 8)) * 36 + 40)
                .padding(.vertical, 8)
            } header: {
                Text(chartTitle)
            } footer: {
                Text(footnote)
            }

            Section {
                ForEach(rows) { row in
                    LabeledContent {
                        VStack(alignment: .trailing) {
                            Text(row.amount.usdCompact).monospacedDigit()
                            if total > 0 {
                                Text((row.amount / total).percent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        Text(row.label)
                    }
                }
                LabeledContent {
                    Text(total.usdCompact).bold().monospacedDigit()
                } label: {
                    Text("Total").bold()
                }
            }
        }
    }
}

