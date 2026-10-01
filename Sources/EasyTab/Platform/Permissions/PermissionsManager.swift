import AppKit
import ApplicationServices

public final class PermissionsManager: @unchecked Sendable {
    public static let shared = PermissionsManager()

    private init() {}

    public var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    @discardableResult
    public func promptForAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
