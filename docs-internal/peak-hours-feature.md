# Peak Hours Visual Indicator Feature

## Goal
When the current time falls within Anthropic's peak hours, visually indicate this in both the menu bar and popover without obscuring actual usage data.

## Peak Hours Definition
- **Weekdays only** (Mon–Fri)
- **5:00 AM – 11:00 AM Pacific Time**
- For Vienna: ~2:00–8:00 PM winter (CET) / ~3:00–9:00 PM summer (CEST)
- During peak hours, the 5-hour session window depletes faster (tokens cost more)

## What Changes Visually

### Menu Bar Icons (both battery and progress bar styles)
- Background track fills with light grey
- Diagonal amber stripes overlay on both the background and the fill
- Normal usage colors (green/orange/red) remain visible underneath the stripes

### Popover Cards
- Amber banner at top with countdown: "Peak Hours — ends in 2h 15m (20:00)"
- 2h advance warning: "Peak Hours in 1h 30m (15:00)"
- Diagonal amber stripes on progress bar fills
- Usage colors unchanged — green/orange/red still reflect actual usage level
- Pace guidance line under each card: "You can go 2.5x faster" / "Slow down to 70%"

### Off-peak
- Everything looks exactly like upstream (green = safe, orange = moderate, red = critical)
- No banner, no stripes

## Status
- [x] Research — peak hours confirmed as weekdays 5–11 AM PT
- [x] PeakHoursHelper — detection, countdown, formatting, local time
- [x] peakAmber color — warm yellow-orange, light/dark adaptive
- [x] PeakHoursBanner — live countdown with local end/start time
- [x] PeakStripes — diagonal amber stripe overlay (SwiftUI)
- [x] Menu bar stripes — battery style + progress bar style (Core Graphics)
- [x] Menu bar grey background during peak
- [x] Pace guidance — multiplier text per usage row
- [x] Auto-update disabled (Sparkle still notifies)
- [x] Build tested and running
