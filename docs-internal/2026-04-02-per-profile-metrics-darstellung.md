# Per-Profile Menu Bar Metrics in Darstellung

## Goal
Replace the single-profile "Menu Bar Metrics" section in AppearanceSettingsView with a multi-profile view showing all profiles' metric toggles simultaneously.

## Tasks
- [x] Restructure metrics section to show one card per profile
- [x] Each profile card shows its relevant metrics (Session/Week for Claude/Codex, Monthly for Copilot)
- [x] Saving writes to the correct profile's iconConfig
- [x] Add localization keys for new section header
- [x] Build and test

## Round 2 — Identification & Intuitiveness

- [x] Add profile prefix to menu bar icons in multi-profile mode (CL·S:, CX·W:, GH·W:)
- [x] Add `menuBarPrefix` to `UsageProviderKind`
- [x] Thread `profilePrefix` through `createImage` → all style renderers
- [x] Pass prefix from `updateMultiProfileButtons` (multi-profile) but not from single-profile paths
- [x] Add status hint on profile cards in Darstellung when profile won't show in menu bar
- [x] Build and test

**Status:** COMPLETED
**Date Completed:** 2026-04-02
