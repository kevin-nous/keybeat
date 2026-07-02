import AppKit
import CoreGraphics

/// Listens for global key-down events via a listen-only CGEventTap and reports
/// a bare "+1" per physical keystroke.
///
/// PRIVACY: this is the only file that touches keyboard events. macOS hands us
/// each event including which key it was — that's how the API works — and the
/// handler below deliberately reads nothing from it except the event type and
/// the autorepeat flag. No keycode, no characters, no modifiers. Keystrokes in
/// password fields never even reach this process (macOS Secure Keyboard Entry).
final class KeystrokeMonitor {
    var onKeystroke: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    static func hasPermission() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// Asks macOS to list this app under Privacy & Security > Input Monitoring.
    /// The user still has to flip the toggle themselves; this can't be silent.
    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestListenEventAccess()
    }

    static func openSettingsPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    /// Returns false when the tap can't be created — either no permission, or a
    /// grant that hasn't taken effect for this already-running process (relaunch).
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // The system disables a tap it deems unresponsive; re-enable and move on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .keyDown else { return }
        // OS auto-repeat from holding a key down isn't typing.
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onKeystroke?()
        }
    }
}
