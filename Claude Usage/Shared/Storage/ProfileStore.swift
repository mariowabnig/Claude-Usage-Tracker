//
//  ProfileStore.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation
import Security

/// Manages storage and retrieval of profiles and profile-related data
class ProfileStore {
    static let shared = ProfileStore()

    private let defaults: UserDefaults
    private let credentialStorage: ProfileCredentialStorage
    private let errorHandler: (Error) -> Void
    private var credentialReadFailed = false
    private var lastLoadedProfiles: [Profile] = []
    private var reportedError = false

    private struct StoredProfiles: Codable {
        var profiles: [Profile]
        var vaultRevision: String
    }

    private typealias Vault = [String: [String: ProfileSecrets]]

    private enum Keys {
        static let profiles = "profiles_v3"
        static let secureProfiles = "profiles_v4"
        static let activeProfileId = "activeProfileId"
        static let displayMode = "profileDisplayMode"
        static let multiProfileConfig = "multiProfileDisplayConfig"
    }

    init(defaults: UserDefaults = .standard,
         credentialStorage: ProfileCredentialStorage = ProfileKeychainVault.shared,
         errorHandler: ((Error) -> Void)? = nil) {
        self.defaults = defaults
        self.credentialStorage = credentialStorage
        self.errorHandler = errorHandler ?? { error in
            ErrorPresenter.shared.showAlert(for: AppError(
                code: .storageWriteFailed,
                message: "Profile credentials could not be accessed securely.",
                technicalDetails: error.localizedDescription,
                isRecoverable: true,
                recoverySuggestion: "Unlock your login Keychain and restart the app. Existing saved credentials have been preserved; profile changes may not have been saved."
            ))
        }
    }

    // MARK: - Profile Management

    func saveProfiles(_ profiles: [Profile]) {
        do {
            try saveProfilesSecurely(profiles)
        } catch {
            reportStorageError(error)
        }
    }

