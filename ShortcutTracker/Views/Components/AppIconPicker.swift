import SwiftUI
import AppKit

/// A view that allows selecting an application icon from installed Mac apps.
struct AppIconPicker: View {
    @Binding var selectedIconPath: String?
    @Binding var appName: String
    
    @State private var showingAppPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon preview
            Button {
                showingAppPicker = true
            } label: {
                Group {
                    if let iconPath = selectedIconPath {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: iconPath))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("App Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Choose from Apps...") {
                    showingAppPicker = true
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(
                onSelect: { app in
                    selectedIconPath = app.path
                    if appName.isEmpty {
                        appName = app.name
                    }
                    showingAppPicker = false
                },
                onCancel: {
                    showingAppPicker = false
                }
            )
        }
    }
}

// MARK: - Installed App Model

struct InstalledApp: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    
    init(name: String, path: String) {
        self.id = path
        self.name = name
        self.path = path
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.path == rhs.path
    }
}

// MARK: - App Cache

/// Singleton cache for installed apps to avoid repeated file system scans
class InstalledAppsCache {
    static let shared = InstalledAppsCache()
    
    private var cachedApps: [InstalledApp]?
    private var isLoading = false
    private var loadCallbacks: [([InstalledApp]) -> Void] = []
    
    private init() {}
    
    func getApps(completion: @escaping ([InstalledApp]) -> Void) {
        if let apps = cachedApps {
            completion(apps)
            return
        }
        
        loadCallbacks.append(completion)
        
        guard !isLoading else { return }
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.loadInstalledApps() ?? []
            
            DispatchQueue.main.async {
                self?.cachedApps = apps
                self?.isLoading = false
                self?.loadCallbacks.forEach { $0(apps) }
                self?.loadCallbacks.removeAll()
            }
        }
    }
    
    private func loadInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fileManager = FileManager.default
        
        let appDirectories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]
        
        for directory in appDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
                continue
            }
            
            for item in contents where item.hasSuffix(".app") {
                let appPath = (directory as NSString).appendingPathComponent(item)
                let appName = (item as NSString).deletingPathExtension
                apps.append(InstalledApp(name: appName, path: appPath))
            }
        }
        
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - App Picker Sheet

private struct AppPickerSheet: View {
    let onSelect: (InstalledApp) -> Void
    let onCancel: () -> Void
    
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Application")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            Divider()
            
            // App grid
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading applications...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No applications found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredApps) { app in
                            AppGridItem(app: app) {
                                onSelect(app)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 450)
        .onAppear {
            InstalledAppsCache.shared.getApps { apps in
                self.installedApps = apps
                self.isLoading = false
            }
        }
    }
}

// MARK: - App Grid Item

private struct AppGridItem: View {
    let app: InstalledApp
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                // Load icon lazily
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                
                Text(app.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .frame(width: 80)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    AppIconPicker(selectedIconPath: .constant(nil), appName: .constant(""))
        .padding()
}
