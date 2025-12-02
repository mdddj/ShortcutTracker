import Foundation

/// Errors that can occur during AI service operations.
enum AIServiceError: Error, LocalizedError {
    /// The API key is missing or not configured
    case apiKeyMissing
    /// A network error occurred during the API call
    case networkError(Error)
    /// The API response was invalid or could not be parsed
    case invalidResponse
    /// An error occurred while parsing the extracted shortcuts
    case parsingError(String)
    /// The API rate limit has been exceeded
    case rateLimitExceeded
    /// The request timed out
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is missing. Please configure your API key in settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI service."
        case .parsingError(let message):
            return "Failed to parse shortcuts: \(message)"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}

/// Protocol defining the interface for AI services that extract shortcuts from text.
/// Implementations can use different AI providers (Gemini, OpenAI, etc.) while
/// maintaining a consistent interface for the rest of the application.
protocol AIServiceProtocol {
    /// Extracts keyboard shortcuts from the provided text using AI analysis.
    /// - Parameter text: The text content to analyze (e.g., article, documentation)
    /// - Returns: An array of extracted ShortcutItem objects
    /// - Throws: AIServiceError if extraction fails
    func extractShortcuts(from text: String) async throws -> [ExtractedShortcut]
}

/// A lightweight struct representing an extracted shortcut before it's persisted.
/// This avoids creating SwiftData model objects until the user confirms the import.
struct ExtractedShortcut: Identifiable, Equatable {
    let id: UUID
    let title: String
    let keys: String
    let description: String?
    let category: String?
    
    init(title: String, keys: String, description: String? = nil, category: String? = nil) {
        self.id = UUID()
        self.title = title
        self.keys = keys
        self.description = description
        self.category = category
    }
    
    /// Converts this extracted shortcut to a ShortcutItem for persistence.
    func toShortcutItem() -> ShortcutItem {
        ShortcutItem(
            title: title,
            keys: keys,
            description: description,
            category: category
        )
    }
}
