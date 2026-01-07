import SwiftData
import SwiftUI

/// Main entry point for the ShortcutTracker application.
/// Sets up the main window, menu bar extra, and shared state.
/// Requirements: 1.6, 5.1, 8.3, 10.1
@main
struct ShortcutTrackerApp: App {
    /// Shared model container for SwiftData persistence
    /// Requirements: 8.3
    var sharedModelContainer: ModelContainer = {
        do {
            print("⚠️ 数据库存储路径: \(URL.applicationSupportDirectory.path)")
            // Use the simplest possible configuration
            return try ModelContainer(for: AppItem.self, ShortcutItem.self)
        } catch {
            

            // MARK: - 捕获错误并删除旧数据

            print("SwiftData 启动失败，可能是 Schema 不匹配，正在删除旧数据: \(error)")

            // 找到默认的数据存储路径
            let fileManager = FileManager.default
            if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let databaseURL = supportDir.appendingPathComponent("default.store")

                // 删除 .store 文件以及相关的 .shm 和 .wal 文件
                do {
                    try fileManager.removeItem(at: databaseURL)
                    try fileManager.removeItem(at: supportDir.appendingPathComponent("default.store-shm"))
                    try fileManager.removeItem(at: supportDir.appendingPathComponent("default.store-wal"))
                    print("旧数据删除成功！")
                } catch {
                    print("无法删除旧数据: \(error)")
                }
            }

            // 删除后再次尝试创建（这次应该是一个全新的库）
            do {
                return try ModelContainer(for:  AppItem.self, ShortcutItem.self)
            } catch {
                fatalError("无法创建 ModelContainer: \(error)")
            }
        }
    }()

    /// Shared AppViewModel for state synchronization across windows
    /// Requirements: 3.2, 4.2, 5.2
    @State private var appViewModel: AppViewModel?

    /// Shared ShortcutViewModel for state synchronization
    @State private var shortcutViewModel: ShortcutViewModel?

    /// Floating panel controller
    @State private var floatingPanelController = FloatingPanelController()

    /// Floating panel view model
    @State private var floatingPanelViewModel: FloatingPanelViewModel?

    /// AI Import view model
    @State private var aiImportViewModel: AIImportViewModel?

    /// Shared DataService instance
    @State private var dataService: DataService?
    
    /// Local backup service for auto-sync
    @State private var localBackupService = LocalBackupService()
    
    /// App selector controller for global hotkey
    @State private var appSelectorController = AppSelectorController.shared

    /// Track if view models have been initialized
    @State private var isInitialized = false

    /// Track if AI Import sheet is shown
    @State private var showAIImportSheet = false

    /// Track if Settings window is shown
    @State private var showSettingsWindow = false

    var body: some Scene {
        // Main window
        WindowGroup {
            Group {
                if let appViewModel = appViewModel,
                   let shortcutViewModel = shortcutViewModel {
                    ContentView(
                        appViewModel: appViewModel,
                        shortcutViewModel: shortcutViewModel
                    )
                } else {
                    ProgressView("Loading...")
                        .frame(minWidth: 700, minHeight: 450)
                }
            }
            .onAppear {
                initializeSharedViewModels()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                // Bring main window to front
                if let window = NSApp.windows.first(where: { $0.title.contains("ShortcutTracker") || $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // If no window found, just activate the app
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFloatingPanel)) { _ in
                showFloatingPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .selectedAppChanged)) { _ in
                // Refresh floating panel content when selected app changes
                // Requirements: 3.2, 4.2
                refreshFloatingPanelIfVisible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAIImport)) { _ in
                // Open AI Import sheet
                // Requirements: 5.5
                openAIImport()
            }
            .onReceive(NotificationCenter.default.publisher(for: .shortcutsDidChange)) { _ in
                // Refresh keystroke overlay cache when shortcuts change
                if let dataService = dataService {
                    refreshKeystrokeOverlayCache(dataService: dataService)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestAppList)) { _ in
                // Provide app list to selector
                if let dataService = dataService {
                    appSelectorController.apps = dataService.fetchApps()
                }
            }
            .onAppear {
                setupAppSelector()
            }
            .sheet(isPresented: $showAIImportSheet) {
                if let aiImportViewModel = aiImportViewModel {
                    AIImportView(viewModel: aiImportViewModel, onDismiss: {
                        showAIImportSheet = false
                    })
                }
            }
        }
        .modelContainer(sharedModelContainer)

        // Menu bar extra with popover
        // Requirements: 5.1, 5.2
        MenuBarExtra("ShortcutTracker", systemImage: "keyboard") {
            if let appViewModel = appViewModel {
                MenuBarPopoverView(appViewModel: appViewModel)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 320, height: 100)
                .onAppear {
                    initializeSharedViewModels()
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Settings window
        // Requirements: 5.6
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
    }

    // MARK: - Private Methods

    /// Initializes shared view models for state synchronization across all windows.
    /// This ensures the main window, floating panel, and menu bar all share the same state.
    /// Requirements: 1.6, 3.2, 4.2, 5.2, 8.3
    private func initializeSharedViewModels() {
        guard !isInitialized else { return }
        isInitialized = true

        // Create shared DataService with the model container's main context
        let sharedDataService = DataService(modelContext: sharedModelContainer.mainContext)
        dataService = sharedDataService

        // Create shared AppViewModel
        let sharedAppViewModel = AppViewModel(dataService: sharedDataService)
        appViewModel = sharedAppViewModel

        // Create shared ShortcutViewModel linked to AppViewModel
        let sharedShortcutViewModel = ShortcutViewModel(
            dataService: sharedDataService,
            appViewModel: sharedAppViewModel
        )
        shortcutViewModel = sharedShortcutViewModel

        // Create FloatingPanelViewModel linked to shared AppViewModel
        let sharedFloatingPanelViewModel = FloatingPanelViewModel(
            panelController: floatingPanelController,
            appViewModel: sharedAppViewModel,
            dataService: sharedDataService
        )
        floatingPanelViewModel = sharedFloatingPanelViewModel

        // Create AIImportViewModel linked to shared AppViewModel
        // Requirements: 6.1
        let sharedAIImportViewModel = AIImportViewModel(
            aiService: GeminiAIService(),
            dataService: sharedDataService,
            appViewModel: sharedAppViewModel
        )
        aiImportViewModel = sharedAIImportViewModel
        
        // Set dataService for app selector
        appSelectorController.dataService = sharedDataService
        
        // Setup local backup service for auto-sync
        localBackupService.setup(with: sharedModelContainer.mainContext)
        setupAutoBackup(dataService: sharedDataService)

        // Refresh keystroke overlay shortcut cache
        refreshKeystrokeOverlayCache(dataService: sharedDataService)
    }

    /// Refreshes the keystroke overlay shortcut cache from all apps.
    private func refreshKeystrokeOverlayCache(dataService: DataService) {
        var cache: [String: String] = [:]
        let apps = dataService.fetchApps()
        for app in apps {
            for shortcut in (app.shortcuts ?? []) {
                // Normalize keys to uppercase for matching
                let normalizedKeys = shortcut.keys.uppercased()
                cache[normalizedKeys] = shortcut.title
            }
        }
        KeystrokeOverlayController.shared.refreshShortcutCache(shortcuts: cache)
    }

    /// Shows the floating panel with current app shortcuts.
    /// The panel reflects the same selected app as the main window.
    /// Requirements: 4.2, 5.4
    private func showFloatingPanel() {
        guard let floatingPanelViewModel = floatingPanelViewModel else {
            // Try to initialize if not yet done
            initializeSharedViewModels()
            guard let vm = self.floatingPanelViewModel else { return }
            showFloatingPanelContent(with: vm)
            return
        }

        showFloatingPanelContent(with: floatingPanelViewModel)
    }

    /// Helper to show the floating panel content.
    private func showFloatingPanelContent(with viewModel: FloatingPanelViewModel) {
        let content = FloatingPanelContentView(
            viewModel: viewModel,
            onClose: { [floatingPanelController] in
                floatingPanelController.hidePanel()
            }
        )

        floatingPanelController.showPanel(with: content)
    }

    /// Refreshes the floating panel content if it's currently visible.
    /// This ensures the panel reflects the current selected app.
    /// Requirements: 3.2, 4.2
    private func refreshFloatingPanelIfVisible() {
        guard floatingPanelController.isVisible,
              let floatingPanelViewModel = floatingPanelViewModel else { return }

        let content = FloatingPanelContentView(
            viewModel: floatingPanelViewModel,
            onClose: { [floatingPanelController] in
                floatingPanelController.hidePanel()
            }
        )

        floatingPanelController.updateContent(with: content)
    }

    /// Sets up the app selector with callback
    private func setupAppSelector() {
        appSelectorController.onAppSelected = { [self] app in
            // Update selected app and show floating panel
            appViewModel?.selectedApp = app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showFloatingPanel()
            }
        }
    }
    
    /// Opens the AI Import sheet.
    /// Requirements: 5.5, 6.1
    private func openAIImport() {
        initializeSharedViewModels()

        // Bring main window to front first
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("ShortcutTracker") || $0.isKeyWindow }) {
            window.makeKeyAndOrderFront(nil)
        }

        showAIImportSheet = true
    }
    
    /// Sets up auto backup functionality
    private func setupAutoBackup(dataService: DataService) {
        // Handle external changes detected by file monitor
        localBackupService.onExternalChangesDetected = { [self] in
            Task { @MainActor in
                do {
                    try await localBackupService.importFromBackup(context: sharedModelContainer.mainContext)
                    // Refresh UI after import
                    appViewModel?.loadApps()
                    NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
                    print("Auto-imported from external backup changes")
                } catch {
                    print("Auto-import failed: \(error)")
                }
            }
        }
        
        // Auto backup when shortcuts change
        NotificationCenter.default.addObserver(
            forName: .shortcutsDidChange,
            object: nil,
            queue: .main
        ) { [self] _ in
            guard localBackupService.autoSyncEnabled else { return }
            Task {
                do {
                    let apps = dataService.fetchApps()
                    try await localBackupService.saveBackup(apps: apps)
                    print("Auto-backup completed")
                } catch {
                    print("Auto-backup failed: \(error)")
                }
            }
        }
        
        // Initial backup check - import if backup exists and is newer
        Task {
            if localBackupService.autoSyncEnabled && localBackupService.backupExists {
                do {
                    try await localBackupService.importFromBackup(context: sharedModelContainer.mainContext)
                    await MainActor.run {
                        appViewModel?.loadApps()
                    }
                    print("Initial backup import completed")
                } catch {
                    print("Initial backup import failed: \(error)")
                }
            }
        }
    }
}