    /// Commit a verified Keychain revision before publishing its metadata.
    /// Keep the previous revision until the preferences commit is complete.
    /// A crash or denied Keychain write therefore leaves the old save readable.
    func saveProfilesSecurely(_ profiles: [Profile]) throws {
        guard !credentialReadFailed else { throw KeychainError.invalidData }
        guard Set(profiles.map(\.id)).count == profiles.count else { throw KeychainError.invalidData }
        var vault = try readVault()
        let secrets = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id.uuidString, ProfileSecrets(profile: $0)) })
        let previous = defaults.data(forKey: Keys.secureProfiles).flatMap {
            try? JSONDecoder().decode(StoredProfiles.self, from: $0)
        }
        let revision: String
        if let previous, vault[previous.vaultRevision] == secrets {
            revision = previous.vaultRevision
        } else {
            revision = UUID().uuidString
            vault[revision] = secrets
            try credentialStorage.saveProfileVault(JSONEncoder().encode(vault))
            guard try readVault()[revision] == secrets else { throw KeychainError.invalidData }
        }

        let stored = StoredProfiles(profiles: profiles.map { $0.withoutSecrets }, vaultRevision: revision)
        let data = try JSONEncoder().encode(stored)
        defaults.set(data, forKey: Keys.secureProfiles)
        // UserDefaults normally flushes asynchronously. Before removing the old
        // secrets/revision, force this cross-store commit to disk; otherwise a
        // crash could leave old metadata referencing a pruned vault revision.
        if previous?.vaultRevision != revision || vault.count > 1 || defaults.data(forKey: Keys.profiles) != nil {
            guard defaults.synchronize() else { throw KeychainError.saveFailed(status: errSecIO) }
        }
        defaults.removeObject(forKey: Keys.profiles)
        lastLoadedProfiles = profiles
        reportedError = false

        // Cleanup is non-fatal: the newly committed revision is already safe.
        if vault.count > 1 {
            try? credentialStorage.saveProfileVault(JSONEncoder().encode([revision: secrets]))
        }
    }

    func loadProfiles() -> [Profile] {
        var metadata: [Profile] = []
        do {
            if let data = defaults.data(forKey: Keys.secureProfiles) {
                let stored = try JSONDecoder().decode(StoredProfiles.self, from: data)
                metadata = stored.profiles
                guard let secrets = try readVault()[stored.vaultRevision] else { throw KeychainError.invalidData }
                let profiles = try stored.profiles.map { profile in
                    guard let secret = secrets[profile.id.uuidString] else { throw KeychainError.invalidData }
                    return secret.restoring(profile)
                }
                credentialReadFailed = false
                reportedError = false
                lastLoadedProfiles = profiles
                // Also finishes cleanup if the app quit immediately after migration.
                if defaults.data(forKey: Keys.profiles) != nil {
                    guard defaults.synchronize() else { throw KeychainError.saveFailed(status: errSecIO) }
                    defaults.removeObject(forKey: Keys.profiles)
                }
                return profiles
            }
            guard let data = defaults.data(forKey: Keys.profiles) else { return [] }
            let profiles = try JSONDecoder().decode([Profile].self, from: data)
            credentialReadFailed = false
            lastLoadedProfiles = profiles
            // Migration failure keeps the original preferences intact and retryable.
            saveProfiles(profiles)
            return profiles
        } catch {
            credentialReadFailed = true
            reportStorageError(error)
            // Preserve profile identities/UI even when Keychain is locked. Never
            // permit these redacted values to overwrite the unavailable vault.
            return lastLoadedProfiles.isEmpty ? metadata : lastLoadedProfiles
        }
    }

    private func readVault() throws -> Vault {
        guard let data = try credentialStorage.loadProfileVault() else { return [:] }
        return try JSONDecoder().decode(Vault.self, from: data)
    }

    private func reportStorageError(_ error: Error) {
        LoggingService.shared.logStorageError("profileCredentialStorage", error: error)
        guard !reportedError else { return }
        reportedError = true
        errorHandler(error)
    }

    func saveActiveProfileId(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Keys.activeProfileId)
    }

    func loadActiveProfileId() -> UUID? {
        guard let uuidString = defaults.string(forKey: Keys.activeProfileId) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func saveDisplayMode(_ mode: ProfileDisplayMode) {
        defaults.set(mode.rawValue, forKey: Keys.displayMode)
    }

    func loadDisplayMode() -> ProfileDisplayMode {
        guard let rawValue = defaults.string(forKey: Keys.displayMode),
              let mode = ProfileDisplayMode(rawValue: rawValue) else {
            return .single
        }
        return mode
    }

    // MARK: - Multi-Profile Display Config

    func saveMultiProfileConfig(_ config: MultiProfileDisplayConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: Keys.multiProfileConfig)
        } catch {
            LoggingService.shared.logStorageError("saveMultiProfileConfig", error: error)
        }
    }

    func loadMultiProfileConfig() -> MultiProfileDisplayConfig {
        guard let data = defaults.data(forKey: Keys.multiProfileConfig) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(MultiProfileDisplayConfig.self, from: data)
        } catch {
            LoggingService.shared.logStorageError("loadMultiProfileConfig", error: error)
            return .default
        }
    }

    // MARK: - Credential Helpers

    func saveProfileCredentials(_ profileId: UUID, credentials: ProfileCredentials) throws {
        var profiles = loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            throw NSError(domain: "ProfileStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }

        // Update credentials directly in profile
        profiles[index].claudeSessionKey = credentials.claudeSessionKey
        profiles[index].organizationId = credentials.organizationId
        profiles[index].apiSessionKey = credentials.apiSessionKey
        profiles[index].apiOrganizationId = credentials.apiOrganizationId
        profiles[index].cliCredentialsJSON = credentials.cliCredentialsJSON

        saveProfiles(profiles)
    }

    func loadProfileCredentials(_ profileId: UUID) throws -> ProfileCredentials {
        let profiles = loadProfiles()
        guard let profile = profiles.first(where: { $0.id == profileId }) else {
            throw NSError(domain: "ProfileStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }

        return ProfileCredentials(
            claudeSessionKey: profile.claudeSessionKey,
            organizationId: profile.organizationId,
            apiSessionKey: profile.apiSessionKey,
            apiOrganizationId: profile.apiOrganizationId,
            cliCredentialsJSON: profile.cliCredentialsJSON
        )
    }
}

private struct ProfileSecrets: Codable, Equatable {
    var claudeSessionKey: String?
    var apiSessionKey: String?
    var cliCredentialsJSON: String?
    var providerCredentials: ProviderCredentials?

    init(profile: Profile) {
        claudeSessionKey = profile.claudeSessionKey
        apiSessionKey = profile.apiSessionKey
        cliCredentialsJSON = profile.cliCredentialsJSON
        providerCredentials = profile.providerCredentials
    }

    func restoring(_ metadata: Profile) -> Profile {
        var profile = metadata
        profile.claudeSessionKey = claudeSessionKey
        profile.apiSessionKey = apiSessionKey
        profile.cliCredentialsJSON = cliCredentialsJSON
        profile.providerCredentials = providerCredentials
        return profile
    }
}

extension Profile {
    fileprivate var withoutSecrets: Profile {
        var profile = self
        profile.claudeSessionKey = nil
        profile.apiSessionKey = nil
        profile.cliCredentialsJSON = nil
        profile.providerCredentials?.claude?.sessionKey = nil
        profile.providerCredentials?.claude?.apiSessionKey = nil
        profile.providerCredentials?.claude?.cliCredentialsJSON = nil
        profile.providerCredentials?.codex?.apiKey = nil
        profile.providerCredentials?.copilot?.githubToken = nil
        return profile
    }
}
