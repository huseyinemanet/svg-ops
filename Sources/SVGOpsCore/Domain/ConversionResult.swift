import Foundation

public struct ConversionResult: Equatable, Sendable {
    public var svg: String
    public var stats: SVGStats
    public var savedURL: URL?
    public var qualityReport: SVGQualityReport

    public init(svg: String, stats: SVGStats, savedURL: URL?, qualityReport: SVGQualityReport = .empty) {
        self.svg = svg
        self.stats = stats
        self.savedURL = savedURL
        self.qualityReport = qualityReport
    }
}

public struct SVGQualityReport: Equatable, Sendable {
    public var optimizerApplied: Bool
    public var cropApplied: Bool
    public var fallbackUsed: Bool
    public var pathCount: Int
    public var viewBox: String?
    public var warnings: [String]
    public var vectorizerTool: String?
    public var vectorizerVersion: String?
    public var vectorizerPath: String?
    public var cleanupApplied: Bool
    public var parserSucceeded: Bool
    public var cropSkippedReason: String?
    public var fallbackReason: String?
    public var unsupportedNodes: [String]

    public init(
        optimizerApplied: Bool,
        cropApplied: Bool,
        fallbackUsed: Bool,
        pathCount: Int,
        viewBox: String?,
        warnings: [String],
        vectorizerTool: String? = nil,
        vectorizerVersion: String? = nil,
        vectorizerPath: String? = nil,
        cleanupApplied: Bool = false,
        parserSucceeded: Bool = false,
        cropSkippedReason: String? = nil,
        fallbackReason: String? = nil,
        unsupportedNodes: [String] = []
    ) {
        self.optimizerApplied = optimizerApplied
        self.cropApplied = cropApplied
        self.fallbackUsed = fallbackUsed
        self.pathCount = pathCount
        self.viewBox = viewBox
        self.warnings = warnings
        self.vectorizerTool = vectorizerTool
        self.vectorizerVersion = vectorizerVersion
        self.vectorizerPath = vectorizerPath
        self.cleanupApplied = cleanupApplied
        self.parserSucceeded = parserSucceeded
        self.cropSkippedReason = cropSkippedReason
        self.fallbackReason = fallbackReason
        self.unsupportedNodes = unsupportedNodes
    }

    public static let empty = SVGQualityReport(
        optimizerApplied: false,
        cropApplied: false,
        fallbackUsed: false,
        pathCount: 0,
        viewBox: nil,
        warnings: []
    )
}
