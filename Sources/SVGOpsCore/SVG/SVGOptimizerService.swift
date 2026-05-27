import Foundation

public struct SVGOptimizerService: Sendable {
    public init() { }

    public func optimize(_ svg: String) -> String {
        optimizeWithReport(svg).svg
    }

    public func optimizeWithReport(_ svg: String) -> SVGOptimizationResult {
        let cleaned = SVGSourceCleaner().clean(svg)
        guard var document = SVGDocumentParser().parse(cleaned) else {
            let safeSVG = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            return SVGOptimizationResult(
                svg: safeSVG,
                report: SVGQualityReport(
                    optimizerApplied: false,
                    cropApplied: false,
                    fallbackUsed: true,
                    pathCount: SVGStatsParser.parse(safeSVG).pathCount,
                    viewBox: SVGOutputInspector.viewBox(in: safeSVG),
                    warnings: ["SVG parser failed; used conservative cleanup."],
                    cleanupApplied: true,
                    parserSucceeded: false,
                    fallbackReason: "parser failed"
                )
            )
        }

        document.root.removeElements(named: "metadata")
        let unsupportedNodes = document.root.unsupportedNodeNames()

        var conservativeDocument = document
        SVGMarkupModernizer().modernize(&conservativeDocument)
        let conservativeSVG = conservativeDocument.serialized().trimmingCharacters(in: .whitespacesAndNewlines)

        let cropApplied: Bool
        let cropSkippedReason: String?
        let normalizer = SVGCanvasNormalizer()
        if let normalized = normalizer.normalize(document) {
            document = normalized
            cropApplied = true
            cropSkippedReason = nil
        } else {
            cropApplied = false
            cropSkippedReason = normalizer.skipReason(for: document)
        }

        SVGMarkupModernizer().modernize(&document)
        let optimizedSVG = document.serialized().trimmingCharacters(in: .whitespacesAndNewlines)
        let validator = SVGOutputValidator()
        let validation = validator.validate(optimizedSVG, comparedTo: cleaned)

        if validation.isValid {
            return SVGOptimizationResult(
                svg: optimizedSVG,
                report: SVGQualityReport(
                    optimizerApplied: true,
                    cropApplied: cropApplied,
                    fallbackUsed: false,
                    pathCount: validation.pathCount,
                    viewBox: validation.viewBox,
                    warnings: validation.warnings,
                    cleanupApplied: true,
                    parserSucceeded: true,
                    cropSkippedReason: cropSkippedReason,
                    unsupportedNodes: unsupportedNodes
                )
            )
        }

        let fallbackValidation = validator.validate(conservativeSVG, comparedTo: cleaned)
        let fallbackSVG = fallbackValidation.isValid ? conservativeSVG : cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let stats = SVGStatsParser.parse(fallbackSVG)

        return SVGOptimizationResult(
            svg: fallbackSVG,
            report: SVGQualityReport(
                optimizerApplied: fallbackValidation.isValid,
                cropApplied: false,
                fallbackUsed: true,
                pathCount: stats.pathCount,
                viewBox: SVGOutputInspector.viewBox(in: fallbackSVG),
                warnings: validation.warnings + ["Optimizer validation failed; used conservative SVG."],
                cleanupApplied: true,
                parserSucceeded: true,
                cropSkippedReason: cropSkippedReason,
                fallbackReason: validation.warnings.first ?? "validation failed",
                unsupportedNodes: unsupportedNodes
            )
        )
    }
}

public struct SVGOptimizationResult: Equatable, Sendable {
    public var svg: String
    public var report: SVGQualityReport
}
