//
//  StatusBarUIManager.swift
//  Claude Usage
//
//  Created by Claude Code on 2025-12-27.
//

import Cocoa
import Combine

/// Manages multiple menu bar status items for different metrics
final class StatusBarUIManager {
    private struct MultiProfileStatusItemKey: Hashable {
        let profileId: UUID
        let metricType: MenuBarMetricType
    }

    // Dictionary to hold multiple status items keyed by metric type (single profile mode)
    private var statusItems: [MenuBarMetricType: NSStatusItem] = [:]

    // Dictionary to hold status items keyed by profile ID + metric type (multi-profile mode)
    private var multiProfileStatusItems: [MultiProfileStatusItemKey: NSStatusItem] = [:]

    // Current display mode
    private var isMultiProfileMode: Bool = false

    private var appearanceObservers: [NSKeyValueObservation] = []
    private var appearanceDebounceTimer: Timer?

    // Image cache to avoid redundant button.image assignments (which trigger KVO)
    private var lastImageData: [ObjectIdentifier: Data] = [:]

    // Icon renderer for creating menu bar images
    private let renderer = MenuBarIconRenderer()

    weak var delegate: StatusBarUIManagerDelegate?

    // MARK: - Initialization

    init() {}

    // MARK: - Setup

    /// Sets up status bar items based on configuration
    func setup(target: AnyObject, action: Selector, config: MenuBarIconConfiguration) {
        // Remove all existing items first
        cleanup()

        // Check if there are any enabled metrics
        if config.enabledMetrics.isEmpty {
            // No credentials/metrics - show default app logo
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = statusItem.button {
                button.action = action
                button.target = target
                // Set a temporary placeholder - will be updated with actual logo
                button.title = ""
            } else {
                LoggingService.shared.logWarning("Status bar button is nil - screens: \(NSScreen.screens.count)")
            }

            // Use a special key to identify the default icon
            statusItems[.session] = statusItem  // Use session as placeholder key
            LoggingService.shared.logUIEvent("Status bar initialized with default app logo (no credentials)")
        } else {
            // Create status items for enabled metrics
            for metricConfig in config.enabledMetrics {
                let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

                if let button = statusItem.button {
                    button.action = action
                    button.target = target
                } else {
                    LoggingService.shared.logWarning("Status bar button is nil for \(metricConfig.metricType.displayName) - screens: \(NSScreen.screens.count)")
                }

                statusItems[metricConfig.metricType] = statusItem
            }

            LoggingService.shared.logUIEvent("Status bar initialized with \(config.enabledMetrics.count) metrics")
        }

        observeAppearanceChanges()
    }

    /// Updates status bar items based on new configuration (incremental approach)
    func updateConfiguration(target: AnyObject, action: Selector, config: MenuBarIconConfiguration) {
        // Determine what the new set of items should be
        let newMetricTypes: Set<MenuBarMetricType>
        if config.enabledMetrics.isEmpty {
            // No credentials/metrics - show default app logo using .session as placeholder
            newMetricTypes = [.session]
        } else {
            newMetricTypes = Set(config.enabledMetrics.map { $0.metricType })
        }

        let currentMetricTypes = Set(statusItems.keys)

        // Step 1: Remove items that are no longer needed
        let itemsToRemove = currentMetricTypes.subtracting(newMetricTypes)
        for metricType in itemsToRemove {
            if let statusItem = statusItems[metricType] {
                if let button = statusItem.button {
                    button.image = nil
                    button.action = nil
                    button.target = nil
                }
                NSStatusBar.system.removeStatusItem(statusItem)
                LoggingService.shared.logUIEvent("Removed status item for \(metricType.displayName)")
            }
            statusItems.removeValue(forKey: metricType)
        }

        // Step 2: Add items that are new
        let itemsToAdd = newMetricTypes.subtracting(currentMetricTypes)
        for metricType in itemsToAdd {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = statusItem.button {
                button.action = action
                button.target = target
                if metricType == .session {
                    // Default logo placeholder
                    button.title = ""
                }
            }

            statusItems[metricType] = statusItem
            LoggingService.shared.logUIEvent("Created status item for \(metricType.displayName)")
        }

        // Step 3: Items that already exist don't need recreation, just keep them
        // Their images will be updated by updateAllButtons() or updateButton()

        LoggingService.shared.logUIEvent("Status bar configuration updated: removed=\(itemsToRemove.count), added=\(itemsToAdd.count), kept=\(currentMetricTypes.intersection(newMetricTypes).count)")
    }

