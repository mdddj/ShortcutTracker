import SwiftUI

/// Row view for displaying an application in the sidebar.
/// Shows app icon and name with hover effects.
/// Requirements: 9.3
struct AppRowView: View {
    let app: AppItem
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Group {
                if let iconPath = app.iconPath {
                    // Use NSWorkspace to get the app icon
                    Image(nsImage: NSWorkspace.shared.icon(forFile: iconPath))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(isHovered ? .primary : .secondary)
                }
            }
            .frame(width: 24, height: 24)
            .scaleEffect(isHovered ? 1.1 : 1.0)
            
            // App name
            Text(app.name)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Shortcut count badge
            if !(app.shortcuts ?? []).isEmpty {
                Text("\((app.shortcuts ?? []).count)")
                    .font(.caption2)
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
                    )
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    List {
        AppRowView(app: {
            let app = AppItem(name: "Xcode")
            return app
        }())
        AppRowView(app: {
            let app = AppItem(name: "Visual Studio Code")
            return app
        }())
    }
    .frame(width: 250)
}
