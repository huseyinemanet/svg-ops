import AppKit
import Foundation

enum RasterPreparationError: LocalizedError {
    case cannotRenderImage
    case cannotEncodePNG

    var errorDescription: String? {
        switch self {
        case .cannotRenderImage:
            "The image could not be prepared for conversion."
        case .cannotEncodePNG:
            "The image could not be converted to a temporary PNG."
        }
    }
}

struct RasterPreparationService: Sendable {
    func preparePNG(from inputURL: URL, in workingDirectory: URL) throws -> URL {
        if inputURL.pathExtension.lowercased() == "png" {
            return inputURL
        }

        guard let image = NSImage(contentsOf: inputURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw RasterPreparationError.cannotRenderImage
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw RasterPreparationError.cannotEncodePNG
        }

        let outputURL = workingDirectory.appendingPathComponent("prepared-input.png")
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }
}
