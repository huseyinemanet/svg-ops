import AppKit
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var originalURL: URL?
    @Published var settings: ConversionSettings
    @Published var result: ConversionResult?
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var isConverting = false
    @Published var isRefreshingPreview = false
    @Published var copied = false
    @Published var isDropTargeted = false

    private let importService = FileImportService()
    private let vectorizationService = VectorizationService()
    private let clipboardService = ClipboardService()
    private let outputService = OutputFileService()
    private var previewRefreshTask: Task<Void, Never>?
    private var previewRefreshID = 0
    private var pendingPreviewRefreshAfterCurrentConversion = false

    init(settings: ConversionSettings) {
        self.settings = settings
    }

    var binaryWarning: String? {
        BinaryLocator.availabilityMessage(for: settings.mode)
    }

    func chooseFile(preferences: PreferencesService) {
        guard let url = importService.chooseImage() else { return }
        load(url: url, preferences: preferences)
    }

    func clear() {
        originalURL = nil
        result = nil
        copied = false
        errorMessage = nil
        statusMessage = nil
        isConverting = false
        isRefreshingPreview = false
        pendingPreviewRefreshAfterCurrentConversion = false
        previewRefreshID += 1
        previewRefreshTask?.cancel()
        previewRefreshTask = nil
    }

    func settingsDidChange(preferences: PreferencesService) {
        guard originalURL != nil else { return }
        guard result != nil || preferences.autoConvertOnDrop else {
            statusMessage = "Settings changed"
            return
        }

        copied = false
        errorMessage = nil

        previewRefreshTask?.cancel()
        if isConverting {
            pendingPreviewRefreshAfterCurrentConversion = true
            return
        }

        schedulePreviewRefresh(preferences: preferences)
    }

    func load(url: URL, preferences: PreferencesService) {
        do {
            try importService.validateRasterImage(url)
            previewRefreshID += 1
            previewRefreshTask?.cancel()
            previewRefreshTask = nil
            originalURL = url
            result = nil
            copied = false
            errorMessage = nil
            isRefreshingPreview = false
            pendingPreviewRefreshAfterCurrentConversion = false

            if let analysis = try? ImageAnalysis.analyze(url: url) {
                statusMessage = analysis.suggestedMode == settings.mode
                    ? "Ready to convert"
                    : "Suggested \(analysis.suggestedMode.title)"
            } else {
                statusMessage = "Ready to convert"
            }

            if preferences.autoConvertOnDrop {
                convert(preferences: preferences)
            }
        } catch {
            showError(error, presentAlert: true)
        }
    }

    func convert(preferences: PreferencesService, sideEffects: Bool = true) {
        guard let originalURL else { return }
        if !sideEffects {
            schedulePreviewRefresh(preferences: preferences)
            return
        }
        guard !isConverting else {
            return
        }

        previewRefreshID += 1
        previewRefreshTask?.cancel()
        previewRefreshTask = nil
        isRefreshingPreview = false
        pendingPreviewRefreshAfterCurrentConversion = false

        let conversionSettings = settings
        isConverting = true
        statusMessage = "Converting..."
        copied = false
        errorMessage = nil
        preferences.updateLastUsedSettings(conversionSettings)

        Task {
            defer {
                isConverting = false
                if pendingPreviewRefreshAfterCurrentConversion {
                    pendingPreviewRefreshAfterCurrentConversion = false
                    schedulePreviewRefresh(preferences: preferences)
                }
            }

            do {
                var converted = try await vectorizationService.convert(inputURL: originalURL, settings: conversionSettings)

                if preferences.copyAfterConversion {
                    clipboardService.copy(converted.svg)
                    copied = true
                    statusMessage = "SVG ready · Copied to clipboard"
                } else {
                    statusMessage = "SVG ready"
                }

                if preferences.saveNextToOriginal {
                    do {
                        let saved = try outputService.saveNextToOriginal(
                            svg: converted.svg,
                            originalURL: originalURL,
                            suffix: conversionSettings.outputFilenameSuffix
                        )
                        converted.savedURL = saved
                    } catch {
                        showError(error, presentAlert: false)
                        if let fallback = try? outputService.saveWithPanel(
                            svg: converted.svg,
                            originalURL: originalURL,
                            suffix: settings.outputFilenameSuffix
                        ) {
                            converted.savedURL = fallback
                        }
                    }
                }

                result = converted
            } catch is CancellationError {
                statusMessage = "Conversion cancelled"
            } catch {
                showError(error, presentAlert: false)
            }
        }
    }

    private func schedulePreviewRefresh(preferences: PreferencesService) {
        guard let originalURL else { return }

        previewRefreshID += 1
        let requestID = previewRefreshID
        let conversionSettings = settings
        preferences.updateLastUsedSettings(conversionSettings)

        isRefreshingPreview = true
        previewRefreshTask?.cancel()
        previewRefreshTask = Task { @MainActor in
            defer {
                if requestID == previewRefreshID {
                    isRefreshingPreview = false
                    previewRefreshTask = nil
                }
            }

            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                let converted = try await vectorizationService.convert(inputURL: originalURL, settings: conversionSettings)
                guard !Task.isCancelled,
                      requestID == previewRefreshID,
                      self.originalURL == originalURL else {
                    return
                }

                result = converted
                statusMessage = "Preview updated"
            } catch is CancellationError {
                return
            } catch {
                guard requestID == previewRefreshID else { return }
                showError(error, presentAlert: false)
            }
        }
    }

    func copySVG() {
        guard let svg = result?.svg else { return }
        clipboardService.copy(svg)
        copied = true
        statusMessage = "Copied"
    }

    func saveSVG() {
        guard let svg = result?.svg else { return }
        do {
            let saved = try outputService.saveWithPanel(
                svg: svg,
                originalURL: originalURL,
                suffix: settings.outputFilenameSuffix
            )
            if let saved {
                result?.savedURL = saved
                statusMessage = "Saved"
            }
        } catch {
            showError(error, presentAlert: true)
        }
    }

    func revealInFinder() {
        guard let url = result?.savedURL else { return }
        outputService.revealInFinder(url)
    }

    private func showError(_ error: Error, presentAlert: Bool) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        errorMessage = message
        statusMessage = message
        if presentAlert {
            NSAlert(error: error).runModal()
        }
    }
}
