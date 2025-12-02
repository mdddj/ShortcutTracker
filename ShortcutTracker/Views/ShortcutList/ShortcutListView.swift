import SwiftUI
import SwiftData

/// View displaying the list of shortcuts for the selected application.
/// Includes search, sort options, and add shortcut functionality.
/// Requirements: 2.1, 2.6, 2.7, 3.3, 9.4
struct ShortcutListView: View {
    @Bindable var appViewModel: AppViewModel
    @Bindable var shortcutViewModel: ShortcutViewModel
    
    @State private var showingAddShortcut = false
    @State private var shortcutToEdit: ShortcutItem?
    @State private var showingDeleteConfirmation = false
    @State private var shortcutToDelete: ShortcutItem?
    @State private var contentOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area
            toolbarView
            
            Divider()
            
            // Content area with transition animation
            Group {
                if shortcutViewModel.shortcuts.isEmpty {
                    emptyStateView
                        .transition(.opacity)
                } else {
                    shortcutListContent
                        .transition(.opacity)
                }
            }
            .opacity(contentOpacity)
            .animation(.easeInOut(duration: 0.2), value: shortcutViewModel.shortcuts.isEmpty)
        }
        .navigationTitle(appViewModel.selectedApp?.name ?? "Shortcuts")
        .onChange(of: appViewModel.selectedApp?.id) { _, _ in
            // Animate content change when switching apps
            withAnimation(.easeOut(duration: 0.1)) {
                contentOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.15)) {
                    contentOpacity = 1.0
                }
            }
        }
        .sheet(isPresented: $showingAddShortcut) {
            ShortcutEditView(
                mode: .add,
                onSave: { title, keys, description, category in
                    shortcutViewModel.addShortcut(
                        title: title,
                        keys: keys,
                        description: description,
                        category: category
                    )
                    showingAddShortcut = false
                },
                onCancel: {
                    showingAddShortcut = false
                }
            )
        }
        .sheet(item: $shortcutToEdit) { shortcut in
            ShortcutEditView(
                mode: .edit(shortcut),
                onSave: { title, keys, description, category in
                    shortcutViewModel.editShortcut(
                        shortcut,
                        title: title,
                        keys: keys,
                        description: description,
                        category: category
                    )
                    shortcutToEdit = nil
                },
                onCancel: {
                    shortcutToEdit = nil
                }
            )
        }

        .confirmationDialog(
            "Delete Shortcut",
            isPresented: $showingDeleteConfirmation,
            presenting: shortcutToDelete
        ) { shortcut in
            Button("Delete", role: .destructive) {
                shortcutViewModel.deleteShortcut(shortcut)
                shortcutToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                shortcutToDelete = nil
            }
        } message: { shortcut in
            Text("Are you sure you want to delete \"\(shortcut.title)\"?")
        }
    }
    
    // MARK: - Toolbar View
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search shortcuts...", text: $shortcutViewModel.searchText)
                    .textFieldStyle(.plain)
                if !shortcutViewModel.searchText.isEmpty {
                    Button(action: { shortcutViewModel.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .frame(maxWidth: 250)
            
            Spacer()
            
            // Sort picker
            Picker("Sort", selection: $shortcutViewModel.sortOption) {
                ForEach(ShortcutSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            // Add button
            Button(action: { showingAddShortcut = true }) {
                Image(systemName: "plus")
            }
            .help("Add Shortcut")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Shortcuts", systemImage: "keyboard")
        } description: {
            if shortcutViewModel.searchText.isEmpty {
                Text("Add shortcuts to keep track of keyboard combinations for this application.")
            } else {
                Text("No shortcuts match your search.")
            }
        } actions: {
            if shortcutViewModel.searchText.isEmpty {
                Button("Add Shortcut") {
                    showingAddShortcut = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Clear Search") {
                    shortcutViewModel.clearSearch()
                }
            }
        }
    }
    
    // MARK: - Shortcut List Content
    
    private var shortcutListContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(shortcutViewModel.shortcuts, id: \.id) { shortcut in
                    ShortcutRowView(shortcut: shortcut)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                        .contextMenu {
                            Button("Edit...") {
                                shortcutToEdit = shortcut
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                shortcutToDelete = shortcut
                                showingDeleteConfirmation = true
                            }
                        }
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.25), value: shortcutViewModel.shortcuts.map { $0.id })
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: AppItem.self, ShortcutItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let dataService = DataService(modelContext: container.mainContext)
    let appVM = AppViewModel(dataService: dataService)
    let shortcutVM = ShortcutViewModel(dataService: dataService, appViewModel: appVM)
    
    ShortcutListView(appViewModel: appVM, shortcutViewModel: shortcutVM)
        .modelContainer(container)
}
