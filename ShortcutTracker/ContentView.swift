import SwiftUI
import SwiftData

/// Main content view with NavigationSplitView layout.
/// Displays sidebar with applications and detail area with shortcuts.
/// Uses shared ViewModels for state synchronization across the app.
/// Requirements: 3.1, 3.2, 4.2, 5.2, 9.4
struct ContentView: View {
    /// Shared AppViewModel for state synchronization
    /// Requirements: 3.2, 4.2, 5.2
    @Bindable var appViewModel: AppViewModel
    
    /// Shared ShortcutViewModel for shortcut operations
    @Bindable var shortcutViewModel: ShortcutViewModel
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: appViewModel)
        } detail: {
            detailContent
        }
        .frame(minWidth: 700, minHeight: 450)
    }
    
    // MARK: - Detail Content with Animation
    
    @ViewBuilder
    private var detailContent: some View {
        Group {
            if appViewModel.selectedApp != nil {
                ShortcutListView(
                    appViewModel: appViewModel,
                    shortcutViewModel: shortcutViewModel
                )
                .id(appViewModel.selectedApp?.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
            } else {
                ContentUnavailableView(
                    "No Application Selected",
                    systemImage: "sidebar.left",
                    description: Text("Select an application from the sidebar to view its shortcuts.")
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appViewModel.selectedApp?.id)
    }
}

#Preview {
    @Previewable @State var dataService = DataService.preview
    @Previewable @State var appViewModel = AppViewModel(dataService: DataService.preview)
    
    ContentView(
        appViewModel: appViewModel,
        shortcutViewModel: ShortcutViewModel(dataService: dataService, appViewModel: appViewModel)
    )
    .modelContainer(for: [AppItem.self, ShortcutItem.self], inMemory: true)
}
