import SwiftUI

// MARK: - View Extensions

extension View {
    /// Applies a card-style background with rounded corners and subtle border.
    func cardStyle() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
    
    /// Applies hover effect with scale and background change.
    /// - Parameter isHovered: Binding to track hover state
    func hoverEffect(isHovered: Binding<Bool>) -> some View {
        self
            .scaleEffect(isHovered.wrappedValue ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered.wrappedValue)
            .onHover { hovering in
                isHovered.wrappedValue = hovering
            }
    }
    
    /// Applies a key badge style for displaying keyboard shortcuts.
    func keyBadgeStyle() -> some View {
        self
            .font(.system(.body, design: .monospaced))
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
            )
            .foregroundStyle(Color.accentColor)
    }
    
    /// Applies a category tag style.
    func categoryTagStyle() -> some View {
        self
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
            )
            .foregroundStyle(.secondary)
    }
}

// MARK: - String Extensions for Key Parsing

extension String {
    /// Extracts keyboard shortcuts from text.
    /// Recognizes formats like "Cmd+S", "⌘S", "Command + Shift + S", etc.
    /// Requirements: 6.5
    func extractShortcuts() -> [String] {
        var shortcuts: [String] = []
        
        // Pattern for symbol-based shortcuts (e.g., ⌘⇧S, ⌃⌥A)
        let symbolPattern = "[⌘⇧⌥⌃]+[A-Za-z0-9↩⎋⌫⇥↑↓←→]+"
        
        // Pattern for text-based shortcuts (e.g., Cmd+S, Ctrl+Alt+Delete)
        let textPattern = "(?:(?:Cmd|Command|Ctrl|Control|Alt|Opt|Option|Shift)\\s*[+\\-]\\s*)+[A-Za-z0-9]+"
        
        // Find symbol-based shortcuts
        if let regex = try? NSRegularExpression(pattern: symbolPattern, options: []) {
            let matches = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in: self))
            for match in matches {
                if let range = Range(match.range, in: self) {
                    shortcuts.append(String(self[range]))
                }
            }
        }
        
        // Find text-based shortcuts
        if let regex = try? NSRegularExpression(pattern: textPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in: self))
            for match in matches {
                if let range = Range(match.range, in: self) {
                    let shortcut = String(self[range])
                    // Convert to symbols
                    let symbolized = KeyCombinationFormatter.textToSymbols(shortcut)
                    if !shortcuts.contains(symbolized) {
                        shortcuts.append(symbolized)
                    }
                }
            }
        }
        
        return shortcuts
    }
    
    /// Checks if the string represents a valid key combination.
    var isValidKeyCombination: Bool {
        guard !self.isEmpty else { return false }
        
        let parsed = KeyCombinationFormatter.parseKeyString(self)
        
        // Must have at least one modifier or be a special key
        let hasModifier = parsed.control || parsed.option || parsed.shift || parsed.command
        let hasMainKey = !parsed.mainKey.isEmpty
        
        // Valid if has modifier + main key, or is a special key alone
        if hasModifier && hasMainKey {
            return true
        }
        
        // Check if it's a valid special key alone (like F1-F12, Escape, etc.)
        let specialKeys = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
                          KeySymbol.escape.rawValue, KeySymbol.return.rawValue, KeySymbol.delete.rawValue]
        return specialKeys.contains(parsed.mainKey)
    }
    
    /// Normalizes a key combination string to standard format.
    /// Ensures modifiers are in correct order: Control, Option, Shift, Command
    var normalizedKeyCombination: String {
        let parsed = KeyCombinationFormatter.parseKeyString(self)
        return KeyCombinationFormatter.buildKeyString(
            control: parsed.control,
            option: parsed.option,
            shift: parsed.shift,
            command: parsed.command,
            mainKey: parsed.mainKey
        )
    }
    
    /// Returns the human-readable version of a key combination.
    var humanReadableKeys: String {
        KeyCombinationFormatter.symbolsToText(self)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Formats the date for display in the UI.
    var shortDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Formats the date as relative time (e.g., "2 hours ago").
    var relativeDisplayString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
