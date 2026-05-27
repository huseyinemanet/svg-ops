import AppKit
import Foundation

public struct ImageAnalysisResult: Equatable, Sendable {
    public var approximateDominantColourCount: Int
    public var isMostlyBlackAndWhite: Bool
    public var hasTransparency: Bool
    public var suggestedMode: ConversionMode
}

public enum ImageAnalysis {
    public static func analyze(url: URL, maxSamples: Int = 12_000) throws -> ImageAnalysisResult {
        guard let image = NSImage(contentsOf: url),
              let rep = bitmapRepresentation(for: image) else {
            throw FileImportError.invalidImage
        }

        return analyze(rep: rep, maxSamples: maxSamples)
    }

    public static func analyze(rep: NSBitmapImageRep, maxSamples: Int = 12_000) -> ImageAnalysisResult {
        let width = max(rep.pixelsWide, 1)
        let height = max(rep.pixelsHigh, 1)
        let totalPixels = width * height
        let sampleStep = Swift.max(1, Int(Double(totalPixels) / Double(maxSamples)).squareRootInt())

        var hasTransparency = false
        var visibleCount = 0
        var blackWhiteLikeCount = 0
        var buckets: [ColourBucket: Int] = [:]

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                guard let pixel = samplePixel(in: rep, x: x, y: y) else { continue }
                if pixel.alpha < 0.05 {
                    hasTransparency = true
                    continue
                }

                visibleCount += 1
                let red = pixel.red
                let green = pixel.green
                let blue = pixel.blue
                let maxChannel = Swift.max(red, Swift.max(green, blue))
                let minChannel = Swift.min(red, Swift.min(green, blue))
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

                if maxChannel - minChannel < 0.08 && (luminance < 0.18 || luminance > 0.82) {
                    blackWhiteLikeCount += 1
                }

                buckets[ColourBucket(red: red, green: green, blue: blue), default: 0] += 1
            }
        }

        let dominantBuckets = buckets.values
            .filter { visibleCount > 0 && Double($0) / Double(visibleCount) > 0.02 }
            .count
        let dominantCount = min(max(dominantBuckets, 1), 8)
        let mostlyBlackWhite = visibleCount == 0 ? false : Double(blackWhiteLikeCount) / Double(visibleCount) > 0.82

        let suggested: ConversionMode
        if mostlyBlackWhite {
            suggested = .lineArt
        } else if dominantCount <= 1 {
            suggested = .singleColour
        } else if dominantCount == 2 {
            suggested = .twoColours
        } else {
            suggested = .threeColours
        }

        return ImageAnalysisResult(
            approximateDominantColourCount: dominantCount,
            isMostlyBlackAndWhite: mostlyBlackWhite,
            hasTransparency: hasTransparency,
            suggestedMode: suggested
        )
    }

    public static func bitmapRepresentation(for image: NSImage) -> NSBitmapImageRep? {
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            return rep
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImage)
    }

    static func samplePixel(in rep: NSBitmapImageRep, x: Int, y: Int) -> PixelSample? {
        let sampleCount = Swift.max(rep.samplesPerPixel, 4)
        var samples = Array(repeating: 0, count: sampleCount)
        rep.getPixel(&samples, atX: x, y: y)

        let maxValue = CGFloat((1 << Swift.min(rep.bitsPerSample, 16)) - 1)
        guard maxValue > 0 else { return nil }

        if rep.samplesPerPixel >= 3 {
            return PixelSample(
                red: CGFloat(samples[0]) / maxValue,
                green: CGFloat(samples[1]) / maxValue,
                blue: CGFloat(samples[2]) / maxValue,
                alpha: rep.hasAlpha ? CGFloat(samples[rep.samplesPerPixel - 1]) / maxValue : 1
            )
        }

        if rep.samplesPerPixel == 1 {
            let gray = CGFloat(samples[0]) / maxValue
            return PixelSample(red: gray, green: gray, blue: gray, alpha: 1)
        }

        return nil
    }
}

struct PixelSample {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
}

private struct ColourBucket: Hashable {
    var red: Int
    var green: Int
    var blue: Int

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = Int((red * 255.0) / 32.0)
        self.green = Int((green * 255.0) / 32.0)
        self.blue = Int((blue * 255.0) / 32.0)
    }
}

private extension Int {
    func squareRootInt() -> Int {
        Swift.max(1, Int(Double(self).squareRoot()))
    }
}
