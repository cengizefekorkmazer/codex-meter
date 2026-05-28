//
//  JSONRPCIncomingMessageTests.swift
//  CodexMeterTests
//

import XCTest
@testable import CodexMeter

final class JSONRPCIncomingMessageTests: XCTestCase {

    func test_parses_a_response_with_id_and_result() throws {
        let raw = Data(#"{"id": 3, "result": {"ok": true}}"#.utf8)
        let message = try JSONRPCIncomingMessage.parse(raw)

        XCTAssertEqual(message.id, 3)
        XCTAssertNil(message.method)
        XCTAssertNil(message.error)
        XCTAssertTrue(message.isResponse)
        XCTAssertFalse(message.isNotification)
        XCTAssertNotNil(message.result)

        let decoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: message.result!) as? [String: Any]
        )
        XCTAssertEqual(decoded["ok"] as? Bool, true)
    }

    func test_parses_an_error_response() throws {
        let raw = Data(#"""
        {"id": 7, "error": {"code": -32601, "message": "method not found"}}
        """#.utf8)
        let message = try JSONRPCIncomingMessage.parse(raw)

        XCTAssertEqual(message.id, 7)
        XCTAssertEqual(message.error?.code, -32601)
        XCTAssertEqual(message.error?.message, "method not found")
        XCTAssertTrue(message.isResponse)
    }

    func test_parses_a_notification_with_method_and_params() throws {
        let raw = Data(#"""
        {"method": "account/rateLimits/updated",
         "params": {"rateLimits": {"limitId": "codex"}}}
        """#.utf8)
        let message = try JSONRPCIncomingMessage.parse(raw)

        XCTAssertNil(message.id)
        XCTAssertEqual(message.method, "account/rateLimits/updated")
        XCTAssertTrue(message.isNotification)
        XCTAssertFalse(message.isResponse)
        XCTAssertNotNil(message.params)
    }

    func test_throws_on_non_object_payload() {
        let raw = Data("[1, 2, 3]".utf8)
        XCTAssertThrowsError(try JSONRPCIncomingMessage.parse(raw))
    }

    func test_throws_on_garbage_json() {
        let raw = Data("not even json".utf8)
        XCTAssertThrowsError(try JSONRPCIncomingMessage.parse(raw))
    }

    func test_error_body_defaults_when_fields_missing() throws {
        let raw = Data(#"{"id": 9, "error": {}}"#.utf8)
        let message = try JSONRPCIncomingMessage.parse(raw)
        XCTAssertEqual(message.error?.code, -1)
        XCTAssertEqual(message.error?.message, "unknown error")
    }
}
