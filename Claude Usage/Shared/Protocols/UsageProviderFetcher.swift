//
//  UsageProviderFetcher.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

/// Protocol for provider-specific usage data fetchers.
/// Each provider implements this to convert its native API responses
/// into the shared ProviderUsageSnapshot format.
protocol UsageProviderFetcher {
    var providerKind: UsageProviderKind { get }

    /// Fetches current usage data for the given profile and returns a provider-neutral snapshot.
    func fetchUsage(for profile: Profile) async throws -> ProviderUsageSnapshot
}
