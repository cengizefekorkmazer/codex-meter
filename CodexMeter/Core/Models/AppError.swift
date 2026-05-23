//
//  AppError.swift
//  CodexMeter
//

import Foundation

enum AppError: Error, Equatable, LocalizedError {
    case codexBinaryNotFound
    case appServerFailedToStart(String)
    case appServerCrashed
    case notAuthenticated
    case jsonRpcError(code: Int, message: String)
    case decodingFailure(String)
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .codexBinaryNotFound:
            return "Codex CLI was not found on PATH."
        case .appServerFailedToStart(let detail):
            return "Codex app-server failed to start: \(detail)"
        case .appServerCrashed:
            return "Codex app-server exited unexpectedly."
        case .notAuthenticated:
            return "Not signed in to Codex."
        case .jsonRpcError(let code, let message):
            return "Codex error \(code): \(message)"
        case .decodingFailure(let detail):
            return "Could not decode Codex response: \(detail)"
        case .unexpected(let detail):
            return detail
        }
    }
}
