import Foundation

/// Represents macOS keyboard modifier and special key symbols.
/// Used for displaying and formatting keyboard shortcuts.
/// Requirements: 2.1
enum KeySymbol: String, CaseIterable, Sendable {
    // Modifier keys
    case command = "⌘"
    case shift = "⇧"
    case option = "⌥"
    case control = "⌃"
    case capsLock = "⇪"
    
    // Special keys
    case escape = "⎋"
    case `return` = "↩"
    case delete = "⌫"
    case forwardDelete = "⌦"
    case tab = "⇥"
    case space = "␣"
    
    // Arrow keys
    case arrowUp = "↑"
    case arrowDown = "↓"
    case arrowLeft = "←"
    case arrowRight = "→"
    
    // Function keys
    case fn = "fn"
    
    /// Human-readable name for the key symbol
    var displayName: String {
        switch self {
        case .command: return "Command"
        case .shift: return "Shift"
        case .option: return "Option"
        case .control: return "Control"
        case .capsLock: return "Caps Lock"
        case .escape: return "Escape"
        case .return: return "Return"
        case .delete: return "Delete"
        case .forwardDelete: return "Forward Delete"
        case .tab: return "Tab"
        case .space: return "Space"
        case .arrowUp: return "Up"
        case .arrowDown: return "Down"
        case .arrowLeft: return "Left"
        case .arrowRight: return "Right"
        case .fn: return "Function"
        }
    }
    
    /// All modifier key symbols
    static var modifiers: [KeySymbol] {
        [.control, .option, .shift, .command]
    }
    
    /// Check if this symbol is a modifier key
    var isModifier: Bool {
        Self.modifiers.contains(self)
    }
}

// MARK: - Key Combination Formatting

/// Utility for building and formatting key combinations
enum KeyCombinationFormatter {
    
    /// Builds a key combination string from modifier flags and a main key.
    /// Modifiers are ordered: Control, Option, Shift, Command (standard macOS order)
    /// - Parameters:
    ///   - control: Include Control modifier
    ///   - option: Include Option modifier
    ///   - shift: Include Shift modifier
    ///   - command: Include Command modifier
    ///   - mainKey: The main key (e.g., "S", "C", "↩")
    /// - Returns: Formatted key combination string (e.g., "⌃⌥⇧⌘S")
    static func buildKeyString(
        control: Bool = false,
        option: Bool = false,
        shift: Bool = false,
        command: Bool = false,
        mainKey: String
    ) -> String {
        var result = ""
        if control { result += KeySymbol.control.rawValue }
        if option { result += KeySymbol.option.rawValue }
        if shift { result += KeySymbol.shift.rawValue }
        if command { result += KeySymbol.command.rawValue }
        result += mainKey
        return result
    }
    
    /// Parses a key combination string into its components.
    /// - Parameter keyString: The key combination string (e.g., "⌘⇧S")
    /// - Returns: Tuple containing modifier states and the main key
    static func parseKeyString(_ keyString: String) -> (
        control: Bool,
        option: Bool,
        shift: Bool,
        command: Bool,
        mainKey: String
    ) {
        var remaining = keyString
        var control = false
        var option = false
        var shift = false
        var command = false
        
        if remaining.contains(KeySymbol.control.rawValue) {
            control = true
            remaining = remaining.replacingOccurrences(of: KeySymbol.control.rawValue, with: "")
        }
        if remaining.contains(KeySymbol.option.rawValue) {
            option = true
            remaining = remaining.replacingOccurrences(of: KeySymbol.option.rawValue, with: "")
        }
        if remaining.contains(KeySymbol.shift.rawValue) {
            shift = true
            remaining = remaining.replacingOccurrences(of: KeySymbol.shift.rawValue, with: "")
        }
        if remaining.contains(KeySymbol.command.rawValue) {
            command = true
            remaining = remaining.replacingOccurrences(of: KeySymbol.command.rawValue, with: "")
        }
        
        return (control, option, shift, command, remaining)
    }
    
    /// Converts text-based key notation to symbol notation.
    /// Handles formats like "Cmd+Shift+S", "Command + S", "Ctrl+Alt+Delete"
    /// - Parameter text: Text representation of key combination
    /// - Returns: Symbol-based key combination string
    static func textToSymbols(_ text: String) -> String {
        var result = text
        
        // Normalize separators
        result = result.replacingOccurrences(of: " + ", with: "+")
        result = result.replacingOccurrences(of: "- ", with: "-")
        
        // Replace text modifiers with symbols (case insensitive)
        let replacements: [(pattern: String, symbol: String)] = [
            ("cmd", KeySymbol.command.rawValue),
            ("command", KeySymbol.command.rawValue),
            ("ctrl", KeySymbol.control.rawValue),
            ("control", KeySymbol.control.rawValue),
            ("opt", KeySymbol.option.rawValue),
            ("option", KeySymbol.option.rawValue),
            ("alt", KeySymbol.option.rawValue),
            ("shift", KeySymbol.shift.rawValue),
            ("return", KeySymbol.return.rawValue),
            ("enter", KeySymbol.return.rawValue),
            ("esc", KeySymbol.escape.rawValue),
            ("escape", KeySymbol.escape.rawValue),
            ("tab", KeySymbol.tab.rawValue),
            ("delete", KeySymbol.delete.rawValue),
            ("backspace", KeySymbol.delete.rawValue),
            ("space", KeySymbol.space.rawValue),
            ("up", KeySymbol.arrowUp.rawValue),
            ("down", KeySymbol.arrowDown.rawValue),
            ("left", KeySymbol.arrowLeft.rawValue),
            ("right", KeySymbol.arrowRight.rawValue),
        ]
        
        for (pattern, symbol) in replacements {
            // Case insensitive replacement
            let regex = try? NSRegularExpression(pattern: "\\b\(pattern)\\b", options: .caseInsensitive)
            if let regex = regex {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: symbol
                )
            }
        }
        
        // Remove separators
        result = result.replacingOccurrences(of: "+", with: "")
        result = result.replacingOccurrences(of: "-", with: "")
        result = result.replacingOccurrences(of: " ", with: "")
        
        return result
    }
    
    /// Converts symbol notation to human-readable text.
    /// - Parameter symbols: Symbol-based key combination (e.g., "⌘⇧S")
    /// - Returns: Human-readable text (e.g., "Command + Shift + S")
    static func symbolsToText(_ symbols: String) -> String {
        var parts: [String] = []
        var remaining = symbols
        
        // Extract modifiers in order
        for modifier in KeySymbol.modifiers {
            if remaining.contains(modifier.rawValue) {
                parts.append(modifier.displayName)
                remaining = remaining.replacingOccurrences(of: modifier.rawValue, with: "")
            }
        }
        
        // Check for special keys
        for symbol in KeySymbol.allCases where !symbol.isModifier {
            if remaining.contains(symbol.rawValue) {
                parts.append(symbol.displayName)
                remaining = remaining.replacingOccurrences(of: symbol.rawValue, with: "")
            }
        }
        
        // Add remaining characters (the main key)
        if !remaining.isEmpty {
            parts.append(remaining)
        }
        
        return parts.joined(separator: " + ")
    }
}
