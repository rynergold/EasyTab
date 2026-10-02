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
    func onSearchActivated()
    func onSearchInput(_ char: Character)
    func onSearchBackspace()
    func onEnterPressed()
    func isSwitcherActive() -> Bool
    func isSearchActive() -> Bool
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
                // If search mode is active, lock open! Releasing Command is a no-op so user can type freely.
                if !delegate.isSearchActive() {
                    DispatchQueue.main.async {
                        delegate.onModifierReleased()
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // 2. KeyDown events
        if type == .keyDown {
            guard delegate.isSwitcherActive() else {
                return Unmanaged.passUnretained(event)
            }

            let keycode = event.getIntegerValueField(.keyboardEventKeycode)

            // Escape key (keycode 53) dismisses switcher
            if keycode == 53 {
                DispatchQueue.main.async {
                    delegate.onCancelPressed()
                }
                return nil
            }

            // In Search Mode:
            if delegate.isSearchActive() {
                // Return / Enter key (keycode 36 or 76 on numpad) -> confirm selection
                if keycode == 36 || keycode == 76 {
                    DispatchQueue.main.async {
                        delegate.onEnterPressed()
                    }
                    return nil
                }

                // Tab key (keycode 48) -> cycle through matching results
                if keycode == 48 {
                    DispatchQueue.main.async {
                        delegate.onTabPressed()
                    }
                    return nil
                }

                // Backspace / Delete key (keycode 51)
                if keycode == 51 {
                    DispatchQueue.main.async {
                        delegate.onSearchBackspace()
                    }
                    return nil
                }

                // Printable text characters typed by user
                if let chars = NSEvent(cgEvent: event)?.characters, !chars.isEmpty {
                    for char in chars {
                        if !char.isNewline && char != "\t" {
                            DispatchQueue.main.async {
                                delegate.onSearchInput(char)
                            }
                        }
                    }
                    return nil
                }

                return nil
            }

            // In Standard Active Mode:
            // Command + Tab key (keycode 48)
            if keycode == 48 && isCmdDown {
                DispatchQueue.main.async {
                    delegate.onTabPressed()
                }
                return nil
            }

            // 's' or 'S' key (keycode 1) -> enter Search Mode!
            if keycode == 1 {
                DispatchQueue.main.async {
                    delegate.onSearchActivated()
                }
                return nil
            }

            // Enter key (keycode 36 or 76) -> confirm selection immediately
            if keycode == 36 || keycode == 76 {
                DispatchQueue.main.async {
                    delegate.onEnterPressed()
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
