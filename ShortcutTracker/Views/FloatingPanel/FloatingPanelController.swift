import AppKit
import SwiftUI
import Combine

/// Custom NSPanel subclass that can become key window for text input
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Override to maintain floating behavior
    override func orderOut(_ sender: Any?) {
        // Don't hide when losing focus if we're supposed to be floating
        if level == .floating {
            return
        }
        super.orderOut(sender)
    }
}

/// Controller for managing the floating panel window.
/// Uses NSPanel to create a floating, draggable, transparent overlay window.
/// Supports state synchronization with the main window selection.
/// Requirements: 4.1, 4.2, 4.3, 4.7
class FloatingPanelController: NSObject, ObservableObject {
    /// The NSPanel instance for the floating window
    private var panel: KeyablePanel?
    
    /// The hosting view for SwiftUI content
    private var hostingView: NSHostingView<AnyView>?
    
    /// Published property to track if panel is visible
    @Published var isVisible: Bool = false
    
    /// Published property to track if panel is pinned (always on top)
    @Published var isPinned: Bool = true
    
    /// Published property for panel transparency (0.0 to 1.0)
    @Published var transparency: CGFloat = 1.0
    
    /// Default panel size
    private let defaultSize = NSSize(width: 320, height: 400)
    
    /// Minimum panel size
    private let minSize = NSSize(width: 250, height: 200)
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Shows the floating panel with the specified SwiftUI content.
    /// - Parameter content: The SwiftUI view to display in the panel
    /// Requirements: 4.1, 9.2
    func showPanel<Content: View>(with content: Content) {
        if panel == nil {
            createPanel()
        }
        
        guard let panel = panel else { return }
        
        // Wrap content in AnyView for type erasure
        let wrappedContent = AnyView(content)
        
        if let hostingView = hostingView {
            hostingView.rootView = wrappedContent
        } else {
            let hosting = NSHostingView(rootView: wrappedContent)
            hosting.frame = panel.contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(hosting)
            hostingView = hosting
        }
        
        // Animate fade in
        panel.alphaValue = 0.0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)  // Activate app to receive keyboard input
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = transparency
        }
        
        isVisible = true
    }

    
    /// Hides the floating panel with fade out animation.
    /// Requirements: 9.2
    func hidePanel() {
        guard let panel = panel else {
            isVisible = false
            return
        }
        
        // Animate fade out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.isVisible = false
        }
    }
    
    /// Toggles the panel visibility.
    func togglePanel<Content: View>(with content: Content) {
        if isVisible {
            hidePanel()
        } else {
            showPanel(with: content)
        }
    }
    
    /// Toggles the pin state of the panel.
    /// When pinned, the panel stays above all other windows.
    /// - Parameter pinned: Whether the panel should be pinned
    /// Requirements: 4.4
    func togglePin(_ pinned: Bool) {
        isPinned = pinned
        updatePanelLevel()
    }
    
    /// Toggles the pin state of the panel.
    func togglePin() {
        isPinned.toggle()
        updatePanelLevel()
    }
    
    /// Sets the transparency of the panel with smooth animation.
    /// - Parameter alpha: The alpha value between 0.0 (fully transparent) and 1.0 (fully opaque)
    /// - Parameter animated: Whether to animate the transparency change (default: true)
    /// Requirements: 4.5, 9.2
    func setTransparency(_ alpha: CGFloat, animated: Bool = true) {
        // Clamp value between 0.0 and 1.0
        let clampedAlpha = max(0.0, min(1.0, alpha))
        transparency = clampedAlpha
        
        guard let panel = panel else { return }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = clampedAlpha
            }
        } else {
            panel.alphaValue = clampedAlpha
        }
    }
    
    /// Updates the content of the panel without recreating it.
    /// - Parameter content: The new SwiftUI view to display
    func updateContent<Content: View>(with content: Content) {
        guard let hostingView = hostingView else {
            showPanel(with: content)
            return
        }
        hostingView.rootView = AnyView(content)
    }
    
    /// Closes and releases the panel resources.
    func closePanel() {
        panel?.close()
        panel = nil
        hostingView = nil
        isVisible = false
    }
    
    // MARK: - Private Methods
    
    /// Creates and configures the NSPanel.
    /// Requirements: 4.1, 4.7
    private func createPanel() {
        // Create panel with borderless style but using custom subclass for key window support
        let styleMask: NSWindow.StyleMask = [
            .borderless,
            .resizable,
            .fullSizeContentView
        ]
        
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        // Configure panel properties
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.minSize = minSize
        panel.hidesOnDeactivate = false  // 防止失去焦点时隐藏
        
        // Set initial level based on pin state
        panel.level = isPinned ? .floating : .normal
        
        // Center the panel on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelX = screenFrame.midX - defaultSize.width / 2
            let panelY = screenFrame.midY - defaultSize.height / 2
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        }
        
        // Create content view with visual effect for background
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: defaultSize))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.autoresizingMask = [.width, .height]
        
        panel.contentView = visualEffectView
        
        // Apply initial transparency
        panel.alphaValue = transparency
        
        self.panel = panel
    }
    
    /// Updates the panel's window level based on pin state.
    private func updatePanelLevel() {
        guard let panel = panel else { return }
        panel.level = isPinned ? .floating : .normal
        panel.hidesOnDeactivate = !isPinned  // 只有非置顶时才允许隐藏
        
        // 如果是置顶状态，确保窗口可见
        if isPinned && !panel.isVisible {
            panel.orderFront(nil)
        }
    }
}
