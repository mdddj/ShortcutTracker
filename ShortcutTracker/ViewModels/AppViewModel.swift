import Foundation
import SwiftData
import Combine

/// ViewModel for managing the application list in ShortcutTracker.
/// Handles app selection, creation, deletion, and renaming operations.
/// Posts notifications when selection changes for state synchronization.
/// Requirements: 1.2, 1.4, 1.5, 1.6, 3.2, 4.2, 5.2
@Observable
class AppViewModel {
    /// The currently selected application
    /// Posts notification when changed for state synchronization
    /// Requirements: 3.2, 4.2, 5.2
    var selectedApp: AppItem? {
        didSet {
            // Post notification for state synchronization across windows
            NotificationCenter.default.post(name: .selectedAppChanged, object: selectedApp)
        }
    }
    
    /// List of all applications
    var apps: [AppItem] = []
    
    /// The data service for persistence operations
    private let dataService: DataService
    
    /// Creates a new AppViewModel with the specified data service.
    /// - Parameter dataService: The DataService to use for persistence
    init(dataService: DataService) {
        self.dataService = dataService
        loadApps()
    }
    
    // MARK: - Public Methods
    
    /// Loads all applications from storage.
    /// Requirements: 1.6
    func loadApps() {
        apps = dataService.fetchApps()
    }
    
    /// Adds a new application with the specified name.
    /// - Parameter name: The name of the application to create
    /// Requirements: 1.2
    func addApp(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newApp = AppItem(name: trimmedName)
        dataService.addApp(newApp)
        loadApps()
        selectedApp = newApp
    }

    
    /// Adds a new application with the specified name and icon path.
    /// - Parameters:
    ///   - name: The name of the application to create
    ///   - iconPath: Optional path to the application's icon
    /// Requirements: 1.2
    func addApp(name: String, iconPath: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newApp = AppItem(name: trimmedName, iconPath: iconPath)
        dataService.addApp(newApp)
        loadApps()
        selectedApp = newApp
    }
    
    /// Deletes the specified application and all its associated shortcuts.
    /// - Parameter app: The application to delete
    /// Requirements: 1.4
    func deleteApp(_ app: AppItem) {
        // Clear selection if deleting the selected app
        if selectedApp?.id == app.id {
            selectedApp = nil
        }
        
        dataService.deleteApp(app)
        loadApps()
    }
    
    /// Renames the specified application.
    /// - Parameters:
    ///   - app: The application to rename
    ///   - newName: The new name for the application
    /// Requirements: 1.5
    func renameApp(_ app: AppItem, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        app.name = trimmedName
        dataService.updateApp(app)
        loadApps()
    }
    
    /// Updates the specified application with new name and icon.
    /// - Parameters:
    ///   - app: The application to update
    ///   - name: The new name for the application
    ///   - iconPath: The new icon path for the application
    func updateApp(_ app: AppItem, name: String, iconPath: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        app.name = trimmedName
        app.iconPath = iconPath
        app.modifiedAt = Date()
        dataService.updateApp(app)
        loadApps()
    }
    
    /// Selects the specified application.
    /// - Parameter app: The application to select, or nil to clear selection
    func selectApp(_ app: AppItem?) {
        selectedApp = app
    }
}
