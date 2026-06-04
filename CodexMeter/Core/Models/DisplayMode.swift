//
//  DisplayMode.swift
//  CodexMeter
//

import Foundation

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case iconOnly
    case compact
    case detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .compact:  return "Icon + percentage"
        case .detailed: return "5h | 7d"
        }
    }
}
