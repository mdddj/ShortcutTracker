import AppKit
import Foundation

/// Represents the current state of the AI import process
enum AIImportState: Equatable {
    case idle
    case loading
    case loaded([ExtractedShortcut])
    case error(String)
    
    static func == (lhs: AIImportState, rhs: AIImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsShortcuts), .loaded(let rhsShortcuts)):
            return lhsShortcuts == rhsShortcuts
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// ViewModel for managing AI-powered shortcut extraction from text.
/// Handles the import workflow: text input -> AI extraction -> preview -> confirm import.
/// Requirements: 6.1, 6.2, 6.3
@Observable
class AIImportViewModel {
    /// The input text to analyze for shortcuts
    var inputText: String = ""
    
    /// The current state of the import process
    var state: AIImportState = .idle

    /// The raw AI response for debugging
    var rawAIResponse: String?
    
    /// The data service for persisting imported shortcuts
    let dataService: DataService
    
    /// Reference to the app view model for accessing selected app
    weak var appViewModel: AppViewModel?

    /// All available apps for selection
    var availableApps: [AppItem] {
        dataService.fetchApps()
    }
    
    /// Gets the current AI service based on user settings
    private var currentAIService: AIServiceProtocol {
        let serviceType = UserDefaults.standard.string(forKey: "AIServiceType") ?? "gemini"
        if serviceType == "openai" {
            return OpenAICompatibleService()
        }
        return GeminiAIService()
    }
    
    /// Creates a new AIImportViewModel with the specified dependencies.
    /// - Parameters:
    ///   - dataService: The data service for persistence
    ///   - appViewModel: The app view model for selected app access
    init(dataService: DataService, appViewModel: AppViewModel) {
        self.dataService = dataService
        self.appViewModel = appViewModel
    }
    
    /// Legacy initializer for compatibility
    init(aiService: AIServiceProtocol, dataService: DataService, appViewModel: AppViewModel) {
        self.dataService = dataService
        self.appViewModel = appViewModel
    }

    /// Select a different app for import
    func selectApp(_ app: AppItem) {
        appViewModel?.selectedApp = app
    }

    
    // MARK: - Computed Properties
    
    /// Whether the view is currently loading
    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }
    
    /// The extracted shortcuts if available
    var extractedShortcuts: [ExtractedShortcut] {
        if case .loaded(let shortcuts) = state {
            return shortcuts
        }
        return []
    }
    
    /// The error message if an error occurred
    var errorMessage: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }
    
    /// Whether the extract button should be enabled
    var canExtract: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    /// Whether the confirm import button should be enabled
    var canConfirmImport: Bool {
        !extractedShortcuts.isEmpty && appViewModel?.selectedApp != nil
    }
    
    /// The name of the currently selected app
    var selectedAppName: String? {
        appViewModel?.selectedApp?.name
    }
    
    // MARK: - Public Methods
    
    /// Extracts shortcuts from the input text using the AI service.
    /// Requirements: 6.1, 6.2
    @MainActor
    func extractShortcuts() async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[AIImport] extractShortcuts called, text length: \(trimmedText.count)")
        guard !trimmedText.isEmpty else {
            print("[AIImport] Text is empty, returning")
            return
        }
        
        state = .loading
        print("[AIImport] State set to loading")
        
        let aiService = currentAIService
        
        do {
            let shortcuts = try await aiService.extractShortcuts(from: trimmedText)
            print("[AIImport] Extracted \(shortcuts.count) shortcuts")
            // Save raw response if available
            if let geminiService = aiService as? GeminiAIService {
                rawAIResponse = geminiService.lastRawResponse
            } else if let openAIService = aiService as? OpenAICompatibleService {
                rawAIResponse = openAIService.lastRawResponse
            }
            state = .loaded(shortcuts)
        } catch let error as AIServiceError {
            print("[AIImport] AIServiceError: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        } catch {
            print("[AIImport] Unexpected error: \(error.localizedDescription)")
            state = .error("An unexpected error occurred: \(error.localizedDescription)")
        }
    }
    
    /// Confirms the import and adds all extracted shortcuts to the selected app.
    /// Requirements: 6.3
    func confirmImport() {
        guard let selectedApp = appViewModel?.selectedApp else { return }
        guard case .loaded(let shortcuts) = state else { return }
        
        for extractedShortcut in shortcuts {
            let shortcutItem = extractedShortcut.toShortcutItem()
            dataService.addShortcut(shortcutItem, to: selectedApp)
        }
        
        // Notify that shortcuts have changed
        NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
        
        // Reset state after successful import
        reset()
    }
    
    /// Resets the view model to its initial state.
    func reset() {
        inputText = ""
        state = .idle
    }
    
    /// Clears the current error and returns to idle state.
    func clearError() {
        if case .error = state {
            state = .idle
        }
    }
    
    /// Removes a shortcut from the extracted list before import.
    /// - Parameter shortcut: The shortcut to remove
    func removeExtractedShortcut(_ shortcut: ExtractedShortcut) {
        if case .loaded(var shortcuts) = state {
            shortcuts.removeAll { $0.id == shortcut.id }
            if shortcuts.isEmpty {
                state = .idle
            } else {
                state = .loaded(shortcuts)
            }
        }
    }

    /// Get JSON representation of extracted shortcuts for copying
    var extractedShortcutsJSON: String {
        guard case .loaded(let shortcuts) = state else { return "[]" }
        let dicts = shortcuts.map { shortcut -> [String: Any] in
            var dict: [String: Any] = [
                "title": shortcut.title,
                "keys": shortcut.keys
            ]
            if let desc = shortcut.description { dict["description"] = desc }
            if let cat = shortcut.category { dict["category"] = cat }
            return dict
        }
        if let data = try? JSONSerialization.data(withJSONObject: dicts, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }

    /// Copy text to clipboard
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
