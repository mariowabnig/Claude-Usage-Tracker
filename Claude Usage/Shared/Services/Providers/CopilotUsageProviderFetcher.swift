//
//  CopilotUsageProviderFetcher.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation
import SwiftUI

/// Fetches GitHub Copilot usage data using the official reporting mode.
/// Labeled as experimental for personal usage since GitHub's official APIs
/// are designed for organization/enterprise reporting, not personal quota tracking.
@MainActor
class CopilotUsageProviderFetcher: UsageProviderFetcher {
    let providerKind: UsageProviderKind = .copilot

    func fetchUsage(for profile: Profile) async throws -> ProviderUsageSnapshot {
        guard let token = profile.copilotCredentials?.githubToken, !token.isEmpty else {
            return ProviderUsageSnapshot(
                provider: .copilot,
                title: "Copilot",
                subtitle: "Not connected",
                primaryRows: [],
                secondaryCards: [
                    ProviderSupplementaryCard(
                        id: "copilot-status",
                        kind: .providerStatus(connected: false, statusText: "GitHub token not configured")
                    )
                ]
            )
        }

        // Validate the token
        let isValid = await CopilotAuthService.shared.validateToken(token)

        var cards: [ProviderSupplementaryCard] = []

        cards.append(ProviderSupplementaryCard(
            id: "copilot-status",
            kind: .providerStatus(
                connected: isValid,
                statusText: isValid ? "Connected" : "Token invalid"
            )
        ))

        return ProviderUsageSnapshot(
            provider: .copilot,
            title: "Copilot",
            subtitle: isValid ? "Connected" : "Not connected",
            primaryRows: [],
            secondaryCards: cards,
            fetchedAt: Date()
        )
    }
}
