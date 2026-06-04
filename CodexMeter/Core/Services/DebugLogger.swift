//
//  DebugLogger.swift
//  CodexMeter
//
//  Appends JSON-RPC traffic to ~/Library/Caches/CodexMeter/debug.log when
//  Debug mode is enabled. API keys, OAuth tokens, and auth URLs are redacted
//  from every line (see `redacted(_:)`); account email and rate-limit history
//  are not, so the file is treated as user-private (mode 0600, never uploaded).
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

    /// JSON keys whose string values are credentials or login URLs; redacted
    /// from every logged frame, inbound and outbound.
    static let sensitiveKeys = ["apiKey", "accessToken", "refreshToken", "authUrl", "verificationUrl"]

    private static let redactionRegex: NSRegularExpression = {
        let keys = sensitiveKeys.joined(separator: "|")
        // Matches  "<key>" : "<value>"  — token/URL values never contain a quote.
        let pattern = "\"(\(keys))\"\\s*:\\s*\"[^\"]*\""
        return try! NSRegularExpression(pattern: pattern)
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

    // MARK: - Redaction

    /// Replaces the value of any `sensitiveKeys` entry with `<redacted>`. Frames
    /// with nothing sensitive (or non-UTF-8 input) are returned unchanged.
    static func redacted(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else { return data }
        let range = NSRange(text.startIndex..., in: text)
        guard redactionRegex.firstMatch(in: text, range: range) != nil else { return data }
        let scrubbed = redactionRegex.stringByReplacingMatches(
            in: text, range: range, withTemplate: "\"$1\":\"<redacted>\""
        )
        return Data(scrubbed.utf8)
    }

    // MARK: - Implementation

    private func append(direction: String, body: Data) {
        let url = Self.logURL
        let timestamp = formatter.string(from: Date())
        let prefix = "[\(timestamp)] \(direction) "
        var line = Data(prefix.utf8)
        line.append(Self.redacted(body))
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
