# Architecture — Claude Usage Tracker

## Purpose
macOS menu bar app that tracks AI coding assistant usage (Claude, Codex, GitHub Copilot) with a popover dashboard and visual status bar icon. Fork of [HamedElfayome/Claude-Usage-Tracker](https://github.com/HamedElfayome/Claude-Usage-Tracker).

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.x |
| UI | SwiftUI + AppKit (NSPopover, NSStatusItem) |
| Charts | Swift Charts |
| Storage | UserDefaults (standard container) + Keychain |
| Networking | URLSession (async/await) |
| Updates | Sparkle (via UpdateManager) |
| Build | Xcode (`Claude Usage.xcodeproj`) |
| Tests | XCTest (`Claude UsageTests/`) |
| CI | GitHub Actions (build, CodeQL, release, Homebrew cask) |

## Folder Structure

```
Claude-Usage-Tracker/
├── Claude Usage/                  # Main app target
│   ├── App/
│   │   ├── ClaudeUsageTrackerApp.swift   # @main entry, SwiftUI App
│   │   └── AppDelegate.swift             # NSApplicationDelegate, lifecycle + wizard
│   ├── MenuBar/
│   │   ├── MenuBarManager.swift          # Central coordinator (ObservableObject)
│   │   ├── MenuBarIconRenderer.swift     # Draws NSImage for status bar icon
│   │   ├── PopoverContentView.swift      # SwiftUI popover (main dashboard)
│   │   ├── StatusBarUIManager.swift      # NSStatusItem + icon updates
│   │   ├── UsageRefreshCoordinator.swift # Timer-driven API refresh
│   │   └── WindowCoordinator.swift       # Manages floating windows
│   ├── Views/
│   │   ├── SettingsView.swift            # Root settings window
│   │   ├── SetupWizardView.swift         # First-launch onboarding
│   │   ├── Settings/
│   │   │   ├── App/                      # App-wide settings tabs
│   │   │   ├── Credentials/              # Per-provider auth UIs
│   │   │   ├── Profile/                  # Per-profile settings
│   │   │   ├── Components/               # Reusable settings widgets
│   │   │   └── DesignSystem/             # Tokens, spacing, typography, colors
│   │   └── APISettingsView.swift
│   └── Shared/
│       ├── Models/                       # Pure value types (Codable structs/enums)
│       ├── Protocols/                    # APIServiceProtocol, UsageProviderFetcher, …
│       ├── Services/
│       │   ├── ClaudeAPIService.swift    # claude.ai session-key API
│       │   ├── ClaudeAPIService+ConsoleAPI.swift   # Anthropic Console billing API
│       │   ├── ClaudeCodeSyncService.swift          # CLI OAuth credential sync
│       │   ├── ClaudeStatusService.swift            # status.anthropic.com polling
│       │   ├── Providers/
│       │   │   ├── ClaudeUsageProviderFetcher.swift
│       │   │   ├── CodexUsageProviderFetcher.swift
│       │   │   ├── CopilotUsageProviderFetcher.swift
│       │   │   └── ClaudeUsageSnapshotAdapter.swift
│       │   ├── ProfileManager.swift      # Multi-profile CRUD + active profile
│       │   ├── KeychainService.swift     # Secure credential storage
│       │   ├── NotificationManager.swift # UNUserNotification triggers
│       │   ├── StatuslineService.swift   # Terminal statusline output
│       │   └── UpdateManager.swift       # Sparkle integration
│       ├── Storage/
│       │   ├── DataStore.swift           # UserDefaults r/w (usage data)
│       │   ├── ProfileStore.swift        # Profiles + active profile id
│       │   └── SharedDataStore.swift     # App-wide settings (language, shortcuts, …)
│       └── Utilities/
│           ├── PeakHoursHelper.swift     # Peak-hours detection + notifications
│           ├── PaceStatus.swift          # Pace guidance (faster/slower)
│           ├── UsageStatusCalculator.swift
│           └── URLBuilder.swift
├── Claude UsageTests/             # XCTest unit tests
├── docs-internal/                 # Fork-specific dev docs (not for users)
│   ├── CUSTOM-CHANGES.md          # All fork modifications vs upstream
│   └── plans/
├── scripts/
│   ├── build-and-install.sh
│   └── validate_localizations.sh
└── .github/workflows/             # CI: build, release, Homebrew cask, CodeQL
```

## Key Modules

| Module | Responsibility |
|---|---|
| `ClaudeUsageTrackerApp` | `@main` entry; attaches `AppDelegate` via `@NSApplicationDelegateAdaptor`; declares `Settings` scene |
| `AppDelegate` | App lifecycle; decides setup wizard vs menu bar; manages activation policy (`.accessory`) |
| `MenuBarManager` | Central `ObservableObject`; owns popover, refresh timer, multi-profile icon set; publishes `usage`, `providerSnapshot`, `status`, `apiUsage` |
| `StatusBarUIManager` | Creates and updates `NSStatusItem`; forwards click to `MenuBarManager` |
| `MenuBarIconRenderer` | Renders custom `NSImage` for each icon style (battery, progress bar, percentage, icon+ring, compact) |
| `UsageRefreshCoordinator` | Protocol-driven timer (`APIServiceProtocol`); fetches usage + status in parallel |
| `ProfileManager` | Singleton; loads/saves profiles; manages active profile; syncs CLI OAuth tokens |
| `DataStore` / `ProfileStore` / `SharedDataStore` | Thin UserDefaults wrappers; separated by scope (usage data / profile list / global settings) |
| `ClaudeAPIService` | Fetches session usage via claude.ai cookie auth; Console API billing via API key |
| `ClaudeCodeSyncService` | Reads CLI OAuth from `~/.claude/.credentials.json` → system Keychain fallback chain |
| `UsageProviderFetcher` (protocol) | Implemented by Claude/Codex/Copilot fetchers; all return `ProviderUsageSnapshot` |
| `PeakHoursHelper` | Detects Anthropic peak hours (Mon–Fri 05:00–11:00 PT); sends 15-min-ahead notification |
| `PaceStatus` | Calculates whether user is on track to hit 100% by reset; shown in popover |

## Data Flow

```
Credentials
  (Keychain / ~/.claude/.credentials.json / UserDefaults)
          │
          ▼
  ClaudeCodeSyncService / KeychainService
          │ resolves tokens
          ▼
  UsageProviderFetcher (Claude / Codex / Copilot)
          │ async throws → ProviderUsageSnapshot
          ▼
  MenuBarManager (@Published properties)
          │ SwiftUI binding / Combine
          ├──► StatusBarUIManager → MenuBarIconRenderer → NSStatusItem icon
          └──► PopoverContentView (SwiftUI) → user-facing dashboard
                     │
                     └──► SettingsView (modal)
```

**Refresh cycle:** `UsageRefreshCoordinator` fires on a per-profile timer (default 30 s). On each tick it calls `fetchUsage()` and `fetchStatus()` concurrently. Results are saved to `DataStore` and pushed to `MenuBarManager` via delegate callbacks. `NotificationManager` checks thresholds after every successful fetch.

**Multi-profile:** `MenuBarManager` iterates `ProfileManager.profiles` that have `isSelectedForDisplay = true`, creates one `NSStatusItem` per profile in multi mode, or a single aggregated item in single mode.

## Patterns & Conventions

| Pattern | Usage |
|---|---|
| Protocol-backed services | `APIServiceProtocol`, `UsageProviderFetcher`, `StorageProvider`, `NotificationServiceProtocol` — enables mock injection in tests |
| `@MainActor` on fetchers | All `UsageProviderFetcher` implementations run on main actor to safely update `@Published` state |
| Singleton singletons | `ProfileManager.shared`, `DataStore.shared`, `SharedDataStore.shared`, `ClaudeCodeSyncService.shared` — app-wide singletons, not injected |
| Credential priority chain | Claude fetcher tries: session key → profile CLI JSON → system Keychain CLI JSON |
| `ProviderUsageSnapshot` | Provider-neutral DTO; all provider fetchers produce it; popover consumes it uniformly |
| Fork tracking | `docs-internal/CUSTOM-CHANGES.md` documents every deviation from upstream for clean merges |
| Design tokens | `DesignSystem/` folder with `SettingsColors`, `Spacing`, `Typography`, `DesignTokens` — used throughout settings views |

## Known Quirks & Gotchas

- **Reinstall**: always `rm -rf` the old `.app` before `cp -R`; stale binary causes crashes (see feedback note in global memory).
- **Keychain truncation**: large CLI credential JSON (>2 KB) may be truncated in the system Keychain. `ClaudeCodeSyncService` handles this via regex extraction fallback → reads from `~/.claude/.credentials.json` first.
- **Headless Mac / Remote Desktop**: `NSStatusItem` may fail to initialize if no display is attached at launch. `AppDelegate` retries after 3 s when screens become available.
- **Dock icon flicker**: App runs as `.accessory` (no dock icon) but temporarily switches to `.regular` during the setup wizard window, then back to `.accessory` on close.
- **`statusLevel` deprecated**: `ClaudeUsage.statusLevel` is `@available(*, deprecated)` — use `UsageStatusCalculator.calculateStatus()` instead.
- **Peak hours stripes**: diagonal amber stripes on menu bar icon + popover bars are a fork-only feature (not in upstream). Logic lives in `PeakHoursHelper` + `MenuBarIconRenderer`.
- **`UsageRefreshCoordinator` vs `MenuBarManager` refresh**: there are two refresh paths; `MenuBarManager` has its own `refreshTimer` (legacy) and also owns a `UsageRefreshCoordinator`. Check which is active for a given profile mode.
