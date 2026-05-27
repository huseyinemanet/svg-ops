import Foundation

struct SVGPathBoundsParser {
    func bounds(for path: String) -> Bounds? {
        let tokens = tokenize(path)
        guard !tokens.isEmpty else { return nil }

        var index = 0
        var command: Character?
        var previousCommand: Character?
        var current = Point.zero
        var subpathStart = Point.zero
        var previousCubicControl: Point?
        var previousQuadraticControl: Point?
        var bounds: Bounds?

        func include(_ point: Point) {
            bounds = bounds?.including(point) ?? Bounds(point: point)
        }

        func include(_ curveBounds: Bounds) {
            bounds = bounds?.union(curveBounds) ?? curveBounds
        }

        while index < tokens.count {
            if let letter = tokens[index].command {
                command = letter
                index += 1
            }

            guard let command else { return nil }
            let relative = command.isLowercase

            switch command.uppercased {
            case "M":
                guard let first = readPoint(tokens, &index, relativeTo: relative ? current : nil) else { return bounds }
                current = first
                subpathStart = first
                include(first)
                while let point = readPoint(tokens, &index, relativeTo: relative ? current : nil) {
                    current = point
                    include(point)
                }
                previousCubicControl = nil
                previousQuadraticControl = nil
            case "L", "T":
                if command.uppercased == "T" {
                    while let end = readPoint(tokens, &index, relativeTo: relative ? current : nil) {
                        let control = previousCommand?.uppercased == "Q" || previousCommand?.uppercased == "T"
                            ? current.reflection(of: previousQuadraticControl ?? current)
                            : current
                        include(QuadraticCurve(start: current, control: control, end: end).bounds)
                        current = end
                        previousQuadraticControl = control
                    }
                } else {
                    while let point = readPoint(tokens, &index, relativeTo: relative ? current : nil) {
                        current = point
                        include(point)
                    }
                    previousQuadraticControl = nil
                }
                previousCubicControl = nil
            case "H":
                while let value = readNumber(tokens, &index) {
                    current.x = relative ? current.x + value : value
                    include(current)
                }
                previousCubicControl = nil
                previousQuadraticControl = nil
            case "V":
                while let value = readNumber(tokens, &index) {
                    current.y = relative ? current.y + value : value
                    include(current)
                }
                previousCubicControl = nil
                previousQuadraticControl = nil
            case "C":
                while let first = readPoint(tokens, &index, relativeTo: relative ? current : nil),
                      let second = readPoint(tokens, &index, relativeTo: relative ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: relative ? current : nil) {
                    include(CubicCurve(start: current, first: first, second: second, end: end).bounds)
                    current = end
                    previousCubicControl = second
                    previousQuadraticControl = nil
                }
            case "S":
                while let second = readPoint(tokens, &index, relativeTo: relative ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: relative ? current : nil) {
                    let first = previousCommand?.uppercased == "C" || previousCommand?.uppercased == "S"
                        ? current.reflection(of: previousCubicControl ?? current)
                        : current
                    include(CubicCurve(start: current, first: first, second: second, end: end).bounds)
                    current = end
                    previousCubicControl = second
                    previousQuadraticControl = nil
                }
            case "Q":
                while let control = readPoint(tokens, &index, relativeTo: relative ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: relative ? current : nil) {
                    include(QuadraticCurve(start: current, control: control, end: end).bounds)
                    current = end
                    previousQuadraticControl = control
                    previousCubicControl = nil
                }
            case "A":
                return nil
            case "Z":
                current = subpathStart
                include(current)
                previousCubicControl = nil
                previousQuadraticControl = nil
            default:
                return nil
            }

            previousCommand = command
        }

        return bounds
    }

