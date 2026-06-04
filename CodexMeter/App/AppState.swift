//
//  AppState.swift
//  CodexMeter
//

import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var account: AccountState = .unknown
    @Published private(set) var snapshots: [RateLimitSnapshot] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var connection: ConnectionState = .disconnected
    @Published private(set) var codexBinaryFound: Bool = true
    @Published private(set) var loginAttempt: LoginPrompt?
    @Published private(set) var apiKeyEntry: ApiKeyEntryState?
    @Published private(set) var error: AppError?
    @Published private(set) var settings: AppSettings = .load()

    private let client = CodexAppServerClient()
    private var listenerTasks: [Task<Void, Never>] = []

    // Reconnect bookkeeping
    private var consecutiveReconnectAttempts: Int = 0
    private var reconnectTask: Task<Void, Never>?

    // Polling
    private var pollingTimer: Timer?
    private var isFetching: Bool = false

    // Sleep/wake
    private var sleepStartedAt: Date?

    init() {
        client.onTermination = { [weak self] in
            Task { @MainActor in self?.handleTermination() }
        }
        registerLifecycleObservers()
        subscribeToNotifications()
        DebugLogger.shared.setEnabled(settings.debugMode)
        if settings.notificationsEnabled {
            Task { await NotificationService.shared.requestPermission() }
        }
        Task { await bringUp() }
    }

    // MARK: - Settings

    func updateSetting(_ apply: (inout AppSettings) -> Void) {
        var next = settings
        apply(&next)
        guard next != settings else { return }
        let intervalChanged = next.refreshIntervalSeconds != settings.refreshIntervalSeconds
        let debugChanged = next.debugMode != settings.debugMode
        settings = next
        next.save()
        if intervalChanged, pollingTimer != nil {
            startPollingTimer()
        }
        if debugChanged {
            DebugLogger.shared.setEnabled(next.debugMode)
        }
    }

    /// Set (or clear, with "") the manual codex binary path, then re-attempt
    /// startup so the change takes effect without relaunching the app.
    func setCustomCodexBinaryPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSetting { $0.customCodexBinaryPath = trimmed }
        retryStartup()
    }

    deinit {
        listenerTasks.forEach { $0.cancel() }
        reconnectTask?.cancel()
        pollingTimer?.invalidate()
        let client = self.client
        Task { @MainActor in client.disconnect() }
    }

    // MARK: - Phase

    var phase: AppPhase {
        AppPhase.derive(
            codexBinaryFound: codexBinaryFound,
            connection: connection,
            account: account,
            loginAttempt: loginAttempt,
            apiKeyEntry: apiKeyEntry
        )
    }

    // MARK: - Lifecycle

    private func bringUp() async {
        reconnectTask?.cancel()
        reconnectTask = nil

        let customPath = settings.customCodexBinaryPath
        let resolvedPath = await Task.detached(priority: .userInitiated) {
            CodexBinaryResolver.resolve(customPath: customPath)
        }.value

        guard let codexPath = resolvedPath else {
            codexBinaryFound = false
            connection = .disconnected
            stopPollingTimer()
            return
        }
        codexBinaryFound = true

        connection = .connecting
        error = nil

        do {
            client.disconnect()  // tear down any stale state from a prior attempt
            try await client.connect(codexPath: codexPath)
            connection = .connected
            consecutiveReconnectAttempts = 0

            try await refreshAccount()
            try await refreshRateLimits()
            lastUpdated = Date()
            startPollingTimer()
        } catch let appError as AppError {
            error = appError
            connection = .failed(reason: appError.errorDescription ?? "unknown error")
            scheduleReconnect()
        } catch {
            self.error = .unexpected(error.localizedDescription)
            connection = .failed(reason: error.localizedDescription)
            scheduleReconnect()
        }
    }

    func retryStartup() {
        consecutiveReconnectAttempts = 0
        Task { await bringUp() }
    }

    func refresh() async {
        guard case .connected = connection else { return }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            try await refreshRateLimits()
            lastUpdated = Date()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
    }

    // MARK: - Reconnect

    private func handleTermination() {
        connection = .failed(reason: "app-server exited")
        stopPollingTimer()
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delays = Constants.Reconnect.backoffDelays
        let index = min(consecutiveReconnectAttempts, delays.count - 1)
        let delay = delays[index]
        consecutiveReconnectAttempts += 1

        print("AppState: scheduling reconnect attempt #\(consecutiveReconnectAttempts) in \(delay)s")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.bringUp()
        }
    }

    // MARK: - Polling

    private func startPollingTimer() {
        stopPollingTimer()
        let interval = TimeInterval(settings.refreshIntervalSeconds)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
    }

    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Sleep/Wake

    private func registerLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSleep() }
        }
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
    }

    private func handleSleep() {
        sleepStartedAt = Date()
        stopPollingTimer()
        reconnectTask?.cancel()
        reconnectTask = nil
        print("AppState: system going to sleep")
    }

    private func handleWake() {
        let sleepDuration = sleepStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        sleepStartedAt = nil
        print("AppState: system woke after \(String(format: "%.0f", sleepDuration))s")

        if sleepDuration >= Constants.WakeRecovery.significantSleepDuration {
            // Discard stale UI state; refresh will repopulate it.
            snapshots = []
            lastUpdated = nil
        }

        if case .connected = connection {
            Task {
                await refresh()
                startPollingTimer()
            }
        } else {
            // Connection had failed or was disconnected — trigger a fresh
            // reconnect attempt immediately rather than waiting on backoff.
            consecutiveReconnectAttempts = 0
            Task { await bringUp() }
        }
    }

    // MARK: - Login

    func startChatGPTLogin() {
        Task { await performLogin(.chatgpt) }
    }

    func startDeviceCodeLogin() {
        Task { await performLogin(.deviceCode) }
    }

    func startApiKeyEntry() {
        apiKeyEntry = ApiKeyEntryState()
    }

    func cancelApiKeyEntry() {
        apiKeyEntry = nil
    }

    func submitApiKey(_ key: String) {
        apiKeyEntry?.isSubmitting = true
        apiKeyEntry?.errorMessage = nil
        Task {
            do {
                _ = try await client.loginWithApiKey(key)
                // Successful API-key login returns immediately; the server
                // then emits account/updated which triggers a refresh.
                apiKeyEntry = nil
                try? await refreshAccount()
                try? await refreshRateLimits()
                lastUpdated = Date()
            } catch let appError as AppError {
                apiKeyEntry?.isSubmitting = false
                apiKeyEntry?.errorMessage = appError.errorDescription ?? "Sign-in failed."
            } catch {
                apiKeyEntry?.isSubmitting = false
                apiKeyEntry?.errorMessage = error.localizedDescription
            }
        }
    }

    func cancelCurrentLogin() {
        guard let attempt = loginAttempt else { return }
        let loginId = attempt.loginId
        loginAttempt = nil
        Task { try? await client.cancelLogin(loginId: loginId) }
    }

    func signOut() {
        Task {
            do {
                try await client.logout()
                account = .signedOut
                snapshots = []
            } catch {
                self.error = (error as? AppError) ?? .unexpected(error.localizedDescription)
            }
        }
    }

    private enum LoginKind { case chatgpt, deviceCode }

    private func performLogin(_ kind: LoginKind) async {
        do {
            let response: LoginAccountResponse
            switch kind {
            case .chatgpt:    response = try await client.startChatGPTLogin()
            case .deviceCode: response = try await client.startDeviceCodeLogin()
            }

            switch response {
            case .chatgpt(let authUrl, let loginId):
                let url = URL(string: authUrl)
                loginAttempt = .chatgpt(authUrl: url, loginId: loginId)
                if let url { NSWorkspace.shared.open(url) }
            case .deviceCode(let userCode, let verificationUrl, let loginId):
                loginAttempt = .deviceCode(
                    userCode: userCode,
                    verificationUrl: URL(string: verificationUrl),
                    loginId: loginId
                )
            case .apiKey:
                loginAttempt = nil
            }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
    }

    // MARK: - Calls

    private func refreshAccount() async throws {
        let response = try await client.readAccount()
        account = Self.mapAccount(response)
    }

    private func refreshRateLimits() async throws {
        guard case .signedIn = account else {
            snapshots = []
            return
        }
        let result = try await client.readRateLimits()
        snapshots = result.buckets
        maybeNotify()
    }

    private static func mapAccount(_ response: GetAccountResponse) -> AccountState {
        guard let codexAccount = response.account else { return .signedOut }
        switch codexAccount {
        case .apiKey:
            return .signedIn(email: nil, planType: nil, accountType: "apiKey")
        case .chatgpt(let email, let plan):
            return .signedIn(email: email, planType: plan, accountType: "chatgpt")
        case .amazonBedrock:
            return .signedIn(email: nil, planType: nil, accountType: "amazonBedrock")
        }
    }

    // MARK: - Notifications

    private func subscribeToNotifications() {
        let rateLimitUpdates = client.rateLimitUpdates
        let accountUpdates = client.accountUpdates
        let loginCompletions = client.loginCompletions

        listenerTasks.append(Task { [weak self] in
            for await snapshot in rateLimitUpdates {
                await self?.applyRateLimitUpdate(snapshot)
            }
        })

        listenerTasks.append(Task { [weak self] in
            for await _ in accountUpdates {
                try? await self?.refreshAccount()
                try? await self?.refreshRateLimits()
                await MainActor.run { self?.lastUpdated = Date() }
            }
        })

        listenerTasks.append(Task { [weak self] in
            for await completion in loginCompletions {
                await self?.handleLoginCompletion(completion)
            }
        })
    }

    private func applyRateLimitUpdate(_ snapshot: RateLimitSnapshot) {
        if let index = snapshots.firstIndex(where: { $0.limitId == snapshot.limitId }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
        snapshots.sort { ($0.limitId ?? "") < ($1.limitId ?? "") }
        lastUpdated = Date()
        maybeNotify()
    }

    private func maybeNotify() {
        guard settings.notificationsEnabled else { return }
        NotificationService.shared.checkAndNotify(
            snapshots: snapshots,
            thresholds: settings.notificationThresholds
        )
    }

    private func handleLoginCompletion(_ completion: AccountLoginCompletedParams) async {
        loginAttempt = nil
        if completion.success {
            try? await refreshAccount()
            try? await refreshRateLimits()
            lastUpdated = Date()
        } else if let message = completion.error {
            error = .unexpected("Login failed: \(message)")
        }
    }

    // MARK: - Computed

    var primaryUsage: Double {
        snapshots.first?.primary.map { Double($0.displayedPercent) } ?? 0
    }
}

// MARK: - App phase

enum AppPhase: Equatable {
    case startup
    case codexMissing
    case error(String)
    case signedOut
    case signingIn(LoginPrompt)
    case apiKeyEntry(ApiKeyEntryState)
    case ready

    /// Pure derivation function — kept separate from `AppState` so it can be
    /// unit-tested without spinning up the live `CodexAppServerClient`.
    static func derive(
        codexBinaryFound: Bool,
        connection: ConnectionState,
        account: AccountState,
        loginAttempt: LoginPrompt?,
        apiKeyEntry: ApiKeyEntryState? = nil
    ) -> AppPhase {
        if !codexBinaryFound { return .codexMissing }
        if case .failed(let reason) = connection { return .error(reason) }
        if case .disconnected = connection, account == .unknown { return .startup }
        if case .connecting = connection { return .startup }
        if let entry = apiKeyEntry { return .apiKeyEntry(entry) }
        if let attempt = loginAttempt { return .signingIn(attempt) }
        if case .signedOut = account { return .signedOut }
        if case .signedIn = account { return .ready }
        return .startup
    }
}

struct ApiKeyEntryState: Equatable {
    var isSubmitting: Bool = false
    var errorMessage: String?
}

enum LoginPrompt: Equatable {
    case chatgpt(authUrl: URL?, loginId: String)
    case deviceCode(userCode: String, verificationUrl: URL?, loginId: String)

    var loginId: String {
        switch self {
        case .chatgpt(_, let id):       return id
        case .deviceCode(_, _, let id): return id
        }
    }
}
