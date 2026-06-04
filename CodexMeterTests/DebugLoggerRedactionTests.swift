//
//  DebugLoggerRedactionTests.swift
//  CodexMeterTests
//

import XCTest
@testable import CodexMeter

final class DebugLoggerRedactionTests: XCTestCase {

    private func redact(_ json: String) -> String {
        String(data: DebugLogger.redacted(Data(json.utf8)), encoding: .utf8)!
    }

    func test_redacts_apiKey_from_outbound_login_frame() {
        let frame = #"{"jsonrpc":"2.0","id":3,"method":"account/login/start","params":{"type":"apiKey","apiKey":"sk-proj-SECRET123"}}"#
        let out = redact(frame)

        XCTAssertFalse(out.contains("sk-proj-SECRET123"), "raw API key must not survive")
        XCTAssertTrue(out.contains(#""apiKey":"<redacted>""#))
        XCTAssertTrue(out.contains(#""method":"account/login/start""#))
        XCTAssertTrue(out.contains(#""type":"apiKey""#))
    }

    func test_redacts_auth_urls_from_inbound_login_response() {
        let frame = #"{"id":4,"result":{"type":"chatgpt","authUrl":"https://auth.openai.com/oauth?state=abc123","loginId":"L1"}}"#
        let out = redact(frame)

        XCTAssertFalse(out.contains("state=abc123"))
        XCTAssertTrue(out.contains(#""authUrl":"<redacted>""#))
        XCTAssertTrue(out.contains(#""loginId":"L1""#))
    }

    func test_redacts_oauth_tokens() {
        let frame = #"{"result":{"accessToken":"eyJhbGciOi.PAYLOAD.SIG","refreshToken":"rt_9f8e7d"}}"#
        let out = redact(frame)

        XCTAssertFalse(out.contains("eyJhbGciOi.PAYLOAD.SIG"))
        XCTAssertFalse(out.contains("rt_9f8e7d"))
        XCTAssertTrue(out.contains(#""accessToken":"<redacted>""#))
        XCTAssertTrue(out.contains(#""refreshToken":"<redacted>""#))
    }

    func test_leaves_non_sensitive_frames_byte_for_byte() {
        let frame = #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":42.0}}}}"#
        XCTAssertEqual(redact(frame), frame)
    }

    func test_does_not_redact_account_email() {
        // Email is intentionally retained — the log is documented as private user data.
        let frame = #"{"result":{"account":{"email":"user@example.com","planType":"plus"}}}"#
        XCTAssertEqual(redact(frame), frame)
    }

    func test_redacts_every_occurrence_in_one_frame() {
        let frame = #"{"a":{"apiKey":"sk-one"},"b":{"apiKey":"sk-two"}}"#
        let out = redact(frame)

        XCTAssertFalse(out.contains("sk-one"))
        XCTAssertFalse(out.contains("sk-two"))
        XCTAssertEqual(out, #"{"a":{"apiKey":"<redacted>"},"b":{"apiKey":"<redacted>"}}"#)
    }
}
