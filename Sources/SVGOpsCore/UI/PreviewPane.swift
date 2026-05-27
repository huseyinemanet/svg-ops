import SwiftUI

struct PreviewPane: View {
    var title: String
    var imageURL: URL?
    var svg: String?
    var placeholder: String
    var hidesSVGContent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.34))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.035), radius: 18, y: 8)

                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(28)
                        default:
                            ProgressView()
                        }
                    }
                } else if let svg, !hidesSVGContent {
                    SVGPreviewWebView(svg: svg)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(1)
                } else if svg != nil {
                    Color.clear
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(placeholder)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minHeight: 300)
        }
    }
}
