import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate, EventTapDelegate,
    @unchecked Sendable
{
    private let engine = SwitcherEngine()
    private let windowProvider = SystemWindowProvider.shared
    private let focusManager = WindowFocusManager.shared
    private let eventInterceptor = EventTapInterceptor()
    private var hudPanel: SwitcherHUDPanel?
    private var menuBarController: MenuBarController?

    private var permissionTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background menu bar accessory (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        let hud = SwitcherHUDPanel()
        hud.onWindowClicked = { [weak self] window in
            self?.hudPanel?.hide()
            self?.focusManager.focus(window: window)
        }
        self.hudPanel = hud

        self.menuBarController = MenuBarController()

        eventInterceptor.delegate = self

        startMonitoringPermissions()
    }

    private func startMonitoringPermissions() {
        // 1. Try starting the interceptor directly. If accessibility is already granted,
        // eventInterceptor.start() succeeds immediately with ZERO system dialogs.
        if eventInterceptor.start() {
            print("🚀 Accessibility granted! Press Command+Tab to switch windows.")
            return
        }

        // 2. Only if the interceptor failed, prompt the user to enable Accessibility
        PermissionsManager.shared.promptForAccessibility()
        print("⚠️ Please enable Accessibility in System Settings.")

        // 3. Poll every 1.0s until accessibility is granted and interceptor starts
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.eventInterceptor.start() {
                print("🚀 Accessibility granted! Press Command+Tab to switch windows.")
                timer.invalidate()
                self.permissionTimer = nil
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
        eventInterceptor.stop()
    }

    // MARK: - EventTapDelegate

    public func isSwitcherActive() -> Bool {
        return engine.state.isShowing
    }

    public func isSearchActive() -> Bool {
        return engine.state.isSearching
    }

    public func onTabPressed() {
        let action = engine.handleTab {
            return self.windowProvider.getVisibleWindowsSync()
        }
        execute(action: action)
    }

    public func onModifierReleased() {
        let action = engine.handleModifierRelease()
        execute(action: action)
    }

    public func onCancelPressed() {
        let action = engine.handleCancel()
        execute(action: action)
    }

    public func onSearchActivated() {
        let action = engine.handleSearchToggle()
        execute(action: action)
    }

    public func onSearchInput(_ char: Character) {
        let action = engine.handleSearchInput(char)
        execute(action: action)
    }

    public func onSearchBackspace() {
        let action = engine.handleSearchBackspace()
        execute(action: action)
    }

    public func onEnterPressed() {
        let action = engine.handleEnter()
        execute(action: action)
    }

    // MARK: - Action Execution

    private func execute(action: SwitcherAction) {
        switch action {
        case .none:
            break

        case .showHUD(let windows, let selectedIndex):
            hudPanel?.show(windows: windows, selectedIndex: selectedIndex)

        case .updateSelection(let selectedIndex):
            hudPanel?.updateSelection(selectedIndex: selectedIndex)

        case .enterSearch(let query, let selectedIndex, let matchedIndices):
            hudPanel?.enterSearch(query: query, selectedIndex: selectedIndex, matchedIndices: matchedIndices)

        case .updateSearch(let query, let selectedIndex, let matchedIndices):
            hudPanel?.updateSearch(query: query, selectedIndex: selectedIndex, matchedIndices: matchedIndices)

        case .focusAndDismiss(let window):
            hudPanel?.hide()
            focusManager.focus(window: window)

        case .dismiss:
            hudPanel?.hide()
        }
    }
}
