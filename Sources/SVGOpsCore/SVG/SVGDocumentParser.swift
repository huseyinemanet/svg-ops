import Foundation

struct SVGDocumentParser {
    func parse(_ svg: String) -> SVGDocument? {
        var scanner = SVGTagScanner(svg)
        var root: SVGElementBuilder?
        var current: SVGElementBuilder?
        var lastTagEnd = svg.startIndex

        while let tag = scanner.nextTag() {
            let textBetweenTags = svg[lastTagEnd..<tag.range.lowerBound]
            guard textBetweenTags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            lastTagEnd = tag.range.upperBound

            if tag.isIgnorable {
                continue
            }

            if tag.isClosing {
                guard current?.element.name == tag.name else { return nil }
                current = current?.parent
                continue
            }

            guard let element = SVGTagParser().parse(tag.raw) else { return nil }
            let builder = SVGElementBuilder(element: element, parent: current)

            if let current {
                current.children.append(builder)
            } else if root == nil, element.name == "svg" {
                root = builder
            } else {
                return nil
            }

            if !tag.isSelfClosing {
                current = builder
            }
        }

        let trailingText = svg[lastTagEnd...]
        guard trailingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              current == nil,
              let root else {
            return nil
        }

        return SVGDocument(root: root.build())
    }
}

struct SVGTag {
    var raw: String
    var range: Range<String.Index>

    var isIgnorable: Bool {
        raw.hasPrefix("<?") || raw.hasPrefix("<!") || raw.hasPrefix("<!--")
    }

    var isClosing: Bool {
        raw.hasPrefix("</")
    }

    var isSelfClosing: Bool {
        raw.dropLast().trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/")
    }

    var name: String {
        let trimmed = raw
            .dropFirst(isClosing ? 2 : 1)
            .dropLast()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "/" }.first.map(String.init) ?? ""
    }
}

struct SVGTagScanner {
    private let svg: String
    private var index: String.Index

    init(_ svg: String) {
        self.svg = svg
        index = svg.startIndex
    }

    mutating func nextTag() -> SVGTag? {
        guard let open = svg[index...].firstIndex(of: "<") else { return nil }
        var cursor = svg.index(after: open)
        var quote: Character?

        while cursor < svg.endIndex {
            let character = svg[cursor]
            if character == "\"" || character == "'" {
                quote = quote == nil ? character : (quote == character ? nil : quote)
            } else if character == ">", quote == nil {
                let end = svg.index(after: cursor)
                let range = open..<end
                index = end
                return SVGTag(raw: String(svg[range]), range: range)
            }
            cursor = svg.index(after: cursor)
        }

        return nil
    }
}

struct SVGTagParser {
    func parse(_ raw: String) -> SVGElement? {
        var content = raw.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasSuffix("/") {
            content = content.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let nameEnd = content.firstIndex(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) else {
            return SVGElement(name: String(content), attributes: [], children: [])
        }

        let name = String(content[..<nameEnd])
        let attributeText = String(content[nameEnd...])
        return SVGElement(name: name, attributes: parseAttributes(attributeText), children: [])
    }

    private func parseAttributes(_ text: String) -> [SVGAttribute] {
        var attributes: [SVGAttribute] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            while cursor < text.endIndex, text[cursor].isWhitespace {
                cursor = text.index(after: cursor)
            }
            guard cursor < text.endIndex else { break }

            let nameStart = cursor
            while cursor < text.endIndex, text[cursor] != "=", !text[cursor].isWhitespace {
                cursor = text.index(after: cursor)
            }
            let name = String(text[nameStart..<cursor])

            while cursor < text.endIndex, text[cursor].isWhitespace {
                cursor = text.index(after: cursor)
            }
            guard cursor < text.endIndex, text[cursor] == "=" else { break }
            cursor = text.index(after: cursor)

            while cursor < text.endIndex, text[cursor].isWhitespace {
                cursor = text.index(after: cursor)
            }
            guard cursor < text.endIndex, text[cursor] == "\"" || text[cursor] == "'" else { break }

            let quote = text[cursor]
            cursor = text.index(after: cursor)
            let valueStart = cursor
            while cursor < text.endIndex, text[cursor] != quote {
                cursor = text.index(after: cursor)
            }
            guard cursor < text.endIndex else { break }

            attributes.append(SVGAttribute(name: name, value: String(text[valueStart..<cursor])))
            cursor = text.index(after: cursor)
        }

        return attributes
    }
}
