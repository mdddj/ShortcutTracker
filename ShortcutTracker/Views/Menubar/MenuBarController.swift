import AppKit
import SwiftUI

/// Controller for managing the menu bar status item and popover.
/// Uses NSStatusBar to create a persistent menu bar icon with popover display.
/// Requirements: 5.1, 5.2
class MenuBarController: NSObject, ObservableObject {
    /// The status item in the menu bar
    private var statusItem: NSStatusItem?
    
    /// The popover for displaying content
    private var popover: NSPopover?
    
    /// Event monitor for detecting clicks outside the popover
    private var eventMonitor: Any?
    
    /// Published property to track if popover is visible
    @Published var isPopoverVisible: Bool = false
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Sets up the menu bar status item with a keyboard icon.
    /// Requirements: 5.1
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ShortcutTracker")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    /// Shows the popover with the specified SwiftUI content.
    /// - Parameter content: The SwiftUI view to display in the popover
    /// Requirements: 5.2
    func showPopover<Content: View>(with content: Content) {
        guard let button = statusItem?.button else { return }
        
        if popover == nil {
            createPopover()
        }
        
        guard let popover = popover else { return }
        
        // Set the content
        let hostingController = NSHostingController(rootView: content)
        popover.contentViewController = hostingController
        
        // Show the popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverVisible = true
        
        // Start monitoring for clicks outside
        startEventMonitor()
    }

    
    /// Hides the popover.
    func hidePopover() {
        popover?.performClose(nil)
        isPopoverVisible = false
        stopEventMonitor()
    }
    
    /// Toggles the popover visibility.
    @objc func togglePopover() {
        if isPopoverVisible {
            hidePopover()
        } else {
            // Notify that popover should be shown
            // The actual content will be provided by the app
            NotificationCenter.default.post(name: .menuBarPopoverToggled, object: nil)
        }
    }
    
    /// Updates the popover content without recreating it.
    /// - Parameter content: The new SwiftUI view to display
    func updateContent<Content: View>(with content: Content) {
        guard let popover = popover else {
            showPopover(with: content)
            return
        }
        
        let hostingController = NSHostingController(rootView: content)
        popover.contentViewController = hostingController
    }
    
    /// Removes the status item from the menu bar.
    func removeStatusItem() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        hidePopover()
    }
    
    // MARK: - Private Methods
    
    /// Creates and configures the popover.
    private func createPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 400)
        self.popover = popover
    }
    
    /// Starts monitoring for mouse events outside the popover.
    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.isPopoverVisible == true {
                self?.hidePopover()
            }
        }
    }
    
    /// Stops monitoring for mouse events.
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the menu bar popover should be toggled
    static let menuBarPopoverToggled = Notification.Name("menuBarPopoverToggled")
    /// Posted when the main window should be opened
    static let openMainWindow = Notification.Name("openMainWindow")
    /// Posted when the floating panel should be opened
    static let openFloatingPanel = Notification.Name("openFloatingPanel")
    /// Posted when the AI import view should be opened
    static let openAIImport = Notification.Name("openAIImport")
    /// Posted when the settings view should be opened
    static let openSettings = Notification.Name("openSettings")
    /// Posted when the selected app changes (for state synchronization)
    /// Requirements: 3.2, 4.2, 5.2
    static let selectedAppChanged = Notification.Name("selectedAppChanged")
    /// Posted when shortcuts data changes (for keystroke overlay cache refresh)
    static let shortcutsDidChange = Notification.Name("shortcutsDidChange")
    /// Request app list for app selector
    static let requestAppList = Notification.Name("requestAppList")
}
