import SwiftUI
import SwiftData

/// Settings tab for local backup and sync configuration
struct BackupSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var apps: [AppItem]
    
    @State private var backupService = LocalBackupService()
    @State private var showSaveSuccess = false
    @State private var showImportSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section("本地备份") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备份目录")
                            .font(.headline)
                        Text(LocalBackupService.defaultBackupPath.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    Spacer()
                    
                    Button {
                        openBackupFolder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("在 Finder 中打开")
                }
                
                if let info = backupInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("备份状态")
                            Spacer()
                            if info.exists {
                                Label("已有备份", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("无备份", systemImage: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let date = info.modificationDate {
                            HStack {
                                Text("最后更新")
                                Spacer()
                                Text(date, style: .relative)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let size = info.fileSize {
                            HStack {
                                Text("文件大小")
                                Spacer()
                                Text(formatFileSize(size))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            Section("手动操作") {
                HStack {
                    Button {
                        saveBackup()
                    } label: {
                        Label("立即备份", systemImage: "arrow.up.doc")
                    }
                    .disabled(isLoading)
                    
                    Spacer()
                    
                    Button {
                        importBackup()
                    } label: {
                        Label("从备份恢复", systemImage: "arrow.down.doc")
                    }
                    .disabled(isLoading || !backupService.backupExists)
                }
                
                Text("将当前数据保存到本地备份目录，或从备份恢复数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("自动同步") {
                Toggle("启用自动同步", isOn: Binding(
                    get: { backupService.autoSyncEnabled },
                    set: { backupService.setAutoSync(enabled: $0) }
                ))
                
                Text("启用后，应用会监控备份文件的变化，并在检测到外部修改时自动导入。同时，数据变更也会自动保存到备份文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if backupService.autoSyncEnabled {
                    HStack {
                        Text("同步状态")
                        Spacer()
                        Text(backupService.syncStatus.description)
                            .foregroundStyle(syncStatusColor)
                    }
                }
            }
            
            Section("说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("备份文件保存在 ~/.shortcutTracker 目录", systemImage: "info.circle")
                    Label("可以通过云盘同步此目录实现多设备同步", systemImage: "cloud")
                    Label("支持手动编辑 JSON 文件后自动导入", systemImage: "doc.text")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            backupService.setup(with: modelContext)
            setupExternalChangeHandler()
        }
        .alert("备份成功", isPresented: $showSaveSuccess) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("数据已保存到本地备份目录。")
        }
        .alert("恢复成功", isPresented: $showImportSuccess) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("已从备份文件恢复数据。")
        }
        .alert("错误", isPresented: $showError) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backupInfo: LocalBackupService.BackupInfo? {
        backupService.backupInfo
    }
    
    private var syncStatusColor: Color {
        switch backupService.syncStatus {
        case .idle: return .secondary
        case .syncing: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    // MARK: - Actions
    
    private func saveBackup() {
        isLoading = true
        Task {
            do {
                try await backupService.saveBackup(apps: apps)
                await MainActor.run {
                    isLoading = false
                    showSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func importBackup() {
        isLoading = true
        Task {
            do {
                try await backupService.importFromBackup(context: modelContext)
                await MainActor.run {
                    isLoading = false
                    showImportSuccess = true
                    // Post notification to refresh UI
                    NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func openBackupFolder() {
        NSWorkspace.shared.open(LocalBackupService.defaultBackupPath)
    }
    
    private func setupExternalChangeHandler() {
        backupService.onExternalChangesDetected = { [self] in
            // Auto import when external changes detected
            if backupService.autoSyncEnabled {
                importBackup()
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    BackupSettingsTab()
}
