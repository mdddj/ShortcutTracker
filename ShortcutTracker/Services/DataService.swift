import Foundation
import SwiftData

/// Service class responsible for all data persistence operations.
/// Provides CRUD operations for AppItem and ShortcutItem using SwiftData.
@Observable
class DataService {
    /// The SwiftData model context for persistence operations
    private var modelContext: ModelContext
    
    /// Creates a new DataService with the specified model context.
    /// - Parameter modelContext: The SwiftData ModelContext to use for persistence
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - App Operations
    
    /// Fetches all AppItems from storage, sorted by name.
    /// - Returns: An array of all persisted AppItems
    func fetchApps() -> [AppItem] {
        let descriptor = FetchDescriptor<AppItem>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching apps: \(error)")
            return []
        }
    }
    
    /// Adds a new AppItem to storage.
    /// - Parameter app: The AppItem to persist
    func addApp(_ app: AppItem) {
        modelContext.insert(app)
        saveContext()
    }
    
    /// Deletes an AppItem and all its associated shortcuts from storage.
    /// The cascade delete rule on the relationship handles shortcut deletion.
    /// - Parameter app: The AppItem to delete
    func deleteApp(_ app: AppItem) {
        modelContext.delete(app)
        saveContext()
    }

    
    /// Updates an existing AppItem in storage.
    /// - Parameter app: The AppItem with updated properties
    func updateApp(_ app: AppItem) {
        app.modifiedAt = Date()
        saveContext()
    }
    
    // MARK: - Shortcut Operations
    
    /// Adds a new ShortcutItem to the specified AppItem.
    /// - Parameters:
    ///   - shortcut: The ShortcutItem to add
    ///   - app: The parent AppItem to associate the shortcut with
    func addShortcut(_ shortcut: ShortcutItem, to app: AppItem) {
        shortcut.app = app
        app.shortcuts?.append(shortcut)
        app.modifiedAt = Date()
        modelContext.insert(shortcut)
        saveContext()
    }
    
    /// Deletes a ShortcutItem from storage.
    /// - Parameter shortcut: The ShortcutItem to delete
    func deleteShortcut(_ shortcut: ShortcutItem) {
        if let app = shortcut.app {
            app.shortcuts?.removeAll { $0.id == shortcut.id }
            app.modifiedAt = Date()
        }
        modelContext.delete(shortcut)
        saveContext()
    }
    
    /// Updates an existing ShortcutItem in storage.
    /// - Parameter shortcut: The ShortcutItem with updated properties
    func updateShortcut(_ shortcut: ShortcutItem) {
        shortcut.modifiedAt = Date()
        if let app = shortcut.app {
            app.modifiedAt = Date()
        }
        saveContext()
    }
    
    // MARK: - Private Helpers
    
    /// Saves the current model context, logging any errors.
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Preview Helper
    
    /// A preview instance of DataService for SwiftUI previews.
    @MainActor
    static var preview: DataService {
        let schema = Schema([AppItem.self, ShortcutItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return DataService(modelContext: container.mainContext)
    }
}
