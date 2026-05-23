//
//  JSONRPCClient.swift
//  CodexMeter
//
//  Line-framed JSON-RPC 2.0 client over a pair of FileHandles. One instance
//  serves one app-server process.
//

import Foundation

actor JSONRPCClient {
    private let input: FileHandle   // we write to this (child's stdin)
    private let output: FileHandle  // we read from this (child's stdout)

    private var nextId: Int = 0
    private var pendingResponses: [Int: CheckedContinuation<Data, Error>] = [:]
    private var readTask: Task<Void, Never>?

    private let notificationContinuation: AsyncStream<JSONRPCIncomingMessage>.Continuation
    /// All incoming notifications. Filtered downstream by method.
    nonisolated let notifications: AsyncStream<JSONRPCIncomingMessage>

    init(input: FileHandle, output: FileHandle) {
        self.input = input
        self.output = output
        var continuation: AsyncStream<JSONRPCIncomingMessage>.Continuation!
        self.notifications = AsyncStream { continuation = $0 }
        self.notificationContinuation = continuation
    }

    /// Begin reading messages off `output`. Idempotent.
    func start() {
        guard readTask == nil else { return }
        readTask = Task.detached(priority: .utility) { [weak self] in
            await self?.readLoop()
        }
    }

    /// Stop the read loop, fail all pending requests, and close the
    /// notification stream.
    func stop(reason: AppError = .appServerCrashed) {
        readTask?.cancel()
        readTask = nil
        for (_, cont) in pendingResponses {
            cont.resume(throwing: reason)
        }
        pendingResponses.removeAll()
        notificationContinuation.finish()
    }

    // MARK: - Sending

    /// Send a JSON-RPC request and await its typed response.
    func request<P: Encodable, R: Decodable>(
        method: String,
        params: P,
        as responseType: R.Type
    ) async throws -> R {
        let id = allocateId()
        let envelope = JSONRPCRequest(id: id, method: method, params: params)
        let line = try Self.encodeLine(envelope)

        let data: Data = try await withCheckedThrowingContinuation { cont in
            pendingResponses[id] = cont
            do {
                try writeLine(line)
            } catch {
                pendingResponses.removeValue(forKey: id)
                cont.resume(throwing: error)
            }
        }

        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw AppError.decodingFailure("\(method): \(error)")
        }
    }

    /// Send a fire-and-forget notification.
    func notify<P: Encodable>(method: String, params: P) throws {
        let envelope = JSONRPCNotificationOut(method: method, params: params)
        let line = try Self.encodeLine(envelope)
        try writeLine(line)
    }

    // MARK: - Reading

    private func readLoop() async {
        do {
            for try await line in output.bytes.lines {
                guard !Task.isCancelled else { return }
                guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                DebugLogger.shared.logInbound(data)
                await handle(data)
            }
        } catch {
            // Read ended (EOF or error); fall through to stop().
        }
        await stop(reason: .appServerCrashed)
    }

    private func handle(_ data: Data) async {
        let message: JSONRPCIncomingMessage
        do {
            message = try JSONRPCIncomingMessage.parse(data)
        } catch {
            return  // ignore unparseable noise
        }

        if message.isResponse, let id = message.id {
            guard let cont = pendingResponses.removeValue(forKey: id) else { return }
            if let err = message.error {
                cont.resume(throwing: AppError.jsonRpcError(code: err.code, message: err.message))
            } else if let result = message.result {
                cont.resume(returning: result)
            } else {
                // result-less success (e.g. logout) — return empty object
                cont.resume(returning: Data("{}".utf8))
            }
        } else if message.isNotification {
            notificationContinuation.yield(message)
        }
        // Server requests are intentionally dropped; we don't act on them.
    }

    // MARK: - Helpers

    private func allocateId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }

    private func writeLine(_ line: Data) throws {
        DebugLogger.shared.logOutbound(line)
        var payload = line
        payload.append(0x0A)  // newline
        try input.write(contentsOf: payload)
    }

    private static func encodeLine<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        do {
            return try encoder.encode(value)
        } catch {
            throw AppError.unexpected("failed to encode JSON-RPC frame: \(error)")
        }
    }
}
