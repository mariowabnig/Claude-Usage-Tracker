# Multi-Provider Usage Visuals Implementation Plan

**Date:** 2026-04-01

**Goal:** Extend the app so GitHub Copilot usage and OpenAI Codex usage can be displayed with the same visual language currently used for Claude usage, while keeping the existing Claude experience stable.

**Status:** Planning only. No code changes have been made yet.

## Summary

The current UI styling is already strong enough to reuse. The main work is not visual polish, but generalizing the app from a Claude-specific tracker into a provider-based tracker.

Today, the app has:

- A reusable-looking popover/dashboard shell
- A reusable-looking history chart shell
- Claude-specific models, services, history storage, and profile credentials

That means the implementation should be split into two tracks:

1. Refactor the app so the UI is driven by provider-neutral data.
2. Add provider integrations for Codex and Copilot behind that abstraction.

The recommended order is:

1. Build the provider abstraction layer.
2. Port Claude onto that layer without changing user-visible behavior.
3. Add Codex support.
4. Add Copilot support.

## What We Found

### Existing UI Can Be Reused

The existing dashboard and row styling can serve as the shared presentation layer:

- `Claude Usage/MenuBar/PopoverContentView.swift`
  - `SmartUsageDashboard`
  - `UsageRow`
- `Claude Usage/Views/Settings/Profile/UsageHistoryView.swift`
  - `UsageSeries`
  - `CombinedUsageChart`

This is where the current “visual style” lives: row layout, progress bars, color behavior, tags, time markers, pace markers, and the overall native menu bar feel.

### Existing Data Flow Is Claude-Specific

The following areas are hard-wired to Claude:

- `Claude Usage/Shared/Models/Profile.swift`
  - Stores Claude session keys, API console values, and Claude CLI credentials
  - Stores `claudeUsage` and `apiUsage` directly on the profile
- `Claude Usage/MenuBar/MenuBarManager.swift`
  - Fetches only `ClaudeUsage`
- `Claude Usage/Shared/Models/UsageHistory.swift`
  - History snapshots only represent Claude session, weekly, and API billing data
- `Claude Usage/Shared/Services/UsageHistoryService.swift`
  - Recording logic assumes Claude-specific reset semantics

### External Research Findings

#### OpenAI Codex

- The local Codex CLI stores auth state in `~/.codex/auth.json`
- OpenAI officially documents Codex auth, but does not appear to publish a stable public per-user usage API for the same kind of live quota view we currently show for Claude
- The open-source Codex project indicates internal usage/account endpoints exist, but they should be treated as implementation details unless OpenAI documents them as supported

Relevant references:

- OpenAI Codex auth docs: <https://developers.openai.com/codex/auth>
- OpenAI Codex repository: <https://github.com/openai/codex>

#### GitHub Copilot

- GitHub officially documents Copilot billing and usage concepts
- GitHub also has official REST APIs for enterprise and organization usage reporting
- Those official endpoints are aimed at aggregate reporting, not a lightweight personal live-quota menu bar view
- Existing third-party implementations appear to use internal Copilot endpoints for personal quota details

Relevant references:

- Copilot requests overview: <https://docs.github.com/en/copilot/concepts/billing/copilot-requests>
- Copilot premium requests billing: <https://docs.github.com/en/billing/concepts/product-billing/github-copilot-premium-requests>
- OpenAI Codex in GitHub context: <https://docs.github.com/en/copilot/concepts/agents/openai-codex>
- Copilot usage metrics REST API: <https://docs.github.com/en/enterprise-cloud%40latest/rest/copilot/copilot-usage-metrics>
- Deprecated Copilot metrics endpoint: <https://docs.github.com/en/enterprise-cloud%40latest/rest/copilot/copilot-metrics>

#### Prior Art

The strongest reference implementation found was:

- `steipete/CodexBar`: <https://github.com/steipete/CodexBar>

This is useful as proof that:

- A shared menu bar UI for Codex and Copilot is feasible
- Provider-specific auth/fetch behavior can live behind a common interface
- Some integrations may rely on internal or undocumented endpoints and should therefore be isolated and labeled experimental

## Product Direction Recommendation

We should define “same visual style” as:

- Same row styling
- Same chart styling
- Same card spacing and hierarchy
- Same menu bar design system

We should **not** assume every provider can support every micro-feature, because provider data differs.

For example:

- Claude supports reset times and pacing well
- Codex may support reset-style views depending on the data source
- Copilot may only support quota snapshots without the same reset metadata

So the correct product goal is:

**Shared visual language, provider-specific metrics.**

## Proposed Architecture

### 1. Introduce Provider Identity

Create a provider type that distinguishes the source of usage data.

Suggested model:

