import SwiftUI

/// View for AI-powered shortcut extraction from text.
/// Provides text input, extraction preview, and import confirmation.
/// Requirements: 6.1, 6.2, 6.3, 6.4
struct AIImportView: View {
    @Bindable var viewModel: AIImportViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content based on state
            Group {
                switch viewModel.state {
                case .idle:
                    inputSection
                case .loading:
                    loadingSection
                case .loaded:
                    previewSection
                case .error(let message):
                    errorSection(message: message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Footer with action buttons
            footer
        }
        .frame(width: 500, height: 550)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text("AI Shortcut Import")
                .font(.headline)
            Spacer()

            // App selector
            if !viewModel.availableApps.isEmpty {
                Picker("", selection: Binding(
                    get: { viewModel.appViewModel?.selectedApp },
                    set: { if let app = $0 { viewModel.selectApp(app) } }
                )) {
                    ForEach(viewModel.availableApps) { app in
                        Text(app.name).tag(app as AppItem?)
                    }
                }
                .frame(width: 150)
            }
        }
        .padding()
    }

    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste article or documentation text containing keyboard shortcuts:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $viewModel.inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            Text("The AI will identify shortcuts in formats like \"Cmd+S\", \"⌘S\", or \"Command + Shift + S\"")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing text for shortcuts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Found \(viewModel.extractedShortcuts.count) shortcut(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()

                // Copy buttons
                Menu {
                    Button("Copy AI Response") {
                        if let response = viewModel.rawAIResponse {
                            viewModel.copyToClipboard(response)
                        }
                    }
                    .disabled(viewModel.rawAIResponse == nil)

                    Button("Copy JSON Data") {
                        viewModel.copyToClipboard(viewModel.extractedShortcutsJSON)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
                
                Button("Back to Input") {
                    viewModel.state = .idle
                }
                .buttonStyle(.link)
            }
            
            if viewModel.extractedShortcuts.isEmpty {
                emptyPreviewState
            } else {
                shortcutPreviewList
            }
        }
        .padding()
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No shortcuts found in the text")
                .font(.headline)
            Text("Try pasting text that contains keyboard shortcuts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var shortcutPreviewList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.extractedShortcuts) { shortcut in
                    ExtractedShortcutRow(
                        shortcut: shortcut,
                        onRemove: { viewModel.removeExtractedShortcut(shortcut) }
                    )
                }
            }
        }
    }

    
    // MARK: - Error Section
    
    private func errorSection(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                viewModel.clearError()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button("Cancel") {
                viewModel.reset()
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            if case .loaded = viewModel.state {
                Button("Import \(viewModel.extractedShortcuts.count) Shortcut(s)") {
                    viewModel.confirmImport()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canConfirmImport)
            } else {
                Button("Extract Shortcuts") {
                    print("[AIImportView] Extract button clicked")
                    Task {
                        await viewModel.extractShortcuts()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canExtract)
            }
        }
        .padding()
    }
}

// MARK: - Extracted Shortcut Row

private struct ExtractedShortcutRow: View {
    let shortcut: ExtractedShortcut
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Key combination badge
            Text(shortcut.keys)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                )
                .foregroundStyle(Color.accentColor)
            
            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = shortcut.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Category tag
            if let category = shortcut.category, !category.isEmpty {
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
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview("Idle State") {
    let mockService = MockAIService()
    let dataService = DataService.preview
    let appVM = AppViewModel(dataService: dataService)
    appVM.addApp(name: "Preview App")
    let viewModel = AIImportViewModel(
        aiService: mockService,
        dataService: dataService,
        appViewModel: appVM
    )
    
    return AIImportView(viewModel: viewModel, onDismiss: {})
}
