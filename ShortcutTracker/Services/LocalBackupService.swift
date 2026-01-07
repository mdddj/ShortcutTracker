import Foundation
import SwiftData
import Combine

/// Service for local backup and sync to ~/.shortcutTracker directory
@Observable
class LocalBackupService {
    
    // MARK: - Properties
    
    /// Default backup directory path
    static let defaultBackupPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".shortcutTracker")
    
    /// Backup file name
    private static let backupFileName = "shortcuts_backup.json"
    
    /// Last sync timestamp
    var lastSyncTime: Date?
    
    /// Sync status
    var syncStatus: SyncStatus = .idle
    
    /// Auto sync enabled
    var autoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoSyncEnabled") }
    }
    
    /// File monitor for watching backup file changes
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    
    /// Model context for data operations
    private var modelContext: ModelContext?
    
    /// Callback when external changes detected
    var onExternalChangesDetected: (() -> Void)?
    
    // MARK: - Sync Status
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "等待同步"
            case .syncing: return "同步中..."
            case .success: return "同步成功"
            case .error(let msg): return "同步失败: \(msg)"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        ensureBackupDirectoryExists()
    }
    
    /// Setup with model context
    func setup(with context: ModelContext) {
        self.modelContext = context
        if autoSyncEnabled {
            startFileMonitoring()
        }
    }
    
    // MARK: - Directory Management
    
    /// Ensures the backup directory exists
    private func ensureBackupDirectoryExists() {
        let fileManager = FileManager.default
        let backupPath = Self.defaultBackupPath
        
        if !fileManager.fileExists(atPath: backupPath.path) {
            do {
                try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)
                print("Created backup directory at: \(backupPath.path)")
            } catch {
                print("Failed to create backup directory: \(error)")
            }
        }
    }
    
    /// Get the backup file URL
    var backupFileURL: URL {
        Self.defaultBackupPath.appendingPathComponent(Self.backupFileName)
    }
    
    // MARK: - Backup Operations
    
    /// Save current data to local backup
    func saveBackup(apps: [AppItem]) async throws {
        syncStatus = .syncing
        
        do {
            let data = try ShortcutExporter.exportAll(apps: apps)
            try data.write(to: backupFileURL, options: .atomic)
            
            lastSyncTime = Date()
            UserDefaults.standard.set(lastSyncTime, forKey: "lastBackupTime")
            syncStatus = .success
            
            print("Backup saved to: \(backupFileURL.path)")
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Load backup from local file
    func loadBackup() throws -> Data? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: backupFileURL.path) else {
            return nil
        }
        
        return try Data(contentsOf: backupFileURL)
    }
    
    /// Import from local backup
    func importFromBackup(context: ModelContext) async throws {
        syncStatus = .syncing
        
        do {
            guard let data = try loadBackup() else {
                syncStatus = .idle
                return
            }
            
            try ShortcutExporter.importAll(from: data, context: context)
            
            lastSyncTime = Date()
            syncStatus = .success
            
            print("Imported from backup successfully")
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Check if backup file exists
    var backupExists: Bool {
        FileManager.default.fileExists(atPath: backupFileURL.path)
    }
    
    /// Get backup file modification date
    var backupModificationDate: Date? {
        guard backupExists else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: backupFileURL.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    
    // MARK: - File Monitoring
    
    /// Start monitoring the backup file for external changes
    func startFileMonitoring() {
        stopFileMonitoring()
        
        let path = backupFileURL.path
        
        // Create file if it doesn't exist (needed for monitoring)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            print("Failed to open file for monitoring")
            return
        }
        
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        fileMonitor?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.handleFileChange()
            }
        }
        
        fileMonitor?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }
        
        fileMonitor?.resume()
        print("Started file monitoring for: \(path)")
    }
    
    /// Stop monitoring the backup file
    func stopFileMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }
    
    /// Handle file change event
    private func handleFileChange() {
        print("Backup file changed externally")
        onExternalChangesDetected?()
    }
    
    // MARK: - Auto Sync
    
    /// Enable or disable auto sync
    func setAutoSync(enabled: Bool) {
        autoSyncEnabled = enabled
        
        if enabled {
            startFileMonitoring()
        } else {
            stopFileMonitoring()
        }
    }
    
    /// Perform full sync - save current data and check for external changes
    func performSync(apps: [AppItem], context: ModelContext) async throws {
        // First, check if there are external changes
        if let backupDate = backupModificationDate,
           let lastSync = lastSyncTime,
           backupDate > lastSync {
            // External changes detected, import first
            try await importFromBackup(context: context)
        }
        
        // Then save current state
        try await saveBackup(apps: apps)
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopFileMonitoring()
    }
}

// MARK: - Backup Info

extension LocalBackupService {
    
    /// Get backup info for display
    struct BackupInfo {
        let exists: Bool
        let path: String
        let modificationDate: Date?
        let fileSize: Int64?
    }
    
    var backupInfo: BackupInfo {
        let exists = backupExists
        var fileSize: Int64? = nil
        
        if exists {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: backupFileURL.path)
                fileSize = attributes[.size] as? Int64
            } catch {}
        }
        
        return BackupInfo(
            exists: exists,
            path: backupFileURL.path,
            modificationDate: backupModificationDate,
            fileSize: fileSize
        )
    }
}
