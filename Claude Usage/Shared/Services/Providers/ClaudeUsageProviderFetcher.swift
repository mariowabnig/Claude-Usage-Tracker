//
//  ClaudeUsageProviderFetcher.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

/// Fetches Claude usage data and converts it to the provider-neutral snapshot format.
/// Wraps the existing ClaudeAPIService fetch logic behind the UsageProviderFetcher protocol.
@MainActor
class ClaudeUsageProviderFetcher: UsageProviderFetcher {
    let providerKind: UsageProviderKind = .claude

    private let apiService: ClaudeAPIService

    init(apiService: ClaudeAPIService = ClaudeAPIService()) {
        self.apiService = apiService
    }

    func fetchUsage(for profile: Profile) async throws -> ProviderUsageSnapshot {
        let claudeUsage = try await fetchClaudeUsage(for: profile)

        // Fetch API usage separately (non-fatal if it fails)
        var apiUsage: APIUsage? = nil
        if let apiSessionKey = profile.apiSessionKey,
           let orgId = profile.apiOrganizationId {
            apiUsage = try? await apiService.fetchAPIUsageData(
                organizationId: orgId,
                apiSessionKey: apiSessionKey
            )
        }

        return ClaudeUsageSnapshotAdapter.snapshot(from: claudeUsage, apiUsage: apiUsage)
    }

    /// Fetches raw ClaudeUsage using the profile's credentials (priority-based)
    func fetchClaudeUsage(for profile: Profile) async throws -> ClaudeUsage {
        // Priority 1: claude.ai session key (cookie-based)
        if let sessionKey = profile.claudeSessionKey,
           let orgId = profile.organizationId {
            return try await apiService.fetchUsageData(sessionKey: sessionKey, organizationId: orgId)
        }

        // Priority 2: Saved CLI OAuth token from profile
        if let cliJSON = profile.cliCredentialsJSON,
           !ClaudeCodeSyncService.shared.isTokenExpired(cliJSON),
           let accessToken = ClaudeCodeSyncService.shared.extractAccessToken(from: cliJSON) {
            return try await apiService.fetchUsageData(oauthAccessToken: accessToken)
        }

        // Priority 3: System Keychain CLI OAuth token
        if let systemCredentials = try? ClaudeCodeSyncService.shared.readSystemCredentials(),
           !ClaudeCodeSyncService.shared.isTokenExpired(systemCredentials),
           let accessToken = ClaudeCodeSyncService.shared.extractAccessToken(from: systemCredentials) {
            return try await apiService.fetchUsageData(oauthAccessToken: accessToken)
        }

        throw AppError(
            code: .sessionKeyNotFound,
            message: "Missing credentials for profile '\(profile.name)'",
            isRecoverable: false
        )
    }
}
