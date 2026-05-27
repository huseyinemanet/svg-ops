import Foundation
import SVGOpsCore

extension SVGOpsSelfTests {
    @MainActor
    static func runProcessRunnerTests(_ runner: SelfTestRunner) async {
        await runner.runAsync("missing binary throws typed error") {
            let missing = URL(fileURLWithPath: "/tmp/not-a-real-svg-ops-binary")
            do {
                _ = try await ShellProcessRunner().run(executable: missing, arguments: [])
                runner.fail("Expected missing binary error")
            } catch let error as ProcessRunnerError {
                runner.expect(error == .binaryMissing(missing))
            } catch {
                runner.fail("Unexpected error: \(error)")
            }
        }

        await runner.runAsync("process runner cancels running process") {
            let started = Date()
            let task = Task {
                try await ShellProcessRunner().run(
                    executable: URL(fileURLWithPath: "/bin/sleep"),
                    arguments: ["5"],
                    timeout: 10
                )
            }

            try await Task.sleep(nanoseconds: 100_000_000)
            task.cancel()

            do {
                _ = try await task.value
                runner.fail("Expected cancellation")
            } catch is CancellationError {
                runner.expect(Date().timeIntervalSince(started) < 2)
            } catch {
                runner.fail("Unexpected error: \(error)")
            }
        }
    }
}
