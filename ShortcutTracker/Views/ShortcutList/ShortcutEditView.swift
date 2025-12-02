import SwiftUI

/// Edit mode for the shortcut edit view
enum ShortcutEditMode: Identifiable {
    case add
    case edit(ShortcutItem)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let shortcut):
            return shortcut.id.uuidString
        }
    }
    
    var title: String {
        switch self {
        case .add:
            return "Add Shortcut"
        case .edit:
            return "Edit Shortcut"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .add:
            return "Add"
        case .edit:
            return "Save"
        }
    }
}

/// View for adding or editing a shortcut.
/// Provides form fields for title, keys, description, and category.
/// Requirements: 2.1, 2.4
struct ShortcutEditView: View {
    let mode: ShortcutEditMode
    let onSave: (String, String, String?, String?) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var keys: String = ""
    @State private var description: String = ""
    @State private var category: String = ""
    
    // Modifier key states
    @State private var useCommand = false
    @State private var useShift = false
    @State private var useOption = false
    @State private var useControl = false
    @State private var mainKey: String = ""
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, mainKey, description, category
    }

    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(mode.title)
                .font(.headline)
            
            // Form fields
            Form {
                // Title field
                TextField("Title", text: $title, prompt: Text("e.g., Save"))
                    .focused($focusedField, equals: .title)
                
                // Key combination section
                Section("Key Combination") {
                    // Modifier key buttons
                    HStack(spacing: 8) {
                        ModifierKeyButton(symbol: "⌃", name: "Control", isSelected: $useControl)
                        ModifierKeyButton(symbol: "⌥", name: "Option", isSelected: $useOption)
                        ModifierKeyButton(symbol: "⇧", name: "Shift", isSelected: $useShift)
                        ModifierKeyButton(symbol: "⌘", name: "Command", isSelected: $useCommand)
                    }
                    
                    // Main key input
                    TextField("Key", text: $mainKey, prompt: Text("e.g., S"))
                        .focused($focusedField, equals: .mainKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: mainKey) { _, newValue in
                            // Limit to single character or special key name
                            if newValue.count > 10 {
                                mainKey = String(newValue.prefix(10))
                            }
                            mainKey = mainKey.uppercased()
                        }
                    
                    // Preview
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Text(buildKeyString())
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                    }
                }
                
                // Description field
                TextField("Description (optional)", text: $description, prompt: Text("What does this shortcut do?"), axis: .vertical)
                    .focused($focusedField, equals: .description)
                    .lineLimit(2...4)
                
                // Category field
                TextField("Category (optional)", text: $category, prompt: Text("e.g., File, Edit, View"))
                    .focused($focusedField, equals: .category)
            }
            .formStyle(.grouped)
            
            // Action buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(mode.actionTitle) {
                    let keyString = buildKeyString()
                    onSave(
                        title,
                        keyString,
                        description.isEmpty ? nil : description,
                        category.isEmpty ? nil : category
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 420)
        .onAppear {
            setupInitialValues()
            focusedField = .title
        }
    }
    
    // MARK: - Helper Methods
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !buildKeyString().isEmpty
    }
    
    private func buildKeyString() -> String {
        var result = ""
        if useControl { result += "⌃" }
        if useOption { result += "⌥" }
        if useShift { result += "⇧" }
        if useCommand { result += "⌘" }
        result += mainKey
        return result
    }
    
    private func setupInitialValues() {
        switch mode {
        case .add:
            break
        case .edit(let shortcut):
            title = shortcut.title
            description = shortcut.shortcutDescription ?? ""
            category = shortcut.category ?? ""
            parseKeyString(shortcut.keys)
        }
    }
    
    private func parseKeyString(_ keyString: String) {
        var remaining = keyString
        
        if remaining.contains("⌃") {
            useControl = true
            remaining = remaining.replacingOccurrences(of: "⌃", with: "")
        }
        if remaining.contains("⌥") {
            useOption = true
            remaining = remaining.replacingOccurrences(of: "⌥", with: "")
        }
        if remaining.contains("⇧") {
            useShift = true
            remaining = remaining.replacingOccurrences(of: "⇧", with: "")
        }
        if remaining.contains("⌘") {
            useCommand = true
            remaining = remaining.replacingOccurrences(of: "⌘", with: "")
        }
        
        mainKey = remaining
    }
}

// MARK: - Modifier Key Button

/// Button for selecting modifier keys with hover effects.
/// Requirements: 9.3
private struct ModifierKeyButton: View {
    let symbol: String
    let name: String
    @Binding var isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.15)) {
                isSelected.toggle()
            }
        }) {
            VStack(spacing: 2) {
                Text(symbol)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                Text(name)
                    .font(.caption2)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : Color(nsColor: .controlBackgroundColor)))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview("Add Mode") {
    ShortcutEditView(
        mode: .add,
        onSave: { _, _, _, _ in },
        onCancel: {}
    )
}

#Preview("Edit Mode") {
    ShortcutEditView(
        mode: .edit(ShortcutItem(title: "Save", keys: "⌘S", description: "Save the document", category: "File")),
        onSave: { _, _, _, _ in },
        onCancel: {}
    )
}
