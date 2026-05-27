import Foundation

struct SVGMarkupModernizer {
    func modernize(_ document: inout SVGDocument) {
        var root = document.root
        let presentation = rootPresentationAttributes(from: root)

        if let fill = presentation.fill {
            for index in root.children.indices {
                root.children[index].removeAttribute("fill", matching: fill)
            }
        }
        if let stroke = presentation.stroke {
            for index in root.children.indices {
                root.children[index].removeAttribute("stroke", matching: stroke)
            }
        }
        for index in root.children.indices {
            root.children[index].removeAttribute("stroke", matching: "none")
        }

        root.attributes = modernRootAttributes(from: root, presentation: presentation)
        root.flattenEmptyGroups()

        document.root = root
    }

    private func modernRootAttributes(from root: SVGElement, presentation: PresentationAttributes) -> [SVGAttribute] {
        var attributes = [
            SVGAttribute(name: "xmlns", value: root.attribute("xmlns") ?? "http://www.w3.org/2000/svg")
        ]

        let resolvedViewBox = root.attribute("viewBox") ?? fallbackViewBoxFromDimensions(root)

        if let viewBox = resolvedViewBox {
            attributes.append(SVGAttribute(name: "viewBox", value: normalizeNumberList(viewBox)))
        }

        let width = normalizedDimension(root.attribute("width"), fallbackFromViewBox: resolvedViewBox, index: 2)
        let height = normalizedDimension(root.attribute("height"), fallbackFromViewBox: resolvedViewBox, index: 3)

        if let width {
            attributes.append(SVGAttribute(name: "width", value: width))
        }
        if let height {
            attributes.append(SVGAttribute(name: "height", value: height))
        }
        if let fill = presentation.fill {
            attributes.append(SVGAttribute(name: "fill", value: fill))
        }
        if let stroke = presentation.stroke, stroke != "none" {
            attributes.append(SVGAttribute(name: "stroke", value: stroke))
        }

        return attributes
    }

    private func fallbackViewBoxFromDimensions(_ root: SVGElement) -> String? {
        guard let width = normalizeSingleNumber(root.attribute("width") ?? ""),
              let height = normalizeSingleNumber(root.attribute("height") ?? "") else {
            return nil
        }
        return "0 0 \(width) \(height)"
    }

    private func rootPresentationAttributes(from root: SVGElement) -> PresentationAttributes {
        guard let firstGroup = root.children.first,
              firstGroup.name == "g" else {
            return PresentationAttributes()
        }

        return PresentationAttributes(
            fill: firstGroup.attribute("fill"),
            stroke: firstGroup.attribute("stroke")
        )
    }

    private func normalizedDimension(_ value: String?, fallbackFromViewBox viewBox: String?, index: Int) -> String? {
        if let value, let normalized = normalizeSingleNumber(value) {
            return normalized
        }
        guard let viewBox else { return nil }
        let values = numericValues(in: viewBox)
        guard values.count == 4 else { return nil }
        return format(values[index])
    }

    private func normalizeSingleNumber(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberText = trimmed.replacingOccurrences(of: #"(?i)(px|pt)$"#, with: "", options: .regularExpression)
        guard let number = Double(numberText) else { return nil }
        return format(number)
    }

    private func normalizeNumberList(_ value: String) -> String {
        let values = numericValues(in: value)
        guard !values.isEmpty else { return value }
        return values.map(format).joined(separator: " ")
    }

    private func numericValues(in value: String) -> [Double] {
        value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .compactMap { Double($0) }
    }
}

struct PresentationAttributes {
    var fill: String?
    var stroke: String?
}
