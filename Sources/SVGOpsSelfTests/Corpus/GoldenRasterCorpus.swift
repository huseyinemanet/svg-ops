import AppKit
import Foundation
import ImageIO
import SVGOpsCore
import UniformTypeIdentifiers

struct GoldenRasterFixture {
    var name: String
    var url: URL
    var settings: ConversionSettings
    var minimumPaths: Int
    var maximumPaths: Int
    var maximumBytes: Int
    var cropAllowed: Bool
    var expectedColourCount: Int?
}

struct GoldenManifest: Decodable {
    var fixtures: [GoldenManifestFixture]
}

struct GoldenManifestFixture: Decodable {
    var name: String
    var source: String
    var format: String
    var mode: String
    var quality: String
    var fill: String
    var minPaths: Int
    var maxPaths: Int
    var maxBytes: Int
    var cropAllowed: Bool
    var expectedColourCount: Int?
    var optional: Bool?
}

enum GoldenManifestError: Error {
    case missingManifest(URL)
    case invalidMode(String)
    case invalidQuality(String)
    case invalidFill(String)
    case unknownGeneratedSource(String)
}

struct GoldenRasterCorpus {
    func makeFixtures() throws -> [GoldenRasterFixture] {
        let manifestURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tests/Fixtures/GoldenImages/manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw GoldenManifestError.missingManifest(manifestURL)
        }

        let manifest = try JSONDecoder().decode(GoldenManifest.self, from: Data(contentsOf: manifestURL))
        let manifestFolder = manifestURL.deletingLastPathComponent()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("svg-ops-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var fixtures: [GoldenRasterFixture] = []
        for entry in manifest.fixtures {
            do {
                fixtures.append(try make(entry, manifestFolder: manifestFolder, outputFolder: folder))
            } catch {
                if entry.optional == true {
                    print("SKIP \(entry.name): fixture could not be prepared")
                } else {
                    throw error
                }
            }
        }
        return fixtures
    }

    private func make(_ entry: GoldenManifestFixture, manifestFolder: URL, outputFolder: URL) throws -> GoldenRasterFixture {
        guard let mode = ConversionMode(rawValue: entry.mode) else {
            throw GoldenManifestError.invalidMode(entry.mode)
        }
        guard let quality = ConversionQuality(rawValue: entry.quality) else {
            throw GoldenManifestError.invalidQuality(entry.quality)
        }
        guard let fill = FillMode(rawValue: entry.fill) else {
            throw GoldenManifestError.invalidFill(entry.fill)
        }

        let url: URL
        if entry.source.hasPrefix("generated:") {
            let recipe = String(entry.source.dropFirst("generated:".count))
            url = try makeGenerated(recipe: recipe, name: entry.name, ext: entry.format, folder: outputFolder)
        } else {
            url = manifestFolder.appendingPathComponent(entry.source)
        }

        return GoldenRasterFixture(
            name: entry.name,
            url: url,
            settings: ConversionSettings(
                mode: mode,
                quality: quality,
                fillMode: fill,
                customFillHex: "#000000",
                outputFilenameSuffix: ".vector"
            ),
            minimumPaths: entry.minPaths,
            maximumPaths: entry.maxPaths,
            maximumBytes: entry.maxBytes,
            cropAllowed: entry.cropAllowed,
            expectedColourCount: entry.expectedColourCount
        )
    }

    private func makeGenerated(recipe: String, name: String, ext: String, folder: URL) throws -> URL {
        switch recipe {
        case "line-art":
            return try make(name, ext: ext, folder: folder) { drawLineArt() }.url
        case "single-colour":
            return try make(name, ext: ext, folder: folder) { drawSingleColourMark() }.url
        case "thick-fill":
            return try make(name, ext: ext, folder: folder) { drawThickFill() }.url
        case "small-icon":
            return try make(name, ext: ext, folder: folder) { drawSmallIcon() }.url
        case "large-empty-canvas":
            return try make(name, ext: ext, folder: folder) { drawSmallIcon(offset: 70) }.url
        case "thin-line":
            return try make(name, ext: ext, folder: folder) { drawLineArt(lineWidth: 2) }.url
        case "two-colour":
            return try make(name, ext: ext, folder: folder) { drawTwoColourBlocks() }.url
        case "three-colour":
            return try make(name, ext: ext, folder: folder) { drawThreeColourEditorial() }.url
        case "alpha-icon":
            return try make(name, ext: ext, folder: folder, transparent: true) { drawSingleColourMark() }.url
        case "diagonal-line":
            return try make(name, ext: ext, folder: folder) { drawDiagonalLine() }.url
        case "three-colour-icon":
            return try make(name, ext: ext, folder: folder) { drawThreeColourIcon() }.url
        default:
            throw GoldenManifestError.unknownGeneratedSource(recipe)
        }
    }

