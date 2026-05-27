import AppKit
import UniformTypeIdentifiers

enum FileImportError: LocalizedError, Equatable {
    case unsupportedFile
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "SVG Ops accepts PNG, JPG, JPEG, and WEBP files."
        case .invalidImage:
            "The selected file could not be opened as an image."
        }
    }
}

struct FileImportService {
    static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]

    static var supportedContentTypes: [UTType] {
        [
            .png,
            .jpeg,
            UTType(filenameExtension: "webp") ?? .image
        ]
    }

    func validateRasterImage(_ url: URL) throws {
        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            throw FileImportError.unsupportedFile
        }

        guard NSImage(contentsOf: url) != nil else {
            throw FileImportError.invalidImage
        }
    }

    @MainActor
    func chooseImage() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.supportedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
