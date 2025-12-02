import Foundation

/// Available Gemini models
enum GeminiModel: String, CaseIterable {
    case gemini25Pro = "gemini-2.5-pro"
    case gemini25Flash = "gemini-2.5-flash"
    case gemini20Flash = "gemini-2.0-flash"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"

    var displayName: String {
        switch self {
        case .gemini25Pro: return "Gemini 2.5 Pro"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        case .gemini20Flash: return "Gemini 2.0 Flash"
        case .gemini15Pro: return "Gemini 1.5 Pro"
        case .gemini15Flash: return "Gemini 1.5 Flash"
        }
    }
}

/// Implementation of AIServiceProtocol using Google's Gemini API.
/// Extracts keyboard shortcuts from text using AI-powered analysis.
class GeminiAIService: AIServiceProtocol {
    
    // MARK: - Configuration
    
    /// The base API endpoint
    private let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
    
    /// The API key for authentication
    private var apiKey: String?
    
    /// URL session for network requests
    private let session: URLSession
    
    /// Request timeout interval in seconds
    private let timeoutInterval: TimeInterval = 60 * 5

    /// Last raw AI response for debugging
    var lastRawResponse: String?
    
    // MARK: - Initialization
    
    /// Creates a new GeminiAIService instance.
    /// - Parameter apiKey: Optional API key. If nil, will attempt to load from configuration.
    init(apiKey: String? = nil) {
        self.apiKey = apiKey ?? GeminiAIService.loadAPIKey()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - AIServiceProtocol
    
    func extractShortcuts(from text: String) async throws -> [ExtractedShortcut] {
        print("[GeminiAI] extractShortcuts called, text length: \(text.count)")
        
        // Reload API key each time to pick up any changes from settings
        let currentAPIKey = apiKey ?? GeminiAIService.loadAPIKey()
        
        guard let key = currentAPIKey, !key.isEmpty else {
            print("[GeminiAI] API key is missing")
            throw AIServiceError.apiKeyMissing
        }
        
        print("[GeminiAI] API key found, building request...")
        let request = try buildRequest(for: text, apiKey: key)
        
        print("[GeminiAI] Performing request...")
        let (data, response) = try await performRequest(request)
        
        print("[GeminiAI] Response received, validating...")
        try validateResponse(response, data: data)
        
        print("[GeminiAI] Parsing response...")
        return try parseResponse(data)
    }
    
    // MARK: - API Key Management
    
    /// Loads the API key from UserDefaults or environment.
    private static func loadAPIKey() -> String? {
        // First try UserDefaults
        if let key = UserDefaults.standard.string(forKey: "GeminiAPIKey"), !key.isEmpty {
            return key
        }
        
        // Then try environment variable
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }
        
        return nil
    }
    
    /// Sets the API key for this service instance and persists it.
    /// - Parameter key: The API key to set
    func setAPIKey(_ key: String) {
        self.apiKey = key
        UserDefaults.standard.set(key, forKey: "GeminiAPIKey")
    }
    
