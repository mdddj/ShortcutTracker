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
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    
    /// Filtered shortcuts based on search text
    private var filteredShortcuts: [ShortcutItem] {
        guard !searchText.isEmpty else {
            return viewModel.currentShortcuts
        }
        let query = searchText.lowercased()
        return viewModel.currentShortcuts.filter { shortcut in
            shortcut.title.lowercased().contains(query) ||
            shortcut.keys.lowercased().contains(query) ||
            (shortcut.category?.lowercased().contains(query) ?? false) ||
            (shortcut.shortcutDescription?.lowercased().contains(query) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app name and controls
            headerView
            
            // Search bar (collapsible)
            if isSearching {
                searchBarView
            }
            
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
            
            // Search toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching.toggle()
                    if isSearching {
                        showSettings = false
                        showAddShortcut = false
                        isSearchFieldFocused = true
                    } else {
                        searchText = ""
                    }
                }
            } label: {
                Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .foregroundStyle(isSearching ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Search shortcuts (⌘F)")
            
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
    
    // MARK: - Search Bar View
    
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("搜索快捷键...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("\(filteredShortcuts.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.2)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Shortcuts List View
    
    private var shortcutsListView: some View {
        Group {
            if filteredShortcuts.isEmpty {
                if searchText.isEmpty {
                    emptyStateView
                } else {
                    noSearchResultsView
                }
            } else {
                ScrollView {
                    if isGridView {
                        // Grid view - 2 columns
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            ForEach(filteredShortcuts) { shortcut in
                                FloatingPanelShortcutGridItem(shortcut: shortcut, searchText: searchText)
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
                            ForEach(filteredShortcuts) { shortcut in
                                FloatingPanelShortcutRow(shortcut: shortcut, searchText: searchText)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                        removal: .opacity.combined(with: .scale(scale: 0.95))
                                    ))
                            }
                        }
                        .padding(12)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: filteredShortcuts.map { $0.id })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: filteredShortcuts.isEmpty)
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
    
    // MARK: - No Search Results View
    
    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("未找到结果")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("没有匹配 \"\(searchText)\" 的快捷键")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
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
    var searchText: String = ""
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Key combination badge
            HighlightedText(text: shortcut.keys, highlight: searchText, isMonospaced: true)
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
            HighlightedText(text: shortcut.title, highlight: searchText)
                .font(.callout)
                .lineLimit(1)
            
            Spacer()
            
            // Category tag (if present)
            if let category = shortcut.category, !category.isEmpty {
                HighlightedText(text: category, highlight: searchText)
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
    var searchText: String = ""
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Key combination badge
            HighlightedText(text: shortcut.keys, highlight: searchText, isMonospaced: true)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Title
            HighlightedText(text: shortcut.title, highlight: searchText)
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

// MARK: - Highlighted Text View

/// A view that displays text with highlighted search matches
struct HighlightedText: View {
    let text: String
    let highlight: String
    var isMonospaced: Bool = false
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            highlightedTextView
        }
    }
    
    private var highlightedTextView: some View {
        let attributedString = createHighlightedAttributedString()
        return Text(attributedString)
    }
    
    private func createHighlightedAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        
        while let range = lowercasedText.range(of: lowercasedHighlight, range: searchStartIndex..<lowercasedText.endIndex) {
            // Convert String.Index to AttributedString.Index
            let startOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let endOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)
            
            let attrStart = attributedString.index(attributedString.startIndex, offsetByCharacters: startOffset)
            let attrEnd = attributedString.index(attributedString.startIndex, offsetByCharacters: endOffset)
            
            attributedString[attrStart..<attrEnd].backgroundColor = .yellow.opacity(0.4)
            attributedString[attrStart..<attrEnd].foregroundColor = .black
            
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

// MARK: - Preview

#Preview {
    FloatingPanelContentView(
        viewModel: FloatingPanelViewModel()
    )
    .frame(width: 320, height: 400)
}
