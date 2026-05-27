import Foundation

@MainActor
final class SelfTestRunner {
    private var failures: [String] = []

    func run(_ name: String, _ block: () throws -> Void) {
        let failureCount = failures.count
        do {
            try block()
            if failures.count == failureCount {
                print("PASS \(name)")
            } else {
                print("FAIL \(name)")
            }
        } catch {
            failures.append("\(name): \(error)")
            print("FAIL \(name): \(error)")
        }
    }

    func runAsync(_ name: String, _ block: () async throws -> Void) async {
        let failureCount = failures.count
        do {
            try await block()
            if failures.count == failureCount {
                print("PASS \(name)")
            } else {
                print("FAIL \(name)")
            }
        } catch {
            failures.append("\(name): \(error)")
            print("FAIL \(name): \(error)")
        }
    }

    func expect(_ condition: @autoclosure () -> Bool, _ message: String = "expectation failed") {
        if !condition() {
            failures.append(message)
        }
    }

    func fail(_ message: String) {
        failures.append(message)
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("All self-tests passed.")
            exit(0)
        }

        print("\nFailures:")
        for failure in failures {
            print("- \(failure)")
        }
        exit(1)
    }
}
