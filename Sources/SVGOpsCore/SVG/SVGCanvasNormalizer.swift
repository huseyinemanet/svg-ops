import Foundation

struct SVGCanvasNormalizer {
    func normalize(_ document: SVGDocument) -> SVGDocument? {
        guard isSafeToCrop(document.root),
              let originalViewBox = document.root.attribute("viewBox"),
              let rootBounds = Bounds(viewBox: originalViewBox),
              let content = contentBounds(in: document.root),
              content.bounds.width > 0,
              content.bounds.height > 0 else {
            return nil
        }

        let padding = max(2, content.maxStrokeWidth / 2 + 2)
        let paddedBounds = content.bounds.insetBy(dx: -padding, dy: -padding)
        guard paddedBounds.width < rootBounds.width * 0.98 || paddedBounds.height < rootBounds.height * 0.98 else {
            return nil
        }

        var normalized = document
        normalized.root.setAttribute("viewBox", value: paddedBounds.viewBoxValue)
        normalized.root.setAttribute("width", value: paddedBounds.sizeValue(paddedBounds.width))
        normalized.root.setAttribute("height", value: paddedBounds.sizeValue(paddedBounds.height))
        return normalized
    }

    func skipReason(for document: SVGDocument) -> String {
        if let unsafe = firstUnsafeNode(in: document.root) {
            return "unsupported node: \(unsafe)"
        }
        if firstUnsafeAttribute(in: document.root) != nil {
            return "unsupported attribute or external reference"
        }
        guard document.root.attribute("viewBox") != nil else {
            return "missing viewBox"
        }
        guard contentBounds(in: document.root) != nil else {
            return "bounds unavailable"
        }
        return "crop not beneficial"
    }

    private func contentBounds(in root: SVGElement) -> ContentBounds? {
        bounds(in: root, transform: .identity, inheritedStrokeWidth: 0)
    }

    private func bounds(in element: SVGElement, transform: SVGTransform, inheritedStrokeWidth: Double) -> ContentBounds? {
        guard let localTransform = SVGTransformParser().parse(element.attribute("transform")) else { return nil }
        let combinedTransform = transform.concatenating(localTransform)
        let strokeWidth = numericLength(element.attribute("stroke-width")) ?? inheritedStrokeWidth

        if element.name == "path" {
            guard let path = element.attribute("d"),
                  let pathBounds = SVGPathBoundsParser().bounds(for: path) else {
                return nil
            }
            return ContentBounds(bounds: pathBounds.applying(combinedTransform), maxStrokeWidth: strokeWidth)
        }

        var output: ContentBounds?
        for child in element.children {
            guard let childBounds = bounds(in: child, transform: combinedTransform, inheritedStrokeWidth: strokeWidth) else {
                return nil
            }
            output = output?.union(childBounds) ?? childBounds
        }
        return output
    }

    private func isSafeToCrop(_ element: SVGElement) -> Bool {
        let unsafeNames: Set<String> = [
            "clipPath", "defs", "filter", "foreignObject", "image", "linearGradient",
            "marker", "mask", "pattern", "radialGradient", "style", "symbol", "text", "use"
        ]

        if unsafeNames.contains(element.name) {
            return false
        }
        if element.name != "svg", element.name != "g", element.name != "path" {
            return false
        }
        if element.attributes.contains(where: isUnsafeAttribute) {
            return false
        }
        return element.children.allSatisfy(isSafeToCrop)
    }

    private func firstUnsafeNode(in element: SVGElement) -> String? {
        let unsafeNames: Set<String> = [
            "clipPath", "defs", "filter", "foreignObject", "image", "linearGradient",
            "marker", "mask", "pattern", "radialGradient", "style", "symbol", "text", "use"
        ]
        if unsafeNames.contains(element.name) {
            return element.name
        }
        if element.name != "svg", element.name != "g", element.name != "path" {
            return element.name
        }
        return element.children.compactMap(firstUnsafeNode).first
    }

    private func firstUnsafeAttribute(in element: SVGElement) -> SVGAttribute? {
        if let attribute = element.attributes.first(where: isUnsafeAttribute) {
            return attribute
        }
        return element.children.compactMap(firstUnsafeAttribute).first
    }

    private func isUnsafeAttribute(_ attribute: SVGAttribute) -> Bool {
        let unsafeNames: Set<String> = ["clip-path", "filter", "href", "mask", "xlink:href"]
        if unsafeNames.contains(attribute.name) {
            return true
        }
        return attribute.value.range(of: "url(", options: .caseInsensitive) != nil
    }

    private func numericLength(_ value: String?) -> Double? {
        guard let value else { return nil }
        let numberText = value.replacingOccurrences(of: #"(?i)(px|pt)$"#, with: "", options: .regularExpression)
        return Double(numberText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct ContentBounds {
    var bounds: Bounds
    var maxStrokeWidth: Double

    func union(_ other: ContentBounds) -> ContentBounds {
        ContentBounds(
            bounds: bounds.union(other.bounds),
            maxStrokeWidth: max(maxStrokeWidth, other.maxStrokeWidth)
        )
    }
}
