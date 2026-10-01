import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout CGWindowID) -> AXError

public final class WindowFocusManager: WindowFocusing, @unchecked Sendable {
    public static let shared = WindowFocusManager()

    public init() {}

    @discardableResult
    public func focus(window: WindowItem) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else {
            return false
        }

        // 1. Activate application
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        // 2. Locate and raise specific window via AXUIElement
        let appAX = AXUIElementCreateApplication(window.pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let axWindows = windowsRef as? [AXUIElement], !axWindows.isEmpty else {
            return true
        }

        // Try finding matching window by exact CGWindowID first
        var matchedWindow: AXUIElement? = nil

        for axWin in axWindows {
            var wid: CGWindowID = 0
            if _AXUIElementGetWindow(axWin, &wid) == .success && wid == window.id {
                matchedWindow = axWin
                break
            }
        }

        // Fallback: match by title if window ID wasn't resolved
        if matchedWindow == nil {
            for axWin in axWindows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String,
                   (title == window.title || title.contains(window.title) || window.title.contains(title)) {
                    matchedWindow = axWin
                    break
                }
            }
        }

        let targetAX = matchedWindow ?? axWindows.first!

        // If minimized, restore it
        AXUIElementSetAttributeValue(targetAX, kAXMinimizedAttribute as CFString, kCFBooleanFalse)

        // Raise window to the front and make it main
        AXUIElementPerformAction(targetAX, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(targetAX, kAXMainAttribute as CFString, kCFBooleanTrue)

        return true
    }
}
