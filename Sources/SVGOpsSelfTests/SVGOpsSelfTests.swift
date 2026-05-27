import Foundation

@main
struct SVGOpsSelfTests {
    @MainActor
    static func main() async {
        let runner = SelfTestRunner()

        runCoreTests(runner)
        runSVGOptimizerTests(runner)
        runImageAnalysisTests(runner)
        await runGoldenCorpusTests(runner)
        await runProcessRunnerTests(runner)

        runner.finish()
    }
}
