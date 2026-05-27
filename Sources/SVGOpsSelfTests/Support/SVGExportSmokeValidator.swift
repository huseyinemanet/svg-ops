import Foundation
import SVGOpsCore

enum SVGExportSmokeValidator {
    static func validate(_ svg: String, expectedPathCount: Int, expectedViewBox: String?) -> [String] {
        var failures: [String] = []
        let trimmed = svg.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.hasPrefix("<svg ") {
            failures.append("export root is not modern <svg> markup")
        }
        if !trimmed.hasSuffix("</svg>") {
            failures.append("export is missing closing svg tag")
        }
        if trimmed.contains("<?xml") || trimmed.contains("<!DOCTYPE") {
            failures.append("export contains legacy XML or DOCTYPE header")
        }

        let pathCount = SVGStatsParser.parse(trimmed).pathCount
        if pathCount != expectedPathCount || pathCount == 0 {
            failures.append("export path count is invalid")
        }

        guard let viewBox = attribute("viewBox", in: trimmed) else {
            failures.append("export is missing viewBox")
            return failures
        }
        if let expectedViewBox, expectedViewBox != viewBox {
            failures.append("export viewBox does not match quality report")
        }

        let values = numericValues(in: viewBox)
        if values.count != 4 || values[2] <= 0 || values[3] <= 0 {
            failures.append("export viewBox is not a positive rectangle")
        }

        if let width = numericAttribute("width", in: trimmed),
           let height = numericAttribute("height", in: trimmed),
           values.count == 4 {
            if abs(width - values[2]) > max(1, values[2] * 0.02) {
                failures.append("export width does not match viewBox width")
            }
            if abs(height - values[3]) > max(1, values[3] * 0.02) {
                failures.append("export height does not match viewBox height")
            }
        }

        return failures
    }

    private static func attribute(_ name: String, in svg: String) -> String? {
        guard let rootEnd = svg.firstIndex(of: ">") else { return nil }
        let root = String(svg[..<rootEnd])
        let marker = "\(name)=\""
        guard let start = root.range(of: marker)?.upperBound,
              let end = root[start...].firstIndex(of: "\"") else {
            return nil
        }
        return String(root[start..<end])
    }

    private static func numericAttribute(_ name: String, in svg: String) -> Double? {
        guard let value = attribute(name, in: svg) else { return nil }
        let number = value.replacingOccurrences(
            of: #"(?i)(px|pt)$"#,
            with: "",
            options: .regularExpression
        )
        return Double(number.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func numericValues(in text: String) -> [Double] {
        text
            .split { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" }
            .compactMap { Double($0) }
    }
}
