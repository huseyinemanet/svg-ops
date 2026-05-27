import Foundation

enum VectorizationTool {
    case potrace
    case vtracer

    var binaryName: String {
        switch self {
        case .potrace: "potrace"
        case .vtracer: "vtracer"
        }
    }

    var displayName: String {
        switch self {
        case .potrace: "Potrace"
        case .vtracer: "VTracer"
        }
    }
}

enum BinaryLocator {
    static func resolve(_ tool: VectorizationTool) throws -> URL {
        let candidateRoots = [
            Bundle.module.resourceURL,
            Bundle.main.resourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("Resources", isDirectory: true)
        ].compactMap { $0 }

        for root in candidateRoots {
            let candidate = root
                .appendingPathComponent("Binaries", isDirectory: true)
                .appendingPathComponent(tool.binaryName)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        let homebrew = URL(fileURLWithPath: "/opt/homebrew/bin/\(tool.binaryName)")
        if FileManager.default.isExecutableFile(atPath: homebrew.path) {
            return homebrew
        }

        let cargo = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cargo/bin", isDirectory: true)
            .appendingPathComponent(tool.binaryName)
        if FileManager.default.isExecutableFile(atPath: cargo.path) {
            return cargo
        }

        throw ProcessRunnerError.binaryMissing(homebrew)
    }

    static func availabilityMessage(for mode: ConversionMode) -> String? {
        do {
            if mode.requiresPotrace {
                _ = try resolve(.potrace)
            }
            if mode.requiresVTracer {
                _ = try resolve(.vtracer)
            }
            return nil
        } catch {
            if mode.requiresPotrace {
                return "Potrace is required for this mode. Add it to Resources/Binaries or install it with Homebrew."
            }
            return "VTracer is required for this mode. Add it to Resources/Binaries or install it with Homebrew."
        }
    }

    static func versionInfo(for tool: VectorizationTool, runner: ShellProcessRunner = ShellProcessRunner()) async -> BinaryVersionInfo {
        do {
            let binary = try resolve(tool)
            let output = try await runner.run(executable: binary, arguments: ["--version"], timeout: 5)
            let version = [output.stdout, output.stderr]
                .joined(separator: "\n")
                .split(separator: "\n")
                .first
                .map(String.init)
            return BinaryVersionInfo(tool: tool.displayName, path: binary.path, version: version)
        } catch {
            return BinaryVersionInfo(tool: tool.displayName, path: nil, version: nil)
        }
    }
}

struct BinaryVersionInfo: Sendable {
    var tool: String
    var path: String?
    var version: String?
}

public struct VectorizationService: Sendable {
    private let potrace = PotraceService()
    private let vtracer = VTracerService()
    private let optimizer = SVGOptimizerService()
    private let rasterPreparation = RasterPreparationService()

    public init() { }

    public func convert(inputURL: URL, settings: ConversionSettings) async throws -> ConversionResult {
        let workingDirectory = try TemporaryFileManager.createWorkingDirectory()
        defer { TemporaryFileManager.remove(workingDirectory) }
        let preparedInputURL = try rasterPreparation.preparePNG(from: inputURL, in: workingDirectory)

        let rawSVG: String
        let tool: VectorizationTool
        if settings.mode.requiresPotrace {
            tool = .potrace
            rawSVG = try await potrace.convert(inputURL: preparedInputURL, settings: settings, workingDirectory: workingDirectory)
        } else {
            tool = .vtracer
            rawSVG = try await vtracer.convert(inputURL: preparedInputURL, settings: settings, workingDirectory: workingDirectory)
        }

        let optimized = optimizer.optimizeWithReport(rawSVG)
        let versionInfo = await BinaryLocator.versionInfo(for: tool)
        var report = optimized.report
        report.vectorizerTool = versionInfo.tool
        report.vectorizerVersion = versionInfo.version
        report.vectorizerPath = versionInfo.path

        return ConversionResult(
            svg: optimized.svg,
            stats: SVGStatsParser.parse(optimized.svg),
            savedURL: nil,
            qualityReport: report
        )
    }
}
