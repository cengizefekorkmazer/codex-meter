//
//  CodexAppServerProcess.swift
//  CodexMeter
//

import Foundation

/// Owns the lifecycle of `codex app-server --listen stdio://` as a child
/// process and exposes its stdin/stdout/stderr file handles.
final class CodexAppServerProcess {
    private var process: Process?
    private(set) var stdinPipe: Pipe?
    private(set) var stdoutPipe: Pipe?
    private(set) var stderrPipe: Pipe?

    var stdinHandle: FileHandle? { stdinPipe?.fileHandleForWriting }
    var stdoutHandle: FileHandle? { stdoutPipe?.fileHandleForReading }
    var stderrHandle: FileHandle? { stderrPipe?.fileHandleForReading }

    var isRunning: Bool { process?.isRunning == true }

    /// Invoked when the child process exits, regardless of cause.
    var onTermination: ((Int32) -> Void)?

    func start(codexPath: String) throws {
        // Allow restart after termination — `process` is reset by the
        // termination handler and by `terminate()`.
        if let existing = process, existing.isRunning {
            return
        }

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.executableURL = URL(fileURLWithPath: codexPath)
        proc.arguments = Constants.Codex.appServerArguments
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        proc.terminationHandler = { [weak self] terminated in
            let status = terminated.terminationStatus
            DispatchQueue.main.async {
                self?.process = nil
                self?.stdinPipe = nil
                self?.stdoutPipe = nil
                self?.stderrPipe = nil
                self?.onTermination?(status)
            }
        }

        do {
            try proc.run()
        } catch {
            throw AppError.appServerFailedToStart(error.localizedDescription)
        }

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
    }

    func terminate() {
        guard let proc = process, proc.isRunning else { return }
        proc.terminate()
        // The terminationHandler will null out `process` and pipes.
    }
}
