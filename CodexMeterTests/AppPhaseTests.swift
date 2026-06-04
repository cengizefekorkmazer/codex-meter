//
//  AppPhaseTests.swift
//  CodexMeterTests
//

import XCTest
@testable import CodexMeter

final class AppPhaseTests: XCTestCase {

    func test_codex_binary_missing_takes_priority_over_everything() {
        let phase = AppPhase.derive(
            codexBinaryFound: false,
            connection: .connected,
            account: .signedIn(email: "a@b.com", planType: "plus", accountType: "chatgpt"),
            loginAttempt: nil
        )
        XCTAssertEqual(phase, .codexMissing)
    }

    func test_connection_failed_maps_to_error_with_reason() {
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .failed(reason: "app-server exited"),
            account: .unknown,
            loginAttempt: nil
        )
        XCTAssertEqual(phase, .error("app-server exited"))
    }

    func test_initial_state_shows_startup() {
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .disconnected,
            account: .unknown,
            loginAttempt: nil
        )
        XCTAssertEqual(phase, .startup)
    }

    func test_connecting_shows_startup() {
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .connecting,
            account: .unknown,
            loginAttempt: nil
        )
        XCTAssertEqual(phase, .startup)
    }

    func test_login_attempt_in_progress_shows_signingIn() {
        let prompt = LoginPrompt.chatgpt(authUrl: URL(string: "https://x"), loginId: "L1")
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .connected,
            account: .signedOut,
            loginAttempt: prompt
        )
        XCTAssertEqual(phase, .signingIn(prompt))
    }

    func test_signed_out_with_no_login_attempt_shows_signedOut() {
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .connected,
            account: .signedOut,
            loginAttempt: nil
        )
        XCTAssertEqual(phase, .signedOut)
    }

    func test_signed_in_and_connected_shows_ready() {
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .connected,
            account: .signedIn(email: "a@b.com", planType: "plus", accountType: "chatgpt"),
            loginAttempt: nil
        )
        XCTAssertEqual(phase, .ready)
    }

    func test_error_overrides_login_attempt() {
        // If the app-server crashed mid-login, surface the error, not the
        // sign-in UI — otherwise the user is stuck staring at a spinner.
        let prompt = LoginPrompt.chatgpt(authUrl: nil, loginId: "L1")
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .failed(reason: "crashed"),
            account: .signedOut,
            loginAttempt: prompt
        )
        XCTAssertEqual(phase, .error("crashed"))
    }

    func test_apiKeyEntry_takes_priority_over_loginAttempt() {
        let prompt = LoginPrompt.chatgpt(authUrl: nil, loginId: "L1")
        let entry = ApiKeyEntryState()
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .connected,
            account: .signedOut,
            loginAttempt: prompt,
            apiKeyEntry: entry
        )
        XCTAssertEqual(phase, .apiKeyEntry(entry))
    }

    func test_apiKeyEntry_yields_to_error() {
        let entry = ApiKeyEntryState()
        let phase = AppPhase.derive(
            codexBinaryFound: true,
            connection: .failed(reason: "boom"),
            account: .signedOut,
            loginAttempt: nil,
            apiKeyEntry: entry
        )
        XCTAssertEqual(phase, .error("boom"))
    }
}
