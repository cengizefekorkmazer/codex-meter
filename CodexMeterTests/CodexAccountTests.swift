//
//  CodexAccountTests.swift
//  CodexMeterTests
//

import XCTest
@testable import CodexMeter

final class CodexAccountTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func test_decodes_chatgpt_with_email_and_plan() throws {
        let json = #"{"type": "chatgpt", "email": "user@example.com", "planType": "plus"}"#
        let account = try decoder.decode(CodexAccount.self, from: Data(json.utf8))
        XCTAssertEqual(account, .chatgpt(email: "user@example.com", planType: "plus"))
    }

    func test_decodes_apiKey() throws {
        let json = #"{"type": "apiKey"}"#
        XCTAssertEqual(try decoder.decode(CodexAccount.self, from: Data(json.utf8)),
                       .apiKey)
    }

    func test_decodes_amazonBedrock() throws {
        let json = #"{"type": "amazonBedrock"}"#
        XCTAssertEqual(try decoder.decode(CodexAccount.self, from: Data(json.utf8)),
                       .amazonBedrock)
    }

    func test_throws_on_unknown_type() {
        let json = #"{"type": "fictional-provider"}"#
        XCTAssertThrowsError(try decoder.decode(CodexAccount.self, from: Data(json.utf8)))
    }

    func test_encode_roundtrip_chatgpt() throws {
        let account = CodexAccount.chatgpt(email: "a@b.com", planType: "team")
        let data = try encoder.encode(account)
        let decoded = try decoder.decode(CodexAccount.self, from: data)
        XCTAssertEqual(account, decoded)
    }

    func test_decodes_inside_GetAccountResponse_wrapper() throws {
        let json = #"""
        {"account": {"type": "chatgpt", "email": "x@y.com", "planType": "pro"},
         "requiresOpenaiAuth": true}
        """#
        let response = try decoder.decode(GetAccountResponse.self, from: Data(json.utf8))
        XCTAssertTrue(response.requiresOpenaiAuth)
        XCTAssertEqual(response.account, .chatgpt(email: "x@y.com", planType: "pro"))
    }

    func test_GetAccountResponse_decodes_null_account_as_signed_out() throws {
        let json = #"{"account": null, "requiresOpenaiAuth": true}"#
        let response = try decoder.decode(GetAccountResponse.self, from: Data(json.utf8))
        XCTAssertNil(response.account)
    }
}

final class LoginAccountResponseTests: XCTestCase {
    private let decoder = JSONDecoder()

    func test_decodes_chatgpt_variant() throws {
        let json = #"{"type": "chatgpt", "authUrl": "https://auth.openai.com/x", "loginId": "abc"}"#
        let response = try decoder.decode(LoginAccountResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response, .chatgpt(authUrl: "https://auth.openai.com/x", loginId: "abc"))
    }

    func test_decodes_deviceCode_variant() throws {
        let json = #"""
        {"type": "chatgptDeviceCode",
         "userCode": "ABCD-EFGH",
         "verificationUrl": "https://chatgpt.com/device",
         "loginId": "dev-1"}
        """#
        let response = try decoder.decode(LoginAccountResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response,
                       .deviceCode(userCode: "ABCD-EFGH",
                                   verificationUrl: "https://chatgpt.com/device",
                                   loginId: "dev-1"))
    }

    func test_decodes_apiKey_variant() throws {
        let json = #"{"type": "apiKey"}"#
        XCTAssertEqual(try decoder.decode(LoginAccountResponse.self, from: Data(json.utf8)),
                       .apiKey)
    }

    func test_throws_on_unknown_type() {
        let json = #"{"type": "magic-link"}"#
        XCTAssertThrowsError(try decoder.decode(LoginAccountResponse.self, from: Data(json.utf8)))
    }
}
