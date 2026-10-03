import Foundation

public enum SwitcherState: Sendable, Equatable {
    case idle
    case active(windows: [WindowItem], selectedIndex: Int)
    case searching(windows: [WindowItem], query: String, matchedIndices: [Int], selectedMatchIndex: Int)

    public var isShowing: Bool {
        switch self {
        case .idle: return false
        case .active, .searching: return true
        }
    }

    public var isSearching: Bool {
        if case .searching = self { return true }
        return false
    }

    public var selectedWindow: WindowItem? {
        switch self {
        case .idle:
            return nil
        case .active(let windows, let index):
            guard index >= 0 && index < windows.count else { return nil }
            return windows[index]
        case .searching(let windows, _, let matchedIndices, let selIdx):
            guard selIdx >= 0 && selIdx < matchedIndices.count else { return nil }
            let actualIdx = matchedIndices[selIdx]
            guard actualIdx >= 0 && actualIdx < windows.count else { return nil }
            return windows[actualIdx]
        }
    }
}

public enum SwitcherAction: Sendable, Equatable {
    case none
    case showHUD(windows: [WindowItem], selectedIndex: Int)
    case updateSelection(selectedIndex: Int)
    case enterSearch(query: String, selectedIndex: Int, matchedIndices: [Int])
    case updateSearch(query: String, selectedIndex: Int, matchedIndices: [Int])
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

        case .searching(let windows, let query, let matchedIndices, let selectedMatchIndex):
            guard !matchedIndices.isEmpty else {
                return .none
            }

            let nextMatch = (selectedMatchIndex + 1) % matchedIndices.count
            _state = .searching(
                windows: windows,
                query: query,
                matchedIndices: matchedIndices,
                selectedMatchIndex: nextMatch
            )
            let targetIndex = matchedIndices[nextMatch]
            return .updateSearch(query: query, selectedIndex: targetIndex, matchedIndices: matchedIndices)
        }
    }

    @discardableResult
    public func handleSearchToggle() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        switch _state {
        case .active(let windows, let selectedIndex):
            let allIndices = Array(0..<windows.count)
            _state = .searching(
                windows: windows,
                query: "",
                matchedIndices: allIndices,
                selectedMatchIndex: selectedIndex
            )
            return .enterSearch(query: "", selectedIndex: selectedIndex, matchedIndices: allIndices)

        case .searching, .idle:
            return .none
        }
    }

    @discardableResult
    public func handleSearchInput(_ char: Character) -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        guard case .searching(let windows, let query, _, _) = _state else {
            return .none
        }

        let newQuery = query + String(char)
        return evaluateQuery(newQuery, windows: windows)
    }

    @discardableResult
    public func handleSearchBackspace() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        guard case .searching(let windows, var query, _, _) = _state else {
            return .none
        }

        if !query.isEmpty {
            query.removeLast()
        }
        return evaluateQuery(query, windows: windows)
    }

    private func evaluateQuery(_ query: String, windows: [WindowItem]) -> SwitcherAction {
        if query.isEmpty {
            let allIndices = Array(0..<windows.count)
            _state = .searching(
                windows: windows,
                query: "",
                matchedIndices: allIndices,
                selectedMatchIndex: 0
            )
            return .updateSearch(query: "", selectedIndex: allIndices.first ?? 0, matchedIndices: allIndices)
        }

        let q = query.lowercased()
        var matches: [Int] = []

        // 1. App name prefix match
        for (i, w) in windows.enumerated() {
            if w.appName.lowercased().hasPrefix(q) {
                matches.append(i)
            }
        }
        // 2. App name substring match
        for (i, w) in windows.enumerated() {
            if !matches.contains(i) && w.appName.lowercased().contains(q) {
                matches.append(i)
            }
        }
        // 3. Window title substring match
        for (i, w) in windows.enumerated() {
            if !matches.contains(i) && w.title.lowercased().contains(q) {
                matches.append(i)
            }
        }

        let targetIdx = matches.first ?? -1
        _state = .searching(
            windows: windows,
            query: query,
            matchedIndices: matches,
            selectedMatchIndex: 0
        )
        return .updateSearch(query: query, selectedIndex: targetIdx, matchedIndices: matches)
    }

    @discardableResult
    public func handleEnter() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        switch _state {
        case .searching(let windows, _, let matchedIndices, let selectedMatchIndex):
            guard !matchedIndices.isEmpty,
                  selectedMatchIndex >= 0,
                  selectedMatchIndex < matchedIndices.count else {
                return .none
            }
            let targetWindow = windows[matchedIndices[selectedMatchIndex]]
            _state = .idle
            return .focusAndDismiss(window: targetWindow)

        case .active(let windows, let selectedIndex):
            guard selectedIndex >= 0, selectedIndex < windows.count else {
                return .none
            }
            let targetWindow = windows[selectedIndex]
            _state = .idle
            return .focusAndDismiss(window: targetWindow)

        case .idle:
            return .none
        }
    }

    @discardableResult
    public func handleModifierRelease() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        switch _state {
        case .searching:
            // Latch open: Releasing Command in search mode is intentionally a no-op
            // so the user can type freely without premature switching.
            return .none

        case .active(let windows, let currentIndex):
            _state = .idle
            if currentIndex >= 0 && currentIndex < windows.count {
                let targetWindow = windows[currentIndex]
                return .focusAndDismiss(window: targetWindow)
            }
            return .dismiss

        case .idle:
            return .none
        }
    }

    @discardableResult
    public func handleCancel() -> SwitcherAction {
        lock.lock()
        defer { lock.unlock() }

        guard _state.isShowing else {
            return .none
        }

        _state = .idle
        return .dismiss
    }
}
