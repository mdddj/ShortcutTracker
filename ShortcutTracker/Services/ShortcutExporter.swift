import Foundation
import SwiftData

/// Service for exporting and importing shortcuts data
class ShortcutExporter {
    
    // MARK: - Export/Import Data Structures
    
    struct ExportData: Codable {
        let version: String
        let exportDate: Date
        let apps: [ExportApp]
    }
    
    struct ExportApp: Codable {
        let name: String
        let iconPath: String?
        let shortcuts: [ExportShortcut]
    }
    
    struct ExportShortcut: Codable {
        let title: String
        let keys: String
        let description: String?
        let category: String?
    }
    
    // MARK: - Export
    
    /// Export all apps and shortcuts to JSON data
    static func exportAll(apps: [AppItem]) throws -> Data {
        let exportApps = apps.map { app in
            ExportApp(
                name: app.name,
                iconPath: app.iconPath,
                shortcuts: (app.shortcuts ?? []).map { shortcut in
                    ExportShortcut(
                        title: shortcut.title,
                        keys: shortcut.keys,
                        description: shortcut.shortcutDescription,
                        category: shortcut.category
                    )
                }
            )
        }
        
        let exportData = ExportData(
            version: "1.0",
            exportDate: Date(),
            apps: exportApps
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(exportData)
    }
    
    // MARK: - Import
    
    /// Import apps and shortcuts from JSON data
    static func importAll(from data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importData = try decoder.decode(ExportData.self, from: data)
        
        for exportApp in importData.apps {
            // Check if app already exists
            let appName = exportApp.name
            let descriptor = FetchDescriptor<AppItem>(
                predicate: #Predicate { $0.name == appName }
            )
            let existingApps = try context.fetch(descriptor)
            
            let app: AppItem
            if let existing = existingApps.first {
                app = existing
            } else {
                app = AppItem(name: exportApp.name, iconPath: exportApp.iconPath)
                context.insert(app)
            }
            
            // Import shortcuts
            for exportShortcut in exportApp.shortcuts {
                // Check if shortcut already exists
                let existingShortcut = (app.shortcuts ?? []).first { $0.keys == exportShortcut.keys }
                
                if existingShortcut == nil {
                    let shortcut = ShortcutItem(
                        title: exportShortcut.title,
                        keys: exportShortcut.keys,
                        description: exportShortcut.description,
                        category: exportShortcut.category
                    )
                    shortcut.app = app
                    app.shortcuts?.append(shortcut)
                    context.insert(shortcut)
                }
            }
        }
        
        try context.save()
    }
    
    // MARK: - Export Single App
    
    /// Export a single app and its shortcuts
    static func exportApp(_ app: AppItem) throws -> Data {
        let exportApp = ExportApp(
            name: app.name,
            iconPath: app.iconPath,
            shortcuts: (app.shortcuts ?? []).map { shortcut in
                ExportShortcut(
                    title: shortcut.title,
                    keys: shortcut.keys,
                    description: shortcut.shortcutDescription,
                    category: shortcut.category
                )
            }
        )
        
        let exportData = ExportData(
            version: "1.0",
            exportDate: Date(),
            apps: [exportApp]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(exportData)
    }
}
