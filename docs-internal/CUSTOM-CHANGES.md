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

**Modified:** `Shared/Extensions/Color+AppColors.swift`
- Added `peakAmber` color (warm yellow-orange, adapts to light/dark mode)
- Added `safeDynamic` on both `Color` and `NSColor` (used internally, not for bar colors)

**Modified:** `MenuBar/PopoverContentView.swift`
- Added `PeakHoursBanner` view in `SmartUsageDashboard`:
  - **During peak:** amber banner — "Peak Hours — ends in 2h 15m (20:00)" with local time
  - **Within 2h of peak:** subtle gray banner — "Peak Hours in 1h 30m (15:00)" with local time
  - **Otherwise:** no banner
  - Refreshes every 30 seconds
- Added `PeakStripes` view — diagonal amber stripes overlaid on progress bars during peak
- Bar colors remain green/orange/red based on usage level (not overridden during peak)

**Modified:** `MenuBar/MenuBarIconRenderer.swift`
- **Progress bar style (W):** light grey striped background + amber diagonal stripes on fill during peak
- **Battery style (S):** light grey background fill + amber diagonal stripes on fill during peak
- Normal colors preserved — stripes overlay on top, so usage level is still visible

### Design decisions
- Bar fill colors stay green/orange/red — they reflect how far along usage is, which must remain readable
- Amber stripes are the peak indicator — visible without obscuring the usage information
- Menu bar background turns light grey with stripes during peak for added visibility
- CLI account indicators, system status, and overage balance colors are unchanged

---

## 2. Pace Guidance

**Date:** 2026-03-30
**Purpose:** Show how much faster or slower you need to use Claude to perfectly hit 100% by reset time.

**Modified:** `MenuBar/PopoverContentView.swift`
- Added `paceGuidanceText` and `paceGuidanceColor` computed properties to `UsageRow`
- Shows below the reset time in each usage card:
  - **"▸ You can go 2.5x faster"** — well under budget, room to use more
  - **"▸ Perfect pace for 100%"** — on track to use the full allocation
  - **"▸ Slow down to 70% of current pace"** — burning too fast (orange/red text)
  - **"▸ You can go much faster"** — when multiplier exceeds 5x
- Only shows when enough time has elapsed (>5%) and usage is meaningful (>1%)
- Colors: neutral (secondary) when on track or under, orange when mildly over, red when significantly over

---

## 3. Auto-Update Disabled

**Date:** 2026-03-30
**Purpose:** Prevent Sparkle from automatically downloading and installing updates, which would overwrite our custom-built app with the stock upstream binary.

**Modified:** `Shared/Services/UpdateManager.swift`
- Set `updaterController.updater.automaticallyDownloadsUpdates = false` on init
- Sparkle still checks for new versions and shows a notification
- To apply an upstream update: `git fetch upstream && git merge upstream/main`, then rebuild

---

## Files Modified (summary)

| File | Change |
|------|--------|
| `Shared/Utilities/PeakHoursHelper.swift` | NEW — peak hours detection, countdown, local time |
| `Shared/Extensions/Color+AppColors.swift` | Added peakAmber, safeDynamic colors |
| `MenuBar/PopoverContentView.swift` | Peak banner, striped bars, pace guidance |
| `MenuBar/MenuBarIconRenderer.swift` | Striped bars + grey background during peak (battery + progress bar) |
| `Shared/Services/UpdateManager.swift` | Disabled auto-download |
