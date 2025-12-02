import SwiftUI

/// Row view for displaying a shortcut in the list.
/// Shows title, keys, description, and category with context menu.
/// Requirements: 2.3, 2.4, 2.5, 9.3
struct ShortcutRowView: View {
    let shortcut: ShortcutItem
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Key combination badge
            keysBadge
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = shortcut.shortcutDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Category tag
            if let category = shortcut.category, !category.isEmpty {
                categoryTag(category)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
                .shadow(color: isHovered ? Color.black.opacity(0.05) : Color.clear, radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: isHovered ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Keys Badge
    
    private var keysBadge: some View {
        Text(shortcut.keys)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.25) : Color.accentColor.opacity(0.15))
            )
            .foregroundStyle(Color.accentColor)
            .scaleEffect(isHovered ? 1.05 : 1.0)
    }
    
    // MARK: - Category Tag
    
    private func categoryTag(_ category: String) -> some View {
        Text(category)
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

#Preview {
    VStack(spacing: 8) {
        ShortcutRowView(shortcut: {
            let s = ShortcutItem(title: "Save", keys: "⌘S", description: "Save the current document", category: "File")
            return s
        }())
        
        ShortcutRowView(shortcut: {
            let s = ShortcutItem(title: "Copy", keys: "⌘C", description: nil, category: "Edit")
            return s
        }())
        
        ShortcutRowView(shortcut: {
            let s = ShortcutItem(title: "Find and Replace", keys: "⌘⇧H", description: "Open find and replace dialog to search and replace text in the document", category: nil)
            return s
        }())
    }
    .padding()
    .frame(width: 500)
}
