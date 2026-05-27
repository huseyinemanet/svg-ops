import Foundation

public struct SVGStats: Equatable, Sendable {
    public var pathCount: Int
    public var byteSize: Int
    public var colourCount: Int?

    public init(pathCount: Int, byteSize: Int, colourCount: Int?) {
        self.pathCount = pathCount
        self.byteSize = byteSize
        self.colourCount = colourCount
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }
}

public enum SVGStatsParser {
    public static func parse(_ svg: String) -> SVGStats {
        let pathCount = matches(in: svg, pattern: #"<\s*path\b"#).count
        let colours = Set(matches(in: svg, pattern: #"#[0-9A-Fa-f]{3,8}\b|currentColor\b"#).map {
            $0.lowercased()
        })

        return SVGStats(
            pathCount: pathCount,
            byteSize: svg.data(using: .utf8)?.count ?? svg.utf8.count,
            colourCount: colours.isEmpty ? nil : colours.count
        )
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}
