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

    @Test("Initial Tab with empty window list is a no-op")
    func testEmptyWindows() {
        let engine = SwitcherEngine()

        let action = engine.handleTab { [] }

        #expect(action == .none)
        #expect(engine.state == .idle)
    }

    @Test("Subsequent Tabs cycle forward and wrap around")
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

    @Test("Releasing modifier triggers focusAndDismiss with current selection")
    func testModifierRelease() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)

        _ = engine.handleTab { windows } // index 1

        let action = engine.handleModifierRelease()
        #expect(action == .focusAndDismiss(window: windows[1]))
        #expect(engine.state == .idle)
    }

    @Test("Cancelling via Escape dismisses without focus")
    func testCancel() {
        let engine = SwitcherEngine()
        let windows = makeSampleWindows(count: 3)

        _ = engine.handleTab { windows }

        let action = engine.handleCancel()
        #expect(action == .dismiss)
        #expect(engine.state == .idle)
    }
}
