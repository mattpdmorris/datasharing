import SwiftUI

/// "Powered by Virtual Economics", shown under the app title and on the About screen.
struct PoweredByTagline: View {
    static let text = "Powered by Virtual Economics"

    var body: some View {
        Label(Self.text, systemImage: "sparkles")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}
