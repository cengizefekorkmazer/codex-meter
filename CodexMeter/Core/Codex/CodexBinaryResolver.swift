//
//  CodexBinaryResolver.swift
//  CodexMeter
//

import Foundation

enum CodexBinaryResolver {

    static func resolve(customPath: String? = nil) -> String? {
        if let custom = customPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty,
           FileManager.default.isExecutableFile(atPath: custom) {
            return custom
        }
        for path in candidatePaths()
            where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return resolveViaLoginShell()
    }

    /// Well-known absolute locations, including per-user node/npm dirs.
    private static func candidatePaths() -> [String] {
        let home = NSHomeDirectory()
        var paths = Constants.Codex.binarySearchPaths
        paths += [
            "\(home)/.npm-global/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.volta/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.deno/bin/codex",
            "/usr/local/bin/codex",
            "/opt/local/bin/codex",
        ]
        return paths
    }

    private static func resolveViaLoginShell() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-ilc", "command -v codex"]

        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()

        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        if done.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        // An interactive shell can print banners; `command -v` output is the
        // last non-empty line.
        let path = String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }

        guard let path, FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }
        return path
    }
}
