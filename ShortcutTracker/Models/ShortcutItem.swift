import Foundation
import SwiftData

/// Represents a keyboard shortcut in the ShortcutTracker.
/// Each ShortcutItem belongs to a parent AppItem.
@Model
final class ShortcutItem {
    /// Unique identifier for the shortcut item
    var id: UUID = UUID()
    
    /// Display title of the shortcut (e.g., "Save", "Copy")
    var title: String = ""
    
    /// Key combination string (e.g., "⌘S", "⌘⇧S")
    var keys: String = ""
    
    /// Optional description of what the shortcut does
    var shortcutDescription: String?
    
    /// Optional category for organizing shortcuts (e.g., "File", "Edit")
    var category: String?
    
    /// Timestamp when the shortcut was created
    var createdAt: Date = Date()
    
    /// Timestamp when the shortcut was last modified
    var modifiedAt: Date = Date()
    
    /// The parent application this shortcut belongs to
    var app: AppItem?
    
    /// Creates a new ShortcutItem with the specified properties.
    /// - Parameters:
    ///   - title: The display title of the shortcut
    ///   - keys: The key combination string
    ///   - description: Optional description of the shortcut
    ///   - category: Optional category for organization
    init(title: String, keys: String, description: String? = nil, category: String? = nil) {
        self.title = title
        self.keys = keys
        self.shortcutDescription = description
        self.category = category
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
