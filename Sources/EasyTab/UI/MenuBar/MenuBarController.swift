import AppKit

public final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var permMenuItem: NSMenuItem?
    private let permissionsManager: PermissionsManager
    private let loginManager: LoginItemManager

    public init(
        permissionsManager: PermissionsManager = .shared,
        loginManager: LoginItemManager = .shared
    ) {
        self.permissionsManager = permissionsManager
        self.loginManager = loginManager
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "EasyTab")
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "EasyTab v1.0 (Open Source)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let permItem = NSMenuItem(
            title: permissionsManager.isAccessibilityGranted ? "Accessibility: Granted ✅" : "Grant Accessibility Permission ⚠️",
            action: #selector(handlePermissionsClicked),
            keyEquivalent: ""
        )
        permItem.target = self
        self.permMenuItem = permItem
        menu.addItem(permItem)

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = loginManager.isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About EasyTab...", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit EasyTab", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        let isGranted = permissionsManager.isAccessibilityGranted
        permMenuItem?.title = isGranted ? "Accessibility: Granted ✅" : "Grant Accessibility Permission ⚠️"
        permMenuItem?.action = isGranted ? nil : #selector(handlePermissionsClicked)
    }

    @objc private func handlePermissionsClicked() {
        if !permissionsManager.isAccessibilityGranted {
            permissionsManager.promptForAccessibility()
            permissionsManager.openAccessibilitySettings()
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        if loginManager.setLaunchAtLogin(enabled: newState) {
            sender.state = newState ? .on : .off
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "EasyTab"
        alert.informativeText = "Fast, lightweight, 100% free and open-source Alt-Tab window switcher for macOS.\n\nNo subscriptions. No paid features. Zero bloat."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
