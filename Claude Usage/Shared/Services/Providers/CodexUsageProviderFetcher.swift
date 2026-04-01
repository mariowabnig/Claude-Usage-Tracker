//
//  CodexUsageProviderFetcher.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation
import SwiftUI

/// Fetches Codex usage data using the conservative approach (Option A from the plan).
/// Shows account connected state, auth health, and last refresh time.
/// Does not attempt undocumented live usage endpoints.
@MainActor
class CodexUsageProviderFetcher: UsageProviderFetcher {
    let providerKind: UsageProviderKind = .codex

    private let authService: CodexAuthService

    init(authService: CodexAuthService = .shared) {
        self.authService = authService
    }

    func fetchUsage(for profile: Profile) async throws -> ProviderUsageSnapshot {
        let validation = authService.validateAuth()

        var rows: [ProviderMetricRow] = []
        var cards: [ProviderSupplementaryCard] = []

        // Connection status card
        cards.append(ProviderSupplementaryCard(
            id: "codex-status",
            kind: .providerStatus(
                connected: validation.isValid,
                statusText: validation.statusText
            )
        ))

        // If we have a valid connection, show what we can
        if validation.isValid {
            if let email = validation.accountEmail {
                cards.append(ProviderSupplementaryCard(
                    id: "codex-account",
                    kind: .keyValue(
                        label: "Account",
                        value: email,
                        valueColor: nil
                    )
                ))
            }
        }

        return ProviderUsageSnapshot(
            provider: .codex,
            title: "Codex",
            subtitle: validation.isValid ? "Connected" : "Not connected",
            primaryRows: rows,
            secondaryCards: cards,
            fetchedAt: Date()
        )
    }
}
