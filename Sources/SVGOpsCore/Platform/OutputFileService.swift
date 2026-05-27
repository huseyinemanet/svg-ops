import AppKit
import Foundation

public enum OutputFileError: LocalizedError {
    case missingOriginalURL
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingOriginalURL:
            "There is no original PNG to save beside."
        case .writeFailed(let message):
            "Could not save SVG. \(message)"
        }
    }
}

public struct OutputFileService {
    public init() { }

    public func suggestedOutputURL(for inputURL: URL, suffix: String) -> URL {
        let sanitizedSuffix = suffix.isEmpty ? ".vector" : suffix
        let base = inputURL.deletingPathExtension().lastPathComponent
        let folder = inputURL.deletingLastPathComponent()
        return folder.appendingPathComponent("\(base)\(sanitizedSuffix).svg")
    }

    public func availableURL(for proposedURL: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: proposedURL.path) else {
            return proposedURL
        }

        let folder = proposedURL.deletingLastPathComponent()
        let ext = proposedURL.pathExtension
        let stem = proposedURL.deletingPathExtension().lastPathComponent

        var index = 2
        while true {
            let candidate = folder.appendingPathComponent("\(stem)-\(index).\(ext)")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    public func saveNextToOriginal(svg: String, originalURL: URL, suffix: String) throws -> URL {
        let proposed = suggestedOutputURL(for: originalURL, suffix: suffix)
        let destination = availableURL(for: proposed)
        do {
            try svg.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        } catch {
            throw OutputFileError.writeFailed(error.localizedDescription)
        }
    }

    @MainActor
    public func saveWithPanel(svg: String, originalURL: URL?, suffix: String) throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = originalURL.map {
            suggestedOutputURL(for: $0, suffix: suffix).lastPathComponent
        } ?? "Untitled\(suffix).svg"

        guard panel.runModal() == .OK, let destination = panel.url else {
            return nil
        }

        do {
            try svg.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        } catch {
            throw OutputFileError.writeFailed(error.localizedDescription)
        }
    }

    @MainActor
    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
