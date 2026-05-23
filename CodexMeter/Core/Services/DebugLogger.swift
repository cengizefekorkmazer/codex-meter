//
//  DebugLogger.swift
//  CodexMeter
//
//  Appends JSON-RPC traffic to ~/Library/Caches/CodexMeter/debug.log when
//  the user enables Debug mode in Settings. The log never includes tokens —
//  the Codex app-server doesn't return them — but it does include account
//  email and rate-limit history, so we treat it as user-private data
//  (file mode 0600, never auto-uploaded).
//

import Foundation

final class DebugLogger {
    static let shared = DebugLogger()

    private let queue = DispatchQueue(label: "ai.codexmeter.debugLogger")
    private(set) var isEnabled: Bool = false
    private let maxFileBytes: Int = 4 * 1024 * 1024  // 4 MiB rolling cap
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    func setEnabled(_ enabled: Bool) {
        queue.async { self.isEnabled = enabled }
    }

    // MARK: - Public log API

    func logOutbound(_ raw: Data) {
        guard isEnabled else { return }
        append(direction: "→", body: raw)
    }

    func logInbound(_ raw: Data) {
        guard isEnabled else { return }
        append(direction: "←", body: raw)
    }

    func logEvent(_ message: String) {
        guard isEnabled else { return }
        append(direction: "·", body: Data(message.utf8))
    }

    // MARK: - File location

    static var logURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("CodexMeter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("debug.log")
    }

    // MARK: - Implementation

    private func append(direction: String, body: Data) {
        let url = Self.logURL
        let timestamp = formatter.string(from: Date())
        let prefix = "[\(timestamp)] \(direction) "
        var line = Data(prefix.utf8)
        line.append(body)
        line.append(0x0A)

        queue.async {
            self.rotateIfNeeded(url: url)
            do {
                if !FileManager.default.fileExists(atPath: url.path) {
                    _ = FileManager.default.createFile(
                        atPath: url.path,
                        contents: nil,
                        attributes: [.posixPermissions: 0o600]
                    )
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } catch {
                // Logging failures are non-fatal; print so they show up in Xcode.
                print("DebugLogger: append failed — \(error)")
            }
        }
    }

    private func rotateIfNeeded(url: URL) {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size > maxFileBytes else { return }
        let rolled = url.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.removeItem(at: rolled)
        try? FileManager.default.moveItem(at: url, to: rolled)
    }
}
