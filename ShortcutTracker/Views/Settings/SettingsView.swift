import Carbon.HIToolbox
import SwiftData
import SwiftUI

/// Settings view for the application.
/// Requirements: 5.6
struct SettingsView: View {
    @AppStorage("GeminiAPIKey") private var geminiAPIKey: String = ""
    
    var body: some View {
        TabView {
            // General settings tab
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // Backup settings tab
            BackupSettingsTab()
                .tabItem {
                    Label("Backup", systemImage: "externaldrive")
                }
            
            // Keystroke Overlay settings tab
            KeystrokeOverlaySettingsTab()
                .tabItem {
                    Label("Keystroke", systemImage: "keyboard")
                }
            
            // AI settings tab
            AISettingsTab(apiKey: $geminiAPIKey)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    @Environment(\.modelContext) private var modelContext
    @Query private var apps: [AppItem]
    
    @State private var showExportSuccess = false
    @State private var showImportSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importedCount = 0
    @State private var showHotkeyCapture = false
    @ObservedObject private var appSelectorController = AppSelectorController.shared

    var body: some View {
        Form {
            Section {
                Text("ShortcutTracker")
                    .font(.headline)
                Text("Version 1.0")
                    .foregroundStyle(.secondary)
            }
            
            Section("Global Hotkey") {
                HStack {
                    Text("App Selector Hotkey")
                    Spacer()
                    Text(appSelectorController.currentHotkeyDisplay)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Button("Change") {
                        showHotkeyCapture = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text("Press this hotkey anywhere to quickly open the app selector.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Reset to Default (⌃⌥P)") {
                    appSelectorController.resetHotkeyToDefault()
                }
                .foregroundStyle(.secondary)
            }

            Section("Data Management") {
                HStack {
                    Button {
                        exportData()
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Spacer()
                    
                    Button {
                        importData()
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                }
                
                Text("Export your shortcuts to a JSON file or import from a backup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("iCloud Sync") {
                Toggle("Sync to iCloud", isOn: $iCloudSyncEnabled)

                Text("Automatically sync your shortcuts across all your devices using iCloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if iCloudSyncEnabled {
                    Text("⚠️ iCloud sync requires app to be signed with iCloud capability.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your shortcuts have been exported successfully.")
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Imported \(importedCount) app(s) with their shortcuts.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showHotkeyCapture) {
            GlobalHotkeyCaptureSheet(
                isPresented: $showHotkeyCapture,
                onCapture: { modifiers, keyCode, display in
                    appSelectorController.updateHotkey(
                        modifiers: modifiers,
                        keyCode: keyCode,
                        display: display
                    )
                }
            )
        }
    }
    
    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ShortcutTracker_Backup_\(formattedDate()).json"
        panel.title = "Export Shortcuts"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try ShortcutExporter.exportAll(apps: apps)
                    try data.write(to: url)
                    showExportSuccess = true
                } catch {
                    errorMessage = "Export failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Import Shortcuts"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let importData = try decoder.decode(ShortcutExporter.ExportData.self, from: data)
                    importedCount = importData.apps.count
                    
                    try ShortcutExporter.importAll(from: data, context: modelContext)
                    showImportSuccess = true
                } catch {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - AI Service Type

enum AIServiceType: String, CaseIterable {
    case gemini = "gemini"
    case openAI = "openai"
    
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI Compatible"
        }
    }
}

// MARK: - AI Settings Tab

struct AISettingsTab: View {
    @Binding var apiKey: String
    @AppStorage("AIServiceType") private var serviceType: String = AIServiceType.gemini.rawValue
    @State private var showPromptEditor = false
    
    var body: some View {
        Form {
            Section("AI Service") {
                Picker("Service Provider", selection: $serviceType) {
                    ForEach(AIServiceType.allCases, id: \.rawValue) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
                
                Text("Choose your AI service provider for shortcut extraction.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if serviceType == AIServiceType.gemini.rawValue {
                GeminiSettingsSection(apiKey: $apiKey, showPromptEditor: $showPromptEditor)
            } else {
                OpenAISettingsSection(showPromptEditor: $showPromptEditor)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showPromptEditor) {
            if serviceType == AIServiceType.gemini.rawValue {
                GeminiPromptEditorView(isPresented: $showPromptEditor)
            } else {
                OpenAIPromptEditorView(isPresented: $showPromptEditor)
            }
        }
    }
}

// MARK: - Gemini Settings Section

struct GeminiSettingsSection: View {
    @Binding var apiKey: String
    @Binding var showPromptEditor: Bool
    @State private var showAPIKey = false
    @AppStorage("GeminiModel") private var selectedModel: String = GeminiModel.gemini25Flash.rawValue
    @AppStorage("GeminiCustomPrompt") private var customPrompt: String = ""
    
    var body: some View {
        Section("Gemini API") {
            HStack {
                if showAPIKey {
                    TextField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            
            Text("Enter your Gemini API key for AI-powered shortcut extraction.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Model") {
            Picker("AI Model", selection: $selectedModel) {
                ForEach(GeminiModel.allCases, id: \.rawValue) { model in
                    Text(model.displayName).tag(model.rawValue)
                }
            }
        }

        Section("Prompt") {
            HStack {
                Text(customPrompt.isEmpty ? "Using default prompt" : "Custom prompt configured")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Edit Prompt") {
                    showPromptEditor = true
                }
            }

            if !customPrompt.isEmpty {
                Button("Reset to Default") {
                    customPrompt = ""
                }
                .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - OpenAI Settings Section

struct OpenAISettingsSection: View {
    @Binding var showPromptEditor: Bool
    @State private var showAPIKey = false
    @AppStorage(OpenAICompatibleService.providerKey) private var provider: String = OpenAIProvider.siliconFlow.rawValue
    @AppStorage(OpenAICompatibleService.apiKeyKey) private var apiKey: String = ""
    @AppStorage(OpenAICompatibleService.endpointKey) private var endpoint: String = ""
    @AppStorage(OpenAICompatibleService.modelKey) private var model: String = ""
    @AppStorage(OpenAICompatibleService.customPromptKey) private var customPrompt: String = ""
    
    private var currentProvider: OpenAIProvider {
        OpenAIProvider(rawValue: provider) ?? .siliconFlow
    }
    
    var body: some View {
        Section("Provider") {
            Picker("Provider", selection: $provider) {
                ForEach(OpenAIProvider.allCases, id: \.rawValue) { p in
                    Text(p.displayName).tag(p.rawValue)
                }
            }
            .onChange(of: provider) { _, newValue in
                if let p = OpenAIProvider(rawValue: newValue) {
                    endpoint = p.defaultEndpoint
                    model = p.defaultModels.first ?? ""
                }
            }
        }
        
        Section("API Configuration") {
            HStack {
                if showAPIKey {
                    TextField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            
            TextField("Endpoint URL", text: $endpoint)
                .textFieldStyle(.roundedBorder)
            
            if currentProvider == .custom {
                Text("Enter your custom OpenAI-compatible API endpoint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        Section("Model") {
            if currentProvider.defaultModels.isEmpty {
                TextField("Model Name", text: $model)
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("Model", selection: $model) {
                    ForEach(currentProvider.defaultModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                
                TextField("Or enter custom model", text: $model)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
        
        Section("Prompt") {
            HStack {
                Text(customPrompt.isEmpty ? "Using default prompt" : "Custom prompt configured")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Edit Prompt") {
                    showPromptEditor = true
                }
            }

            if !customPrompt.isEmpty {
                Button("Reset to Default") {
                    customPrompt = ""
                }
                .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Gemini Prompt Editor View

struct GeminiPromptEditorView: View {
    @Binding var isPresented: Bool
    @AppStorage("GeminiCustomPrompt") private var prompt: String = ""
    
    var body: some View {
        PromptEditorView(
            prompt: $prompt,
            isPresented: $isPresented,
            defaultPrompt: GeminiAIService.defaultPrompt
        )
    }
}

// MARK: - OpenAI Prompt Editor View

struct OpenAIPromptEditorView: View {
    @Binding var isPresented: Bool
    @AppStorage(OpenAICompatibleService.customPromptKey) private var prompt: String = ""
    
    var body: some View {
        PromptEditorView(
            prompt: $prompt,
            isPresented: $isPresented,
            defaultPrompt: OpenAICompatibleService.defaultPrompt
        )
    }
}

// MARK: - Prompt Editor View

struct PromptEditorView: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    var defaultPrompt: String = GeminiAIService.defaultPrompt

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit AI Prompt")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            TextEditor(text: $prompt)
                .font(.system(.body, design: .monospaced))
                .padding()

            Divider()

            HStack {
                Text("Use {{TEXT}} as placeholder for input text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to Default") {
                    prompt = defaultPrompt
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            if prompt.isEmpty {
                prompt = defaultPrompt
            }
        }
    }
}

// MARK: - Keystroke Overlay Settings Tab

struct KeystrokeOverlaySettingsTab: View {
    @ObservedObject private var controller = KeystrokeOverlayController.shared
    @State private var selectedTextColor: Color = .white
    @State private var selectedBgColor: Color = .black

    private var previewFont: Font {
        let size = controller.fontSize * 0.6
        if controller.useCustomFont, !controller.fontName.isEmpty {
            return Font.custom(controller.fontName, size: size)
                .weight(controller.isBold ? .bold : .regular)
        }
        return Font.system(size: size, weight: controller.isBold ? .bold : .regular, design: controller.fontDesign.swiftUIDesign)
    }
    
    private func showCustomPositionPicker() {
        CustomPositionPickerController.shared.showPicker(
            initialX: controller.customPositionX,
            initialY: controller.customPositionY
        ) { x, y in
            controller.setCustomPosition(x: x, y: y)
        }
    }

    var body: some View {
        Form {
            Section("Keystroke Display") {
                Toggle("Enable Keystroke Overlay", isOn: $controller.isEnabled)

                Toggle("Show All Keys", isOn: $controller.showAllKeys)

                Toggle("Show Mouse Clicks", isOn: $controller.showMouseClicks)

                Toggle("Show Matched Shortcut Title", isOn: $controller.showMatchedTitle)

                Text("Shows keyboard shortcuts on screen. When a shortcut matches a recorded one, its title will be displayed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $controller.fontSize, in: 16...48, step: 2)
                        .frame(width: 150)
                    Text("\(Int(controller.fontSize))pt")
                        .frame(width: 40)
                        .foregroundStyle(.secondary)
                }

                Toggle("Bold Text", isOn: $controller.isBold)

                Toggle("Use Custom Font", isOn: $controller.useCustomFont)

                if controller.useCustomFont {
                    HStack {
                        Text("Font")
                        Spacer()
                        Text(controller.fontName.isEmpty ? "System" : controller.fontName)
                            .foregroundStyle(.secondary)
                        Button("Select...") {
                            FontPanelManager.shared.showFontPanel(
                                currentFont: controller.currentNSFont
                            ) { newFont in
                                controller.fontName = newFont.fontName
                                controller.fontSize = newFont.pointSize
                            }
                        }
                    }
                } else {
                    Picker("Font Style", selection: $controller.fontDesign) {
                        ForEach(KeystrokeOverlayController.FontDesign.allCases, id: \.self) { design in
                            Text(design.displayName).tag(design)
                        }
                    }
                }

                ColorPicker("Text Color", selection: $selectedTextColor)
                    .onChange(of: selectedTextColor) { _, newValue in
                        if let nsColor = NSColor(newValue).usingColorSpace(.sRGB) {
                            controller.textColorHex = nsColor.hexString
                        }
                    }

                ColorPicker("Background Color", selection: $selectedBgColor)
                    .onChange(of: selectedBgColor) { _, newValue in
                        if let nsColor = NSColor(newValue).usingColorSpace(.sRGB) {
                            controller.backgroundColorHex = nsColor.hexString
                        }
                    }

                HStack {
                    Text("Background Opacity")
                    Spacer()
                    Slider(value: $controller.backgroundOpacity, in: 0...1, step: 0.1)
                        .frame(width: 120)
                    Text("\(Int(controller.backgroundOpacity * 100))%")
                        .frame(width: 40)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Slider(value: $controller.cornerRadius, in: 0...20, step: 2)
                        .frame(width: 120)
                    Text("\(Int(controller.cornerRadius))px")
                        .frame(width: 40)
                        .foregroundStyle(.secondary)
                }

                Stepper("Max Lines: \(controller.maxLines)", value: $controller.maxLines, in: 1 ... 6)
            }

            Section("Position") {
                Picker("Screen Position", selection: $controller.position) {
                    ForEach(KeystrokeOverlayController.OverlayPosition.allCases, id: \.self) { pos in
                        Label(pos.displayName, systemImage: pos.icon).tag(pos)
                    }
                }
                .pickerStyle(.radioGroup)
                
                if controller.position == .custom {
                    HStack {
                        Text("Current: (\(Int(controller.customPositionX)), \(Int(controller.customPositionY)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                
                Button("Set Custom Position...") {
                    showCustomPositionPicker()
                }
                .buttonStyle(.bordered)
                
                Text("Click to show a draggable preview box. Drag it to your desired position and click Save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Timing") {
                HStack {
                    Text("Display Duration")
                    Spacer()
                    Slider(value: $controller.displayDuration, in: 1 ... 10, step: 0.5)
                        .frame(width: 150)
                    Text("\(controller.displayDuration, specifier: "%.1f")s")
                        .frame(width: 40)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Preview") {
                HStack {
                    Spacer()
                    Text("⌘⇧S")
                        .font(previewFont)
                        .foregroundColor(selectedTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: controller.cornerRadius)
                                .fill(selectedBgColor.opacity(controller.backgroundOpacity))
                        )
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            selectedTextColor = Color(controller.textColor)
            selectedBgColor = Color(controller.backgroundColor)
        }
    }
}

// MARK: - Global Hotkey Capture Sheet

struct GlobalHotkeyCaptureSheet: View {
    @Binding var isPresented: Bool
    let onCapture: (UInt32, UInt32, String) -> Void
    
    @State private var capturedDisplay = ""
    @State private var capturedModifiers: UInt32 = 0
    @State private var capturedKeyCode: UInt32 = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Press a keyboard shortcut")
                .font(.headline)
            
            Text(capturedDisplay.isEmpty ? "Waiting for input..." : capturedDisplay)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .foregroundStyle(capturedDisplay.isEmpty ? .secondary : .primary)
                .frame(height: 50)
            
            Text("Use modifier keys (⌃⌥⇧⌘) with a letter or number")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Use This Hotkey") {
                    onCapture(capturedModifiers, capturedKeyCode, capturedDisplay)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(capturedDisplay.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(
            GlobalHotkeyCaptureNSViewWrapper(
                capturedDisplay: $capturedDisplay,
                capturedModifiers: $capturedModifiers,
                capturedKeyCode: $capturedKeyCode,
                onEscape: { isPresented = false }
            )
        )
    }
}

struct GlobalHotkeyCaptureNSViewWrapper: NSViewRepresentable {
    @Binding var capturedDisplay: String
    @Binding var capturedModifiers: UInt32
    @Binding var capturedKeyCode: UInt32
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> GlobalHotkeyCaptureNSView {
        let view = GlobalHotkeyCaptureNSView()
        view.onKeyCapture = { display, modifiers, keyCode in
            capturedDisplay = display
            capturedModifiers = modifiers
            capturedKeyCode = keyCode
        }
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: GlobalHotkeyCaptureNSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class GlobalHotkeyCaptureNSView: NSView {
    var onKeyCapture: ((String, UInt32, UInt32) -> Void)?
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        // Check for Escape without modifiers
        if event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            onEscape?()
            return
        }
        
        let flags = event.modifierFlags
        
        // Require at least one modifier key
        let hasModifier = flags.contains(.control) || flags.contains(.option) ||
                          flags.contains(.shift) || flags.contains(.command)
        
        guard hasModifier else { return }
        
        // Build display string
        var parts: [String] = []
        var carbonModifiers: UInt32 = 0
        
        if flags.contains(.control) {
            parts.append("⌃")
            carbonModifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            parts.append("⌥")
            carbonModifiers |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            parts.append("⇧")
            carbonModifiers |= UInt32(shiftKey)
        }
        if flags.contains(.command) {
            parts.append("⌘")
            carbonModifiers |= UInt32(cmdKey)
        }
        
        // Add the main key
        if let key = keyString(for: event.keyCode, with: event.charactersIgnoringModifiers) {
            parts.append(key)
            let display = parts.joined()
            onKeyCapture?(display, carbonModifiers, UInt32(event.keyCode))
        }
    }
    
    private func keyString(for keyCode: UInt16, with characters: String?) -> String? {
        let specialKeys: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        
        if let special = specialKeys[keyCode] {
            return special
        }
        
        if let char = characters?.uppercased(), !char.isEmpty {
            return char
        }
        
        return nil
    }
}

#Preview {
    SettingsView()
}
