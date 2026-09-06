# Security Policy

This document describes the custom `mariowabnig/Claude-Usage-Tracker` fork on `main`. Upstream release binaries can have different behavior; build this fork from source to use its changes.

## Credential storage

Profile session keys, CLI OAuth JSON, Codex API keys, and saved GitHub tokens are stored in the encrypted macOS login Keychain under `com.claudeusagetracker.profile-credentials`. UserDefaults contains redacted profile metadata and usage history, not these secrets.

On first launch of the updated app, `profiles_v3` credentials are copied to a vault revision and read back for verification. Only then is redacted `profiles_v4` metadata committed and the old plaintext preference removed. If Keychain access fails, the app preserves the previous save, reports the error, and does not fall back to writing new plaintext credentials. Historical backups of preferences are not modified.

The login Keychain supports unsigned local builds without data-protection entitlements. Its normal application access controls remain enabled: macOS may ask you to authorize Keychain access after rebuilding the app. Unlock the login Keychain and restart if storage is unavailable. Do not grant unrelated applications access to the vault.

Provider CLI authentication files and CLI-owned Keychain items remain owned by those tools; this migration does not delete or rewrite them. Explicit CLI account switching remains an opt-in setting. Automatic sync requires matching token continuity and never guesses that the currently logged-in account belongs to every saved profile.

## Network and local data

The app contacts provider services over HTTPS: Claude/Anthropic usage and status services, ChatGPT-backed Codex usage, and GitHub Copilot authentication/usage. Credentials are supplied to the relevant provider endpoints. Usage history and optional network debug logs are local data; review debug exports before sharing them.

The app runs without App Sandbox to support local CLI integration. Protect your macOS account and backups. This fork's local builds are unsigned unless you configure your own signing identity.

## Reporting

Do not post tokens or credential payloads in public issues. For vulnerabilities affecting upstream, use [upstream private security reporting](https://github.com/hamed-elfayome/Claude-Usage-Tracker/security/advisories). For fork-specific problems, report privately to the fork owner without including real credentials. Use synthetic reproductions whenever possible.
