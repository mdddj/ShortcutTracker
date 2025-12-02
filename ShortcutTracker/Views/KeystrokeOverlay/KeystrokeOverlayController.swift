import AppKit
import SwiftUI

// MARK: - Enums

extension KeystrokeOverlayController {
    enum OverlayPosition: String, CaseIterable {
        case bottomLeft = "bottomLeft"
        case bottomRight = "bottomRight"
        case topLeft = "topLeft"
        case topRight = "topRight"

        var displayName: String {
            switch self {
            case .bottomLeft: return "Bottom Left"
            case .bottomRight: return "Bottom Right"
            case .topLeft: return "Top Left"
            case .topRight: return "Top Right"
            }
        }

        var icon: String {
            switch self {
            case .bottomLeft: return "arrow.down.left.square"
            case .bottomRight: return "arrow.down.right.square"
            case .topLeft: return "arrow.up.left.square"
            case .topRight: return "arrow.up.right.square"
            }
        }
    }

    enum FontDesign: String, CaseIterable {
        case `default` = "default"
        case rounded = "rounded"
        case monospaced = "monospaced"
        case serif = "serif"

        var displayName: String {
            switch self {
            case .default: return "Default"
            case .rounded: return "Rounded"
            case .monospaced: return "Monospaced"
            case .serif: return "Serif"
            }
        }

        var swiftUIDesign: Font.Design {
            switch self {
            case .default: return .default
            case .rounded: return .rounded
            case .monospaced: return .monospaced
            case .serif: return .serif
            }
        }
    }
}

/// Controller for the keystroke overlay window.
/// Displays pressed keys in a floating overlay for screen recording.
class KeystrokeOverlayController: NSObject, ObservableObject {
    /// Shared instance
    static let shared = KeystrokeOverlayController()

    /// The overlay window
    private var overlayWindow: NSWindow?

    /// Event monitor for global key events
    private var eventMonitor: Any?

    /// Flag to prevent didSet during initialization
    private var isInitializing = true

    /// Currently displayed keystrokes
    @Published var keystrokes: [KeystrokeItem] = []

    /// Settings
    @Published var isEnabled: Bool = false {
        didSet {
            guard !isInitializing else { return }
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
            UserDefaults.standard.set(isEnabled, forKey: "KeystrokeOverlayEnabled")
        }
    }

