import Foundation

struct SVGDocument {
    var root: SVGElement

    func serialized() -> String {
        root.serialized(level: 0)
    }
}

struct SVGElement {
    var name: String
    var attributes: [SVGAttribute]
    var children: [SVGElement]

    func attribute(_ name: String) -> String? {
        attributes.first { $0.name == name }?.value
    }

    mutating func setAttribute(_ name: String, value: String) {
        if let index = attributes.firstIndex(where: { $0.name == name }) {
            attributes[index].value = value
        } else {
            attributes.append(SVGAttribute(name: name, value: value))
        }
    }

    mutating func removeAttribute(_ name: String) {
        attributes.removeAll { $0.name == name }
    }

    mutating func removeAttribute(_ name: String, matching value: String) {
        attributes.removeAll { $0.name == name && $0.value == value }
        for index in children.indices {
            children[index].removeAttribute(name, matching: value)
        }
    }

    mutating func removeElements(named targetName: String) {
        children.removeAll { $0.name == targetName }
        for index in children.indices {
            children[index].removeElements(named: targetName)
        }
    }

    mutating func flattenEmptyGroups() {
        for index in children.indices {
            children[index].flattenEmptyGroups()
        }

        var flattened: [SVGElement] = []
        for child in children {
            if child.name == "g", child.attributes.isEmpty {
                flattened.append(contentsOf: child.children)
            } else {
                flattened.append(child)
            }
        }
        children = flattened
    }

    func countElements(named targetName: String) -> Int {
        children.reduce(name == targetName ? 1 : 0) { count, child in
            count + child.countElements(named: targetName)
        }
    }

    func unsupportedNodeNames() -> [String] {
        let supported: Set<String> = ["svg", "g", "path"]
        let current = supported.contains(name) ? [] : [name]
        return Array(Set(current + children.flatMap { $0.unsupportedNodeNames() })).sorted()
    }

    func serialized(level: Int) -> String {
        let indent = String(repeating: "  ", count: level)
        let renderedAttributes = attributes
            .map { "\($0.name)=\"\(escapeAttribute($0.value))\"" }
            .joined(separator: " ")
        let tagPrefix = renderedAttributes.isEmpty ? "<\(name)" : "<\(name) \(renderedAttributes)"

        guard !children.isEmpty else {
            return "\(indent)\(tagPrefix)/>"
        }

        let inner = children
            .map { $0.serialized(level: level + 1) }
            .joined(separator: "\n")
        return """
        \(indent)\(tagPrefix)>
        \(inner)
        \(indent)</\(name)>
        """
    }

    private func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

struct SVGAttribute {
    var name: String
    var value: String
}

final class SVGElementBuilder {
    var element: SVGElement
    weak var parent: SVGElementBuilder?
    var children: [SVGElementBuilder] = []

    init(element: SVGElement, parent: SVGElementBuilder?) {
        self.element = element
        self.parent = parent
    }

    func build() -> SVGElement {
        var built = element
        built.children = children.map { $0.build() }
        return built
    }
}
