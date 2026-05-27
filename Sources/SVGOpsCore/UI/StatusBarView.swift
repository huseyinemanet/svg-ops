import SwiftUI

struct StatusBarView: View {
    var message: String?
    var isConverting: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isConverting {
                ProgressView()
                    .controlSize(.small)
            }

            Text(message ?? " ")
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .font(.footnote)
        .frame(height: 18)
    }
}
