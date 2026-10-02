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

    // 1. Initial Tab Forward
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        let action = engine.handleTab { windows }
        assertEqual(action, .showHUD(windows: windows, selectedIndex: 1), "Initial tab should select index 1 (2nd window)")
        assertEqual(engine.state, .active(windows: windows, selectedIndex: 1))
        print("  ✅ Initial Tab Forward (MRU Index 1)")
    }

    // 2. Single Window
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 1)
        let action = engine.handleTab { windows }
        assertEqual(action, .showHUD(windows: windows, selectedIndex: 0), "Single window should select index 0")
        assertEqual(engine.state, .active(windows: windows, selectedIndex: 0))
        print("  ✅ Single Window Selection")
    }

    // 3. Empty Windows
    do {
        let engine = SwitcherEngine()
        let action = engine.handleTab { [] }
        assertEqual(action, .none, "Empty windows should be no-op")
        assertEqual(engine.state, .idle)
        print("  ✅ Empty Windows Graceful No-Op")
    }

    // 4. Cycling Forward and Wrap Around
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
        print("  ✅ Rapid Forward Cycling & Wrap Around")
    }

    // 5. Modifier Release -> Focus & Dismiss
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        _ = engine.handleTab { windows } // index 1

        let action = engine.handleModifierRelease()
        assertEqual(action, .focusAndDismiss(window: windows[1]))
        assertEqual(engine.state, .idle)
        print("  ✅ Command Release -> Focus & Dismiss")
    }

    // 6. Cancel / Escape
    do {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)
        _ = engine.handleTab { windows }

        let action = engine.handleCancel()
        assertEqual(action, .dismiss)
        assertEqual(engine.state, .idle)
        print("  ✅ Cancel via Escape")
    }

    // 7. Search Toggle & Latching
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
        print("  ✅ Search Mode Activation & Command Latch (Zero Accidental Dismiss)")
    }

    // 8. Search Typing & Exact Match Resolution
    do {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Brave Browser", title: "GitHub - rynergold/EasyTab"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh - ~/Developer"),
            WindowItem(id: 3, pid: 103, appName: "Antigravity", title: "EasyTab Workspace")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        // Type 'a' -> should match Antigravity (index 2)
        _ = engine.handleSearchInput("a")
        _ = engine.handleSearchInput("n")
        let matchAction = engine.handleSearchInput("t")
        assertEqual(matchAction, .updateSearch(query: "ant", selectedIndex: 2, matchedIndices: [2]))
        assertEqual(engine.state.selectedWindow?.appName, "Antigravity")

        // Press Enter to focus match
        let enterAction = engine.handleEnter()
        assertEqual(enterAction, .focusAndDismiss(window: windows[2]))
        assertEqual(engine.state, .idle)
        print("  ✅ Real-time Keystroke Search & Enter Confirmation")
    }

    // 9. Search Tab Cycling Between Multiple Matches
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
        print("  ✅ Tab Cycling Across Filtered Matches")
    }

    // 10. Search Backspace & Recovery
    do {
        let engine = SwitcherEngine()
        let windows = [
            WindowItem(id: 1, pid: 101, appName: "Slack", title: "General"),
            WindowItem(id: 2, pid: 102, appName: "Ghostty", title: "zsh")
        ]
        _ = engine.handleTab { windows }
        _ = engine.handleSearchToggle()

        _ = engine.handleSearchInput("z") // No matches
        let backAction = engine.handleSearchBackspace()
        assertEqual(backAction, .updateSearch(query: "", selectedIndex: 0, matchedIndices: [0, 1]))
        print("  ✅ Backspace & Recovery to Full Window List")
    }

    print("\n🎉 ALL TESTS PASSED SUCCESSFULLY! (0 Failures)\n")
}

@main
struct TestRunnerMain {
    static func main() {
        runAllTests()
    }
}
