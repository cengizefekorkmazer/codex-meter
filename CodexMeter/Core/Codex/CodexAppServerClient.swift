//
//  CodexAppServerClient.swift
//  CodexMeter
//
//  High-level client for the Codex app-server. Coordinates the child process,
//  the JSON-RPC transport, and the typed methods we care about.
//

import Foundation

@MainActor
final class CodexAppServerClient {
    private let processManager = CodexAppServerProcess()
    private var rpc: JSONRPCClient?
    private var notificationListener: Task<Void, Never>?

    /// Stream of rate-limit snapshots pushed by the server. The caller merges
    /// each snapshot into the local store by `limitId`.
    let rateLimitUpdates: AsyncStream<RateLimitSnapshot>
    private let rateLimitUpdatesContinuation: AsyncStream<RateLimitSnapshot>.Continuation

    /// Stream of `account/updated` notifications. Most callers respond to
    /// these by re-issuing `account/read`.
    let accountUpdates: AsyncStream<Void>
    private let accountUpdatesContinuation: AsyncStream<Void>.Continuation

    /// Stream of `account/login/completed` notifications.
    let loginCompletions: AsyncStream<AccountLoginCompletedParams>
    private let loginCompletionsContinuation: AsyncStream<AccountLoginCompletedParams>.Continuation

    /// Called when the child process exits unexpectedly.
    var onTermination: (() -> Void)?

    init() {
        var rlCont: AsyncStream<RateLimitSnapshot>.Continuation!
        self.rateLimitUpdates = AsyncStream { rlCont = $0 }
        self.rateLimitUpdatesContinuation = rlCont

        var acCont: AsyncStream<Void>.Continuation!
        self.accountUpdates = AsyncStream { acCont = $0 }
        self.accountUpdatesContinuation = acCont

        var lcCont: AsyncStream<AccountLoginCompletedParams>.Continuation!
        self.loginCompletions = AsyncStream { lcCont = $0 }
        self.loginCompletionsContinuation = lcCont

        processManager.onTermination = { [weak self] _ in
            Task { @MainActor in self?.handleTermination() }
        }
    }

    // MARK: - Lifecycle

    /// Resolve the codex binary, spawn the app-server, run the initialize
    /// handshake, and start listening for notifications.
    func connect() async throws {
        guard let path = CodexBinaryResolver.resolve() else {
            throw AppError.codexBinaryNotFound
        }

        try processManager.start(codexPath: path)

        guard let stdin = processManager.stdinHandle,
              let stdout = processManager.stdoutHandle else {
            throw AppError.appServerFailedToStart("missing stdio pipes")
        }

        let client = JSONRPCClient(input: stdin, output: stdout)
        await client.start()
        self.rpc = client

        _ = try await client.request(
            method: CodexMethod.initialize,
            params: InitializeParams(
                clientInfo: InitializeClientInfo(
                    name: "codex-meter",
                    title: "CodexMeter",
                    version: Bundle.main.shortVersion ?? "0.1.0"
                ),
                capabilities: nil
            ),
            as: InitializeResponse.self
        )

        try await client.notify(method: CodexMethod.initialized, params: EmptyParams())

        startNotificationListener(on: client)
    }

    func disconnect() {
        notificationListener?.cancel()
        notificationListener = nil
        Task { [rpc] in await rpc?.stop() }
        rpc = nil
        processManager.terminate()
    }

    // MARK: - RPC methods

    func readAccount() async throws -> GetAccountResponse {
        guard let rpc else { throw AppError.appServerCrashed }
        return try await rpc.request(
            method: CodexMethod.accountRead,
            params: GetAccountParams(refreshToken: false),
            as: GetAccountResponse.self
        )
    }

    func readRateLimits() async throws -> RateLimitsReadResult {
        guard let rpc else { throw AppError.appServerCrashed }
        return try await rpc.request(
            method: CodexMethod.rateLimitsRead,
            params: EmptyParams(),
            as: RateLimitsReadResult.self
        )
    }

    func startChatGPTLogin() async throws -> LoginAccountResponse {
        guard let rpc else { throw AppError.appServerCrashed }
        return try await rpc.request(
            method: CodexMethod.loginStart,
            params: LoginAccountParams.chatgpt(codexStreamlinedLogin: nil),
            as: LoginAccountResponse.self
        )
    }

    func startDeviceCodeLogin() async throws -> LoginAccountResponse {
        guard let rpc else { throw AppError.appServerCrashed }
        return try await rpc.request(
            method: CodexMethod.loginStart,
            params: LoginAccountParams.chatgptDeviceCode,
            as: LoginAccountResponse.self
        )
    }

    func cancelLogin(loginId: String) async throws {
        guard let rpc else { throw AppError.appServerCrashed }
        _ = try await rpc.request(
            method: CodexMethod.loginCancel,
            params: CancelLoginAccountParams(loginId: loginId),
            as: CancelLoginAccountResponse.self
        )
    }

    func logout() async throws {
        guard let rpc else { throw AppError.appServerCrashed }
        _ = try await rpc.request(
            method: CodexMethod.logout,
            params: EmptyParams(),
            as: LogoutAccountResponse.self
        )
    }

    // MARK: - Notifications

    private func startNotificationListener(on client: JSONRPCClient) {
        notificationListener = Task { [weak self] in
            for await message in client.notifications {
                guard let self else { return }
                await self.dispatch(message)
            }
        }
    }

    private func dispatch(_ message: JSONRPCIncomingMessage) async {
        guard let method = message.method else { return }
        switch method {
        case CodexMethod.rateLimitsUpdated:
            guard let data = message.params,
                  let payload = try? JSONDecoder().decode(RateLimitsUpdatedParams.self, from: data) else { return }
            rateLimitUpdatesContinuation.yield(payload.rateLimits)
        case CodexMethod.accountUpdated:
            accountUpdatesContinuation.yield(())
        case CodexMethod.loginCompleted:
            guard let data = message.params,
                  let payload = try? JSONDecoder().decode(AccountLoginCompletedParams.self, from: data) else { return }
            loginCompletionsContinuation.yield(payload)
        default:
            break  // ignore methods we don't care about
        }
    }

    private func handleTermination() {
        disconnect()
        onTermination?()
    }
}

private extension Bundle {
    var shortVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
