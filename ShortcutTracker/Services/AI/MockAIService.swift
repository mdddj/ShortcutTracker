import Foundation

/// A mock implementation of AIServiceProtocol for testing and preview purposes.
/// Parses text for common keyboard shortcut patterns without requiring an actual AI service.
class MockAIService: AIServiceProtocol {
    
    // MARK: - Shortcut Pattern Definitions
    
    /// Regular expression patterns for matching various shortcut formats
    private let patterns: [(pattern: String, options: NSRegularExpression.Options)] = [
        // Pattern: "Cmd+Shift+S" or "Ctrl+Alt+Delete"
        (#"(Cmd|Ctrl|Alt|Shift|Option|Command|Control)(\s*\+\s*(Cmd|Ctrl|Alt|Shift|Option|Command|Control|[A-Z0-9]))+\b"#, [.caseInsensitive]),
        // Pattern: "⌘⇧S" or "⌃⌥⌘A"
        (#"[⌘⇧⌥⌃]+[A-Z0-9↑↓←→⎋↩⌫⇥␣]"#, []),
        // Pattern: "Command + Shift + S"
        (#"(Command|Control|Option|Shift)(\s*\+\s*(Command|Control|Option|Shift|[A-Z0-9]))+\b"#, [.caseInsensitive])
    ]
    
    /// Mapping from text representations to symbol representations
    private let keyMappings: [String: String] = [
        "cmd": "⌘", "command": "⌘",
        "ctrl": "⌃", "control": "⌃",
        "alt": "⌥", "option": "⌥",
        "shift": "⇧",
        "return": "↩", "enter": "↩",
        "delete": "⌫", "backspace": "⌫",
        "tab": "⇥",
        "space": "␣",
        "esc": "⎋", "escape": "⎋",
        "up": "↑", "down": "↓", "left": "←", "right": "→"
    ]
    
    // MARK: - AIServiceProtocol
    
    func extractShortcuts(from text: String) async throws -> [ExtractedShortcut] {
        var extractedShortcuts: [ExtractedShortcut] = []
        var seenKeys = Set<String>()
        
        // Split text into lines for context extraction
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let shortcuts = extractShortcutsFromLine(line)
            for shortcut in shortcuts {
                // Avoid duplicates
                if !seenKeys.contains(shortcut.keys) {
                    seenKeys.insert(shortcut.keys)
                    extractedShortcuts.append(shortcut)
                }
            }
        }
        
        return extractedShortcuts
    }
    
    // MARK: - Private Methods
    
    /// Extracts shortcuts from a single line of text.
    private func extractShortcutsFromLine(_ line: String) -> [ExtractedShortcut] {
        var shortcuts: [ExtractedShortcut] = []
        
        for (pattern, options) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                continue
            }
            
            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            
            for match in matches {
                guard let matchRange = Range(match.range, in: line) else { continue }
                let matchedText = String(line[matchRange])
                
                let normalizedKeys = normalizeKeys(matchedText)
                let title = extractTitle(from: line, shortcutMatch: matchRange)
                let category = extractCategory(from: line)
                
                let shortcut = ExtractedShortcut(
                    title: title,
                    keys: normalizedKeys,
                    description: nil,
                    category: category
                )
                shortcuts.append(shortcut)
            }
        }
        
        return shortcuts
    }
    
    /// Normalizes key combinations to use standard macOS symbols.
    private func normalizeKeys(_ keys: String) -> String {
        // If already using symbols, return as-is
        if keys.contains("⌘") || keys.contains("⇧") || keys.contains("⌥") || keys.contains("⌃") {
            return keys
        }
        
        // Split by + and normalize each part
        let parts = keys.components(separatedBy: "+")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        var result = ""
        var regularKey = ""
        
        for part in parts {
            if let symbol = keyMappings[part] {
                result += symbol
            } else if part.count == 1 {
                regularKey = part.uppercased()
            } else {
                regularKey = part.uppercased()
            }
        }
        
        return result + regularKey
    }
    
    /// Attempts to extract a title/description from the context around the shortcut.
    private func extractTitle(from line: String, shortcutMatch: Range<String.Index>) -> String {
        // Try to find text before the shortcut that might be a title
        let beforeShortcut = String(line[..<shortcutMatch.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        
        // Common patterns: "Save: Cmd+S" or "Save - Cmd+S" or "Save (Cmd+S)"
        let separators = [":", "-", "–", "—", "(", "["]
        
        for separator in separators {
            if let separatorIndex = beforeShortcut.lastIndex(of: Character(separator)) {
                let title = String(beforeShortcut[..<separatorIndex])
                    .trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && title.count < 50 {
                    return title
                }
            }
        }
        
        // If no clear title found, try text after the shortcut
        let afterShortcut = String(line[shortcutMatch.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        
        for separator in separators {
            if afterShortcut.hasPrefix(String(separator)) {
                let remaining = String(afterShortcut.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                let words = remaining.components(separatedBy: .whitespaces)
                let title = words.prefix(5).joined(separator: " ")
                if !title.isEmpty && title.count < 50 {
                    return title
                }
            }
        }
        
        // Default to "Shortcut" if no title found
        return "Shortcut"
    }
    
    /// Attempts to extract a category from the line context.
    private func extractCategory(from line: String) -> String? {
        let lowercaseLine = line.lowercased()
        
        // Common category keywords
        let categories: [String: [String]] = [
            "File": ["file", "save", "open", "new", "close", "export", "import", "print"],
            "Edit": ["edit", "copy", "paste", "cut", "undo", "redo", "select", "find", "replace"],
            "View": ["view", "zoom", "window", "panel", "sidebar", "toolbar", "fullscreen"],
            "Navigation": ["navigate", "go to", "jump", "move", "scroll", "next", "previous"],
            "Format": ["format", "font", "style", "bold", "italic", "underline", "align"],
            "Tools": ["tool", "debug", "build", "run", "test", "compile"],
            "Help": ["help", "documentation", "about"]
        ]
        
        for (category, keywords) in categories {
            for keyword in keywords {
                if lowercaseLine.contains(keyword) {
                    return category
                }
            }
        }
        
        return nil
    }
}
