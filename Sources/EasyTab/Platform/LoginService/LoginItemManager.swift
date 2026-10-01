import Foundation
import ServiceManagement

public final class LoginItemManager: @unchecked Sendable {
    public static let shared = LoginItemManager()

    private init() {}

    public var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    public func setLaunchAtLogin(enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                return true
            } catch {
                print("Failed to update Launch at Login: \(error.localizedDescription)")
                return false
            }
        }
        return false
    }
}
