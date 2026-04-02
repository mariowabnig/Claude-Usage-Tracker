# Custom Fork Changes

All modifications made to our fork of [HamedElfayome/Claude-Usage-Tracker](https://github.com/HamedElfayome/Claude-Usage-Tracker).
This file helps track what we've changed so upstream merges stay manageable.

---

## 1. Peak Hours Visual Indicator

**Date:** 2026-03-30
**Purpose:** Make it immediately visible when Anthropic's peak hours are active, since usage costs more during that window (the 5-hour session depletes faster).

### What are peak hours?
- Weekdays (Mon–Fri), 5:00–11:00 AM Pacific Time
- For Vienna (CET/CEST): ~2:00–8:00 PM winter / ~3:00–9:00 PM summer
- Anthropic confirmed (March 2026) that token cost per session is inflated during this window

### Changes

**New file:** `Shared/Utilities/PeakHoursHelper.swift`
- `isPeakHours` — checks if current time is within peak window (converts to Pacific Time)
- `countdown()` — returns time remaining until peak ends (if active) or starts (if off-peak)
- `formatCountdown()` — formats interval as "Xh Ym"
- `localTargetTime()` — returns the end/start time in the user's local timezone ("HH:mm")
- `localScheduleString` — peak hours in local time, e.g. "15:00–21:00"
- `checkAndSendPeakWarning()` — sends macOS notification 15 min before peak starts (once per window)

**Modified:** `Shared/Extensions/Color+AppColors.swift`
- Added `peakAmber` color (warm yellow-orange, adapts to light/dark mode)
- Added `safeDynamic` on both `Color` and `NSColor` (used internally)

**Modified:** `MenuBar/PopoverContentView.swift`
- `PeakHoursBanner` — countdown banner with local end/start time
- `PeakStripes` — diagonal amber stripes on progress bars during peak
- `PopoverInfoFooter` — peak schedule line + weekly usage trend
- Bar colors remain green/orange/red (stripes overlay, don't replace)

**Modified:** `MenuBar/MenuBarIconRenderer.swift`
- Progress bar style (W): light grey striped background + amber stripes on fill during peak
- Battery style (S): light grey background fill + amber stripes on fill during peak

**Modified:** `MenuBar/MenuBarManager.swift`
- Hooked `PeakHoursHelper.checkAndSendPeakWarning()` into refresh cycle

---

## 2. Pace Guidance

**Date:** 2026-03-30
**Purpose:** Show how much faster or slower you need to use Claude to perfectly hit 100% by reset time.

**Modified:** `MenuBar/PopoverContentView.swift`
- `paceGuidanceText` / `paceGuidanceColor` in `UsageRow`
- Shows: "▸ You can go 2.5x faster" / "▸ Perfect pace" / "▸ Slow down to 70%"
- Only when >5% elapsed and >1% used

---

## 3. Peak Hours Notification

**Date:** 2026-03-30
**Purpose:** Get a macOS notification ~15 minutes before peak hours begin.

**Modified:** `Shared/Utilities/PeakHoursHelper.swift`
- `checkAndSendPeakWarning()` — fires once per peak window, triggered by refresh cycle

---

## 4. Peak Hours Schedule in Footer

**Date:** 2026-03-30
**Purpose:** Always-visible reference for when peak hours are in your local timezone.

**Modified:** `MenuBar/PopoverContentView.swift`
- `PopoverInfoFooter` — shows "Peak: 15:00–21:00 Mon–Fri" at bottom of popover

---

## 5. Weekly Usage Trend

**Date:** 2026-03-30
**Purpose:** Quick comparison of this week's usage vs last week.

**Modified:** `MenuBar/PopoverContentView.swift`
- `PopoverInfoFooter` — compares last 2 weekly snapshots, shows "↑ 12% more than last week"

---

## 6. Auto-Update Disabled

**Date:** 2026-03-30
**Purpose:** Prevent Sparkle auto-download from overwriting our custom build.

**Modified:** `Shared/Services/UpdateManager.swift`
- `automaticallyDownloadsUpdates = false` — still checks and notifies

---

## 7. German Localization

**Date:** 2026-03-30
**Purpose:** All custom peak/pace text was in English while the rest of the UI is German.

**Modified:** `Resources/de.lproj/Localizable.strings`, `Resources/en.lproj/Localizable.strings`
- Added `peak.*` keys: banner, footer, pace, notifications, tooltips
- German: "Stoßzeiten", "Du kannst 2.5x schneller arbeiten", "Perfektes Tempo für 100%", etc.

**Modified:** `MenuBar/PopoverContentView.swift`, `Shared/Utilities/PeakHoursHelper.swift`
- All hardcoded English strings replaced with `.localized` calls

---

## 8. Weekend Indicator

**Date:** 2026-03-30
**Purpose:** On weekends, show "Heute keine Stoßzeiten" instead of the peak schedule, so you know you can go full throttle.

**Modified:** `MenuBar/PopoverContentView.swift`
- `PopoverInfoFooter` checks `isWeekend` — swaps clock icon for sun icon and shows localized "no peak today"

---

## 9. Menu Bar Tooltips

**Date:** 2026-03-30
**Purpose:** Hovering over W or S icons shows usage % and peak status without opening the popover.

**Modified:** `MenuBar/StatusBarUIManager.swift`
- `button.toolTip` set on every icon update (both `updateAllButtons` and `updateButton`)
- Shows: "Session: 28% genutzt" + "Stoßzeiten aktiv — endet 21:00" during peak

**Modified:** `Shared/Utilities/PeakHoursHelper.swift`
- Added `tooltip(metricName:percentage:)` helper

---

## 10. Build Script

**Date:** 2026-03-30
**Purpose:** One command to build, install, and relaunch the custom app.

**New file:** `scripts/build-and-install.sh`
- Runs `xcodebuild`, kills old app, `rm -rf` + `cp -R` to `/Applications`, `lsregister`, launches

---

## 11. Elapsed Time Percentage on Usage Rows

**Date:** 2026-03-31
**Purpose:** Show how much of each time window (5h session, weekly) has elapsed, so you can compare usage % against time % at a glance.

### Changes

**Modified:** `MenuBar/PopoverContentView.swift`
- `UsageRow`: Added elapsed percentage display ("· X% elapsed") next to the reset time text
- Only shown when both `resetTime` and `periodDuration` are available (session + weekly all-models rows)
- Uses existing `rawElapsedFraction` computation

**Modified:** All 9 `Localizable.strings` files
- Added `menubar.elapsed_percentage` key (e.g. "%d%% elapsed", "%d%% verstrichen", etc.)

---

## 12. Peak Hours Countdown in Footer

**Date:** 2026-03-31
**Purpose:** Always show how long until peak hours start or end in the bottom footer, not just the schedule.

### Changes

**Modified:** `MenuBar/PopoverContentView.swift`
- `PopoverInfoFooter`: Added live countdown ("· starts in Xh Ym" / "· ends in Xh Ym") next to the peak schedule line
- Updates every 30 seconds via Timer
- Hidden on weekends

**Modified:** `en.lproj/Localizable.strings`, `de.lproj/Localizable.strings`
- Added `peak.footer.starts_in` and `peak.footer.ends_in` keys

---

## 13. Compact Reset + Elapsed Line

**Date:** 2026-04-02
**Purpose:** Reduce popover height by combining the reset time and elapsed percentage into a single line, separated by a pipe character.

**Modified:** `MenuBar/PopoverContentView.swift`
- `UsageRow`: Merged the "Zurücksetzen …" and "X% verstrichen" texts into one line: `Zurücksetzen Today 15:59  |  29% verstrichen`
- Falls back to showing either value alone when the other is unavailable

---

## 14. Peak Visuals Scoped to Claude Only

**Date:** 2026-04-02
**Purpose:** Peak-hour visuals represent Anthropic pricing behavior and should not affect Copilot or Codex displays.

### Changes

**Modified:** `MenuBar/PopoverContentView.swift`
- `UsageRow` now supports provider-gated peak stripes via `showPeakStripes`
- `SmartUsageDashboard` enables peak stripes only when `snapshot.provider == .claude`

**Modified:** `MenuBar/MenuBarIconRenderer.swift`
- Added `showPeakEffects` gating to peak-specific rendering in battery/progress styles
- Amber peak overlays/backgrounds now render only when `showPeakEffects` is enabled

**Modified:** `MenuBar/StatusBarUIManager.swift`
- Multi-profile renderer now passes `showPeakEffects: profile.providerKind == .claude`

---

## Files Modified (summary)

| File | Change |
|------|--------|
| `Shared/Utilities/PeakHoursHelper.swift` | NEW — peak detection, countdown, notifications, tooltips |
| `Shared/Extensions/Color+AppColors.swift` | peakAmber, safeDynamic colors |
| `MenuBar/PopoverContentView.swift` | Banner, stripes, pace, footer (schedule + trend + weekend), elapsed %, peak countdown, compact reset+elapsed line |
| `MenuBar/MenuBarIconRenderer.swift` | Striped bars during peak (battery + progress bar) |
| `MenuBar/MenuBarManager.swift` | Peak warning notification hook |
| `MenuBar/StatusBarUIManager.swift` | Tooltips on menu bar icons |
| `Shared/Services/UpdateManager.swift` | Disabled auto-download |
| `Resources/en.lproj/Localizable.strings` | Peak hours localization keys |
| `Resources/de.lproj/Localizable.strings` | German translations |
| `scripts/build-and-install.sh` | NEW — build + install script |
