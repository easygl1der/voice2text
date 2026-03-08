import Foundation
import AppKit
import HotKey
import Carbon

class HotKeyManager: ObservableObject {
    @Published var isEnabled = false

    var onHotKeyDown: (() -> Void)?
    var onHotKeyUp: (() -> Void)?

    private var hotKey: HotKey?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isKeyDown = false

    func setup(key: Key = .v, modifiers: NSEvent.ModifierFlags = .option) {
        hotKey = HotKey(key: key, modifiers: modifiers)

        // Use flagsChanged to detect when Option key is pressed and released
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let optionPressed = event.modifierFlags.contains(.option)

            if optionPressed && !self.isKeyDown {
                // Option key just pressed
                self.isKeyDown = true
                self.onHotKeyDown?()
            } else if !optionPressed && self.isKeyDown {
                // Option key just released
                self.isKeyDown = false
                self.onHotKeyUp?()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            let optionPressed = event.modifierFlags.contains(.option)

            if optionPressed && !self.isKeyDown {
                self.isKeyDown = true
                self.onHotKeyDown?()
            } else if !optionPressed && self.isKeyDown {
                self.isKeyDown = false
                self.onHotKeyUp?()
            }
            return event
        }

        isEnabled = true
    }

    func stop() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        hotKey = nil
        isEnabled = false
    }

    deinit {
        stop()
    }
}
