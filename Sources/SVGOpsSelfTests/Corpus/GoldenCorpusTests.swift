import Foundation
import SVGOpsCore

extension SVGOpsSelfTests {
    @MainActor
    static func runGoldenCorpusTests(_ runner: SelfTestRunner) async {
        await runner.runAsync("golden corpus converts flat raster fixtures") {
            let corpus = try GoldenRasterCorpus().makeFixtures()
            runner.expect(corpus.count >= 12, "Expected at least 12 golden raster fixtures")

            for fixture in corpus {
                do {
                    let result = try await VectorizationService().convert(inputURL: fixture.url, settings: fixture.settings)
                    runner.expect(!result.svg.isEmpty, "\(fixture.name): SVG is empty")
                    runner.expect(result.svg.hasPrefix("<svg "), "\(fixture.name): SVG is not modern root markup")
                    runner.expect(result.stats.pathCount >= fixture.minimumPaths, "\(fixture.name): path count is too low")
                    runner.expect(result.stats.pathCount <= fixture.maximumPaths, "\(fixture.name): path count is too high")
                    runner.expect(result.stats.byteSize <= fixture.maximumBytes, "\(fixture.name): SVG is too large")
                    runner.expect(result.qualityReport.pathCount == result.stats.pathCount, "\(fixture.name): quality report path count mismatch")
                    runner.expect(result.qualityReport.vectorizerTool != nil, "\(fixture.name): missing vectorizer tool")
                    runner.expect(result.qualityReport.cleanupApplied, "\(fixture.name): cleanup pass was not reported")
                    runner.expect(result.qualityReport.parserSucceeded, "\(fixture.name): parser pass was not reported")

                    if !fixture.cropAllowed {
                        runner.expect(!result.qualityReport.cropApplied, "\(fixture.name): crop applied unexpectedly")
                    }
                    if let expectedColourCount = fixture.expectedColourCount {
                        runner.expect(result.stats.colourCount == expectedColourCount, "\(fixture.name): colour count mismatch")
                    }

                    if let viewBox = result.qualityReport.viewBox {
                        runner.expect(GoldenRasterCorpus.isReasonableViewBox(viewBox), "\(fixture.name): unreasonable viewBox \(viewBox)")
                    } else {
                        runner.fail("\(fixture.name): missing viewBox")
                    }

                    let smokeFailures = SVGExportSmokeValidator.validate(
                        result.svg,
                        expectedPathCount: result.stats.pathCount,
                        expectedViewBox: result.qualityReport.viewBox
                    )
                    for failure in smokeFailures {
                        runner.fail("\(fixture.name): \(failure)")
                    }

                    if let tool = result.qualityReport.vectorizerTool {
                        let version = result.qualityReport.vectorizerVersion ?? "unknown version"
                        let path = result.qualityReport.vectorizerPath ?? "unknown path"
                        print("INFO \(fixture.name): \(tool) \(version) at \(path)")
                    }
                } catch ProcessRunnerError.binaryMissing {
                    print("SKIP \(fixture.name): required vectorizer is not installed")
                } catch {
                    runner.fail("\(fixture.name): \(error)")
                }
            }
        }
    }
}
