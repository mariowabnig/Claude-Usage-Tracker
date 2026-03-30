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

## Files Modified (summary)

| File | Change |
|------|--------|
| `Shared/Utilities/PeakHoursHelper.swift` | NEW — peak detection, countdown, notifications |
| `Shared/Extensions/Color+AppColors.swift` | peakAmber, safeDynamic colors |
| `MenuBar/PopoverContentView.swift` | Banner, stripes, pace, footer (schedule + trend) |
| `MenuBar/MenuBarIconRenderer.swift` | Striped bars during peak (battery + progress bar) |
| `MenuBar/MenuBarManager.swift` | Peak warning notification hook |
| `Shared/Services/UpdateManager.swift` | Disabled auto-download |
