import Foundation

/// Available OpenAI compatible providers
enum OpenAIProvider: String, CaseIterable {
    case siliconFlow = "siliconflow"
    case openAI = "openai"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .siliconFlow: return "硅基流动 (SiliconFlow)"
        case .openAI: return "OpenAI"
        case .custom: return "Custom Endpoint"
        }
    }
    
    var defaultEndpoint: String {
        switch self {
        case .siliconFlow: return "https://api.siliconflow.cn/v1/chat/completions"
        case .openAI: return "https://api.openai.com/v1/chat/completions"
        case .custom: return ""
        }
    }
    
    var defaultModels: [String] {
        switch self {
        case .siliconFlow: return ["Qwen/Qwen2.5-7B-Instruct", "Qwen/Qwen2.5-32B-Instruct", "deepseek-ai/DeepSeek-V2.5"]
        case .openAI: return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo"]
        case .custom: return []
        }
    }
}

/// Implementation of AIServiceProtocol using OpenAI-compatible API.
/// Supports SiliconFlow, OpenAI, and custom endpoints.
class OpenAICompatibleService: AIServiceProtocol {
    
    // MARK: - Configuration Keys
    
    static let providerKey = "OpenAIProvider"
    static let apiKeyKey = "OpenAIAPIKey"
    static let endpointKey = "OpenAIEndpoint"
    static let modelKey = "OpenAIModel"
    static let customPromptKey = "OpenAICustomPrompt"
    
    // MARK: - Properties
    
    private var apiKey: String?
    private let session: URLSession
    private let timeoutInterval: TimeInterval = 60 * 5
    
    var lastRawResponse: String?
    
    // MARK: - Initialization
    
    init(apiKey: String? = nil) {
        self.apiKey = apiKey ?? Self.loadAPIKey()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - AIServiceProtocol
    
    func extractShortcuts(from text: String) async throws -> [ExtractedShortcut] {
        let currentAPIKey = apiKey ?? Self.loadAPIKey()
        
        guard let key = currentAPIKey, !key.isEmpty else {
            throw AIServiceError.apiKeyMissing
        }
        
        let request = try buildRequest(for: text, apiKey: key)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return try parseResponse(data)
    }
    
    // MARK: - Configuration
    
    static func loadProvider() -> OpenAIProvider {
        if let raw = UserDefaults.standard.string(forKey: providerKey),
           let provider = OpenAIProvider(rawValue: raw) {
            return provider
        }
        return .siliconFlow
    }
    
    static func loadAPIKey() -> String? {
        UserDefaults.standard.string(forKey: apiKeyKey)
    }
    
    static func loadEndpoint() -> String {
        if let endpoint = UserDefaults.standard.string(forKey: endpointKey), !endpoint.isEmpty {
            return endpoint
        }
        return loadProvider().defaultEndpoint
    }
    
    static func loadModel() -> String {
        if let model = UserDefaults.standard.string(forKey: modelKey), !model.isEmpty {
            return model
        }
        return loadProvider().defaultModels.first ?? "gpt-4o-mini"
    }
    
    static func loadCustomPrompt() -> String? {
        UserDefaults.standard.string(forKey: customPromptKey)
    }
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
        UserDefaults.standard.set(key, forKey: Self.apiKeyKey)
    }
    
    var hasAPIKey: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }
    
    // MARK: - Request Building
    
    private func buildRequest(for text: String, apiKey: String) throws -> URLRequest {
        let endpoint = Self.loadEndpoint()
        
        guard let url = URL(string: endpoint) else {
            throw AIServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = buildPrompt(for: text)
        let model = Self.loadModel()
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(role: "system", content: "You are a helpful assistant that extracts keyboard shortcuts from text. Always respond with valid JSON only."),
                OpenAIMessage(role: "user", content: prompt)
            ],
            temperature: 0.1
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
    
    static let defaultPrompt = GeminiAIService.defaultPrompt
    
    private func buildPrompt(for text: String) -> String {
        let template = Self.loadCustomPrompt() ?? Self.defaultPrompt
        return template.replacingOccurrences(of: "{{TEXT}}", with: text)
    }
    
    // MARK: - Network
    
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
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 429:
            throw AIServiceError.rateLimitExceeded
        case 401, 403:
            throw AIServiceError.apiKeyMissing
        default:
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIServiceError.parsingError("API Error (\(httpResponse.statusCode)): \(message)")
            }
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ data: Data) throws -> [ExtractedShortcut] {
        let openAIResponse: OpenAIResponse
        do {
            openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw AIServiceError.parsingError("Failed to decode response: \(error.localizedDescription)")
        }
        
        guard let textContent = openAIResponse.choices.first?.message.content else {
            throw AIServiceError.parsingError("No content in response")
        }
        
        lastRawResponse = textContent
        return try parseShortcutsJSON(textContent)
    }
    
    private func parseShortcutsJSON(_ text: String) throws -> [ExtractedShortcut] {
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
    
    private func extractJSONArray(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("[") {
            return trimmed
        }
        
        if let startIndex = trimmed.firstIndex(of: "["),
           let endIndex = trimmed.lastIndex(of: "]") {
            return String(trimmed[startIndex...endIndex])
        }
        
        return "[]"
    }
}

// MARK: - Request/Response Models

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
}

private struct ShortcutDTO: Decodable {
    let title: String
    let keys: String
    let description: String?
    let category: String?
}
