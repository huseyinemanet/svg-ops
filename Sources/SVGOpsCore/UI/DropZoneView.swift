import SwiftUI

struct DropZoneView: View {
    var isTargeted: Bool
    var chooseAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isTargeted ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.16), lineWidth: 1)
                }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.06), radius: 14, y: 5)

                    Image(systemName: "photo")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                }

                Text(isTargeted ? "Release to add image" : "Drop image here")
                    .font(.title2.weight(.semibold))

                Text(isTargeted ? "PNG, JPG, or WEBP" : "PNG, JPG, WEBP · flat illustrations, icons, line art, or simple 2-3 colour images")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button {
                    chooseAction()
                } label: {
                    Label("Choose File...", systemImage: "plus")
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .padding(.top, 2)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 34)
        .padding(.top, 64)
        .padding(.bottom, 34)
    }
}
