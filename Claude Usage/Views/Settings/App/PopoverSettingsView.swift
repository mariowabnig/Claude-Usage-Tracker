//
//  PopoverSettingsView.swift
//  Claude Usage
//
//  Popover display settings (app-wide, applies to both single and multi-profile)
//

import SwiftUI

struct PopoverSettingsView: View {
    @State private var timeDisplay: PopoverTimeDisplay = SharedDataStore.shared.loadPopoverTimeDisplay()
    @State private var timeFormat: TimeFormatPreference = SharedDataStore.shared.loadTimeFormatPreference()
    @State private var showProviderDetails: Bool = SharedDataStore.shared.loadPopoverShowProviderDetails()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.section) {
                SettingsPageHeader(
                    title: "popover.title".localized,
                    subtitle: "popover.subtitle".localized
                )

                SettingsSectionCard(title: "popover.time_display".localized, subtitle: "popover.time_display_desc".localized) {
                    Picker("", selection: $timeDisplay) {
                        Text("popover.time_display_reset".localized).tag(PopoverTimeDisplay.resetTime)
                        Text("popover.time_display_remaining".localized).tag(PopoverTimeDisplay.remainingTime)
                        Text("popover.time_display_both".localized).tag(PopoverTimeDisplay.both)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingsSectionCard(title: "popover.time_format".localized, subtitle: "popover.time_format_desc".localized) {
                    Picker("", selection: $timeFormat) {
                        Text("popover.time_format_system".localized).tag(TimeFormatPreference.system)
                        Text("popover.time_format_12h".localized).tag(TimeFormatPreference.twelveHour)
                        Text("popover.time_format_24h".localized).tag(TimeFormatPreference.twentyFourHour)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingsSectionCard(
                    title: "Provider details",
                    subtitle: "Show account and credit details for providers like Codex in the popover"
                ) {
                    SettingToggle(
                        title: "Show provider account details",
                        description: "Off by default. Enable this only if you want to see account and token-related provider details in the popover.",
                        isOn: $showProviderDetails
                    )
                }
            }
            .padding()
        }
        .onChange(of: timeDisplay) { _, newValue in
            SharedDataStore.shared.savePopoverTimeDisplay(newValue)
        }
        .onChange(of: timeFormat) { _, newValue in
            SharedDataStore.shared.saveTimeFormatPreference(newValue)
        }
        .onChange(of: showProviderDetails) { _, newValue in
            SharedDataStore.shared.savePopoverShowProviderDetails(newValue)
        }
    }
}
