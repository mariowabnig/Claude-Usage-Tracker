# September 2026 audit fixes

Addresses the five findings from the local/GitHub fork audit at `7a05c9b`.

## Account isolation

`ClaudeCodeSyncService.credentialsMatch` requires a nonempty shared refresh or access token. Startup sync, pre-switch resync, and system-token usage fallback all use it. Startup saves the exact validated payload, avoiding a second read of a possibly changed login. Fully rotated/unknown credentials require explicit reconnect rather than automatic reassignment.

## Secure persistence

`ProfileStore` splits metadata and secrets. The encrypted login Keychain vault keeps immutable credential revisions; `profiles_v4` references one verified revision. New vault data is verified before publishing preferences, then legacy `profiles_v3` data and old revisions are removed. A failed write or migration leaves the last committed save readable. Failed secure reads preserve IDs and block writes of redacted data. Usage-only updates do not rewrite credentials.

A native synthetic probe reproduced `errSecMissingEntitlement` (-34018) with the legacy `SecAccessControl` options. The new `ProfileKeychainVault` uses the ordinary login Keychain without data-protection-only attributes. It preserves normal application ACLs; rebuilt unsigned apps may require macOS Keychain authorization. It never creates a plaintext fallback.

## Refreshes and errors

Single-profile, multi-profile and popover paths share `refreshProfiles`. Every request captures a profile and generation. Results are accepted only while the profile still exists with matching credentials and no newer request. Cache/history saves use that profile's ID. Only the current active profile affects the main display. Codex/Copilot authentication, HTTP, network and decoding errors throw; cached data survives and failed/partial batches do not advance the success timestamp.

## Removed peak policy

Removed hardcoded banners, stripes, tooltips, countdown timers and notifications. Pace markers and usage percentages remain based on actual API data. Policy source: [Anthropic, May 6, 2026](https://www.anthropic.com/news/higher-limits-spacex), which removes the Claude Code Pro/Max peak-hour reduction.

## Verification

Final XCTest result: **171 passed, 0 failed, 0 skipped**, including 17 new regression tests. All nine locales have 730 matching keys. Debug/test compilation has no project Swift warnings; Xcode emits only its standard optional AppIntents metadata message.

- XCTest regression coverage: legacy migration and relaunch; failed writes/verification; locked vault; credential deletion; metadata-only writes; account mismatches; out-of-order responses; profile switching during a request; cached data after failure; multi-profile partial failures; both providers' 401/403/429/500, malformed JSON and offline responses.
- Unit test host does not initialize live account migration or polling. Provider tests use synthetic credentials and a mock URLSession; profile/history tests use isolated preferences and an in-memory vault.
- Native vault probe uses a uniquely named disposable Keychain item and synthetic 32/40 KB payloads; it checks create/read/update and deletes the item afterward.
- All nine localization files have matching keys; removed the unused Korean-only keys.
- Debug tests and Release build are checked separately. The freshly built Debug bundle was installed to `/Applications/Claude Usage.app` on September 6, 2026; the previous app bundle was preserved at `/tmp/Claude Usage.app.previous-20260906-114559` for recovery. The installed process was verified at the expected executable path. No real-account polling was performed.
