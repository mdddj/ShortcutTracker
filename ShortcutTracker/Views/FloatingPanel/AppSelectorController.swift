import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Controller for the app selector panel that appears with global hotkey.
/// Shows a list of apps and allows keyboard navigation.
class AppSelectorController: NSObject, ObservableObject {
    static let shared = AppSelectorController()
    
    // MARK: - UserDefaults Keys
    static let hotkeyModifiersKey = "AppSelectorHotkeyModifiers"
    static let hotkeyKeyCodeKey = "AppSelectorHotkeyKeyCode"
    static let hotkeyDisplayKey = "AppSelectorHotkeyDisplay"
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var eventMonitor: Any?
    private var eventHandlerRef: EventHandlerRef?
    
    @Published var isVisible = false
    @Published var selectedIndex = 0
    @Published var apps: [AppItem] = []
    @Published var currentHotkeyDisplay: String = "⌃⌥P"
    
    var onAppSelected: ((AppItem) -> Void)?
    
    /// DataService reference for fetching apps
    var dataService: DataService?
    
    private let panelSize = NSSize(width: 300, height: 400)
    private var hotKeyRef: EventHotKeyRef?
    
    private override init() {
        super.init()
        loadHotkeyFromDefaults()
        registerGlobalHotkey()
    }
    
    deinit {
        unregisterGlobalHotkey()
    }
    
    // MARK: - Hotkey Configuration
    
    /// Default hotkey: Ctrl+Option+P
    static let defaultModifiers: UInt32 = UInt32(controlKey | optionKey)
    static let defaultKeyCode: UInt32 = 0x23 // P key
    static let defaultDisplay = "⌃⌥P"
    
    private var currentModifiers: UInt32 = defaultModifiers
    private var currentKeyCode: UInt32 = defaultKeyCode
    
    private func loadHotkeyFromDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.hotkeyKeyCodeKey) != nil {
            currentModifiers = UInt32(defaults.integer(forKey: Self.hotkeyModifiersKey))
            currentKeyCode = UInt32(defaults.integer(forKey: Self.hotkeyKeyCodeKey))
            currentHotkeyDisplay = defaults.string(forKey: Self.hotkeyDisplayKey) ?? Self.defaultDisplay
        } else {
            currentModifiers = Self.defaultModifiers
            currentKeyCode = Self.defaultKeyCode
            currentHotkeyDisplay = Self.defaultDisplay
        }
    }
    
    /// Updates the global hotkey with new key combination
    func updateHotkey(modifiers: UInt32, keyCode: UInt32, display: String) {
        // Save to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(Int(modifiers), forKey: Self.hotkeyModifiersKey)
        defaults.set(Int(keyCode), forKey: Self.hotkeyKeyCodeKey)
        defaults.set(display, forKey: Self.hotkeyDisplayKey)
        
        // Update current values
        currentModifiers = modifiers
        currentKeyCode = keyCode
        currentHotkeyDisplay = display
        
        // Re-register hotkey
        unregisterGlobalHotkey()
        registerGlobalHotkey()
    }
    
    /// Resets hotkey to default (Ctrl+Option+P)
    func resetHotkeyToDefault() {
        updateHotkey(
            modifiers: Self.defaultModifiers,
            keyCode: Self.defaultKeyCode,
            display: Self.defaultDisplay
        )
    }
    
    // MARK: - Global Hotkey Registration
    
    private func registerGlobalHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x53545250) // "STRP"
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(
            currentKeyCode,
            currentModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }
        
        // Install event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<AppSelectorController>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        controller.toggleSelector()
                    }
                }
                
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }
    
    private func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
    }
    
    // MARK: - Panel Management
    
    func toggleSelector() {
        if isVisible {
            hideSelector()
        } else {
            showSelector()
        }
    }
    
    func showSelector() {
        // Fetch apps directly from dataService
        if let dataService = dataService {
            apps = dataService.fetchApps()
        } else {
            // Fallback to notification if dataService not set
            NotificationCenter.default.post(name: .requestAppList, object: nil)
        }
        
        if panel == nil {
            createPanel()
        }
        
        guard let panel = panel else { return }
        
        selectedIndex = 0
        
        let content = AppSelectorView(controller: self)
        
        if let hostingView = hostingView {
            hostingView.rootView = AnyView(content)
        } else {
            let hosting = NSHostingView(rootView: AnyView(content))
            hosting.frame = panel.contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(hosting)
            hostingView = hosting
        }
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }
        
        isVisible = true
        startKeyboardMonitor()
    }
    
    func hideSelector() {
        guard let panel = panel else { return }
        
        stopKeyboardMonitor()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.isVisible = false
        }
    }
    
    func selectApp(at index: Int) {
        guard index >= 0 && index < apps.count else { return }
        let app = apps[index]
        hideSelector()
        onAppSelected?(app)
    }
    
    // MARK: - Keyboard Navigation
    
    private func startKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            
            switch event.keyCode {
            case 126: // Up arrow
                self.moveSelection(by: -1)
                return nil
            case 125: // Down arrow
                self.moveSelection(by: 1)
                return nil
            case 36: // Return/Enter
                self.selectApp(at: self.selectedIndex)
                return nil
            case 53: // Escape
                self.hideSelector()
                return nil
            default:
                return event
            }
        }
    }
    
    private func stopKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func moveSelection(by delta: Int) {
        guard !apps.isEmpty else { return }
        var newIndex = selectedIndex + delta
        if newIndex < 0 { newIndex = apps.count - 1 }
        if newIndex >= apps.count { newIndex = 0 }
        selectedIndex = newIndex
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        let styleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView]
        
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.autoresizingMask = [.width, .height]
        
        panel.contentView = visualEffectView
        self.panel = panel
    }
}

// MARK: - App Selector View

struct AppSelectorView: View {
    @ObservedObject var controller: AppSelectorController
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                Text("Select App")
                    .font(.headline)
                Spacer()
                Text(controller.currentHotkeyDisplay)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            
            Divider()
            
            if controller.apps.isEmpty {
                VStack {
                    Spacer()
                    Text("No apps available")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(controller.apps.enumerated()), id: \.element.id) { index, app in
                                AppSelectorRow(
                                    app: app,
                                    isSelected: index == controller.selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    controller.selectApp(at: index)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: controller.selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Label("Navigate", systemImage: "arrow.up.arrow.down")
                Spacer()
                Label("Select", systemImage: "return")
                Spacer()
                Label("Close", systemImage: "escape")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct AppSelectorRow: View {
    let app: AppItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let iconPath = app.iconPath,
                   let image = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text(app.name)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(app.shortcuts?.count ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        )
        .padding(.horizontal, 8)
    }
}