```swift
enum UsageProviderKind: String, Codable, CaseIterable {
    case claude
    case codex
    case copilot
}
```

This provider kind should become part of each profile.

### 2. Separate Credentials by Provider

Instead of storing only Claude-specific credentials directly on `Profile`, move toward provider-scoped credentials.

Suggested direction:

```swift
struct ProviderCredentials: Codable, Equatable {
    var claude: ClaudeProviderCredentials?
    var codex: CodexProviderCredentials?
    var copilot: CopilotProviderCredentials?
}
```

Possible provider credential models:

- `ClaudeProviderCredentials`
  - session key
  - organization ID
  - API console session values
  - CLI OAuth JSON
- `CodexProviderCredentials`
  - auth source (`auth.json`, API key, future OAuth mode)
  - cached account metadata if needed
- `CopilotProviderCredentials`
  - GitHub OAuth token or device-flow token
  - optional enterprise/org identifiers for reporting mode
  - provider mode (`personalExperimental`, `orgReporting`)

### 3. Introduce a Provider-Neutral Usage Snapshot

The UI should not depend on `ClaudeUsage` directly.

Suggested direction:

```swift
struct ProviderUsageSnapshot: Equatable {
    let provider: UsageProviderKind
    let title: String
    let subtitle: String?
    let primaryRows: [ProviderMetricRow]
    let secondaryCards: [ProviderSupplementaryCard]
    let fetchedAt: Date
}
```

Suggested row model:

```swift
struct ProviderMetricRow: Identifiable, Equatable {
    let id: String
    let title: String
    let tag: String?
    let subtitle: String?
    let usedPercentage: Double?
    let remainingPercentage: Double?
    let resetTime: Date?
    let periodDuration: TimeInterval?
    let supportsPaceMarkers: Bool
    let accentStyle: MetricAccentStyle
}
```

The important detail is that the row structure captures what the UI needs without assuming Claude token semantics.

### 4. Introduce a Provider Fetcher Protocol

Suggested protocol:

```swift
protocol UsageProviderFetcher {
    var provider: UsageProviderKind { get }
    func fetchUsage(for profile: Profile) async throws -> ProviderUsageSnapshot
}
```

Concrete implementations:

- `ClaudeUsageProviderFetcher`
- `CodexUsageProviderFetcher`
- `CopilotUsageProviderFetcher`

This will let `MenuBarManager` stop hardcoding Claude-specific fetch paths.

### 5. Introduce Provider-Neutral History

Current history is built around Claude resets. That should be replaced or wrapped by a provider-neutral history format.

Suggested direction:

```swift
enum ProviderHistorySeriesKind: String, Codable {
    case session
    case weekly
    case monthly
    case billing
    case premiumRequests
    case chatRequests
    case experimental
}

struct ProviderHistoryPoint: Codable, Identifiable, Equatable {
    let id: UUID
    let provider: UsageProviderKind
    let series: ProviderHistorySeriesKind
    let timestamp: Date
    let value: Double
    let unit: HistoryValueUnit
    let resetTime: Date?
    let metadata: [String: String]
}
```

This allows the chart to remain visually consistent while plotting different provider metrics.

### 6. Make the UI Render Rows, Not Providers

Refactor the dashboard so it renders a list of rows/cards returned by the provider layer instead of constructing Claude rows inline.

That means:

- `SmartUsageDashboard` receives provider-neutral view data
- `UsageRow` remains mostly intact
- Optional features like pace markers and reset markers become capability-driven instead of assumed

## Implementation Phases

## Phase 1: Stabilize the Shared UI Contract

**Objective:** Keep the existing visual style but stop encoding Claude assumptions directly in the view hierarchy.

### Tasks

1. Create provider-neutral display models:
   - `UsageProviderKind`
   - `ProviderUsageSnapshot`
   - `ProviderMetricRow`
   - `ProviderSupplementaryCard`
2. Refactor `SmartUsageDashboard` to render arrays of rows/cards.
3. Keep `UsageRow` as the shared visual component.
4. Add a small adapter layer that converts `ClaudeUsage` + `APIUsage` into provider-neutral display data.

### Deliverable

Claude still works exactly as before, but the dashboard is no longer Claude-shaped.

### Success Criteria

- No visual regression for Claude users
- No product behavior change in the popover
- The dashboard can render rows for any provider

## Phase 2: Generalize Profile and Fetching

**Objective:** Move the app from Claude-only profiles to provider-aware profiles.

### Tasks

1. Add `providerKind` to `Profile`
2. Introduce provider-specific credentials models
3. Add migration logic for existing Claude profiles
4. Replace direct `claudeUsage` dependence in fetch orchestration with provider fetchers
5. Refactor `MenuBarManager.fetchUsageForProfile(_:)` into provider dispatch

