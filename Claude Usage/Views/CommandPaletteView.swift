//
//  CommandPaletteView.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-04-07.
//

import SwiftUI

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var drillStack: [PaletteCommand] = []
    @FocusState private var isSearchFocused: Bool

    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    @Environment(\.colorScheme) private var colorScheme

    private let frecency = FrecencyTracker.shared

    // MARK: - Commands

    private var rootCommands: [PaletteCommand] {
        var cmds: [PaletteCommand] = []

        // Actions
        cmds.append(PaletteCommand(
            id: "refresh_now", title: "command_palette.refresh_now".localized,
            icon: "arrow.clockwise", category: .actions
        ) {
            NotificationCenter.default.post(name: .commandPaletteRefresh, object: nil)
            dismiss()
        })

        cmds.append(PaletteCommand(
            id: "force_refresh_all", title: "command_palette.force_refresh_all".localized,
            icon: "arrow.triangle.2.circlepath", category: .actions
        ) {
            NotificationCenter.default.post(name: .commandPaletteForceRefreshAll, object: nil)
            dismiss()
        })

        cmds.append(PaletteCommand(
            id: "copy_usage", title: "command_palette.copy_usage".localized,
            icon: "doc.on.clipboard", category: .actions
        ) {
            NotificationCenter.default.post(name: .commandPaletteCopyUsage, object: nil)
            dismiss()
        })

        // Profiles
        let profileChildren = profileManager.profiles.map { profile in
            PaletteCommand(
                id: "switch_profile_\(profile.id.uuidString)",
                title: profile.name,
                icon: profileManager.activeProfile?.id == profile.id ? "checkmark.circle.fill" : "person.circle",
                category: .profiles
            ) {
                Task { @MainActor in
                    await profileManager.activateProfile(profile.id)
                }
                dismiss()
            }
        }
        cmds.append(PaletteCommand(
            id: "switch_profile", title: "command_palette.switch_profile".localized,
            icon: "person.crop.circle", category: .profiles, children: profileChildren
        ))

        cmds.append(PaletteCommand(
            id: "create_profile", title: "command_palette.create_profile".localized,
            icon: "person.badge.plus", category: .profiles
        ) {
            _ = profileManager.createProfile()
            dismiss()
        })

        cmds.append(PaletteCommand(
            id: "edit_profile", title: "command_palette.edit_profile".localized,
            icon: "pencil.circle", category: .profiles
        ) {
            NotificationCenter.default.post(name: .commandPaletteNavigateSettings, object: SettingsSection.manageProfiles)
            dismiss()
        })

        // Settings — Icon Style (drillable)
        let iconStyleChildren = MenuBarIconStyle.allCases.map { style in
            PaletteCommand(
                id: "icon_style_\(style.rawValue)",
                title: style.displayName,
                icon: "paintbrush",
                category: .settings
            ) {
                if var profile = profileManager.activeProfile {
                    profile.iconConfig.metrics = profile.iconConfig.metrics.map { metric in
                        var m = metric
                        m.iconStyle = style
                        return m
                    }
                    profileManager.updateProfile(profile)
                    NotificationCenter.default.post(name: .menuBarIconConfigChanged, object: nil)
                }
                dismiss()
            }
        }
        cmds.append(PaletteCommand(
            id: "toggle_icon_style", title: "command_palette.icon_style".localized,
            icon: "paintbrush.fill", category: .settings, children: iconStyleChildren
        ))

        // Settings — Color Mode (drillable)
        let colorModeChildren = StatuslineColorMode.allCases.map { mode in
            PaletteCommand(
                id: "color_mode_\(mode.rawValue)",
                title: mode.displayName,
                icon: "circle.lefthalf.filled",
                category: .settings
            ) {
                if var profile = profileManager.activeProfile {
                    profile.iconConfig.colorMode = mode
                    profileManager.updateProfile(profile)
                    NotificationCenter.default.post(name: .menuBarIconConfigChanged, object: nil)
                }
                dismiss()
            }
        }
        cmds.append(PaletteCommand(
            id: "toggle_color_mode", title: "command_palette.color_mode".localized,
            icon: "circle.lefthalf.filled", category: .settings, children: colorModeChildren
        ))

        // Settings — Switch Language (drillable)
        let langChildren = LanguageManager.SupportedLanguage.allCases.map { lang in
            PaletteCommand(
                id: "lang_\(lang.code)",
                title: lang.displayName,
                icon: languageManager.currentLanguage == lang ? "checkmark.circle.fill" : "globe",
                category: .settings
            ) {
                languageManager.currentLanguage = lang
                dismiss()
            }
        }
        cmds.append(PaletteCommand(
            id: "switch_language", title: "command_palette.switch_language".localized,
            icon: "globe", category: .settings, children: langChildren
        ))

        // Window
        cmds.append(PaletteCommand(
            id: "open_settings", title: "command_palette.open_settings".localized,
            icon: "gearshape", category: .window
        ) {
            NotificationCenter.default.post(name: .openSettings, object: nil)
            dismiss()
        })

        cmds.append(PaletteCommand(
            id: "close_settings", title: "command_palette.close_settings".localized,
            icon: "xmark.circle", category: .window
        ) {
            NSApp.keyWindow?.close()
            dismiss()
        })

        cmds.append(PaletteCommand(
            id: "detach_popover", title: "command_palette.detach_popover".localized,
            icon: "rectangle.portrait.and.arrow.right", category: .window
        ) {
            NotificationCenter.default.post(name: .commandPaletteDetachPopover, object: nil)
            dismiss()
        })

        cmds.append(PaletteCommand(
            id: "open_feedback", title: "command_palette.open_feedback".localized,
            icon: "envelope", category: .window
        ) {
            NotificationCenter.default.post(name: .commandPaletteShowFeedback, object: nil)
            dismiss()
        })

        // Updates
        cmds.append(PaletteCommand(
            id: "check_updates", title: "command_palette.check_updates".localized,
            icon: "arrow.down.circle", category: .updates
        ) {
            UpdateManager.shared.checkForUpdates()
            dismiss()
        })

        return cmds
    }

    private var activeCommands: [PaletteCommand] {
        if let parent = drillStack.last, let children = parent.children {
            return children
        }
        return rootCommands
    }

    private var filteredCommands: [PaletteCommand] {
        let commands = activeCommands
        guard !searchText.isEmpty else {
            // Sort by frecency when no search
            return commands.sorted { frecency.score(for: $0.id) > frecency.score(for: $1.id) }
        }
        let filtered = commands.filter {
            $0.title.localizedStandardContains(searchText) ||
            $0.category.localizedTitle.localizedStandardContains(searchText)
        }
        return filtered.sorted { frecency.score(for: $0.id) > frecency.score(for: $1.id) }
    }

    private var groupedCommands: [(String, [PaletteCommand])] {
        if drillStack.last != nil {
            // When drilled in, don't group
            return [("", filteredCommands)]
        }
        let dict = Dictionary(grouping: filteredCommands) { $0.category.localizedTitle }
        return PaletteCommand.Category.allCases.compactMap { cat in
            guard let cmds = dict[cat.localizedTitle], !cmds.isEmpty else { return nil }
            return (cat.localizedTitle, cmds)
        }
    }

    private var flatCommands: [PaletteCommand] {
        groupedCommands.flatMap { $0.1 }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("command_palette.placeholder".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _ in
                        selectedIndex = 0
                    }

                if !drillStack.isEmpty {
                    Button {
                        drillStack.removeLast()
                        searchText = ""
                        selectedIndex = 0
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("command_palette.back".localized)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Breadcrumb for drill
            if let parent = drillStack.last {
                HStack(spacing: 4) {
                    Image(systemName: parent.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(parent.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
            }

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if flatCommands.isEmpty {
                            Text("command_palette.no_results".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(groupedCommands, id: \.0) { category, commands in
                                if !category.isEmpty {
                                    Text(category.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 8)
                                        .padding(.bottom, 2)
                                }

                                ForEach(commands) { command in
                                    let idx = flatCommands.firstIndex(of: command) ?? 0
                                    CommandRow(
                                        command: command,
                                        isSelected: idx == selectedIndex,
                                        hasDrill: command.children != nil
                                    )
                                    .id(command.id)
                                    .onTapGesture {
                                        executeCommand(command)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedIndex) { newIndex in
                    let cmds = flatCommands
                    if cmds.indices.contains(newIndex) {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(cmds[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            // Footer hint
            Divider()
            HStack(spacing: 12) {
                Label("↑↓", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryLabel)
                Label("command_palette.hint_enter".localized, systemImage: "return")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryLabel)
                Label("esc", systemImage: "escape")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryLabel)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onExitCommand {
            if drillStack.isEmpty {
                dismiss()
            } else {
                drillStack.removeLast()
                searchText = ""
                selectedIndex = 0
            }
        }
        .background(KeyEventHandling(
            onUp: { moveSelection(-1) },
            onDown: { moveSelection(1) },
            onEnter: { executeSelected() }
        ))
    }

    // MARK: - Actions

    private func dismiss() {
        isPresented = false
    }

    private func moveSelection(_ delta: Int) {
        let count = flatCommands.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func executeSelected() {
        let cmds = flatCommands
        guard cmds.indices.contains(selectedIndex) else { return }
        executeCommand(cmds[selectedIndex])
    }

    private func executeCommand(_ command: PaletteCommand) {
        if let children = command.children, !children.isEmpty {
            drillStack.append(command)
            searchText = ""
            selectedIndex = 0
        } else {
            frecency.record(command.id)
            command.action()
        }
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let hasDrill: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: command.icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20)

            Text(command.title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            if hasDrill {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .tertiaryLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Keyboard Event Handling

private struct KeyEventHandling: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onEnter = onEnter
    }

    class KeyEventView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEnter: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: // Up arrow
                onUp?()
            case 125: // Down arrow
                onDown?()
            case 36: // Return/Enter
                onEnter?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let commandPaletteRefresh = Notification.Name("commandPaletteRefresh")
    static let commandPaletteForceRefreshAll = Notification.Name("commandPaletteForceRefreshAll")
    static let commandPaletteCopyUsage = Notification.Name("commandPaletteCopyUsage")
    static let commandPaletteDetachPopover = Notification.Name("commandPaletteDetachPopover")
    static let commandPaletteShowFeedback = Notification.Name("commandPaletteShowFeedback")
    static let commandPaletteNavigateSettings = Notification.Name("commandPaletteNavigateSettings")
}
