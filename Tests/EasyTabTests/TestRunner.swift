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

    print("\n🎉 ALL TESTS PASSED SUCCESSFULLY! (0 Failures)\n")
}

@main
struct TestRunnerMain {
    static func main() {
        runAllTests()
    }
}
