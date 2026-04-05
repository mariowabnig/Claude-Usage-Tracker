# Claude Usage Tracker

macOS menu bar app — tracks Claude API/subscription usage with visual dashboard.

## Stack
- Swift / SwiftUI
- Xcode project (`Claude Usage.xcodeproj`)

## Dev
- Open in Xcode, build with Cmd+B
- Tests in `Claude UsageTests/`

## Quirks
- When reinstalling: always `rm -rf` the old .app before `cp -R` to avoid stale binaries
