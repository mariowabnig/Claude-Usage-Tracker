//
//  CopilotAuthService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

/// Service for managing GitHub Copilot authentication.
/// Supports GitHub OAuth device flow for personal usage tracking.
@MainActor
class CopilotAuthService {
    static let shared = CopilotAuthService()

    private let tokenCacheKey = "copilot.cliToken.cache"
    private var cachedCLIToken: String?
    private var tokenRefreshTask: Task<String?, Never>?

    private init() {
        cachedCLIToken = UserDefaults.standard.string(forKey: tokenCacheKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            _ = await refreshCLITokenIfNeeded()
        }
    }

    var hasCLIToken: Bool {
        cachedCLIToken?.isEmpty == false
    }

    // MARK: - GitHub OAuth Device Flow

    /// GitHub OAuth client ID for device flow
    /// This should be configured with a registered GitHub OAuth app
    private let clientId = ""  // To be configured with actual OAuth app

    /// Starts the GitHub device flow authentication
    func startDeviceFlow() async throws -> GitHubDeviceFlowResponse {
        guard !clientId.isEmpty else {
            throw AppError(
                code: .configurationError,
                message: "GitHub OAuth client ID not configured",
                isRecoverable: false
            )
        }

        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "scope": "copilot"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GitHubDeviceFlowResponse.self, from: data)
    }

    /// Polls for device flow token completion
    func pollForToken(deviceCode: String, interval: Int) async throws -> GitHubTokenResponse {
        guard !clientId.isEmpty else {
            throw AppError(
                code: .configurationError,
                message: "GitHub OAuth client ID not configured",
                isRecoverable: false
            )
        }

        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(GitHubTokenResponse.self, from: data)
    }

    /// Validates an existing GitHub token
    func validateToken(_ token: String) async -> Bool {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            LoggingService.shared.logError("CopilotAuthService: Token validation failed: \(error.localizedDescription)")
        }
        return false
    }

    /// Reads the cached GitHub CLI token if available.
    /// This is intentionally non-blocking so SwiftUI/UI code can call it safely.
    func readCLIToken() -> String? {
        cachedCLIToken
    }

    /// Refreshes the cached GitHub CLI token off the main thread.
    func refreshCLITokenIfNeeded(force: Bool = false) async -> String? {
        if !force, let cachedCLIToken, !cachedCLIToken.isEmpty {
            return cachedCLIToken
        }

        if let tokenRefreshTask {
            return await tokenRefreshTask.value
        }

        let task = Task.detached(priority: .utility) {
            Self.loadCLITokenFromCLI()
        }
        tokenRefreshTask = task

        let token = await task.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        tokenRefreshTask = nil
        cachedCLIToken = token?.isEmpty == false ? token : nil

        if let cachedCLIToken {
            UserDefaults.standard.set(cachedCLIToken, forKey: tokenCacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: tokenCacheKey)
        }

        return cachedCLIToken
    }

    nonisolated private static func loadCLITokenFromCLI() -> String? {
        guard let ghExecutablePath = resolveGitHubCLIPath() else {
            LoggingService.shared.logError("CopilotAuthService: GitHub CLI not found in standard locations")
            return nil
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: ghExecutablePath)
        process.arguments = ["auth", "token"]
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
                LoggingService.shared.logError("CopilotAuthService: GitHub CLI token command failed: \(errorOutput)")
                return nil
            }

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let token = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return token?.isEmpty == false ? token : nil
        } catch {
            LoggingService.shared.logError("CopilotAuthService: Failed to read GitHub CLI token: \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated private static func resolveGitHubCLIPath() -> String? {
        let environmentPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let candidatePaths = environmentPaths + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin"
        ]

        let fileManager = FileManager.default
        for directory in candidatePaths {
            let executablePath = (directory as NSString).appendingPathComponent("gh")
            if fileManager.isExecutableFile(atPath: executablePath) {
                return executablePath
            }
        }

        return nil
    }
}

// MARK: - GitHub Auth Models

struct GitHubDeviceFlowResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct GitHubTokenResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }

    var isComplete: Bool {
        accessToken != nil
    }

    var isPending: Bool {
        error == "authorization_pending"
    }
}
