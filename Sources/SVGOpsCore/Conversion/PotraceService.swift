import AppKit
import Foundation

struct PotraceService: Sendable {
    private let runner: ShellProcessRunner

    init(runner: ShellProcessRunner = ShellProcessRunner()) {
        self.runner = runner
    }

    func convert(inputURL: URL, settings: ConversionSettings, workingDirectory: URL) async throws -> String {
        let binary = try BinaryLocator.resolve(.potrace)
        let maskURL = workingDirectory.appendingPathComponent("mask.pbm")
        let svgURL = workingDirectory.appendingPathComponent("potrace-output.svg")

        try PotraceMaskPreprocessor().writeMask(
            from: inputURL,
            to: maskURL,
            mode: settings.mode,
            quality: settings.quality
        )

        var arguments = [
            maskURL.path,
            "--svg",
            "--output", svgURL.path,
            "--flat"
        ]
        arguments.append(contentsOf: potraceArguments(for: settings.quality))

        _ = try await runner.run(executable: binary, arguments: arguments, timeout: 90)
        var svg = try String(contentsOf: svgURL, encoding: .utf8)
        svg = applyFill(to: svg, settings: settings)
        return svg
    }

    private func potraceArguments(for quality: ConversionQuality) -> [String] {
        switch quality {
        case .clean:
            ["--turdsize", "8", "--alphamax", "1.0", "--opttolerance", "0.4"]
        case .balanced:
            ["--turdsize", "4", "--alphamax", "1.0", "--opttolerance", "0.2"]
        case .accurate:
            ["--turdsize", "2", "--alphamax", "1.2", "--opttolerance", "0.1"]
        }
    }

    private func applyFill(to svg: String, settings: ConversionSettings) -> String {
        let fill: String
        switch settings.fillMode {
        case .currentColor:
            fill = "currentColor"
        case .original:
            fill = "#000000"
        case .custom:
            fill = settings.customFillHex.isEmpty ? "#000000" : settings.customFillHex
        }

        if svg.contains("fill=\"") {
            return svg.replacingOccurrences(
                of: #"fill="[^"]*""#,
                with: "fill=\"\(fill)\"",
                options: .regularExpression
            )
        }

        return svg.replacingOccurrences(of: "<svg", with: "<svg fill=\"\(fill)\"", options: [], range: svg.range(of: "<svg"))
    }
}

struct PotraceMaskPreprocessor {
    func writeMask(from inputURL: URL, to outputURL: URL, mode: ConversionMode, quality: ConversionQuality) throws {
        guard let image = NSImage(contentsOf: inputURL),
              let rep = ImageAnalysis.bitmapRepresentation(for: image) else {
            throw FileImportError.invalidImage
        }

        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let threshold = thresholdValue(for: quality)
        let minimumNeighbours = minimumNeighboursForNoiseCleanup(for: quality)
        var foreground = Array(repeating: false, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                guard let pixel = ImageAnalysis.samplePixel(in: rep, x: x, y: y) else { continue }
                guard pixel.alpha >= 0.05 else { continue }

                let luminance = 0.2126 * pixel.red + 0.7152 * pixel.green + 0.0722 * pixel.blue
                if mode == .singleColour {
                    foreground[y * width + x] = pixel.alpha > 0.12 && luminance < 0.98
                } else {
                    foreground[y * width + x] = luminance < threshold
                }
            }
        }

        let cleaned = cleanup(foreground, width: width, height: height, minimumNeighbours: minimumNeighbours)
        try writePBM(cleaned, width: width, height: height, to: outputURL)
    }

    private func thresholdValue(for quality: ConversionQuality) -> CGFloat {
        switch quality {
        case .clean: 0.48
        case .balanced: 0.58
        case .accurate: 0.70
        }
    }

    private func minimumNeighboursForNoiseCleanup(for quality: ConversionQuality) -> Int {
        switch quality {
        case .clean: 2
        case .balanced: 1
        case .accurate: 0
        }
    }

    private func cleanup(_ pixels: [Bool], width: Int, height: Int, minimumNeighbours: Int) -> [Bool] {
        guard minimumNeighbours > 0, width > 2, height > 2 else { return pixels }
        var output = pixels

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                guard pixels[index] else { continue }

                var neighbours = 0
                for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        if pixels[(y + dy) * width + (x + dx)] {
                            neighbours += 1
                        }
                    }
                }

                if neighbours < minimumNeighbours {
                    output[index] = false
                }
            }
        }

        return output
    }

    private func writePBM(_ pixels: [Bool], width: Int, height: Int, to url: URL) throws {
        var text = "P1\n\(width) \(height)\n"
        for y in 0..<height {
            var row: [String] = []
            row.reserveCapacity(width)
            for x in 0..<width {
                row.append(pixels[y * width + x] ? "1" : "0")
            }
            text += row.joined(separator: " ")
            text += "\n"
        }
        try text.write(to: url, atomically: true, encoding: .ascii)
    }
}