    @Published var displayDuration: Double = 3.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(displayDuration, forKey: "KeystrokeOverlayDuration")
        }
    }

    @Published var fontSize: CGFloat = 24 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(fontSize, forKey: "KeystrokeOverlayFontSize")
        }
    }

    @Published var textColorHex: String = "#FFFFFF" {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(textColorHex, forKey: "KeystrokeOverlayTextColorHex")
        }
    }

    @Published var isBold: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(isBold, forKey: "KeystrokeOverlayBold")
        }
    }

    @Published var showAllKeys: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showAllKeys, forKey: "KeystrokeOverlayShowAllKeys")
        }
    }

    @Published var maxLines: Int = 3 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(maxLines, forKey: "KeystrokeOverlayMaxLines")
        }
    }

    @Published var fontName: String = "" {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(fontName, forKey: "KeystrokeOverlayFontName")
        }
    }

    @Published var fontDesign: FontDesign = .monospaced {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(fontDesign.rawValue, forKey: "KeystrokeOverlayFontDesign")
        }
    }

    @Published var useCustomFont: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(useCustomFont, forKey: "KeystrokeOverlayUseCustomFont")
        }
    }

    @Published var backgroundColorHex: String = "#000000" {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(backgroundColorHex, forKey: "KeystrokeOverlayBackgroundColorHex")
        }
    }

    @Published var backgroundOpacity: Double = 0.5 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(backgroundOpacity, forKey: "KeystrokeOverlayBackgroundOpacity")
        }
    }

    @Published var cornerRadius: CGFloat = 8 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(cornerRadius, forKey: "KeystrokeOverlayCornerRadius")
        }
    }

    @Published var position: OverlayPosition = .bottomLeft {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(position.rawValue, forKey: "KeystrokeOverlayPosition")
            updateWindowPosition()
        }
    }

    /// Computed property for background NSColor
    var backgroundColor: NSColor {
        NSColor(hex: backgroundColorHex) ?? .black
    }

    /// Get the current NSFont based on settings
    var currentNSFont: NSFont {
        if useCustomFont, !fontName.isEmpty,
           let customFont = NSFont(name: fontName, size: fontSize) {
            return isBold ? NSFontManager.shared.convert(customFont, toHaveTrait: .boldFontMask) : customFont
        }
        // Fall back to system font with design
        let weight: NSFont.Weight = isBold ? .bold : .regular
        return NSFont.systemFont(ofSize: fontSize, weight: weight)
    }

    /// Get SwiftUI Font based on settings
    var currentFont: Font {
        if useCustomFont, !fontName.isEmpty {
            return Font.custom(fontName, size: fontSize)
                .weight(isBold ? .bold : .regular)
        }
        return Font.system(size: fontSize, weight: isBold ? .bold : .regular, design: fontDesign.swiftUIDesign)
    }

    @Published var showMouseClicks: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showMouseClicks, forKey: "KeystrokeOverlayShowMouseClicks")
            if isEnabled {
                if showMouseClicks {
                    startMouseMonitoring()
                } else {
                    stopMouseMonitoring()
                }
            }
        }
    }

    /// Computed property for NSColor
    var textColor: NSColor {
        NSColor(hex: textColorHex) ?? .white
    }

    @Published var showMatchedTitle: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showMatchedTitle, forKey: "KeystrokeOverlayShowMatchedTitle")
        }
    }

    /// Cached shortcuts for matching (keys -> title)
    private var shortcutCache: [String: String] = [:]

    /// Refresh the shortcut cache from the data store
    func refreshShortcutCache(shortcuts: [String: String]) {
        shortcutCache = shortcuts
    }

    /// Find matching shortcut title for the given keys
    private func findMatchingTitle(for keys: String) -> String? {
        guard showMatchedTitle else { return nil }
        // Normalize the keys for comparison
        let normalizedKeys = keys.uppercased()
        return shortcutCache[normalizedKeys]
    }

    override private init() {
        super.init()
        loadSettings()
        isInitializing = false
    }

    private func loadSettings() {
        // Load display duration
        let savedDuration = UserDefaults.standard.double(forKey: "KeystrokeOverlayDuration")
        displayDuration = savedDuration > 0 ? savedDuration : 3.0

        // Load font size
        let savedFontSize = UserDefaults.standard.double(forKey: "KeystrokeOverlayFontSize")
        fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 24

        // Load bold setting
        if UserDefaults.standard.object(forKey: "KeystrokeOverlayBold") != nil {
            isBold = UserDefaults.standard.bool(forKey: "KeystrokeOverlayBold")
        } else {
            isBold = true
        }

        // Load text color
        if let savedHex = UserDefaults.standard.string(forKey: "KeystrokeOverlayTextColorHex") {
            textColorHex = savedHex
        }

        // Load show all keys setting
        showAllKeys = UserDefaults.standard.bool(forKey: "KeystrokeOverlayShowAllKeys")

        // Load max lines
        let savedMaxLines = UserDefaults.standard.integer(forKey: "KeystrokeOverlayMaxLines")
        maxLines = savedMaxLines > 0 ? savedMaxLines : 3

        // Load font design
        if let savedDesign = UserDefaults.standard.string(forKey: "KeystrokeOverlayFontDesign"),
           let design = FontDesign(rawValue: savedDesign) {
            fontDesign = design
        }

        // Load custom font settings
        if let savedFontName = UserDefaults.standard.string(forKey: "KeystrokeOverlayFontName") {
            fontName = savedFontName
        }
        useCustomFont = UserDefaults.standard.bool(forKey: "KeystrokeOverlayUseCustomFont")

        // Load background settings
        if let savedBgHex = UserDefaults.standard.string(forKey: "KeystrokeOverlayBackgroundColorHex") {
            backgroundColorHex = savedBgHex
        }
        let savedBgOpacity = UserDefaults.standard.double(forKey: "KeystrokeOverlayBackgroundOpacity")
        backgroundOpacity = savedBgOpacity > 0 ? savedBgOpacity : 0.5

        let savedCornerRadius = UserDefaults.standard.double(forKey: "KeystrokeOverlayCornerRadius")
        cornerRadius = savedCornerRadius > 0 ? CGFloat(savedCornerRadius) : 8

        // Load position
        if let savedPosition = UserDefaults.standard.string(forKey: "KeystrokeOverlayPosition"),
           let pos = OverlayPosition(rawValue: savedPosition) {
            position = pos
        }

        // Load show mouse clicks
        showMouseClicks = UserDefaults.standard.bool(forKey: "KeystrokeOverlayShowMouseClicks")

        // Load show matched title setting
        if UserDefaults.standard.object(forKey: "KeystrokeOverlayShowMatchedTitle") != nil {
            showMatchedTitle = UserDefaults.standard.bool(forKey: "KeystrokeOverlayShowMatchedTitle")
        } else {
            showMatchedTitle = true
        }

        // Load enabled state last (don't auto-start on launch)
        // isEnabled = UserDefaults.standard.bool(forKey: "KeystrokeOverlayEnabled")
    }

    // MARK: - Window Management

    private func showOverlay() {
        guard overlayWindow == nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let contentView = KeystrokeOverlayView(controller: self)
            let hostingView = NSHostingView(rootView: contentView)
            
            // Set fixed size to prevent constraint issues
            hostingView.translatesAutoresizingMaskIntoConstraints = false

            // Create a borderless, transparent window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            window.contentView = hostingView
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            
            // Disable automatic content size adjustment
            window.contentMinSize = NSSize(width: 400, height: 160)
            window.contentMaxSize = NSSize(width: 400, height: 160)

            self.overlayWindow = window
            self.updateWindowPosition()
            window.orderFront(nil)
        }
    }

    private func updateWindowPosition() {
        guard let window = overlayWindow, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowSize = NSSize(width: 400, height: 160)
        let margin: CGFloat = 40
        
        var origin: NSPoint
        
        switch position {
        case .bottomLeft:
            origin = NSPoint(x: screenFrame.minX + margin, y: screenFrame.minY + margin)
        case .bottomRight:
            origin = NSPoint(x: screenFrame.maxX - windowSize.width - margin, y: screenFrame.minY + margin)
        case .topLeft:
            origin = NSPoint(x: screenFrame.minX + margin, y: screenFrame.maxY - windowSize.height - margin)
        case .topRight:
            origin = NSPoint(x: screenFrame.maxX - windowSize.width - margin, y: screenFrame.maxY - windowSize.height - margin)
        }
        
        let windowFrame = NSRect(origin: origin, size: windowSize)
        window.setFrame(windowFrame, display: true, animate: true)
    }

    private func hideOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.close()
            self?.overlayWindow = nil
        }
    }

    // MARK: - Event Monitoring

    private var localEventMonitor: Any?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    private func startMonitoring() {
        // Request accessibility permission
        requestAccessibilityPermission()

        showOverlay()

        // 2. 本地监听 (App 在前台活跃时生效)
        // 注意：本地监听需要返回 event，否则按键会被“吃掉”，系统听不到声音也打不出字
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event // 必须返回 event，让事件继续传递
        }
        // Monitor global key events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Start mouse monitoring if enabled
        if showMouseClicks {
            startMouseMonitoring()
        }
    }

    private func startMouseMonitoring() {
        // Global mouse monitoring
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleMouseEvent(event)
        }

        // Local mouse monitoring
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }

    private func stopMouseMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        let clickType: String
        switch event.type {
        case .leftMouseDown:
            clickType = "🖱️ Left Click"
        case .rightMouseDown:
            clickType = "🖱️ Right Click"
        case .otherMouseDown:
            clickType = "🖱️ Middle Click"
        default:
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.addKeystroke(clickType)
        }
    }

    private func requestAccessibilityPermission() {
        // 1. 获取 Unmanaged 的值，使用 takeUnretainedValue (不获取所有权)
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

        // 2. 构建字典
        let options: NSDictionary = [promptKey: true]

        // 3. 调用 API
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        print("辅助功能权限状态: \(isTrusted)")
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        // 移除本地监听
        if let localMonitor = localEventMonitor {
            NSEvent.removeMonitor(localMonitor)
            localEventMonitor = nil
        }
        // 移除鼠标监听
        stopMouseMonitoring()
        hideOverlay()
        DispatchQueue.main.async { [weak self] in
            self?.keystrokes.removeAll()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyString = buildKeyString(from: event)
        guard !keyString.isEmpty else { return }

        // Check if we should show this key
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifiers = flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
        
        // Also show function keys without modifiers
        let isFunctionKey = (96 ... 122).contains(Int(event.keyCode))
        
        // If showAllKeys is false, only show keys with modifiers or function keys
        if !showAllKeys {
            guard hasModifiers || isFunctionKey else { return }
        }

        DispatchQueue.main.async { [weak self] in
            self?.addKeystroke(keyString)
        }
    }

    private func addKeystroke(_ keys: String, matchedTitle: String? = nil) {
        let title = matchedTitle ?? findMatchingTitle(for: keys)
        let item = KeystrokeItem(keys: keys, matchedTitle: title)
        let duration = displayDuration

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            keystrokes.insert(item, at: 0)

            // Remove excess keystrokes
            while keystrokes.count > maxLines {
                keystrokes.removeLast()
            }
        }

        // Schedule removal
        let itemId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.keystrokes.removeAll { $0.id == itemId }
            }
        }
    }

    private func buildKeyString(from event: NSEvent) -> String {
        var parts: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        if let key = keyString(for: event.keyCode, with: event.charactersIgnoringModifiers) {
            parts.append(key)
        }

        return parts.joined()
    }

    private func keyString(for keyCode: UInt16, with characters: String?) -> String? {
        let specialKeys: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
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

// MARK: - Keystroke Item

struct KeystrokeItem: Identifiable, Equatable {
    let id = UUID()
    let keys: String
    let matchedTitle: String?  // 匹配到的快捷键操作标题
    let timestamp = Date()

    init(keys: String, matchedTitle: String? = nil) {
        self.keys = keys
        self.matchedTitle = matchedTitle
    }
}

// MARK: - Font Panel Manager

class FontPanelManager: NSObject, NSWindowDelegate {
    static let shared = FontPanelManager()
    
    private var onFontSelected: ((NSFont) -> Void)?
    
    func showFontPanel(currentFont: NSFont, onSelect: @escaping (NSFont) -> Void) {
        onFontSelected = onSelect
        
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(changeFont(_:))
        fontManager.setSelectedFont(currentFont, isMultiple: false)
        
        let fontPanel = fontManager.fontPanel(true)
        fontPanel?.delegate = self
        fontPanel?.makeKeyAndOrderFront(nil)
        
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func changeFont(_ sender: NSFontManager?) {
        guard let fontManager = sender else { return }
        let newFont = fontManager.convert(NSFont.systemFont(ofSize: 24))
        onFontSelected?(newFont)
    }
    
    func windowWillClose(_ notification: Notification) {
        NSFontManager.shared.target = nil
        onFontSelected = nil
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
