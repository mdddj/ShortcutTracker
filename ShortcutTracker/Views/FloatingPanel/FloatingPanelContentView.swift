import SwiftUI

/// Content view for the floating panel.
/// Displays shortcuts for the selected app with pin toggle and transparency controls.
/// Requirements: 4.2, 4.4, 4.5, 4.6
struct FloatingPanelContentView: View {
    @Bindable var viewModel: FloatingPanelViewModel
    
    /// Callback to close the panel
    var onClose: (() -> Void)?
    
    @State private var showSettings = false
    @State private var showAddShortcut = false
    @State private var newShortcutTitle = ""
    @State private var newShortcutKeys = ""
    @State private var newShortcutCategory = ""
    @State private var isGridView = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app name and controls
            headerView
            
            Divider()
            
            // Shortcuts list
            shortcutsListView
            
            // Add shortcut panel (collapsible)
            if showAddShortcut {
                Divider()
                addShortcutView
            }
            
            // Settings panel (collapsible)               
            if showSettings {
                Divider()
                settingsView
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // App name
            Text(viewModel.selectedAppName)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            // View mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridView.toggle()
                }
            } label: {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isGridView ? "Switch to list view" : "Switch to grid view")
            
            // Add shortcut button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAddShortcut.toggle()
                    if showAddShortcut {
                        showSettings = false
                    }
                }
            } label: {
                Image(systemName: showAddShortcut ? "plus.circle.fill" : "plus.circle")
                    .foregroundStyle(showAddShortcut ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Add shortcut")
            .disabled(viewModel.selectedApp == nil)
            
            // Settings toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                    if showSettings {
                        showAddShortcut = false
                    }
                }
            } label: {
                Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            
            // Pin toggle button
            Button {
                viewModel.togglePin()
            } label: {
                Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(viewModel.isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(viewModel.isPinned ? "Unpin from top" : "Pin to top")
            
            // Close button
            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close panel")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Shortcuts List View
    
    private var shortcutsListView: some View {
        Group {
            if viewModel.currentShortcuts.isEmpty {
                emptyStateView
                    .transition(.opacity)
            } else {
                ScrollView {
                    if isGridView {
                        // Grid view - 2 columns
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            ForEach(viewModel.currentShortcuts) { shortcut in
                                FloatingPanelShortcutGridItem(shortcut: shortcut)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                        removal: .opacity.combined(with: .scale(scale: 0.95))
                                    ))
                            }
                        }
                        .padding(12)
                    } else {
                        // List view
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.currentShortcuts) { shortcut in
                                FloatingPanelShortcutRow(shortcut: shortcut)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                        removal: .opacity.combined(with: .scale(scale: 0.95))
                                    ))
                            }
                        }
                        .padding(12)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentShortcuts.map { $0.id })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentShortcuts.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: isGridView)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "keyboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No Shortcuts")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if viewModel.selectedApp == nil {
                Text("Select an app to view shortcuts")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Add shortcuts in the main window")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Add Shortcut View
    
    private var addShortcutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Shortcut")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Key capture field
            VStack(alignment: .leading, spacing: 4) {
                Text("Keys")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                KeyCaptureField(keys: $newShortcutKeys, placeholder: "Click and press keys...")
            }
            
            // Title field
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Save, Copy, Paste", text: $newShortcutTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Category field (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Category (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. File, Edit, View", text: $newShortcutCategory)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    resetAddShortcutForm()
                    withAnimation {
                        showAddShortcut = false
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Add") {
                    addShortcut()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newShortcutKeys.isEmpty || newShortcutTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }
    
    private func addShortcut() {
        guard let app = viewModel.selectedApp else { return }
        
        let title = newShortcutTitle.trimmingCharacters(in: .whitespaces)
        let category = newShortcutCategory.trimmingCharacters(in: .whitespaces)
        
        viewModel.addShortcut(
            title: title,
            keys: newShortcutKeys,
            category: category.isEmpty ? nil : category,
            to: app
        )
        
        resetAddShortcutForm()
        // Keep the panel open for adding more shortcuts
    }
    
    private func resetAddShortcutForm() {
        newShortcutTitle = ""
        newShortcutKeys = ""
        newShortcutCategory = ""
    }
    
    // MARK: - Settings View
    
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Transparency slider
            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.secondary)
                
                Text("Opacity")
                    .font(.subheadline)
                
                Slider(value: Binding(
                    get: { viewModel.transparency },
                    set: { viewModel.setTransparency($0) }
                ), in: 0.3...1.0)
                .frame(maxWidth: 150)
                
                Text("\(Int(viewModel.transparency * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            
            // Pin toggle
            Toggle(isOn: Binding(
                get: { viewModel.isPinned },
                set: { _ in viewModel.togglePin() }
            )) {
                HStack {
                    Image(systemName: "pin")
                        .foregroundStyle(.secondary)
                    Text("Always on top")
                        .font(.subheadline)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(16)
    }
}

// MARK: - Floating Panel Shortcut Row (List View)

/// Compact shortcut row for the floating panel list view.
/// Requirements: 4.2
struct FloatingPanelShortcutRow: View {
    let shortcut: ShortcutItem
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Key combination badge
            Text(shortcut.keys)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
            
            // Category tag (if present)
            if let category = shortcut.category, !category.isEmpty {
                Text(category)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

// MARK: - Floating Panel Shortcut Grid Item (Grid View)

/// Compact shortcut card for the floating panel grid view.
struct FloatingPanelShortcutGridItem: View {
    let shortcut: ShortcutItem
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Key combination badge
            Text(shortcut.keys)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Title
            Text(shortcut.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FloatingPanelContentView(
        viewModel: FloatingPanelViewModel()
    )
    .frame(width: 320, height: 400)
}
