@preconcurrency import Foundation

public struct ProcessOutput: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitStatus: Int32
}

public enum ProcessRunnerError: LocalizedError, Equatable, Sendable {
    case binaryMissing(URL)
    case launchFailed(String)
    case nonZeroExit(status: Int32, stderr: String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .binaryMissing(let url):
            "Required tool is missing or not executable: \(url.path)"
        case .launchFailed(let message):
            "Could not start conversion tool. \(message)"
        case .nonZeroExit(_, let stderr):
            stderr.isEmpty ? "Conversion tool failed." : stderr
        case .timedOut:
            "Conversion timed out."
        }
    }
}

public struct ShellProcessRunner: Sendable {
    public init() { }

    public func run(executable: URL, arguments: [String], timeout: TimeInterval = 60) async throws -> ProcessOutput {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProcessRunnerError.binaryMissing(executable)
        }

        let state = ProcessRunState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                state.setContinuation(continuation)
                state.setProcess(process)

                process.executableURL = executable
                process.arguments = arguments
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    state.terminate()
                    state.resumeFailure(.timedOut)
                }

                process.terminationHandler = { process in
                    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let output = ProcessOutput(stdout: stdout, stderr: stderr, exitStatus: process.terminationStatus)

                    if process.terminationStatus == 0 {
                        state.resumeSuccess(output)
                    } else {
                        state.resumeFailure(.nonZeroExit(status: process.terminationStatus, stderr: stderr))
                    }
                }

                if Task.isCancelled {
                    state.cancel()
                    return
                }

                do {
                    try process.run()
                } catch {
                    state.resumeFailure(.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            state.cancel()
        }
    }
}

private final class ProcessRunState: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private var continuation: CheckedContinuation<ProcessOutput, Error>?
    private var process: Process?

    func setContinuation(_ continuation: CheckedContinuation<ProcessOutput, Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }

    func setProcess(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        self.process = process
    }

    func terminate() {
        lock.lock()
        let process = process
        lock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }

    func cancel() {
        terminate()
        resumeCancellation()
    }

    func resumeSuccess(_ output: ProcessOutput) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation?.resume(returning: output)
        continuation = nil
    }

    func resumeFailure(_ error: ProcessRunnerError) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func resumeCancellation() {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}
