//
//  UsageProviderKind.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation
import SwiftUI

/// Identifies the source provider for usage data
enum UsageProviderKind: String, Codable, CaseIterable, Identifiable {
    case claude
    case codex
    case copilot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .codex:   return "Codex"
        case .copilot: return "GitHub Copilot"
        }
    }

    var iconName: String {
        switch self {
        case .claude:  return "brain.head.profile"
        case .codex:   return "terminal.fill"
        case .copilot: return "airplane"
        }
    }

    var accentColor: Color {
        switch self {
        case .claude:  return .accentColor
        case .codex:   return .green
        case .copilot: return .blue
        }
    }

    /// Short prefix for menu bar icon labels in multi-profile mode
    var menuBarPrefix: String {
        switch self {
        case .claude:  return "CL"
        case .codex:   return "CX"
        case .copilot: return "GH"
        }
    }
}