    /// Checks if an API key is configured.
    var hasAPIKey: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }
    
    // MARK: - Request Building
    
    /// Builds the API request with the prompt for shortcut extraction.
    private func buildRequest(for text: String, apiKey: String) throws -> URLRequest {
        let model = GeminiAIService.loadModel()
        let endpoint = "\(baseEndpoint)\(model.rawValue):generateContent"
        
        guard var urlComponents = URLComponents(string: endpoint) else {
            throw AIServiceError.invalidResponse
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw AIServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = buildPrompt(for: text)
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(parts: [GeminiPart(text: prompt)])
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        return request
    }

    /// Loads the selected model from UserDefaults
    static func loadModel() -> GeminiModel {
        if let modelString = UserDefaults.standard.string(forKey: "GeminiModel"),
           let model = GeminiModel(rawValue: modelString) {
            return model
        }
        return .gemini25Flash
    }

    /// Loads the custom prompt from UserDefaults
    static func loadCustomPrompt() -> String? {
        UserDefaults.standard.string(forKey: "GeminiCustomPrompt")
    }

    /// Default prompt template
    static let defaultPrompt = """
        Analyze the following text and extract all keyboard shortcuts mentioned. \
        For each shortcut, provide:
        1. title: A brief name for the action (e.g., "Save", "Copy")
        2. keys: The key combination using macOS symbols (⌘ for Command, ⇧ for Shift, ⌥ for Option, ⌃ for Control)
        3. description: A brief description of what the shortcut does (optional)
        4. category: A category like "File", "Edit", "View", "Navigation", "Format", "Tools" (optional)
        
        Return the results as a JSON array with objects containing these fields.
        If no shortcuts are found, return an empty array [].
        
        Example output format:
        [
            {"title": "Save", "keys": "⌘S", "description": "Save the current document", "category": "File"},
            {"title": "Copy", "keys": "⌘C", "description": "Copy selected text", "category": "Edit"}
        ]
        
        Text to analyze:
        ---
        {{TEXT}}
        ---
        
        Return only the JSON array, no additional text.
        """
    
    /// Builds the prompt for the Gemini API to extract shortcuts.
    private func buildPrompt(for text: String) -> String {
        let template = GeminiAIService.loadCustomPrompt() ?? GeminiAIService.defaultPrompt
        return template.replacingOccurrences(of: "{{TEXT}}", with: text)
    }
    
    // MARK: - Network Operations
    
    /// Performs the network request with error handling.
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw AIServiceError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw AIServiceError.networkError(error)
            default:
                throw AIServiceError.networkError(error)
            }
        } catch {
            throw AIServiceError.networkError(error)
        }
    }
    
    /// Validates the HTTP response.
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return // Success
        case 429:
            throw AIServiceError.rateLimitExceeded
        case 401, 403:
            throw AIServiceError.apiKeyMissing
        case 400:
            // Try to extract error message from response
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.parsingError("API Error: \(message)")
            }
            throw AIServiceError.invalidResponse
        default:
            // Try to extract error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.parsingError("API Error (\(httpResponse.statusCode)): \(message)")
            }
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - Response Parsing
    
    /// Parses the Gemini API response into ExtractedShortcut objects.
    private func parseResponse(_ data: Data) throws -> [ExtractedShortcut] {
        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            throw AIServiceError.parsingError("Failed to decode Gemini response: \(error.localizedDescription)")
        }
        
        // Extract the text content from the response
        guard let textContent = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw AIServiceError.parsingError("No text content in response")
        }

        // Save raw response for debugging
        lastRawResponse = textContent
        
        // Parse the JSON array from the text content
        return try parseShortcutsJSON(textContent)
    }
    
    /// Parses the JSON array of shortcuts from the AI response text.
    private func parseShortcutsJSON(_ text: String) throws -> [ExtractedShortcut] {
        // Try to extract JSON array from the text (in case there's extra text around it)
        let jsonText = extractJSONArray(from: text)
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIServiceError.parsingError("Failed to convert response to data")
        }
        
        let shortcutDTOs: [ShortcutDTO]
        do {
            shortcutDTOs = try JSONDecoder().decode([ShortcutDTO].self, from: jsonData)
        } catch {
            throw AIServiceError.parsingError("Failed to parse shortcuts JSON: \(error.localizedDescription)")
        }
        
        return shortcutDTOs.map { dto in
            ExtractedShortcut(
                title: dto.title,
                keys: dto.keys,
                description: dto.description,
                category: dto.category
            )
        }
    }
    
    /// Extracts a JSON array from text that might contain additional content.
    private func extractJSONArray(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it already starts with [, assume it's valid JSON
        if trimmed.hasPrefix("[") {
            return trimmed
        }
        
        // Try to find JSON array in the text
        if let startIndex = trimmed.firstIndex(of: "["),
           let endIndex = trimmed.lastIndex(of: "]") {
            return String(trimmed[startIndex...endIndex])
        }
        
        // Return empty array if no JSON found
        return "[]"
    }
}

// MARK: - API Request/Response Models

/// Request body for Gemini API
private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

private struct GeminiPart: Codable {
    let text: String
}

/// Response from Gemini API
private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent?
}

/// DTO for parsing shortcut JSON from AI response
private struct ShortcutDTO: Decodable {
    let title: String
    let keys: String
    let description: String?
    let category: String?
}
