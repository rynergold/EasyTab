import Foundation

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        print("❌ Assertion Failed: [\(file):\(line)]")
        print("   Expected: \(expected)")
        print("   Got:      \(actual)")
        if !message.isEmpty { print("   Note:     \(message)") }
        exit(1)
    }
}

func makeSampleWindows(count: Int) -> [WindowItem] {
    return (0..<count).map { i in
        WindowItem(
            id: UInt32(i + 1),
            pid: Int32(100 + i),
            appName: "App \(i)",
            title: "Window \(i)"
        )
    }
}

func runAllTests() {
    print("🚀 Running EasyTab Test Suite...")

    // ==========================================
    // 1. HAPPY PATHS
    // ==========================================
    print("\n  [1. Happy Paths]")

    // 1.1 Initial Tab Forward (MRU selection)
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        let action = engine.handleTab { windows }
        assertEqual(action, .showHUD(windows: windows, selectedIndex: 1), "Initial tab should select index 1 (2nd window)")
        assertEqual(engine.state, .active(windows: windows, selectedIndex: 1))
        print("  ✅ 1. Initial Tab selects second window (MRU index 1) in multi-window scenario")
    }

    // 1.2 Single Window Selection
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 1)
        let action = engine.handleTab { windows }
        assertEqual(action, .showHUD(windows: windows, selectedIndex: 0), "Single window should select index 0")
        assertEqual(engine.state, .active(windows: windows, selectedIndex: 0))
        print("  ✅ 2. Initial Tab with single window selects index 0")
    }

    // 1.3 Command Release -> Focus & Dismiss
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        _ = engine.handleTab { windows } // index 1

        let action = engine.handleModifierRelease()
        assertEqual(action, .focusAndDismiss(window: windows[1]))
        assertEqual(engine.state, .idle)
        print("  ✅ 3. Command release triggers focus and dismisses HUD")
    }

    // 1.4 Search Mode Activation & Command Latch
    do {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "GitHub - rynergold/EasyTab"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh - ~/Developer"),
            WindowItem(id: 3, pid: 103, appName: "Antigravity", title: "EasyTab Workspace")
        ]
        _ = engine.handleTab { windows } // index 1 (Ghostty)

        // Toggle Search
        let searchAction = engine.handleSearchToggle()
        assertEqual(searchAction, .enterSearch(query: "", selectedIndex: 1, matchedIndices: [0, 1, 2]))
        assertEqual(engine.state.isSearching, true)

        // Releasing modifier while searching MUST be a no-op (latching open)
        let releaseAction = engine.handleModifierRelease()
        assertEqual(releaseAction, .none, "Modifier release in search mode must not dismiss")
        assertEqual(engine.state.isSearching, true)
        print("  ✅ 4. Search mode activation latches window open across Command release")
    }

    // 1.5 Real-time Keystroke Search & Enter Confirmation
    do {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "GitHub - rynergold/EasyTab"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh - ~/Developer"),
            WindowItem(id: 3, pid: 103, appName: "Antigravity", title: "EasyTab Workspace")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        // Type 'a' -> 'n' -> 't' matches Antigravity (index 2)
        _ = engine.handleSearchInput("a")
        _ = engine.handleSearchInput("n")
        let matchAction = engine.handleSearchInput("t")
        assertEqual(matchAction, .updateSearch(query: "ant", selectedIndex: 2, matchedIndices: [2]))
        assertEqual(engine.state.selectedWindow?.appName, "Antigravity")

        // Press Enter to focus match
        let enterAction = engine.handleEnter()
        assertEqual(enterAction, .focusAndDismiss(window: windows[2]))
        assertEqual(engine.state, .idle)
        print("  ✅ 5. Real-time keystroke search updates filtered matches and Enter confirms")
    }

    // ==========================================
    // 2. OBVIOUS BAD CASES
    // ==========================================
    print("\n  [2. Obvious Bad Cases]")

    // 2.1 Empty Windows Graceful No-Op
    do {
        let engine = SwitcherEngine()
        let action = engine.handleTab { [] }
        assertEqual(action, .none, "Empty windows should be no-op")
        assertEqual(engine.state, .idle)
        print("  ✅ 6. Initial Tab with empty window list is a graceful no-op")
    }

    // 2.2 Search Backspace & Recovery with Empty Query
    do {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Slack", title: "General"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        _ = engine.handleSearchInput("z") // Non-matching query
        let backAction = engine.handleSearchBackspace()
        assertEqual(backAction, .updateSearch(query: "", selectedIndex: 0, matchedIndices: [0, 1]))
        print("  ✅ 7. Search backspace with no query recovers full window list gracefully")
    }

    // ==========================================
    // 3. EDGE CASES
    // ==========================================
    print("\n  [3. Edge Cases]")

    // 3.1 Rapid Forward Cycling & Circular Wrap Around
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        _ = engine.handleTab { windows } // index 1
        
        let a2 = engine.handleTab { windows }
        assertEqual(a2, .updateSelection(selectedIndex: 2))

        let a0 = engine.handleTab { windows }
        assertEqual(a0, .updateSelection(selectedIndex: 0), "Should wrap to 0")

        let a1 = engine.handleTab { windows }
        assertEqual(a1, .updateSelection(selectedIndex: 1), "Should advance to 1")
        print("  ✅ 8. Rapid Tab cycling forward and circular wrap-around to index 0")
    }

    // 3.2 Cancel via Escape
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        _ = engine.handleTab { windows }

        let action = engine.handleCancel()
        assertEqual(action, .dismiss)
        assertEqual(engine.state, .idle)
        print("  ✅ 9. Escape key cancels switcher without focusing")
    }

    // 3.3 Tab Cycling Across Filtered Matches
    do {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "Tab 1"),
            WindowItem(id: 2, pid: 102, appName: "Brave Browser", title: "Tab 2"),
            WindowItem(id: 3, pid: 103, appName: "Slack", title: "General")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        _ = engine.handleSearchInput("b")
        _ = engine.handleSearchInput("r") // Matches indices 0 and 1

        // Tab cycles between match 0 and match 1
        let tab1 = engine.handleTab { windows }
        assertEqual(tab1, .updateSearch(query: "br", selectedIndex: 1, matchedIndices: [0, 1]))

        let tab2 = engine.handleTab { windows }
        assertEqual(tab2, .updateSearch(query: "br", selectedIndex: 0, matchedIndices: [0, 1]))
        print("  ✅ 10. Tab cycling across filtered search matches wraps circularly")
    }

    print("\n🎉 ALL TESTS PASSED SUCCESSFULLY! (0 Failures)\n")
}

@main
struct TestRunnerMain {
    static func main() {
        runAllTests()
    }
}
