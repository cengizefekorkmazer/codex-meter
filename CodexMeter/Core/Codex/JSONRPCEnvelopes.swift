//
//  JSONRPCEnvelopes.swift
//  CodexMeter
//
//  Generic JSON-RPC 2.0 frame types used to encode outgoing requests and
//  decode incoming responses / notifications from the Codex app-server.
//

import Foundation

struct JSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: Params

    init(id: Int, method: String, params: Params) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

struct JSONRPCNotificationOut<Params: Encodable>: Encodable {
    let jsonrpc: String
    let method: String
    let params: Params

    init(method: String, params: Params) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

struct JSONRPCErrorBody: Codable, Error, Equatable {
    let code: Int
    let message: String
}

/// Generic decoder for any incoming message. We do a two-pass decode: first
/// peek at which fields are present to decide message kind, then decode the
/// concrete payload as needed.
struct JSONRPCIncomingMessage {
    let id: Int?
    let method: String?
    let result: Data?
    let params: Data?
    let error: JSONRPCErrorBody?

    var isResponse: Bool { id != nil && method == nil }
    var isNotification: Bool { id == nil && method != nil }

    static func parse(_ data: Data) throws -> JSONRPCIncomingMessage {
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.decodingFailure("not a JSON object")
        }

        let id = raw["id"] as? Int
        let method = raw["method"] as? String

        func reencode(_ key: String) -> Data? {
            guard let obj = raw[key] else { return nil }
            return try? JSONSerialization.data(withJSONObject: obj)
        }

        let errorBody: JSONRPCErrorBody? = {
            guard let err = raw["error"] as? [String: Any] else { return nil }
            let code = (err["code"] as? Int) ?? -1
            let message = (err["message"] as? String) ?? "unknown error"
            return JSONRPCErrorBody(code: code, message: message)
        }()

        return JSONRPCIncomingMessage(
            id: id,
            method: method,
            result: reencode("result"),
            params: reencode("params"),
            error: errorBody
        )
    }
}

/// Used when an RPC method takes no parameters.
struct EmptyParams: Codable {}
