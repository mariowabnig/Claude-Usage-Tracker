import Foundation

@MainActor
final class ProfileRefreshTracker {
    struct Request {
        let profile: Profile
        let generation: UUID
    }
    private var latest: [UUID: UUID] = [:]

    func begin(for profile: Profile) -> Request {
        let request = Request(profile: profile, generation: UUID())
        latest[profile.id] = request.generation
        return request
    }

    func accepts(_ request: Request, currentProfiles: [Profile]) -> Bool {
        guard latest[request.profile.id] == request.generation,
              let current = currentProfiles.first(where: { $0.id == request.profile.id }) else { return false }
        let original = request.profile
        return current.providerKind == original.providerKind
            && current.providerCredentials == original.providerCredentials
            && current.claudeSessionKey == original.claudeSessionKey
            && current.organizationId == original.organizationId
            && current.cliCredentialsJSON == original.cliCredentialsJSON
            && current.apiSessionKey == original.apiSessionKey
            && current.apiOrganizationId == original.apiOrganizationId
    }
}
