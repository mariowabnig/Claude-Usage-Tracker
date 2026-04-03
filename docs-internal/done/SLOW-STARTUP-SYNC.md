# Slow Startup Sync — Menu Bar Usage Data

## Problem
After PC restart, usage data takes a long time to appear in the menu bar.

## Root Causes Found

### 1. Blocking keychain subprocess calls on main thread during startup
- `ProfileManager.loadProfiles()` → on first launch only calls `syncCLICredentialsToDefaultProfile` → `readSystemCredentials()` which spawns blocking `/usr/bin/security` subprocesses
- `AppDelegate.shouldShowSetupWizard()` → `hasValidSystemCLICredentials()` → calls `readSystemCredentials()` AGAIN — this runs even on normal launches (not first launch) if profile has no credentials
- `resolveServiceName()` tries `keychainItemExists()` (blocking subprocess), and if that fails calls `findHashedServiceName()` which runs `dump-keychain` (very slow, dumps entire keychain)
- All these block the main thread with `process.waitUntilExit()`

### 2. Intentional 1-second startup delay (MenuBarManager.swift:197)
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
    self?.refreshUsage()
}
```
Comment says "for launch-at-login scenarios" but adds unnecessary delay.

### 3. Wake-from-sleep has additional 3-second delay (MenuBarManager.swift:682)
On restart, macOS may fire didWakeNotification, adding 3 more seconds.

### 4. Network monitor race condition
NWPathMonitor may fire `onNetworkAvailable` before or after the 1.0s initial fetch, with only a 2s debounce — can cause the fetch to be skipped if network becomes available too soon OR too late.

### 5. Timer doesn't fire immediately
`Timer.scheduledTimer` fires AFTER the interval (30s), not at time 0. Initial fetch is only via the asyncAfter(+1.0s) path.

## Fixes

### Fix 1: Reduce startup delay from 1.0s to 0.3s
- [x] The 1s delay is overly conservative. 0.3s is enough for the run loop to stabilize.

### Fix 2: Reduce wake delay from 3.0s to 1.0s  
- [x] 3 seconds is excessive for wake-from-sleep refresh.

### Fix 3: Move keychain calls off main thread in AppDelegate
- [x] `hasValidSystemCLICredentials()` calls should be async, not blocking the main thread.

### Fix 4: Network-available should always trigger refresh if no successful refresh yet
- [x] If `lastSuccessfulRefreshTime` is nil, always refresh when network appears (don't debounce).