    private func tokenize(_ path: String) -> [PathToken] {
        let pattern = #"[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:(?:\d*\.\d+)|(?:\d+\.?))(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        return regex.matches(in: path, range: range).compactMap { result in
            guard let range = Range(result.range, in: path) else { return nil }
            let value = String(path[range])
            if value.count == 1, let character = value.first, character.isLetter {
                return .command(character)
            }
            return Double(value).map(PathToken.number)
        }
    }

    private func readPoint(_ tokens: [PathToken], _ index: inout Int, relativeTo origin: Point?) -> Point? {
        guard let x = readNumber(tokens, &index), let y = readNumber(tokens, &index) else { return nil }
        let point = Point(x: x, y: y)
        return origin.map { point.offsetBy($0) } ?? point
    }

    private func readNumber(_ tokens: [PathToken], _ index: inout Int) -> Double? {
        guard index < tokens.count, case .number(let value) = tokens[index] else { return nil }
        index += 1
        return value
    }
}

private struct CubicCurve {
    var start: Point
    var first: Point
    var second: Point
    var end: Point

    var bounds: Bounds {
        var output = Bounds(point: start).including(end)
        for t in extrema(first: start.x, second: first.x, third: second.x, fourth: end.x) {
            output = output.including(point(at: t))
        }
        for t in extrema(first: start.y, second: first.y, third: second.y, fourth: end.y) {
            output = output.including(point(at: t))
        }
        return output
    }

    private func point(at t: Double) -> Point {
        let mt = 1 - t
        return Point(
            x: mt * mt * mt * start.x + 3 * mt * mt * t * first.x + 3 * mt * t * t * second.x + t * t * t * end.x,
            y: mt * mt * mt * start.y + 3 * mt * mt * t * first.y + 3 * mt * t * t * second.y + t * t * t * end.y
        )
    }

    private func extrema(first p0: Double, second p1: Double, third p2: Double, fourth p3: Double) -> [Double] {
        let a = -p0 + 3 * p1 - 3 * p2 + p3
        let b = 2 * (p0 - 2 * p1 + p2)
        let c = -p0 + p1

        if abs(a) < 0.000001 {
            guard abs(b) > 0.000001 else { return [] }
            let t = -c / b
            return (0..<1).contains(t) ? [t] : []
        }

        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return [] }
        let root = sqrt(discriminant)
        return [(-b + root) / (2 * a), (-b - root) / (2 * a)]
            .filter { (0..<1).contains($0) }
    }
}

private struct QuadraticCurve {
    var start: Point
    var control: Point
    var end: Point

    var bounds: Bounds {
        var output = Bounds(point: start).including(end)
        if let t = extrema(first: start.x, second: control.x, third: end.x) {
            output = output.including(point(at: t))
        }
        if let t = extrema(first: start.y, second: control.y, third: end.y) {
            output = output.including(point(at: t))
        }
        return output
    }

    private func point(at t: Double) -> Point {
        let mt = 1 - t
        return Point(
            x: mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x,
            y: mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        )
    }

    private func extrema(first p0: Double, second p1: Double, third p2: Double) -> Double? {
        let denominator = p0 - 2 * p1 + p2
        guard abs(denominator) > 0.000001 else { return nil }
        let t = (p0 - p1) / denominator
        return (0..<1).contains(t) ? t : nil
    }
}

struct SVGTransformParser {
    func parse(_ text: String?) -> SVGTransform? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .identity
        }

        let pattern = #"([A-Za-z]+)\(([^)]*)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return nil }

        var consumed = ""
        var transform = SVGTransform.identity
        for result in matches {
            guard let fullRange = Range(result.range(at: 0), in: text),
                  let nameRange = Range(result.range(at: 1), in: text),
                  let valuesRange = Range(result.range(at: 2), in: text) else {
                return nil
            }
            consumed += text[fullRange]
            let name = String(text[nameRange])
            let values = String(text[valuesRange])
                .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
                .compactMap { Double($0) }
            guard let next = transformFunction(name: name, values: values) else { return nil }
            transform = transform.concatenating(next)
        }

        let strippedInput = text.filter { !$0.isWhitespace && $0 != "," }
        let strippedConsumed = consumed.filter { !$0.isWhitespace && $0 != "," }
        return strippedInput == strippedConsumed ? transform : nil
    }

    private func transformFunction(name: String, values: [Double]) -> SVGTransform? {
        switch name {
        case "translate":
            return SVGTransform(a: 1, b: 0, c: 0, d: 1, e: values.first ?? 0, f: values.dropFirst().first ?? 0)
        case "scale":
            let x = values.first ?? 1
            return SVGTransform(a: x, b: 0, c: 0, d: values.dropFirst().first ?? x, e: 0, f: 0)
        case "matrix" where values.count >= 6:
            return SVGTransform(a: values[0], b: values[1], c: values[2], d: values[3], e: values[4], f: values[5])
        default:
            return nil
        }
    }
}

