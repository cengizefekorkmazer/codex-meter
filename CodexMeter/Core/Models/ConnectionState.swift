//
//  ConnectionState.swift
//  CodexMeter
//

import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(reason: String)
}
