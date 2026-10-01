import Foundation

public protocol WindowProvider: Sendable {
    func getVisibleWindowsSync() -> [WindowItem]
}

public protocol WindowFocusing: Sendable {
    @discardableResult
    func focus(window: WindowItem) -> Bool
}
