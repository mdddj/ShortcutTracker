import Foundation
import Combine

/// ViewModel for managing the floating panel state.
/// Handles pin state and transparency settings.
/// Requirements: 4.4, 4.5
@Observable
class FloatingPanelViewModel {
    /// Whether the panel is pinned (always on top)
    /// Requirements: 4.4
    var isPinned: Bool = true {
        didSet {
            panelController?.togglePin(isPinned)
        }
    }
    
    /// The transparency level of the panel (0.0 to 1.0)
    /// Requirements: 4.5
    var transparency: CGFloat = 1.0 {
        didSet {
            panelController?.setTransparency(transparency)
        }
    }
    
    /// Whether the panel content is collapsed
    var isCollapsed: Bool = false {
        didSet {
            let height: CGFloat = isCollapsed ? 50 : 400
            panelController?.resizePanel(height: height)
        }
    }
    
    /// Whether the panel is currently visible
    var isVisible: Bool {
        panelController?.isVisible ?? false
    }
    
    /// Reference to the panel controller
    private var panelController: FloatingPanelController?
    
    /// Reference to the app view model for accessing selected app
    private weak var appViewModel: AppViewModel?
    
    /// Reference to the data service for persistence
    private var dataService: DataService?
    
    /// Creates a new FloatingPanelViewModel.
    /// - Parameters:
    ///   - panelController: The FloatingPanelController to manage
    ///   - appViewModel: The AppViewModel for accessing selected app data
    ///   - dataService: The DataService for persistence operations
    init(panelController: FloatingPanelController? = nil, appViewModel: AppViewModel? = nil, dataService: DataService? = nil) {
        self.panelController = panelController
        self.appViewModel = appViewModel
        self.dataService = dataService
    }
    
    // MARK: - Public Methods
    
    /// Sets the panel controller reference.
    /// - Parameter controller: The FloatingPanelController to use
    func setPanelController(_ controller: FloatingPanelController) {
        self.panelController = controller
        // Sync initial state
        controller.togglePin(isPinned)
        controller.setTransparency(transparency)
    }
    
    /// Sets the app view model reference.
    /// - Parameter viewModel: The AppViewModel to use
    func setAppViewModel(_ viewModel: AppViewModel) {
        self.appViewModel = viewModel
    }
    
    /// Toggles the pin state of the panel.
    /// Requirements: 4.4
    func togglePin() {
        isPinned.toggle()
    }
    
    /// Toggles the collapsed state of the panel.
    func toggleCollapse() {
        isCollapsed.toggle()
    }
    
    /// Sets the transparency of the panel.
    /// - Parameter value: The transparency value between 0.0 and 1.0
    /// Requirements: 4.5
    func setTransparency(_ value: CGFloat) {
        // Clamp value between 0.0 and 1.0
        transparency = max(0.0, min(1.0, value))
    }
    
    /// Returns the shortcuts for the currently selected app.
    var currentShortcuts: [ShortcutItem] {
        appViewModel?.selectedApp?.shortcuts ?? []
    }
    
    /// Returns the currently selected app.
    var selectedApp: AppItem? {
        appViewModel?.selectedApp
    }
    
    /// Returns the name of the currently selected app, or a default string.
    var selectedAppName: String {
        appViewModel?.selectedApp?.name ?? "No App Selected"
    }
    
    /// Sets the data service reference.
    /// - Parameter service: The DataService to use
    func setDataService(_ service: DataService) {
        self.dataService = service
    }
    
    /// Adds a new shortcut to the specified app.
    /// - Parameters:
    ///   - title: The title of the shortcut
    ///   - keys: The key combination
    ///   - category: Optional category
    ///   - app: The app to add the shortcut to
    func addShortcut(title: String, keys: String, category: String?, to app: AppItem) {
        guard let dataService = dataService else { return }
        
        let shortcut = ShortcutItem(
            title: title,
            keys: keys,
            description: nil,
            category: category
        )
        
        dataService.addShortcut(shortcut, to: app)
        
        // Notify that shortcuts changed
        appViewModel?.loadApps()
    }
}