    func cleanup() {
        appearanceObservers.forEach { $0.invalidate() }
        appearanceObservers.removeAll()

        // Clean up single profile status items
        for (_, statusItem) in statusItems {
            // Clear button references first
            if let button = statusItem.button {
                button.image = nil
                button.action = nil
                button.target = nil
            }
            // Then remove from status bar
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItems.removeAll()

        // Clean up multi-profile status items
        for (_, statusItem) in multiProfileStatusItems {
            if let button = statusItem.button {
                button.image = nil
                button.action = nil
                button.target = nil
            }
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        multiProfileStatusItems.removeAll()

        isMultiProfileMode = false

        LoggingService.shared.logUIEvent("Status bar cleaned up")
    }

    // MARK: - Multi-Profile Mode

    /// Sets up status bar for multi-profile display mode
    func setupMultiProfile(profiles: [Profile], target: AnyObject, action: Selector) {
        // Clean up existing items
        cleanup()

        isMultiProfileMode = true

        let selectedProfiles = profiles.filter { $0.isSelectedForDisplay }
        let selectedItems = selectedProfiles.flatMap { profile in
            multiProfileMetricConfigs(for: profile).map { MultiProfileStatusItemKey(profileId: profile.id, metricType: $0.metricType) }
        }

        if selectedItems.isEmpty {
            // No profiles selected - show default logo
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem.button {
                button.action = action
                button.target = target
                button.title = ""
            } else {
                LoggingService.shared.logWarning("Multi-profile status bar button is nil - screens: \(NSScreen.screens.count)")
            }
            // Use a placeholder UUID for default logo
            multiProfileStatusItems[MultiProfileStatusItemKey(profileId: UUID(), metricType: .session)] = statusItem
            LoggingService.shared.logUIEvent("Multi-profile: No profiles selected, showing default logo")
        } else {
            // Create one status item per selected metric window
            for item in selectedItems {
                let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

                if let button = statusItem.button {
                    button.action = action
                    button.target = target
                } else {
                    LoggingService.shared.logWarning("Multi-profile status bar button is nil for \(item.profileId.uuidString.prefix(8))/\(item.metricType.rawValue) - screens: \(NSScreen.screens.count)")
                }

                multiProfileStatusItems[item] = statusItem
            }

            LoggingService.shared.logUIEvent("Multi-profile: Created \(selectedItems.count) status items")
        }

        observeAppearanceChanges()
    }

    /// Updates all multi-profile status items
    func updateMultiProfileButtons(
        profiles: [Profile],
        snapshots: [UUID: ProviderUsageSnapshot],
        config: MultiProfileDisplayConfig
    ) {
        guard isMultiProfileMode else { return }
        _ = config

        for profile in profiles where profile.isSelectedForDisplay {
            for metricConfig in multiProfileMetricConfigs(for: profile) {
                let itemKey = MultiProfileStatusItemKey(profileId: profile.id, metricType: metricConfig.metricType)
                guard let statusItem = multiProfileStatusItems[itemKey],
                      let button = statusItem.button else {
                    continue
                }

                let menuBarIsDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

                guard let snapshot = snapshots[profile.id],
                      let usage = syntheticUsage(for: snapshot, preferredMetric: metricConfig.metricType),
                      let metricRow = row(for: metricConfig.metricType, in: snapshot, provider: profile.providerKind) else {
                    let logoImage = renderer.createDefaultAppLogo(isDarkMode: menuBarIsDark)
                    logoImage.isTemplate = true
                    setButtonImage(button, image: logoImage)
                    button.toolTip = profile.name
                    continue
                }

                let image = renderer.createImage(
                    for: metricConfig.metricType,
                    config: metricConfig,
                    globalConfig: profile.iconConfig,
                    usage: usage,
                    apiUsage: nil,
                    isDarkMode: menuBarIsDark,
                    colorMode: profile.iconConfig.colorMode,
                    singleColorHex: profile.iconConfig.singleColorHex,
                    showIconName: profile.iconConfig.showIconNames,
                    showNextSessionTime: metricConfig.showNextSessionTime,
                    profilePrefix: profile.providerKind.menuBarPrefix
                )

                image.isTemplate = profile.iconConfig.colorMode == .monochrome && !profile.iconConfig.showPaceMarker
                setButtonImage(button, image: image)
                button.toolTip = tooltip(for: profile, primaryRow: metricRow, secondaryRow: nil, styleConfig: metricConfig)
            }
        }
    }

    private func multiProfileMetricConfigs(for profile: Profile) -> [MetricIconConfig] {
        let enabledMetrics = profile.iconConfig.enabledMetrics.filter { $0.metricType != .api }

        switch profile.providerKind {
        case .claude, .codex:
            return enabledMetrics.filter { $0.metricType == .session || $0.metricType == .week }
        case .copilot:
            if let monthlyConfig = enabledMetrics.first(where: { $0.metricType == .week }) {
                return [monthlyConfig]
            }
            return []
        }
    }

    private func syntheticUsage(for snapshot: ProviderUsageSnapshot, preferredMetric: MenuBarMetricType) -> ClaudeUsage? {
        let meteredRows = snapshot.primaryRows.filter { $0.usedPercentage != nil }
        guard !meteredRows.isEmpty else { return nil }

        let sessionRow = row(for: .session, in: snapshot, provider: snapshot.provider)
            ?? (preferredMetric == .session ? meteredRows.first : nil)
            ?? meteredRows.first
        let weekRow = row(for: .week, in: snapshot, provider: snapshot.provider)
            ?? (preferredMetric == .week ? meteredRows.first : nil)
            ?? meteredRows.dropFirst().first
            ?? sessionRow

        guard let sessionRow else { return nil }

        let sessionPercentage = max(0, min(sessionRow.usedPercentage ?? 0, 100))
        let weekPercentage = max(0, min(weekRow?.usedPercentage ?? 0, 100))
        let sessionLimit = 100
        let weeklyLimit = Constants.weeklyLimit

        return ClaudeUsage(
            sessionTokensUsed: Int(Double(sessionLimit) * (sessionPercentage / 100.0)),
            sessionLimit: sessionLimit,
            sessionPercentage: sessionPercentage,
            sessionResetTime: sessionRow.resetTime ?? Date().addingTimeInterval(Constants.sessionWindow),
            weeklyTokensUsed: Int(Double(weeklyLimit) * (weekPercentage / 100.0)),
            weeklyLimit: weeklyLimit,
            weeklyPercentage: weekPercentage,
            weeklyResetTime: weekRow?.resetTime ?? Date().addingTimeInterval(Constants.weeklyWindow),
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            overageBalance: nil,
            overageBalanceCurrency: nil,
            lastUpdated: snapshot.fetchedAt,
            userTimezone: .current
        )
    }

    private func row(for metricType: MenuBarMetricType, in snapshot: ProviderUsageSnapshot, provider: UsageProviderKind) -> ProviderMetricRow? {
        let meteredRows = snapshot.primaryRows.filter { $0.usedPercentage != nil }
        guard !meteredRows.isEmpty else { return nil }

        let matchingRow = meteredRows.first { row in
            let id = row.id.lowercased()
            let title = row.title.lowercased()
            switch metricType {
            case .session:
                if provider == .copilot { return false }
                return id.contains("session") || id.contains("primary") || title.contains("session")
            case .week:
                if provider == .copilot {
                    return id.contains("premium") || id.contains("chat") || title.contains("premium") || title.contains("monthly")
                }
                return id.contains("week") || id.contains("weekly") || id.contains("secondary") || title.contains("week")
            case .api:
                return id.contains("api") || title.contains("api")
            }
        }

        switch metricType {
        case .session:
            return matchingRow ?? meteredRows.first
        case .week:
            return matchingRow ?? meteredRows.dropFirst().first ?? meteredRows.first
        case .api:
            return matchingRow
        }
    }

    private func tooltip(
        for profile: Profile,
        primaryRow: ProviderMetricRow,
        secondaryRow: ProviderMetricRow?,
        styleConfig: MetricIconConfig?
    ) -> String {
        var parts = ["\(profile.name) • \(primaryRow.title)"]

        if let secondaryRow {
            parts.append(secondaryRow.title)
        }

        if let styleConfig {
            parts.append(styleConfig.iconStyle.displayName)
        }

        return parts.joined(separator: " • ")
    }

    /// Checks if currently in multi-profile mode
    var isInMultiProfileMode: Bool {
        return isMultiProfileMode
    }

    /// Checks if status bar has at least one valid button (for headless mode detection)
    var hasValidStatusBar: Bool {
        // Check single-profile status items
        for (_, statusItem) in statusItems {
            if statusItem.button != nil {
                return true
            }
        }
        // Check multi-profile status items
        for (_, statusItem) in multiProfileStatusItems {
            if statusItem.button != nil {
                return true
            }
        }
        return false
    }

    /// Get button for a specific profile (multi-profile mode)
    func button(for profileId: UUID) -> NSStatusBarButton? {
        let preferredOrder: [MenuBarMetricType] = [.session, .week, .api]
        for metricType in preferredOrder {
            if let button = multiProfileStatusItems[MultiProfileStatusItemKey(profileId: profileId, metricType: metricType)]?.button {
                return button
            }
        }
        return multiProfileStatusItems.first(where: { $0.key.profileId == profileId })?.value.button
    }

    /// Find which profile ID owns the given button (multi-profile mode)
    func profileId(for sender: NSStatusBarButton?) -> UUID? {
        guard let sender = sender else { return nil }

        for (itemKey, statusItem) in multiProfileStatusItems {
            if statusItem.button === sender {
                return itemKey.profileId
            }
        }
        return nil
    }

    // MARK: - UI Updates

    /// Updates all status bar buttons based on current usage data
    func updateAllButtons(
        usage: ClaudeUsage,
        apiUsage: APIUsage?
    ) {
        // Get config from active profile
        let profile = ProfileManager.shared.activeProfile
        let config = profile?.iconConfig ?? .default

        // Check if we should show default logo (no usage credentials OR no enabled metrics)
        let hasUsageCredentials = profile?.hasUsageCredentials ?? false
        if !hasUsageCredentials || config.enabledMetrics.isEmpty {
            // Show default app logo
            if let statusItem = statusItems[.session],  // We use .session as placeholder key
               let button = statusItem.button {
                // Get actual menu bar appearance from the button
                let menuBarIsDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let logoImage = renderer.createDefaultAppLogo(isDarkMode: menuBarIsDark)
                logoImage.isTemplate = true  // Let macOS handle the color
                setButtonImage(button, image: logoImage)
            }
            return
        }

        // Normal metric display
        for metricConfig in config.enabledMetrics {
            guard let statusItem = statusItems[metricConfig.metricType],
                  let button = statusItem.button else {
                continue
            }

            // Get actual menu bar appearance from the button
            let menuBarIsDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            // Create image directly using our renderer
            let image = renderer.createImage(
                for: metricConfig.metricType,
                config: metricConfig,
                globalConfig: config,
                usage: usage,
                apiUsage: apiUsage,
                isDarkMode: menuBarIsDark,
                colorMode: config.colorMode,
                singleColorHex: config.singleColorHex,
                showIconName: config.showIconNames,
                showNextSessionTime: metricConfig.showNextSessionTime
            )

            image.isTemplate = config.colorMode == .monochrome && !config.showPaceMarker
            button.image = image

            // Tooltip with usage + peak hours info
            let metricName = metricConfig.metricType == .session ? "Session" : (metricConfig.metricType == .week ? "Week" : "API")
            let pct: Int
            switch metricConfig.metricType {
            case .session: pct = Int(usage.effectiveSessionPercentage)
            case .week: pct = Int(usage.weeklyPercentage)
            case .api: pct = Int(apiUsage?.usagePercentage ?? 0)
            }
            button.toolTip = PeakHoursHelper.tooltip(metricName: metricName, percentage: pct)
        }
    }

    /// Updates a specific metric's button
    func updateButton(
        for metricType: MenuBarMetricType,
        usage: ClaudeUsage,
        apiUsage: APIUsage?
    ) {
        guard let statusItem = statusItems[metricType],
              let button = statusItem.button else {
            return
        }

        // Get config from active profile
        let config = ProfileManager.shared.activeProfile?.iconConfig ?? .default
        guard let metricConfig = config.config(for: metricType) else {
            return
        }

        // Get the actual menu bar appearance from the button's effective appearance
        let menuBarIsDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Create image directly using our renderer
        let image = renderer.createImage(
            for: metricType,
            config: metricConfig,
            globalConfig: config,
            usage: usage,
            apiUsage: apiUsage,
            isDarkMode: menuBarIsDark,
            colorMode: config.colorMode,
            singleColorHex: config.singleColorHex,
            showIconName: config.showIconNames,
            showNextSessionTime: metricConfig.showNextSessionTime
        )

        image.isTemplate = config.colorMode == .monochrome && !config.showPaceMarker
        button.image = image

        let metricName = metricType == .session ? "Session" : (metricType == .week ? "Week" : "API")
        let pct: Int
        switch metricType {
        case .session: pct = Int(usage.effectiveSessionPercentage)
        case .week: pct = Int(usage.weeklyPercentage)
        case .api: pct = Int(apiUsage?.usagePercentage ?? 0)
        }
        button.toolTip = PeakHoursHelper.tooltip(metricName: metricName, percentage: pct)
    }

    /// Get button for a specific metric (used for popover positioning)
    func button(for metricType: MenuBarMetricType) -> NSStatusBarButton? {
        return statusItems[metricType]?.button
    }

    /// Get the first enabled metric's button (for backwards compatibility)
    var primaryButton: NSStatusBarButton? {
        let config = DataStore.shared.loadMenuBarIconConfiguration()
        guard let firstMetric = config.enabledMetrics.first else {
            return nil
        }
        return statusItems[firstMetric.metricType]?.button
    }

    /// Find which metric type owns the given button (sender)
    func metricType(for sender: NSStatusBarButton?) -> MenuBarMetricType? {
        guard let sender = sender else { return nil }

        // Find which status item has this button
        for (metricType, statusItem) in statusItems {
            if statusItem.button === sender {
                return metricType
            }
        }
        return nil
    }

    // MARK: - Appearance Observation

    private var lastObservedAppearanceName: NSAppearance.Name?

    private func observeAppearanceChanges() {
        appearanceObservers.forEach { $0.invalidate() }
        appearanceObservers.removeAll()

        // IMPORTANT: Do NOT observe per-button effectiveAppearance.
        // Setting button.image triggers effectiveAppearance KVO on the button,
        // which causes an infinite redraw loop.
        let appObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, change in
            guard let self = self else { return }
            let newName = change.newValue?.name
            guard newName != self.lastObservedAppearanceName else { return }
            self.lastObservedAppearanceName = newName
            // Clear image cache so next update re-renders with new appearance
            self.lastImageData.removeAll()
            self.delegate?.statusBarAppearanceDidChange()
        }
        appearanceObservers.append(appObserver)
    }

    /// Only sets button.image if the image data actually changed.
    /// This prevents triggering effectiveAppearance KVO when the image is identical.
    private func setButtonImage(_ button: NSStatusBarButton, image: NSImage) {
        let buttonId = ObjectIdentifier(button)
        guard let newData = image.tiffRepresentation else {
            button.image = image
            return
        }
        if lastImageData[buttonId] == newData { return }
        lastImageData[buttonId] = newData
        button.image = image
    }

    /// Debounces appearance change notifications so multiple displays/buttons
    /// coalesce into a single delegate callback
    private func scheduleAppearanceUpdate() {
        appearanceDebounceTimer?.invalidate()
        appearanceDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.delegate?.statusBarAppearanceDidChange()
        }
    }
}

// MARK: - Delegate Protocol

protocol StatusBarUIManagerDelegate: AnyObject {
    func statusBarAppearanceDidChange()
}
