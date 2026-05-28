//
//  CodexProtocolTypes.swift
//  CodexMeter
//
//  Codable types mirroring the Codex app-server JSON-RPC schema. Source of
//  truth is `Docs/protocol-schema/` (frozen from codex 0.133.0).
//

import Foundation

// MARK: - initialize

struct InitializeClientInfo: Codable {
    let name: String
    let title: String?
    let version: String
}

struct InitializeCapabilities: Codable {
    let experimentalApi: Bool?
    let requestAttestation: Bool?
}

struct InitializeParams: Codable {
    let clientInfo: InitializeClientInfo
    let capabilities: InitializeCapabilities?
}

struct InitializeResponse: Codable {
    let userAgent: String
    let codexHome: String
    let platformFamily: String?
    let platformOs: String?
}

// MARK: - account/read

struct GetAccountParams: Codable {
    let refreshToken: Bool

    init(refreshToken: Bool = false) {
        self.refreshToken = refreshToken
    }
}

struct GetAccountResponse: Codable {
    let account: CodexAccount?
    let requiresOpenaiAuth: Bool
}

/// Discriminated union: `{ "type": "apiKey" } | { "type": "chatgpt", email, planType } | { "type": "amazonBedrock" }`
enum CodexAccount: Codable, Equatable {
    case apiKey
    case chatgpt(email: String, planType: String)
    case amazonBedrock

    private enum CodingKeys: String, CodingKey {
        case type, email, planType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "apiKey":
            self = .apiKey
        case "chatgpt":
            let email = try c.decode(String.self, forKey: .email)
            let plan = try c.decode(String.self, forKey: .planType)
            self = .chatgpt(email: email, planType: plan)
        case "amazonBedrock":
            self = .amazonBedrock
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: c,
                debugDescription: "Unknown account type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .apiKey:
            try c.encode("apiKey", forKey: .type)
        case .chatgpt(let email, let plan):
            try c.encode("chatgpt", forKey: .type)
            try c.encode(email, forKey: .email)
            try c.encode(plan, forKey: .planType)
        case .amazonBedrock:
            try c.encode("amazonBedrock", forKey: .type)
        }
    }
}

// MARK: - account/rateLimits/updated notification payload

struct RateLimitsUpdatedParams: Codable {
    let rateLimits: RateLimitSnapshot
}

// MARK: - account/login/start

/// Discriminated union sent to `account/login/start`.
enum LoginAccountParams: Encodable {
    case chatgpt(codexStreamlinedLogin: Bool?)
    case chatgptDeviceCode
    case apiKey(String)

    private enum CodingKeys: String, CodingKey {
        case type, codexStreamlinedLogin, apiKey
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .chatgpt(let streamlined):
            try c.encode("chatgpt", forKey: .type)
            try c.encodeIfPresent(streamlined, forKey: .codexStreamlinedLogin)
        case .chatgptDeviceCode:
            try c.encode("chatgptDeviceCode", forKey: .type)
        case .apiKey(let key):
            try c.encode("apiKey", forKey: .type)
            try c.encode(key, forKey: .apiKey)
        }
    }
}

/// Discriminated union returned by `account/login/start`.
enum LoginAccountResponse: Decodable, Equatable {
    case apiKey
    case chatgpt(authUrl: String, loginId: String)
    case deviceCode(userCode: String, verificationUrl: String, loginId: String)

    private enum CodingKeys: String, CodingKey {
        case type, authUrl, loginId, userCode, verificationUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "apiKey":
            self = .apiKey
        case "chatgpt":
            let url = try c.decode(String.self, forKey: .authUrl)
            let id = try c.decode(String.self, forKey: .loginId)
            self = .chatgpt(authUrl: url, loginId: id)
        case "chatgptDeviceCode":
            let code = try c.decode(String.self, forKey: .userCode)
            let url = try c.decode(String.self, forKey: .verificationUrl)
            let id = try c.decode(String.self, forKey: .loginId)
            self = .deviceCode(userCode: code, verificationUrl: url, loginId: id)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: c,
                debugDescription: "Unknown login response type: \(type)"
            )
        }
    }
}

// MARK: - account/login/cancel

struct CancelLoginAccountParams: Encodable {
    let loginId: String
}

struct CancelLoginAccountResponse: Decodable {
    let status: String  // "canceled" | "notFound"
}

// MARK: - account/logout

struct LogoutAccountResponse: Decodable {}

// MARK: - account/login/completed notification

struct AccountLoginCompletedParams: Decodable {
    let success: Bool
    let error: String?
    let loginId: String?
}

// MARK: - method names

enum CodexMethod {
    static let initialize       = "initialize"
    static let initialized      = "initialized"
    static let accountRead      = "account/read"
    static let rateLimitsRead   = "account/rateLimits/read"
    static let loginStart       = "account/login/start"
    static let loginCancel      = "account/login/cancel"
    static let logout           = "account/logout"
    static let rateLimitsUpdated = "account/rateLimits/updated"
    static let accountUpdated   = "account/updated"
    static let loginCompleted   = "account/login/completed"
}
