import SwiftUI

/// The app-wide "show figures as" control. Changing it here changes every tab.
struct LensPicker: View {
    @Environment(DataStore.self) private var store
    var showNote = true

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 8) {
            Picker("Show as", selection: $store.lens) {
                ForEach(Lens.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(store.anu == nil)

            if store.lens == .real {
                Picker("Price index", selection: $store.deflator) {
                    ForEach(Deflator.allCases) { Text($0.title).tag($0) }
                }
                .font(.subheadline)
            }
            if store.anu == nil {
                Explainer(text: "ANU denominators are not bundled, so only printed kina can be shown.")
            } else if showNote && store.lens != .nominal {
                Explainer(text: store.lensNote)
            }
        }
    }
}

/// Small marker for figures whose ANU denominator is an estimate or projection.
struct ProvisionalMark: View {
    var body: some View {
        Text("e")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .accessibilityLabel("denominator is an estimate or projection")
    }
}
