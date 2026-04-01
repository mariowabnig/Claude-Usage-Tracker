//
//  ProviderCredentials.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

// MARK: - Claude Provider Credentials

/// Credentials specific to Claude (Anthropic) usage tracking
struct ClaudeProviderCredentials: Codable, Equatable {
    /// Claude.ai session key (cookie-based)
    var sessionKey: String?
    /// Claude.ai organization ID
    var organizationId: String?
    /// API console session key
    var apiSessionKey: String?
    /// API console organization ID
    var apiOrganizationId: String?
    /// API console session key expiry date
    var apiSessionKeyExpiry: Date?
    /// Claude CLI OAuth credentials (JSON string)
    var cliCredentialsJSON: String?
    /// Whether a CLI account was detected
    var hasCliAccount: Bool
    /// When the CLI account was last synced
    var cliAccountSyncedAt: Date?

    init(
        sessionKey: String? = nil,
        organizationId: String? = nil,
        apiSessionKey: String? = nil,
        apiOrganizationId: String? = nil,
        apiSessionKeyExpiry: Date? = nil,
        cliCredentialsJSON: String? = nil,
        hasCliAccount: Bool = false,
        cliAccountSyncedAt: Date? = nil
    ) {
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.apiSessionKey = apiSessionKey
        self.apiOrganizationId = apiOrganizationId
        self.apiSessionKeyExpiry = apiSessionKeyExpiry
        self.cliCredentialsJSON = cliCredentialsJSON
        self.hasCliAccount = hasCliAccount
        self.cliAccountSyncedAt = cliAccountSyncedAt
    }

    var hasClaudeAI: Bool {
        sessionKey != nil && organizationId != nil
    }

    var hasAPIConsole: Bool {
        apiSessionKey != nil && apiOrganizationId != nil
    }

    var hasCLI: Bool {
        cliCredentialsJSON != nil
    }
}

// MARK: - Codex Provider Credentials

/// Credentials for OpenAI Codex usage tracking
struct CodexProviderCredentials: Codable, Equatable {
    /// How auth was obtained
    var authSource: CodexAuthSource
    /// Optional API key for direct API access
    var apiKey: String?
    /// Cached account email from auth.json
    var accountEmail: String?

    init(
        authSource: CodexAuthSource = .authJson,
        apiKey: String? = nil,
        accountEmail: String? = nil
    ) {
        self.authSource = authSource
        self.apiKey = apiKey
        self.accountEmail = accountEmail
    }
}

/// Source of Codex authentication
enum CodexAuthSource: String, Codable, Equatable {
    case authJson   // ~/.codex/auth.json
    case apiKey     // Manual API key entry
}

// MARK: - Copilot Provider Credentials

/// Credentials for GitHub Copilot usage tracking
struct CopilotProviderCredentials: Codable, Equatable {
    /// GitHub OAuth access token
    var githubToken: String?
    /// Provider mode determines which APIs to use
    var mode: CopilotProviderMode
    /// Optional enterprise slug for org-level reporting
    var enterpriseSlug: String?
    /// Optional organization login for org-level reporting
    var organizationLogin: String?

    init(
        githubToken: String? = nil,
        mode: CopilotProviderMode = .personalExperimental,
        enterpriseSlug: String? = nil,
        organizationLogin: String? = nil
    ) {
        self.githubToken = githubToken
        self.mode = mode
        self.enterpriseSlug = enterpriseSlug
        self.organizationLogin = organizationLogin
    }
}

/// Mode for Copilot provider - determines which endpoints are used
enum CopilotProviderMode: String, Codable, Equatable, CaseIterable {
    case personalExperimental   // Internal endpoints for personal quota (experimental)
    case orgReporting           // Official GitHub REST API for org reporting

    var displayName: String {
        switch self {
        case .personalExperimental: return "Personal (Experimental)"
        case .orgReporting:         return "Organization Reporting"
        }
    }
}

// MARK: - Provider Credentials Container

/// Unified container for provider-specific credentials on a profile.
/// Only the credentials matching the profile's providerKind should be populated.
struct ProviderCredentials: Codable, Equatable {
    var claude: ClaudeProviderCredentials?
    var codex: CodexProviderCredentials?
    var copilot: CopilotProviderCredentials?

    init(
        claude: ClaudeProviderCredentials? = nil,
        codex: CodexProviderCredentials? = nil,
        copilot: CopilotProviderCredentials? = nil
    ) {
        self.claude = claude
        self.codex = codex
        self.copilot = copilot
    }

    /// Returns true if any provider credentials are configured
    var hasAny: Bool {
        claude != nil || codex != nil || copilot != nil
    }
}
