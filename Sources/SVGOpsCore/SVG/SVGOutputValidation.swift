import Foundation

struct SVGOutputValidator {
    func validate(_ svg: String, comparedTo originalSVG: String) -> SVGValidationResult {
        var warnings: [String] = []

        guard let document = SVGDocumentParser().parse(svg) else {
            return SVGValidationResult(isValid: false, pathCount: 0, viewBox: nil, warnings: ["Optimized SVG could not be parsed."])
        }

        guard document.root.name == "svg" else {
            return SVGValidationResult(isValid: false, pathCount: 0, viewBox: nil, warnings: ["Root element is not svg."])
        }

        let pathCount = document.root.countElements(named: "path")
        let originalPathCount = SVGStatsParser.parse(originalSVG).pathCount
        if originalPathCount > 0, pathCount == 0 {
            warnings.append("Optimized SVG has no paths.")
            return SVGValidationResult(isValid: false, pathCount: pathCount, viewBox: document.root.attribute("viewBox"), warnings: warnings)
        }

        guard let viewBoxText = document.root.attribute("viewBox"),
              let viewBox = Bounds(viewBox: viewBoxText),
              viewBox.width > 0,
              viewBox.height > 0 else {
            warnings.append("SVG viewBox is missing or invalid.")
            return SVGValidationResult(isValid: false, pathCount: pathCount, viewBox: document.root.attribute("viewBox"), warnings: warnings)
        }

        if let width = numericDimension(document.root.attribute("width")),
           abs(width - viewBox.width) > max(0.5, viewBox.width * 0.01) {
            warnings.append("SVG width does not match viewBox width.")
            return SVGValidationResult(isValid: false, pathCount: pathCount, viewBox: viewBoxText, warnings: warnings)
        }

        if let height = numericDimension(document.root.attribute("height")),
           abs(height - viewBox.height) > max(0.5, viewBox.height * 0.01) {
            warnings.append("SVG height does not match viewBox height.")
            return SVGValidationResult(isValid: false, pathCount: pathCount, viewBox: viewBoxText, warnings: warnings)
        }

        if let originalViewBoxText = SVGOutputInspector.viewBox(in: originalSVG),
           let originalViewBox = Bounds(viewBox: originalViewBoxText) {
            if viewBox.width < max(1, originalViewBox.width * 0.002) ||
                viewBox.height < max(1, originalViewBox.height * 0.002) {
                warnings.append("SVG crop is too aggressive.")
                return SVGValidationResult(isValid: false, pathCount: pathCount, viewBox: viewBoxText, warnings: warnings)
            }
        }

        if originalSVG.range(of: #"<(defs|clipPath|mask|filter|pattern|use)\b"#, options: [.regularExpression, .caseInsensitive]) != nil,
           !svg.contains(viewBoxText),
           SVGOutputInspector.viewBox(in: originalSVG) != viewBoxText {
            warnings.append("Complex SVG structure changed unexpectedly.")
            return SVGValidationResult(isValid: false, pathCount: pathCount, viewBox: viewBoxText, warnings: warnings)
        }

        return SVGValidationResult(isValid: true, pathCount: pathCount, viewBox: viewBoxText, warnings: warnings)
    }

    private func numericDimension(_ value: String?) -> Double? {
        guard let value else { return nil }
        let numberText = value.replacingOccurrences(of: #"(?i)(px|pt)$"#, with: "", options: .regularExpression)
        return Double(numberText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct SVGValidationResult {
    var isValid: Bool
    var pathCount: Int
    var viewBox: String?
    var warnings: [String]
}

enum SVGOutputInspector {
    static func viewBox(in svg: String) -> String? {
        guard let svgTagRange = svg.range(of: #"<svg\b[^>]*>"#, options: .regularExpression) else {
            return nil
        }

        let tag = String(svg[svgTagRange])
        guard let regex = try? NSRegularExpression(pattern: #"\bviewBox="([^"]*)""#),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..<tag.endIndex, in: tag)),
              let range = Range(match.range(at: 1), in: tag) else {
            return nil
        }

        return String(tag[range])
    }
}
