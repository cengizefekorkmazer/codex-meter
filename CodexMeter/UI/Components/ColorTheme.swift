//
//  ColorTheme.swift
//  CodexMeter
//

import SwiftUI

enum ColorTheme {
    /// Map a 0-100 usage percentage to a status color.
    static func color(forUsage usedPercent: Double) -> Color {
        switch usedPercent {
        case ..<50: return .green
        case ..<75: return .yellow
        case ..<90: return .orange
        default:    return .red
        }
    }
}