enum PathToken {
    case command(Character)
    case number(Double)

    var command: Character? {
        if case .command(let command) = self { return command }
        return nil
    }
}

struct SVGTransform {
    var a: Double
    var b: Double
    var c: Double
    var d: Double
    var e: Double
    var f: Double

    static let identity = SVGTransform(a: 1, b: 0, c: 0, d: 1, e: 0, f: 0)

    func apply(to point: Point) -> Point {
        Point(
            x: a * point.x + c * point.y + e,
            y: b * point.x + d * point.y + f
        )
    }

    func concatenating(_ other: SVGTransform) -> SVGTransform {
        SVGTransform(
            a: a * other.a + c * other.b,
            b: b * other.a + d * other.b,
            c: a * other.c + c * other.d,
            d: b * other.c + d * other.d,
            e: a * other.e + c * other.f + e,
            f: b * other.e + d * other.f + f
        )
    }
}

struct Point {
    var x: Double
    var y: Double

    static let zero = Point(x: 0, y: 0)

    func offsetBy(_ origin: Point) -> Point {
        Point(x: origin.x + x, y: origin.y + y)
    }

    func reflection(of control: Point) -> Point {
        Point(x: 2 * x - control.x, y: 2 * y - control.y)
    }
}

struct Bounds {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    init(point: Point) {
        minX = point.x
        minY = point.y
        maxX = point.x
        maxY = point.y
    }

    init?(viewBox: String) {
        let values = viewBox
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        minX = values[0]
        minY = values[1]
        maxX = values[0] + values[2]
        maxY = values[1] + values[3]
    }

    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var viewBoxValue: String { "\(format(minX)) \(format(minY)) \(format(width)) \(format(height))" }

    func sizeValue(_ value: Double) -> String {
        format(value)
    }

    func including(_ point: Point) -> Bounds {
        Bounds(
            minX: min(minX, point.x),
            minY: min(minY, point.y),
            maxX: max(maxX, point.x),
            maxY: max(maxY, point.y)
        )
    }

    func union(_ other: Bounds) -> Bounds {
        Bounds(
            minX: min(minX, other.minX),
            minY: min(minY, other.minY),
            maxX: max(maxX, other.maxX),
            maxY: max(maxY, other.maxY)
        )
    }

    func insetBy(dx: Double, dy: Double) -> Bounds {
        Bounds(minX: minX + dx, minY: minY + dy, maxX: maxX - dx, maxY: maxY - dy)
    }

    func applying(_ transform: SVGTransform) -> Bounds {
        [
            Point(x: minX, y: minY),
            Point(x: maxX, y: minY),
            Point(x: minX, y: maxY),
            Point(x: maxX, y: maxY)
        ].map(transform.apply(to:)).reduce(nil as Bounds?) { partial, point in
            partial?.including(point) ?? Bounds(point: point)
        } ?? self
    }

    private init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    private func format(_ value: Double) -> String {
        SVGNumberFormatter.format(value)
    }
}

enum SVGNumberFormatter {
    static func format(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(format: "%.3f", rounded)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}

func format(_ value: Double) -> String {
    SVGNumberFormatter.format(value)
}

private extension Character {
    var uppercased: String {
        String(self).uppercased()
    }

    var isLowercase: Bool {
        String(self).lowercased() == String(self)
    }
}
