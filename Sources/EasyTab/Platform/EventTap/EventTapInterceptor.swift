import AppKit
import CoreGraphics

// MARK: - Private SkyLight / CGS APIs for Symbolic Hotkeys (AltTab Mechanism)

@_silgen_name("CGSSetSymbolicHotKeyEnabled")
@discardableResult
func CGSSetSymbolicHotKeyEnabled(_ hotKey: Int, _ isEnabled: Bool) -> Int32

public enum CGSSymbolicHotKey: Int, CaseIterable {
    case commandTab = 1
    case commandShiftTab = 2
}

public func setNativeCommandTabEnabled(_ isEnabled: Bool) {
    for hotkey in CGSSymbolicHotKey.allCases {
        CGSSetSymbolicHotKeyEnabled(hotkey.rawValue, isEnabled)
    }
}

// MARK: - Minimal EventTap Protocol (Pure Tab & Dismiss)

public protocol EventTapDelegate: AnyObject, Sendable {
    func onTabPressed()
    func onModifierReleased()
    func onCancelPressed()
    func isSwitcherActive() -> Bool
}

public final class EventTapInterceptor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    public weak var delegate: EventTapDelegate?

    public init() {
        signal(SIGINT) { _ in
            setNativeCommandTabEnabled(true)
            exit(0)
        }
        signal(SIGTERM) { _ in
            setNativeCommandTabEnabled(true)
            exit(0)
        }
        atexit {
            setNativeCommandTabEnabled(true)
        }
    }

    deinit {
        stop()
    }

    public var isRunning: Bool {
        return eventTap != nil
    }

    public func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let interceptor = Unmanaged<EventTapInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            return interceptor.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPointer
        ) else {
            print("Failed to create CGEventTap. Ensure Accessibility permissions are granted.")
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Disable macOS native Dock Command+Tab & Command+Shift+Tab
        setNativeCommandTabEnabled(false)

        return true
    }

    public func stop() {
        setNativeCommandTabEnabled(true)

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let delegate = delegate else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let isCmdDown = flags.contains(.maskCommand)

        // 1. Check for Command modifier release when switcher is open
        if type == .flagsChanged {
            if !isCmdDown && delegate.isSwitcherActive() {
                DispatchQueue.main.async {
                    delegate.onModifierReleased()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // 2. Check for KeyDown events: Command+Tab (keycode 48) & Escape (keycode 53)
        if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)

            // Command + Tab key (keycode 48)
            if keycode == 48 && isCmdDown {
                DispatchQueue.main.async {
                    delegate.onTabPressed()
                }
                // Suppress Tab keystroke so it doesn't trigger native macOS Dock switcher
                return nil
            }

            // Escape key (keycode 53) dismisses switcher
            if keycode == 53 && delegate.isSwitcherActive() {
                DispatchQueue.main.async {
                    delegate.onCancelPressed()
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
