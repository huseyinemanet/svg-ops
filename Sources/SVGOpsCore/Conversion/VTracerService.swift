import Foundation

struct VTracerService: Sendable {
    private let runner: ShellProcessRunner

    init(runner: ShellProcessRunner = ShellProcessRunner()) {
        self.runner = runner
    }

    func convert(inputURL: URL, settings: ConversionSettings, workingDirectory: URL) async throws -> String {
        let binary = try BinaryLocator.resolve(.vtracer)
        let svgURL = workingDirectory.appendingPathComponent("vtracer-output.svg")

        var arguments = [
            "--input", inputURL.path,
            "--output", svgURL.path,
            "--colormode", "color",
            "--color_precision", "6",
            "--path_precision", pathPrecision(for: settings.quality),
            "--filter_speckle", filterSpeckle(for: settings.quality),
            "--mode", "spline"
        ]

        if settings.mode == .twoColours {
            arguments.append(contentsOf: ["--hierarchical", "stacked"])
        }

        _ = try await runner.run(executable: binary, arguments: arguments, timeout: 120)
        return try String(contentsOf: svgURL, encoding: .utf8)
    }

    private func pathPrecision(for quality: ConversionQuality) -> String {
        switch quality {
        case .clean: "2"
        case .balanced: "3"
        case .accurate: "4"
        }
    }

    private func filterSpeckle(for quality: ConversionQuality) -> String {
        switch quality {
        case .clean: "12"
        case .balanced: "6"
        case .accurate: "2"
        }
    }
}
