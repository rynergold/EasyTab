import Foundation

public enum SwitcherState: Sendable, Equatable {
    case idle
    case active(windows: [WindowItem], selectedIndex: Int)

    public var isShowing: Bool {
        if case .active = self { return true }
        return false
    }

    public var selectedWindow: WindowItem? {
        if case .active(let windows, let index) = self, index >= 0, index < windows.count {
            return windows[index]
        }
        return nil
    }
}

public enum SwitcherAction: Sendable, Equatable {
    case none
    case showHUD(windows: [WindowItem], selectedIndex: Int)
    case updateSelection(selectedIndex: Int)
    case focusAndDismiss(window: WindowItem)
    case dismiss
}

public final class SwitcherEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var _state: SwitcherState = .idle

    public init() {}

    public var state: SwitcherState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    @discardableResult
    public func handleTab(windowsProvider: () -> [WindowItem]) -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        switch _state {
        case .idle:
            let windows = windowsProvider()
            guard !windows.isEmpty else {
                return .none
            }

            // Alt-Tab behavior: 1st press selects 2nd window (index 1) in MRU list
            let initialIndex = windows.count == 1 ? 0 : 1
            _state = .active(windows: windows, selectedIndex: initialIndex)
            return .showHUD(windows: windows, selectedIndex: initialIndex)

        case .active(let windows, let currentIndex):
            guard !windows.isEmpty else {
                _state = .idle
                return .dismiss
            }

            let nextIndex = (currentIndex + 1) % windows.count
            _state = .active(windows: windows, selectedIndex: nextIndex)
            return .updateSelection(selectedIndex: nextIndex)
        }
    }

    @discardableResult
    public func handleModifierRelease() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        guard case .active(let windows, let currentIndex) = _state else {
            return .none
        }

        _state = .idle

        if currentIndex >= 0 && currentIndex < windows.count {
            let targetWindow = windows[currentIndex]
            return .focusAndDismiss(window: targetWindow)
        }

        return .dismiss
    }

    @discardableResult
    public func handleCancel() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        guard case .active = _state else {
            return .none
        }

        _state = .idle
        return .dismiss
    }
}