    private func make(
        _ name: String,
        ext: String,
        folder: URL,
        transparent: Bool = false,
        draw: () -> Void
    ) throws -> GoldenRasterFixture {
        let url = folder.appendingPathComponent("\(name).\(ext)")
        let image = NSImage(size: NSSize(width: 220, height: 220))
        image.lockFocus()
        if transparent {
            NSColor.clear.setFill()
        } else {
            NSColor.white.setFill()
        }
        NSRect(x: 0, y: 0, width: 220, height: 220).fill()
        draw()
        image.unlockFocus()

        try write(image: image, to: url, ext: ext)
        return GoldenRasterFixture(
            name: name,
            url: url,
            settings: .defaults,
            minimumPaths: 1,
            maximumPaths: 250,
            maximumBytes: 180_000,
            cropAllowed: true,
            expectedColourCount: nil
        )
    }

    private func write(image: NSImage, to url: URL, ext: String) throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw CocoaError(.fileWriteUnknown)
        }

        switch ext {
        case "jpg":
            guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url)
        case "webp":
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.webP.identifier as CFString, 1, nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw CocoaError(.fileWriteUnknown)
            }
        default:
            guard let data = rep.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url)
        }
    }

    static func isReasonableViewBox(_ viewBox: String) -> Bool {
        let values = viewBox
            .split { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" }
            .compactMap { Double($0) }
        guard values.count == 4 else { return false }
        return values[2] > 0 && values[3] > 0 && values[2] < 2_000 && values[3] < 2_000
    }

    private func drawLineArt(lineWidth: CGFloat = 4) {
        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.move(to: NSPoint(x: 42, y: 60))
        path.curve(to: NSPoint(x: 178, y: 72), controlPoint1: NSPoint(x: 72, y: 126), controlPoint2: NSPoint(x: 138, y: 124))
        path.move(to: NSPoint(x: 58, y: 74))
        path.line(to: NSPoint(x: 92, y: 146))
        path.move(to: NSPoint(x: 112, y: 154))
        path.line(to: NSPoint(x: 168, y: 152))
        path.stroke()
    }

    private func drawSingleColourMark() {
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 68, y: 70, width: 84, height: 84)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 92, y: 94, width: 36, height: 36)).fill()
    }

    private func drawThickFill() {
        NSColor.black.setFill()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 48, y: 52))
        path.line(to: NSPoint(x: 172, y: 72))
        path.line(to: NSPoint(x: 152, y: 160))
        path.line(to: NSPoint(x: 74, y: 148))
        path.close()
        path.fill()
    }

    private func drawSmallIcon(offset: CGFloat = 0) {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 80 + offset, y: 86, width: 28, height: 28), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: 112 + offset, y: 118, width: 30, height: 30), xRadius: 6, yRadius: 6).fill()
    }

    private func drawTwoColourBlocks() {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 48, y: 72, width: 88, height: 74), xRadius: 12, yRadius: 12).fill()
        NSColor(calibratedRed: 0.88, green: 0.03, blue: 0.03, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 104, y: 92, width: 66, height: 66)).fill()
    }

    private func drawThreeColourEditorial() {
        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 5
        path.move(to: NSPoint(x: 38, y: 68))
        path.curve(to: NSPoint(x: 182, y: 76), controlPoint1: NSPoint(x: 90, y: 150), controlPoint2: NSPoint(x: 138, y: 34))
        path.stroke()
        NSColor(calibratedRed: 0.1, green: 0.35, blue: 0.95, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 54, y: 120, width: 48, height: 48)).fill()
        NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 124, y: 92, width: 54, height: 42), xRadius: 8, yRadius: 8).fill()
    }

    private func drawDiagonalLine() {
        NSColor.black.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 3
        path.move(to: NSPoint(x: 42, y: 46))
        path.line(to: NSPoint(x: 178, y: 174))
        path.stroke()
    }

    private func drawThreeColourIcon() {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 68, width: 54, height: 54), xRadius: 10, yRadius: 10).fill()
        NSColor(calibratedRed: 0.1, green: 0.46, blue: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 92, y: 106, width: 58, height: 58), xRadius: 12, yRadius: 12).fill()
        NSColor(calibratedRed: 0.95, green: 0.25, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 132, y: 70, width: 42, height: 42)).fill()
    }
}
