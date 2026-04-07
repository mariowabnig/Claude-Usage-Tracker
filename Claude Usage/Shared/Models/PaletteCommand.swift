//
//  PaletteCommand.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-07.
//

import Foundation

/// A single command shown in the command palette
struct PaletteCommand: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let category: Category
    let action: () -> Void
    /// Optional children for drillable commands (e.g. language list)
    let children: [PaletteCommand]?

    enum Category: String, CaseIterable {
        case actions = "Actions"
        case profiles = "Profiles"
        case settings = "Settings"
        case window = "Window"
        case updates = "Updates"

        var localizedTitle: String {
            switch self {
            case .actions: return "command_palette.category.actions".localized
            case .profiles: return "command_palette.category.profiles".localized
            case .settings: return "command_palette.category.settings".localized
            case .window: return "command_palette.category.window".localized
            case .updates: return "command_palette.category.updates".localized
            }
        }
    }

    init(id: String, title: String, icon: String, category: Category, children: [PaletteCommand]? = nil, action: @escaping () -> Void = {}) {
        self.id = id
        self.title = title
        self.icon = icon
        self.category = category
        self.children = children
        self.action = action
    }

    static func == (lhs: PaletteCommand, rhs: PaletteCommand) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Frecency Tracking

@MainActor
final class FrecencyTracker {
    static let shared = FrecencyTracker()
    private let key = "commandPaletteFrecency"

    private struct Entry: Codable {
        var count: Int
        var lastUsed: Date
    }

    private var entries: [String: Entry] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func record(_ commandId: String) {
        var current = entries
        var entry = current[commandId] ?? Entry(count: 0, lastUsed: .distantPast)
        entry.count += 1
        entry.lastUsed = Date()
        current[commandId] = entry
        entries = current
    }

    /// Returns a score combining frequency and recency (higher = more relevant)
    func score(for commandId: String) -> Double {
        guard let entry = entries[commandId] else { return 0 }
        let recencyHours = max(1, -entry.lastUsed.timeIntervalSinceNow / 3600)
        // Decay: recent usage counts more
        return Double(entry.count) / log2(recencyHours + 1)
    }
}
