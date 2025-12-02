import SwiftUI

/// Popover view displayed when clicking the menu bar icon.
/// Shows a compact shortcut list for the selected app with action buttons.
/// Requirements: 5.2, 5.3, 5.4, 5.5, 5.6
struct MenuBarPopoverView: View {
    @Bindable var appViewModel: AppViewModel
    
    /// Environment action to open settings
    @Environment(\.openSettings) private var openSettings
    
    /// Callback to close the popover
    var onClose: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app selector
            headerView
            
            Divider()
            
            // Shortcuts list
            shortcutsListView
            
            Divider()
            
            // Action buttons
            actionButtonsView
        }
        .frame(width: 320, height: 400)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // App selector menu
            Menu {
                ForEach(appViewModel.apps) { app in
                    Button {
                        appViewModel.selectApp(app)
                    } label: {
                        HStack {
                            Text(app.name)
                            if appViewModel.selectedApp?.id == app.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if appViewModel.apps.isEmpty {
                    Text("No apps added")
                        .foregroundStyle(.secondary)
                }
            } label: {
                HStack(spacing: 6) {
                    if let selectedApp = appViewModel.selectedApp {
                        Text(selectedApp.name)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text("Select App")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer()
            
            // Shortcut count badge
            if let selectedApp = appViewModel.selectedApp {
                Text("\((selectedApp.shortcuts ?? []).count) shortcuts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Shortcuts List View
    
    private var shortcutsListView: some View {
        Group {
            if let selectedApp = appViewModel.selectedApp {
                if (selectedApp.shortcuts ?? []).isEmpty {
                    emptyShortcutsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach((selectedApp.shortcuts ?? []).sorted { $0.title < $1.title }) { shortcut in
                                MenuBarShortcutRow(shortcut: shortcut)
                            }
                        }
                        .padding(12)
                    }
                }
            } else {
                noAppSelectedView
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Empty States
    
    private var emptyShortcutsView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "keyboard")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text("No Shortcuts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Add shortcuts in the main window")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noAppSelectedView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text("No App Selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Select an app from the menu above")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    
    // MARK: - Action Buttons View
    
    /// Action buttons for opening main window, floating panel, AI import, and settings.
    /// Requirements: 5.3, 5.4, 5.5, 5.6
    private var actionButtonsView: some View {
        VStack(spacing: 8) {
            // Keystroke overlay toggle
            KeystrokeOverlayToggle()
            
            HStack(spacing: 8) {
                // Open Main Window button
                // Requirements: 5.3
                MenuBarActionButton(
                    title: "Main Window",
                    systemImage: "macwindow",
                    action: {
                        onClose?()
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .openMainWindow, object: nil)
                    }
                )
                
                // Open Floating Panel button
                // Requirements: 5.4
                MenuBarActionButton(
                    title: "Floating Panel",
                    systemImage: "rectangle.on.rectangle",
                    action: {
                        onClose?()
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .openFloatingPanel, object: nil)
                    }
                )
            }
            
            HStack(spacing: 8) {
                // AI Import button
                // Requirements: 5.5
                MenuBarActionButton(
                    title: "AI Import",
                    systemImage: "sparkles",
                    action: {
                        onClose?()
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .openAIImport, object: nil)
                    }
                )
                
                // Settings button
                // Requirements: 5.6
                MenuBarActionButton(
                    title: "Settings",
                    systemImage: "gearshape",
                    action: {
                        onClose?()
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }
                )
            }
        }
        .padding(12)
    }
}

// MARK: - Keystroke Overlay Toggle

struct KeystrokeOverlayToggle: View {
    @ObservedObject private var controller = KeystrokeOverlayController.shared
    
    var body: some View {
        Button {
            controller.isEnabled.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: controller.isEnabled ? "keyboard.badge.eye" : "keyboard")
                    .font(.caption)
                    .foregroundStyle(controller.isEnabled ? Color.green : Color.secondary)
                
                Text(controller.isEnabled ? "Keystroke Display ON" : "Keystroke Display OFF")
                    .font(.caption)
                
                Spacer()
                
                Circle()
                    .fill(controller.isEnabled ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(controller.isEnabled ? Color.green.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Bar Shortcut Row

/// Compact shortcut row for the menu bar popover.
/// Requirements: 5.2
struct MenuBarShortcutRow: View {
    let shortcut: ShortcutItem
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Key combination badge
            Text(shortcut.keys)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.15))
                )
                .foregroundStyle(Color.accentColor)
            
            // Title
            Text(shortcut.title)
                .font(.callout)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Menu Bar Action Button

/// Reusable action button for the menu bar popover.
struct MenuBarActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarPopoverView(
        appViewModel: AppViewModel(dataService: DataService.preview)
    )
}
