import AppKit
import CoreGraphics
import CoreFoundation
import ApplicationServices

// MARK: - Zero-Allocation CoreFoundation Helpers

@inline(__always)
private func cfGetInt32(_ dict: CFDictionary, _ key: CFString) -> Int32? {
    let keyPtr = Unmanaged.passUnretained(key).toOpaque()
    guard let valPtr = CFDictionaryGetValue(dict, keyPtr) else { return nil }
    let num = Unmanaged<CFNumber>.fromOpaque(valPtr).takeUnretainedValue()
    var outVal: Int32 = 0
    return CFNumberGetValue(num, .sInt32Type, &outVal) ? outVal : nil
}

@inline(__always)
private func cfGetUInt32(_ dict: CFDictionary, _ key: CFString) -> UInt32? {
    let keyPtr = Unmanaged.passUnretained(key).toOpaque()
    guard let valPtr = CFDictionaryGetValue(dict, keyPtr) else { return nil }
    let num = Unmanaged<CFNumber>.fromOpaque(valPtr).takeUnretainedValue()
    var outVal: UInt32 = 0
    return CFNumberGetValue(num, .sInt32Type, &outVal) ? outVal : nil
}

@inline(__always)
private func cfGetDouble(_ dict: CFDictionary, _ key: CFString) -> Double? {
    let keyPtr = Unmanaged.passUnretained(key).toOpaque()
    guard let valPtr = CFDictionaryGetValue(dict, keyPtr) else { return nil }
    let num = Unmanaged<CFNumber>.fromOpaque(valPtr).takeUnretainedValue()
    var outVal: Double = 0
    return CFNumberGetValue(num, .doubleType, &outVal) ? outVal : nil
}

@inline(__always)
private func cfGetString(_ dict: CFDictionary, _ key: CFString) -> String? {
    let keyPtr = Unmanaged.passUnretained(key).toOpaque()
    guard let valPtr = CFDictionaryGetValue(dict, keyPtr) else { return nil }
    return Unmanaged<CFString>.fromOpaque(valPtr).takeUnretainedValue() as String
}

@inline(__always)
private func cfGetBounds(_ dict: CFDictionary) -> CGRect? {
    let keyPtr = Unmanaged.passUnretained(kCGWindowBounds).toOpaque()
    guard let valPtr = CFDictionaryGetValue(dict, keyPtr) else { return nil }
    let boundsDict = Unmanaged<CFDictionary>.fromOpaque(valPtr).takeUnretainedValue()
    return CGRect(dictionaryRepresentation: boundsDict)
}

// MARK: - Zero-Allocation System Window Provider

public final class SystemWindowProvider: WindowProvider, @unchecked Sendable {
    public static let shared = SystemWindowProvider()

    private let myPID: pid_t = ProcessInfo.processInfo.processIdentifier

    public init() {}

    public func getVisibleWindowsSync() -> [WindowItem] {
        return autoreleasepool {
            let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            guard let cfList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) else {
                return []
            }

            let count = CFArrayGetCount(cfList)
            var results: [WindowItem] = []
            results.reserveCapacity(min(count, 16))
            var seenWindowIDs = Set<CGWindowID>()

            for i in 0..<count {
                guard let dictPtr = CFArrayGetValueAtIndex(cfList, i) else { continue }
                let dict = Unmanaged<CFDictionary>.fromOpaque(dictPtr).takeUnretainedValue()

                // Fast integer extraction without dictionary allocations
                guard let windowID = cfGetUInt32(dict, kCGWindowNumber),
                      let layer = cfGetInt32(dict, kCGWindowLayer),
                      let pid = cfGetInt32(dict, kCGWindowOwnerPID) else {
                    continue
                }

                // Exclude non-standard layers (menu bar, notification center, spotlight, dock)
                guard layer == 0 else { continue }

                // Exclude our own application
                guard pid != myPID else { continue }

                // Exclude duplicates
                guard !seenWindowIDs.contains(windowID) else { continue }

                // Check alpha transparency
                if let alpha = cfGetDouble(dict, kCGWindowAlpha), alpha < 0.05 {
                    continue
                }

                // Check window dimensions (ignore zero-size or micro tracker windows)
                guard let bounds = cfGetBounds(dict), bounds.width >= 100 && bounds.height >= 100 else {
                    continue
                }

                // Resolve running application
                guard let app = NSRunningApplication(processIdentifier: pid) else { continue }

                // Only include regular applications (apps that live in Dock / user space)
                guard app.activationPolicy == .regular else { continue }

                let appName = app.localizedName ?? cfGetString(dict, kCGWindowOwnerName) ?? "Unknown App"
                var windowTitle = cfGetString(dict, kCGWindowName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if windowTitle.isEmpty {
                    let appAX = AXUIElementCreateApplication(pid)
                    AXUIElementSetMessagingTimeout(appAX, 0.03) // 30ms timeout prevents hang on frozen apps
                    var windowsRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                       let axWindows = windowsRef as? [AXUIElement] {
                        for axWin in axWindows {
                            var wid: CGWindowID = 0
                            if _AXUIElementGetWindow(axWin, &wid) == .success && wid == windowID {
                                var titleRef: CFTypeRef?
                                if AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleRef) == .success,
                                   let t = titleRef as? String, !t.isEmpty {
                                    windowTitle = t.trimmingCharacters(in: .whitespacesAndNewlines)
                                    break
                                }
                            }
                        }
                    }
                }
                let displayTitle = windowTitle.isEmpty ? appName : windowTitle

                let item = WindowItem(
                    id: windowID,
                    pid: pid,
                    appName: appName,
                    title: displayTitle
                )

                seenWindowIDs.insert(windowID)
                results.append(item)
            }

            return results
        }
    }
}
