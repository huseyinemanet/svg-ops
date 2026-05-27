import SwiftUI

public struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    public init() { }

    public var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                AppMark()

                VStack(spacing: 5) {
                    Text("SVG Ops")
                        .font(.system(size: 28, weight: .semibold))

                    Text("Flat PNG, JPG, and WEBP in. Clean SVG out.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                InfoRow(label: "Version", value: "\(version) (\(build))")
                InfoRow(label: "Designed and developed by", value: "yaba.studio")
                InfoRow(label: "Year", value: "2026")
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.44))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    }
            }

            Text("Local personal utility. No cloud, no account, no uploads.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 30)
        .padding(.top, 42)
        .padding(.bottom, 28)
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 74, height: 74)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 16, y: 7)

            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

private struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