Suggested dispatch shape:

```swift
switch profile.providerKind {
case .claude:
    ...
case .codex:
    ...
case .copilot:
    ...
}
```

### Deliverable

The app can decide which provider fetch logic to use based on the profile.

### Success Criteria

- Existing profiles migrate cleanly
- Claude profiles remain functional
- New provider types can be added without changing the dashboard

## Phase 3: Generalize History and Charts

**Objective:** Reuse the same chart styling for multiple providers.

### Tasks

1. Introduce provider-neutral history models
2. Update `UsageHistoryService` so recording is provider-aware
3. Refactor `UsageSeries` into provider-defined series metadata
4. Replace `CombinedUsageChart(sessionSnapshots:weeklySnapshots:)` with a more generic chart input such as:

```swift
CombinedUsageChart(series: [ProviderHistorySeries])
```

5. Update export formats to include provider and metric names

### Deliverable

A charting layer that can show:

- Claude session/weekly usage
- Codex usage trends
- Copilot premium/chat quota trends

### Success Criteria

- Chart visuals remain consistent
- Different providers can supply different series sets
- Empty or unsupported series degrade gracefully

## Phase 4: Add Codex Provider

**Objective:** Add the first new provider using the shared UI architecture.

### Recommended Scope for Initial Codex Support

Start narrow:

- Detect auth from `~/.codex/auth.json`
- Read enough identity/account info to validate the profile
- Attempt a live usage fetch only if a stable path is available
- If a stable live usage path is not available, start with a limited provider mode:
  - account connected state
  - local activity/session history where possible
  - experimental live usage toggle if we choose to use internal endpoints

### Codex Integration Options

#### Option A: Conservative

Show:

- connected account
- auth health
- last refresh
- local activity trends

Do not show:

- unsupported live quota data

Pros:

- Low risk
- Uses known local data

Cons:

- Does not fully match the richness of Claude

#### Option B: Experimental Live Usage

Use implementation-derived endpoints or flows discovered from the Codex CLI/open-source client.

Pros:

- Closest parity with Claude-style live usage

Cons:

- Potential breakage if OpenAI changes internal behavior
- More maintenance risk

### Recommendation

Implement Option A first, then evaluate Option B behind an explicit experimental flag.

### Deliverable

A working Codex profile type that renders in the same dashboard style.

### Success Criteria

- Users can add a Codex profile
- The menu bar and popover visually match Claude
- Unsupported fields are hidden rather than faked

## Phase 5: Add Copilot Provider

**Objective:** Add Copilot in a way that acknowledges the difference between official reporting APIs and internal personal quota endpoints.

### Copilot Integration Modes

#### Mode 1: Official Reporting Mode

Use GitHub’s official usage reporting endpoints.

Best for:

- organization or enterprise accounts
- trustworthy reporting

Pros:

- Officially documented
- Lower maintenance risk

Cons:

- Not ideal for personal real-time usage in a menu bar app

#### Mode 2: Experimental Personal Live Mode

Use the same kind of internal endpoint strategy seen in prior-art apps.

Best for:

- personal menu bar quota tracking

Pros:

- Better parity with the existing live tracker UX

Cons:

- Undocumented endpoint risk
- Potential auth/permission changes over time

### Recommendation

Ship both concepts if needed, but label them clearly:

- `Copilot (Official Reporting)`
- `Copilot (Experimental Personal Usage)`

For MVP, it is also reasonable to postpone Copilot until after Codex is stable.

### Deliverable

A Copilot provider with at least one viable supported mode.

### Success Criteria

- Copilot can render in the shared dashboard
- Experimental behavior is explicitly marked
- The app does not over-promise unsupported precision

## Proposed File-Level Changes

This is the likely first-wave impact area.

### High-Priority Refactors

- `Claude Usage/Shared/Models/Profile.swift`
  - add provider kind
  - migrate credentials structure
- `Claude Usage/MenuBar/MenuBarManager.swift`
  - replace Claude-only fetch path with provider dispatch
- `Claude Usage/MenuBar/PopoverContentView.swift`
  - stop building Claude rows inline
  - render generic provider rows/cards
- `Claude Usage/Views/Settings/Profile/UsageHistoryView.swift`
  - replace fixed series assumptions
- `Claude Usage/Shared/Models/UsageHistory.swift`
  - generalize snapshot structure
- `Claude Usage/Shared/Services/UsageHistoryService.swift`
  - generalize history recording logic

### New Likely Files

