import SwiftUI

struct ResultActionsView: View {
    var result: ConversionResult?
    var copied: Bool
    var copyAction: () -> Void
    var saveAction: () -> Void
    var revealAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let result {
                stat("\(result.stats.pathCount)", "paths")
                stat(result.stats.formattedSize, nil)
                if let colourCount = result.stats.colourCount {
                    stat("\(colourCount)", "colours")
                }
            }

            Spacer()

            Button {
                copyAction()
            } label: {
                Text("Copy")
            }
            .disabled(result == nil)
            .buttonStyle(.bordered)

            Button {
                saveAction()
            } label: {
                Text("Save")
            }
            .disabled(result == nil)
            .buttonStyle(.bordered)

            if result?.savedURL != nil {
                Button("Reveal in Finder", action: revealAction)
                    .buttonStyle(.bordered)
            }
        }
        .font(.callout)
        .padding(.horizontal, 2)
    }

    private func stat(_ value: String, _ label: String?) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .fontWeight(.semibold)
            if let label {
                Text(label)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
