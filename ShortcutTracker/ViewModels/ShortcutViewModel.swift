import Foundation
import SwiftData

/// Sort options for the shortcut list
enum ShortcutSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case modifiedAt = "Modified"
    
    var id: String { rawValue }
}

/// ViewModel for managing shortcuts within a selected application.
/// Handles shortcut CRUD operations, sorting, and filtering.
/// Requirements: 2.2, 2.4, 2.5, 2.6, 2.7
@Observable
class ShortcutViewModel {
    /// The current search text for filtering shortcuts
    var searchText: String = ""
    
    /// The current sort option
    var sortOption: ShortcutSortOption = .name
    
    /// The data service for persistence operations
    private let dataService: DataService
    
    /// Reference to the app view model for accessing selected app
    private weak var appViewModel: AppViewModel?
    
    /// Creates a new ShortcutViewModel with the specified dependencies.
    /// - Parameters:
    ///   - dataService: The DataService to use for persistence
    ///   - appViewModel: The AppViewModel to observe for selected app changes
    init(dataService: DataService, appViewModel: AppViewModel) {
        self.dataService = dataService
        self.appViewModel = appViewModel
    }
    
    // MARK: - Computed Properties
    
    /// Returns the shortcuts for the currently selected app, filtered and sorted.
    var shortcuts: [ShortcutItem] {
        guard let selectedApp = appViewModel?.selectedApp else {
            return []
        }
        
        var result = selectedApp.shortcuts
        
        // Apply search filter
        if !searchText.isEmpty {
            result = filterShortcuts(result ?? [], by: searchText)
        }
        
        // Apply sorting
        result = sortShortcuts(result ?? [], by: sortOption)
        
        return result ?? []
    }

    
    // MARK: - Public Methods
    
    /// Adds a new shortcut to the currently selected application.
    /// - Parameters:
    ///   - title: The title of the shortcut
    ///   - keys: The key combination string
    ///   - description: Optional description of the shortcut
    ///   - category: Optional category for organization
    /// Requirements: 2.2
    func addShortcut(title: String, keys: String, description: String? = nil, category: String? = nil) {
        guard let selectedApp = appViewModel?.selectedApp else { return }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKeys = keys.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty, !trimmedKeys.isEmpty else { return }
        
        let newShortcut = ShortcutItem(
            title: trimmedTitle,
            keys: trimmedKeys,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        dataService.addShortcut(newShortcut, to: selectedApp)
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
    }
    
    /// Edits an existing shortcut with new values.
    /// - Parameters:
    ///   - shortcut: The shortcut to edit
    ///   - title: The new title
    ///   - keys: The new key combination
    ///   - description: The new description
    ///   - category: The new category
    /// Requirements: 2.4
    func editShortcut(_ shortcut: ShortcutItem, title: String, keys: String, description: String?, category: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKeys = keys.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty, !trimmedKeys.isEmpty else { return }
        
        shortcut.title = trimmedTitle
        shortcut.keys = trimmedKeys
        shortcut.shortcutDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        shortcut.category = category?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        dataService.updateShortcut(shortcut)
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
    }
    
    /// Deletes the specified shortcut.
    /// - Parameter shortcut: The shortcut to delete
    /// Requirements: 2.5
    func deleteShortcut(_ shortcut: ShortcutItem) {
        dataService.deleteShortcut(shortcut)
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
    }

    
    // MARK: - Sorting and Filtering
    
    /// Sorts shortcuts by the specified criteria.
    /// - Parameters:
    ///   - shortcuts: The shortcuts to sort
    ///   - option: The sort option to apply
    /// - Returns: The sorted array of shortcuts
    /// Requirements: 2.6
    func sortShortcuts(_ shortcuts: [ShortcutItem], by option: ShortcutSortOption) -> [ShortcutItem] {
        switch option {
        case .name:
            return shortcuts.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .modifiedAt:
            return shortcuts.sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }
    
    /// Filters shortcuts by the search query.
    /// Matches against title, keys, and description.
    /// - Parameters:
    ///   - shortcuts: The shortcuts to filter
    ///   - query: The search query
    /// - Returns: The filtered array of shortcuts
    /// Requirements: 2.7
    func filterShortcuts(_ shortcuts: [ShortcutItem], by query: String) -> [ShortcutItem] {
        let lowercasedQuery = query.lowercased()
        
        return shortcuts.filter { shortcut in
            shortcut.title.lowercased().contains(lowercasedQuery) ||
            shortcut.keys.lowercased().contains(lowercasedQuery) ||
            (shortcut.shortcutDescription?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    /// Clears the current search text.
    func clearSearch() {
        searchText = ""
    }
    
    /// Sets the sort option.
    /// - Parameter option: The new sort option
    func setSortOption(_ option: ShortcutSortOption) {
        sortOption = option
    }
}
