# Claude Usage Tracker

> **Required Reading:** See [ARCHITECTURE.md](ARCHITECTURE.md) for full app structure, data flow, modules, and gotchas.

## Stack

| | |
|---|---|
| Language | Swift 5.x |
| UI | SwiftUI + AppKit |
| Build | Xcode (`Claude Usage.xcodeproj`) |
| Tests | XCTest (`Claude UsageTests/`) |
| CI | GitHub Actions (`.github/workflows/`) |

## Build / Dev / Test

```bash
# Build & run
open "Claude Usage.xcodeproj"   # then Cmd+B / Cmd+R in Xcode

# CLI build (release)
./scripts/build-and-install.sh

# Validate localizations
./scripts/validate_localizations.sh

# Tests
# Run via Xcode (Cmd+U) or: xcodebuild test -scheme "Claude Usage" -destination 'platform=macOS'
```

## Critical Gotchas

- **Reinstall:** always `rm -rf` old `.app` before `cp -R` — stale binary causes crashes.
- **Keychain truncation:** CLI credentials >2 KB may be truncated; app falls back to `~/.claude/.credentials.json`.
- **Headless / Remote Desktop:** status bar init may fail; `AppDelegate` auto-retries after 3 s.
- **`statusLevel` deprecated:** use `UsageStatusCalculator.calculateStatus()`, not `ClaudeUsage.statusLevel`.
- **Fork tracking:** all deviations from upstream documented in `docs-internal/CUSTOM-CHANGES.md`.
