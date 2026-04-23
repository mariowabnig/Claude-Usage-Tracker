# Safe Upstream Sync — 2026-04-23

## Goal
Bring useful upstream fixes from `hamed-elfayome/main` into this fork without overwriting the fork’s multi-provider work (Claude, Codex, GitHub Copilot).

## Approach
- Preserve fork-specific provider-neutral architecture first.
- Cherry-pick only low-risk upstream commits.
- Manually port overlapping menu bar/popover fixes instead of doing a wholesale merge.
- Rebuild and retest after each batch.

## Cherry-picked upstream commits
- `a7171bd` → local `02e298c`
  - Browser-like request headers for Claude.ai session-key auth (fixes E3000 / false unauthorized responses)
- `5d85258` → local `5177866`
  - Hard timeouts for `/usr/bin/security` subprocesses in `ClaudeCodeSyncService`
- `f6caf1d` → local `911b8f0`
  - Fresh login cookies + popup-based Google SSO in `ConsoleAuthWebView`
  - Kept fork polling fallback during conflict resolution
- `a3e0d65` → local `87795be`
  - Manual session/API key entry always visible
- `6727628` → local `60ae55b`
  - Removed incorrect CLI tracking note
- `554c793` → local `08d1a24`
  - Added missing multi-profile icon-style translations

## Manual adaptations
- Fork-specific non-Claude single-profile menu bar rendering preserved via `ProviderUsageSnapshot`
- Incremental multi-profile status item updates added to avoid destructive teardown/recreation
- Stable status-item `autosaveName` values added for persistence
- Popover close/switch race fixed with synchronous close behavior
- Detached popover window uses a separate hosting controller to avoid layout cycles
- `AppDelegate` now instantiates `MenuBarManager` early for safer setup/wizard flow
- Active Claude profile may use valid system CLI credentials when profile-local usage credentials are absent

## Intentionally skipped
- Full upstream menu bar refactors that assume upstream-only structure
- Full statusline refactor chain
- Any merge that would risk provider-neutral fork behavior

## Verification
- `xcodebuild -project 'Claude Usage.xcodeproj' -scheme 'Claude Usage' -sdk macosx build` → `BUILD SUCCEEDED`
- `xcodebuild test -project 'Claude Usage.xcodeproj' -scheme 'Claude Usage' -destination 'platform=macOS'` → `TEST SUCCEEDED`

## Result
`main` keeps the fork’s multi-provider behavior and gains the upstream auth, keychain, sign-in, localization, and popover/menu bar stability fixes that were safe to import.