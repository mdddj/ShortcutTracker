import Foundation
import SwiftData

/// Represents an application in the ShortcutTracker.
/// Each AppItem contains a collection of shortcuts associated with that application.
@Model
final class AppItem {
    /// Unique identifier for the app item
    var id: UUID = UUID()
    
    /// Display name of the application
    var name: String = ""
    
    /// Optional path to the application's icon
    var iconPath: String?
    
    /// Timestamp when the app item was created
    var createdAt: Date = Date()
    
    /// Timestamp when the app item was last modified
    var modifiedAt: Date = Date()
    
    /// Collection of shortcuts associated with this application.
    /// Uses cascade delete rule to remove all shortcuts when the app is deleted.
    @Relationship(deleteRule: .cascade, inverse: \ShortcutItem.app)
    var shortcuts: [ShortcutItem]? = []
    
    /// Creates a new AppItem with the specified name and optional icon path.
    /// - Parameters:
    ///   - name: The display name of the application
    ///   - iconPath: Optional path to the application's icon
    init(name: String, iconPath: String? = nil) {
        self.name = name
        self.iconPath = iconPath
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
