//
//  CodexBinaryResolver.swift
//  CodexMeter
//

import Foundation

enum CodexBinaryResolver {
    /// Locate the `codex` executable.
    ///
    /// Search order:
    ///   1. Constants.Codex.binarySearchPaths (well-known install locations)
    ///   2. `/usr/bin/env which codex` for any custom PATH entry
    static func resolve() -> String? {
        for path in Constants.Codex.binarySearchPaths
            where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return resolveFromEnv()
    }

    private static func resolveFromEnv() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "codex"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }
}