- `Claude Usage/Shared/Models/UsageProviderKind.swift`
- `Claude Usage/Shared/Models/ProviderUsageSnapshot.swift`
- `Claude Usage/Shared/Models/ProviderHistory.swift`
- `Claude Usage/Shared/Services/Providers/ClaudeUsageProviderFetcher.swift`
- `Claude Usage/Shared/Services/Providers/CodexUsageProviderFetcher.swift`
- `Claude Usage/Shared/Services/Providers/CopilotUsageProviderFetcher.swift`
- `Claude Usage/Shared/Services/CodexAuthService.swift`
- `Claude Usage/Shared/Services/CopilotAuthService.swift`

## Migration Plan

### Existing User Data

We should assume existing users have only Claude profiles.

Migration steps:

1. Add `providerKind` with default `.claude`
2. Preserve current credentials fields long enough for migration
3. Convert existing profiles on load
4. Migrate or wrap existing history entries as Claude provider history

### Safety Requirements

- No data loss for existing profiles
- No history loss
- Existing menu bar behavior must continue working after migration

## UI and UX Plan

### Profile Creation

Add provider selection during profile creation:

- Claude
- Codex
- Copilot

Each provider should then show its own credential instructions.

### Settings

Provider-specific settings should appear only when relevant.

Examples:

- Claude
  - session key
  - API console auth
  - CLI sync
- Codex
  - auth.json detection
  - optional API key mode
  - experimental live usage toggle
- Copilot
  - GitHub login/device flow
  - official reporting mode vs experimental personal mode

### Popover Consistency Rules

The popover should feel identical across providers:

- same row height
- same progress bar treatment
- same typography and spacing
- same chart placement

But it should not fabricate unavailable fields:

- no fake reset timer
- no fake pace marker
- no fake token numbers

## Risks

### 1. Internal/Undocumented Endpoints

Both Codex and Copilot personal live usage may require non-public endpoints.

Mitigation:

- keep integrations isolated in provider services
- label risky modes as experimental
- build graceful fallbacks

### 2. Overfitting UI to Claude Semantics

Current UI assumes reset times and percentage-based pacing.

Mitigation:

- make those capabilities optional per row
- render only what the provider supports

### 3. Migration Complexity

Profile and history migrations touch core app data.

Mitigation:

- ship migration in a dedicated phase
- test migration from real existing data
- preserve backwards compatibility temporarily

### 4. Product Ambiguity Around “Codex”

There are two meanings that may matter:

- standalone OpenAI Codex
- OpenAI Codex accessed through GitHub Copilot

Mitigation:

- model standalone Codex and Copilot separately
- if needed, document that GitHub-hosted Codex usage belongs under Copilot billing

## Testing Strategy

### Unit Tests

Add tests for:

- profile migration
- provider selection and dispatch
- Claude adapter into provider-neutral snapshot format
- history model encoding/decoding
- chart data shaping for multiple providers

### Integration Tests

Add targeted tests or manual verification for:

- existing Claude profile upgrade
- creating a Codex profile
- creating a Copilot profile
- empty/unsupported provider states

### Manual QA

Verify:

1. Claude profile still renders exactly as before
2. Codex profile renders with identical visual style
3. Copilot profile renders with identical visual style
4. Missing provider capabilities are hidden cleanly
5. Multi-profile mode still works

## Recommended Delivery Sequence

### Milestone 1

Provider-neutral UI models and Claude adapter only.

### Milestone 2

Provider-aware profile model and fetch dispatch.

### Milestone 3

Provider-neutral history and charting.

### Milestone 4

Codex provider MVP.

### Milestone 5

Copilot provider MVP.

### Milestone 6

Experimental live-usage enhancements where safe and worthwhile.

## Recommended First Implementation Task

The first coding task should be:

**Refactor `SmartUsageDashboard` so it renders provider-neutral metric rows instead of constructing Claude rows inline.**

Why this first:

- It unlocks shared visuals immediately
- It does not require external auth work yet
- It creates the stable contract that every provider will plug into
- It lets us port Claude first and verify there is no UI regression

## Open Decisions

These should be resolved before implementing provider integrations:

1. Should standalone OpenAI Codex ship only in conservative mode first, or should experimental live usage be included from the start?
2. Should Copilot support launch with only official reporting mode, or include experimental personal mode?
3. Do we want one unified “AI Providers” settings area, or keep provider setup embedded inside profile screens?
4. Should existing Claude terminology in the UI be renamed where it becomes provider-neutral?

## Final Recommendation

Proceed, but do it in layers.

The correct path is not “add two more hardcoded dashboards.” The correct path is:

1. convert the visual layer into a provider-neutral renderer,
2. convert the data layer into provider-specific fetchers behind a shared contract,
3. add Codex first,
4. add Copilot with a clear distinction between official and experimental modes.

That gives us the shared visual style the user wants while keeping the codebase maintainable and honest about what each provider can actually expose.
