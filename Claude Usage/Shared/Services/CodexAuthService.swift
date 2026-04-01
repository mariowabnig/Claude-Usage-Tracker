//
//  CodexAuthService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

/// Service for detecting and reading Codex CLI authentication state.
/// Reads from ~/.codex/auth.json to determine if the user has Codex configured.
@MainActor
class CodexAuthService {
    static let shared = CodexAuthService()

    private init() {}

    /// Path to the Codex auth file
    var authFilePath: URL {
        let home = Constants.ClaudePaths.homeDirectory
        return home.appendingPathComponent(".codex").appendingPathComponent("auth.json")
    }

    /// Whether a Codex auth file exists on disk
    var hasLocalAuth: Bool {
        FileManager.default.fileExists(atPath: authFilePath.path)
    }

    /// Reads and parses the Codex auth.json file
    func readAuthState() -> CodexAuthState? {
        guard hasLocalAuth else { return nil }
        do {
            let data = try Data(contentsOf: authFilePath)
            let state = try JSONDecoder().decode(CodexAuthState.self, from: data)
            return state
        } catch {
            LoggingService.shared.logError("CodexAuthService: Failed to read auth.json: \(error.localizedDescription)")
            return nil
        }
    }

    /// Validates that the stored auth state is usable
    func validateAuth() -> CodexAuthValidation {
        guard let state = readAuthState() else {
            return CodexAuthValidation(isValid: false, statusText: "Not configured", accountEmail: nil)
        }

        let resolvedAccessToken = state.resolvedAccessToken
        let hasToken = resolvedAccessToken != nil && !(resolvedAccessToken?.isEmpty ?? true)
        let isExpired: Bool
        if let expiry = state.resolvedExpiresAt {
            isExpired = expiry < Date()
        } else {
            isExpired = false
        }

        if hasToken && !isExpired {
            return CodexAuthValidation(
                isValid: true,
                statusText: "Connected",
                accountEmail: state.resolvedAccountLabel
            )
        } else if hasToken && isExpired {
            return CodexAuthValidation(
                isValid: false,
                statusText: "Token expired",
                accountEmail: state.resolvedAccountLabel
            )
        } else {
            return CodexAuthValidation(
                isValid: false,
                statusText: "Missing token",
                accountEmail: nil
            )
        }
    }
}

// MARK: - Codex Auth Models

/// Represents the parsed contents of ~/.codex/auth.json
struct CodexAuthState: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Date?
    let email: String?
    let accountId: String?
    let tokens: NestedCodexTokens?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case email
        case accountId = "account_id"
        case tokens
    }

    var resolvedAccessToken: String? {
        accessToken ?? tokens?.accessToken
    }

    var resolvedRefreshToken: String? {
        refreshToken ?? tokens?.refreshToken
    }

    var resolvedExpiresAt: Date? {
        expiresAt ?? tokens?.expiresAt
    }

    var resolvedAccountLabel: String? {
        if let email, !email.isEmpty {
            return email
        }

        if let nestedAccountId = tokens?.accountId, !nestedAccountId.isEmpty {
            return Self.maskedIdentifier(nestedAccountId)
        }

        if let accountId, !accountId.isEmpty {
            return Self.maskedIdentifier(accountId)
        }

        return nil
    }

    private static func maskedIdentifier(_ value: String) -> String {
        guard value.count > 10 else { return value }
        return "\(value.prefix(4))...\(value.suffix(4))"
    }
}

struct NestedCodexTokens: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Date?
    let accountId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case accountId = "account_id"
    }
}

/// Result of validating Codex auth state
struct CodexAuthValidation {
    let isValid: Bool
    let statusText: String
    let accountEmail: String?
}
