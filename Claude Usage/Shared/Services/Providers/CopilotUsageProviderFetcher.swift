//
//  CopilotUsageProviderFetcher.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation
import SwiftUI

/// Fetches GitHub Copilot personal usage data from the same internal endpoint
/// used by the VS Code Copilot extension.
@MainActor
class CopilotUsageProviderFetcher: UsageProviderFetcher {
    let providerKind: UsageProviderKind = .copilot

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(for profile: Profile) async throws -> ProviderUsageSnapshot {
        let savedToken = profile.copilotCredentials?.githubToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cliToken = CopilotAuthService.shared.readCLIToken()
        let token = (savedToken?.isEmpty == false ? savedToken : nil) ?? cliToken

        guard let token else {
            return ProviderUsageSnapshot(
                provider: .copilot,
                title: "Copilot",
                subtitle: "Not connected",
                primaryRows: [],
                secondaryCards: [
                    ProviderSupplementaryCard(
                        id: "copilot-status",
                        kind: .providerStatus(connected: false, statusText: "GitHub auth not configured")
                    )
                ]
            )
        }

        do {
            let response = try await fetchUsageResponse(token: token)
            let connectionSource = savedToken?.isEmpty == false ? "Saved GitHub token" : "GitHub CLI auth"
            var rows: [ProviderMetricRow] = []
            var cards: [ProviderSupplementaryCard] = [
                ProviderSupplementaryCard(
                    id: "copilot-status",
                    kind: .providerStatus(connected: true, statusText: "Connected via \(connectionSource)")
                )
            ]

            if let premium = response.quotaSnapshots.premiumInteractions ?? response.quotaSnapshots.completions,
               premium.hasPercentRemaining,
               !premium.isUnlimited
            {
                rows.append(ProviderMetricRow(
                    id: "copilot-premium",
                    title: "Premium Interactions",
                    subtitle: quotaSubtitle(for: premium),
                    usedPercentage: max(0, 100 - premium.percentRemaining),
                    resetTime: parseQuotaResetDate(response.quotaResetDate),
                    periodDuration: nil,
                    supportsPaceMarkers: false,
                    accentStyle: .primary
                ))
            }

            if let chat = response.quotaSnapshots.chat {
                if chat.isUnlimited {
                    cards.append(ProviderSupplementaryCard(
                        id: "copilot-chat-unlimited",
                        kind: .keyValue(label: "Chat", value: "Unlimited", valueColor: .adaptiveGreen)
                    ))
                } else if chat.hasPercentRemaining {
                    rows.append(ProviderMetricRow(
                        id: "copilot-chat",
                        title: "Chat",
                        subtitle: quotaSubtitle(for: chat),
                        usedPercentage: max(0, 100 - chat.percentRemaining),
                        resetTime: parseQuotaResetDate(response.quotaResetDate),
                        periodDuration: nil,
                        supportsPaceMarkers: false,
                        accentStyle: .secondary
                    ))
                }
            }

            if rows.isEmpty {
                cards.append(ProviderSupplementaryCard(
                    id: "copilot-no-metered-quota",
                    kind: .keyValue(label: "Usage", value: "No metered quotas exposed", valueColor: .secondary)
                ))
            }

            if let resetDate = parseQuotaResetDate(response.quotaResetDate) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                cards.append(ProviderSupplementaryCard(
                    id: "copilot-reset-date",
                    kind: .keyValue(label: "Resets", value: formatter.string(from: resetDate), valueColor: nil)
                ))
            }

            return ProviderUsageSnapshot(
                provider: .copilot,
                title: "Copilot",
                subtitle: response.copilotPlan.capitalized,
                primaryRows: rows,
                secondaryCards: cards,
                fetchedAt: Date()
            )
        } catch {
            LoggingService.shared.logError("Copilot usage fetch failed: \(error.localizedDescription)")
            return ProviderUsageSnapshot(
                provider: .copilot,
                title: "Copilot",
                subtitle: "Connection issue",
                primaryRows: [],
                secondaryCards: [
                    ProviderSupplementaryCard(
                        id: "copilot-status",
                        kind: .providerStatus(connected: false, statusText: "Usage fetch failed")
                    )
                ],
                fetchedAt: Date()
            )
        }
    }

    private func fetchUsageResponse(token: String) async throws -> CopilotUsageAPIResponse {
        var request = URLRequest(url: URL(string: "https://api.github.com/copilot_internal/user")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
        request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(httpResponse.statusCode == 401 || httpResponse.statusCode == 403
                ? .userAuthenticationRequired
                : .badServerResponse)
        }

        return try JSONDecoder().decode(CopilotUsageAPIResponse.self, from: data)
    }

    private func parseQuotaResetDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func quotaSubtitle(for quota: CopilotQuotaSnapshot) -> String? {
        if quota.entitlement > 0 {
            let used = max(0, quota.entitlement - quota.remaining)
            return "\(Int(used)) / \(Int(quota.entitlement)) used"
        }
        return nil
    }
}

private struct CopilotUsageAPIResponse: Decodable {
    let quotaSnapshots: CopilotQuotaSnapshots
    let copilotPlan: String
    let quotaResetDate: String?

    enum CodingKeys: String, CodingKey {
        case quotaSnapshots = "quota_snapshots"
        case copilotPlan = "copilot_plan"
        case quotaResetDate = "quota_reset_date"
    }
}

private struct CopilotQuotaSnapshots: Decodable {
    let premiumInteractions: CopilotQuotaSnapshot?
    let chat: CopilotQuotaSnapshot?
    let completions: CopilotQuotaSnapshot?

    enum CodingKeys: String, CodingKey {
        case premiumInteractions = "premium_interactions"
        case chat
        case completions
    }
}

private struct CopilotQuotaSnapshot: Decodable {
    let entitlement: Double
    let remaining: Double
    let percentRemaining: Double
    let quotaId: String
    let isUnlimited: Bool
    let hasPercentRemaining: Bool

    enum CodingKeys: String, CodingKey {
        case entitlement
        case remaining
        case percentRemaining = "percent_remaining"
        case quotaId = "quota_id"
        case isUnlimited = "unlimited"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entitlement = Self.decodeNumber(container, key: .entitlement) ?? 0
        remaining = Self.decodeNumber(container, key: .remaining) ?? 0
        quotaId = (try? container.decode(String.self, forKey: .quotaId)) ?? ""
        isUnlimited = (try? container.decode(Bool.self, forKey: .isUnlimited)) ?? false

        if let explicitPercent = Self.decodeNumber(container, key: .percentRemaining) {
            percentRemaining = max(0, min(100, explicitPercent))
            hasPercentRemaining = true
        } else if entitlement > 0 {
            percentRemaining = max(0, min(100, (remaining / entitlement) * 100))
            hasPercentRemaining = true
        } else {
            percentRemaining = 0
            hasPercentRemaining = false
        }
    }

    private static func decodeNumber(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}
