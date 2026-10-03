import AppKit
import Darwin

public final class SwitcherHUDPanel: NSPanel {
    private var switcherView: AppKitSwitcherView?
    public var onWindowClicked: ((WindowItem) -> Void)?

    public init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
    }

    public func show(windows: [WindowItem], selectedIndex: Int) {
        WindowThumbnailCache.shared.clear()

        let view = AppKitSwitcherView(windows: windows, selectedIndex: selectedIndex)
        view.onWindowClicked = { [weak self] targetWin in
            self?.onWindowClicked?(targetWin)
        }
        self.switcherView = view
        self.contentView = view

        reposition(for: view.calculatePreferredSize())
        self.orderFrontRegardless()
    }

    public func updateSelection(selectedIndex: Int) {
        switcherView?.updateSelection(selectedIndex)
    }

    public func enterSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        switcherView?.enterSearch(query: query, selectedIndex: selectedIndex, matchedIndices: matchedIndices)
    }

    public func updateSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        switcherView?.updateSearch(query: query, selectedIndex: selectedIndex, matchedIndices: matchedIndices)
    }

    public func hide() {
        self.orderOut(nil)
        switcherView?.teardown()
        self.contentView = nil
        self.switcherView = nil
        WindowThumbnailCache.shared.clear()

        // Pressure relief on malloc zone to return freed pages immediately to kernel
        malloc_zone_pressure_relief(malloc_default_zone(), 0)
    }

    private func reposition(for size: NSSize) {
        // Target screen where the mouse pointer currently is
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let screenFrame = targetScreen.visibleFrame
        let x = screenFrame.midX - (size.width / 2)
        let y = screenFrame.midY - (size.height / 2)

        self.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
