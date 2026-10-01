import Foundation
import CoreGraphics

public struct WindowItem: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let title: String

    public init(
        id: CGWindowID,
        pid: pid_t,
        appName: String,
        title: String
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.title = title
    }

    public static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
        return lhs.id == rhs.id && lhs.pid == rhs.pid
    }
}
