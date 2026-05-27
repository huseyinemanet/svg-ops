import Foundation
import SVGOpsCore

extension SVGOpsSelfTests {
    @MainActor
    static func runSVGOptimizerTests(_ runner: SelfTestRunner) {
        runner.run("SVG cleanup preserves path data") {
            let svg = """
            <svg viewBox="0 0 10 10">
            <!-- generated -->
            <metadata>noise</metadata>
            <path d="M 0 0 C 1 2 3 4 10 10" fill="#000000"/>
            </svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(!optimized.contains("generated"))
            runner.expect(!optimized.contains("<metadata>"))
            runner.expect(optimized.contains("M 0 0 C 1 2 3 4 10 10"))
        }

        runner.run("SVG cleanup crops Potrace canvas to visible paths") {
            let svg = """
            <svg width="100pt" height="100pt" viewBox="0 0 100 100"><g transform="translate(0,100) scale(0.1,-0.1)"><path d="M 200 300 L 400 300 L 400 500 Z"/></g></svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(optimized.contains(#"viewBox="18 48 24 24""#))
            runner.expect(optimized.contains(#"width="24""#))
            runner.expect(optimized.contains(#"height="24""#))
            runner.expect(optimized.contains(#"M 200 300 L 400 300 L 400 500 Z"#))
        }

        runner.run("SVG cleanup emits modern root markup") {
            let svg = """
            <?xml version="1.0" standalone="no"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20010904//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd"><svg version="1.0" xmlns="http://www.w3.org/2000/svg" width="100.000000pt" height="100.000000pt" viewBox="0 0 100.000000 100.000000" preserveAspectRatio="xMidYMid meet"><g fill="currentColor" stroke="none"><path d="M 0 0 L 10 10 Z"/></g></svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(!optimized.contains("<?xml"), "modern root still contains XML declaration")
            runner.expect(!optimized.contains("<!DOCTYPE"), "modern root still contains DOCTYPE")
            runner.expect(!optimized.contains(#"version="1.0""#), "modern root still contains SVG 1.0 version")
            runner.expect(!optimized.contains("pt\""), "modern root still contains point units")
            runner.expect(
                optimized.hasPrefix(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2 14 14" width="14" height="14" fill="currentColor">"#),
                "modern root prefix was: \(optimized)"
            )
            runner.expect(!optimized.contains(#"stroke="none""#), "modern root still contains stroke none")
            runner.expect(
                optimized.contains("\n  <path d=\"M 0 0 L 10 10 Z\"/>\n</svg>"),
                "modern root did not flatten path: \(optimized)"
            )
        }

        runner.run("SVG cleanup handles nested transforms") {
            let svg = """
            <svg width="100" height="100" viewBox="0 0 100 100"><g transform="translate(10,20)"><g transform="scale(2)"><path d="M 5 5 L 10 5 L 10 10 Z"/></g></g></svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(optimized.contains(#"viewBox="18 28 14 14""#))
            runner.expect(optimized.contains(#"width="14""#))
            runner.expect(optimized.contains(#"height="14""#))
        }

        runner.run("SVG cleanup uses curve extrema instead of control point bounds") {
            let svg = """
            <svg width="200" height="200" viewBox="0 0 200 200"><path d="M 0 0 C 0 100 100 100 100 0"/></svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(optimized.contains(#"viewBox="-2 -2 104 79""#))
            runner.expect(!optimized.contains(#"viewBox="-2 -2 104 104""#))
        }

        runner.run("SVG cleanup skips crop for masks and filters") {
            let svg = """
            <svg width="100" height="100" viewBox="0 0 100 100"><defs><mask id="m"><path d="M0 0 L10 0 L10 10 Z"/></mask></defs><path mask="url(#m)" d="M 40 40 L 45 40 L 45 45 Z"/></svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(optimized.contains(#"viewBox="0 0 100 100""#))
            runner.expect(optimized.contains(#"mask="url(#m)""#))
        }

        runner.run("SVG cleanup pads crop for stroke width") {
            let svg = """
            <svg width="100" height="100" viewBox="0 0 100 100"><path stroke-width="10" d="M 20 20 L 30 20 L 30 30 L 20 30 Z"/></svg>
            """
            let optimized = SVGOptimizerService().optimize(svg)
            runner.expect(optimized.contains(#"viewBox="13 13 24 24""#))
            runner.expect(optimized.contains(#"width="24""#))
            runner.expect(optimized.contains(#"height="24""#))
        }

        runner.run("SVG optimizer reports fallback for malformed SVG") {
            let svg = """
            <svg viewBox="0 0 100 100"><path d="M 0 0 L 10 10 Z"></svg>
            """
            let result = SVGOptimizerService().optimizeWithReport(svg)
            runner.expect(result.report.fallbackUsed)
            runner.expect(result.report.cleanupApplied)
            runner.expect(!result.report.parserSucceeded)
            runner.expect(result.report.fallbackReason == "parser failed")
            runner.expect(result.report.warnings.contains { $0.contains("parser failed") })
            runner.expect(result.svg.contains("<svg"))
        }

        runner.run("SVG optimizer quality report records crop") {
            let svg = """
            <svg width="100" height="100" viewBox="0 0 100 100"><path d="M 40 40 L 50 40 L 50 50 Z"/></svg>
            """
            let result = SVGOptimizerService().optimizeWithReport(svg)
            runner.expect(result.report.optimizerApplied)
            runner.expect(result.report.cropApplied)
            runner.expect(!result.report.fallbackUsed)
            runner.expect(result.report.cleanupApplied)
            runner.expect(result.report.parserSucceeded)
            runner.expect(result.report.cropSkippedReason == nil)
            runner.expect(result.report.pathCount == 1)
            runner.expect(result.report.viewBox == "38 38 14 14")
        }

        runner.run("SVG optimizer reports unsupported crop skip reason") {
            let svg = """
            <svg width="100" height="100" viewBox="0 0 100 100"><defs><clipPath id="c"><path d="M0 0 L10 0 L10 10 Z"/></clipPath></defs><path clip-path="url(#c)" d="M 40 40 L 45 40 L 45 45 Z"/></svg>
            """
            let result = SVGOptimizerService().optimizeWithReport(svg)
            runner.expect(result.report.parserSucceeded)
            runner.expect(!result.report.cropApplied)
            runner.expect(result.report.cropSkippedReason?.contains("unsupported") == true)
            runner.expect(result.report.unsupportedNodes.contains("defs"))
            runner.expect(result.report.unsupportedNodes.contains("clipPath"))
        }

        runner.run("SVG optimizer skips crop when arc bounds are unavailable") {
            let svg = """
            <svg width="100" height="100" viewBox="0 0 100 100"><path d="M 20 50 A 30 30 0 0 1 80 50"/></svg>
            """
            let result = SVGOptimizerService().optimizeWithReport(svg)
            runner.expect(result.report.parserSucceeded)
            runner.expect(!result.report.cropApplied)
            runner.expect(result.report.cropSkippedReason == "bounds unavailable")
            runner.expect(result.svg.contains(#"viewBox="0 0 100 100""#))
        }
    }
}
