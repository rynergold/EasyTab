import Testing
@testable import EasyTab

@Suite("SwitcherEngine State Machine Tests")
struct SwitcherEngineTests {

    private func makeSampleWindows(count: Int) -> [WindowItem] {
        return (0..<count).map { i in
            WindowItem(
                id: UInt32(i + 1),
                pid: Int32(100 + i),
                appName: "App \(i)",
                title: "Window \(i)"
            )
        }
    }

    // ==========================================
    // 1. HAPPY PATHS
    // ==========================================

    @Test("Initial Tab selects second window (MRU index 1) in multi-window scenario")
    func testInitialTabForward() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)

        let action = engine.handleTab { windows }

        #expect(action == .showHUD(windows: windows, selectedIndex: 1))
        #expect(engine.state == .active(windows: windows, selectedIndex: 1))
    }

    @Test("Initial Tab with single window selects index 0")
    func testSingleWindow() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 1)

        let action = engine.handleTab { windows }

        #expect(action == .showHUD(windows: windows, selectedIndex: 0))
        #expect(engine.state == .active(windows: windows, selectedIndex: 0))
    }

    @Test("Command release triggers focus and dismisses HUD")
    func testModifierRelease() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)

        _ = engine.handleTab { windows } // index 1

        let action = engine.handleModifierRelease()
        #expect(action == .focusAndDismiss(window: windows[1]))
        #expect(engine.state == .idle)
    }

    @Test("Search mode activation latches window open across Command release")
    func testSearchToggleAndLatching() {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "GitHub - rynergold/EasyTab"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh - ~/Developer"),
            WindowItem(id: 3, pid: 103, appName: "Antigravity", title: "EasyTab Workspace")
        ]
        _ = engine.handleTab { windows } // index 1 (Ghostty)

        let searchAction = engine.handleSearchToggle()
        #expect(searchAction == .enterSearch(query: "", selectedIndex: 1, matchedIndices: [0, 1, 2]))
        #expect(engine.state.isSearching == true)

        let releaseAction = engine.handleModifierRelease()
        #expect(releaseAction == .none)
        #expect(engine.state.isSearching == true)
    }

    @Test("Real-time keystroke search updates filtered matches and Enter confirms")
    func testSearchTypingAndEnterConfirmation() {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "GitHub - rynergold/EasyTab"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh - ~/Developer"),
            WindowItem(id: 3, pid: 103, appName: "Antigravity", title: "EasyTab Workspace")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        _ = engine.handleSearchInput("a")
        _ = engine.handleSearchInput("n")
        let matchAction = engine.handleSearchInput("t")
        #expect(matchAction == .updateSearch(query: "ant", selectedIndex: 2, matchedIndices: [2]))
        #expect(engine.state.selectedWindow?.appName == "Antigravity")

        let enterAction = engine.handleEnter()
        #expect(enterAction == .focusAndDismiss(window: windows[2]))
        #expect(engine.state == .idle)
    }

    // ==========================================
    // 2. OBVIOUS BAD CASES
    // ==========================================

    @Test("Initial Tab with empty window list is a graceful no-op")
    func testEmptyWindows() {
        let engine = SwitcherEngine()

        let action = engine.handleTab { [] }

        #expect(action == .none)
        #expect(engine.state == .idle)
    }

    @Test("Search backspace with no query recovers full window list gracefully")
    func testSearchBackspaceRecovery() {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Slack", title: "General"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        _ = engine.handleSearchInput("z")
        let backAction = engine.handleSearchBackspace()
        #expect(backAction == .updateSearch(query: "", selectedIndex: 0, matchedIndices: [0, 1]))
    }

    // ==========================================
    // 3. EDGE CASES
    // ==========================================

    @Test("Rapid Tab cycling forward and circular wrap-around to index 0")
    func testCyclingForward() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)

        // Starts at index 1
        _ = engine.handleTab { windows }

        // Next -> index 2
        let action2 = engine.handleTab { windows }
        #expect(action2 == .updateSelection(selectedIndex: 2))

        // Next -> wrap around to 0
        let action0 = engine.handleTab { windows }
        #expect(action0 == .updateSelection(selectedIndex: 0))

        // Next -> index 1
        let action1 = engine.handleTab { windows }
        #expect(action1 == .updateSelection(selectedIndex: 1))
    }

    @Test("Escape key cancels switcher without focusing")
    func testCancel() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)

        _ = engine.handleTab { windows }

        let action = engine.handleCancel()
        #expect(action == .dismiss)
        #expect(engine.state == .idle)
    }

    @Test("Tab cycling across filtered search matches wraps circularly")
    func testSearchTabCycling() {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "Tab 1"),
            WindowItem(id: 2, pid: 102, appName: "Brave Browser", title: "Tab 2"),
            WindowItem(id: 3, pid: 103, appName: "Slack", title: "General")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        _ = engine.handleSearchInput("b")
        _ = engine.handleSearchInput("r")

        let tab1 = engine.handleTab { windows }
        #expect(tab1 == .updateSearch(query: "br", selectedIndex: 1, matchedIndices: [0, 1]))

        let tab2 = engine.handleTab { windows }
        #expect(tab2 == .updateSearch(query: "br", selectedIndex: 0, matchedIndices: [0, 1]))
    }
}
