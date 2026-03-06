import Foundation
import HotKey
import Carbon

class HotKeyManager: ObservableObject {
    @Published var isEnabled = false

    var onHotKeyDown: (() -> Void)?
    var onHotKeyUp: (() -> Void)?

    private var hotKey: HotKey?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func setup(key: Key = .v, modifiers: NSEvent.ModifierFlags = .option) {
        hotKey = HotKey(key: key, modifiers: modifiers)

        hotKey?.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            self.onHotKeyDown?()
        }

        // Setup global key up monitor for Option key release
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if !event.modifierFlags.contains(.option) {
                self?.onHotKeyUp?()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if !event.modifierFlags.contains(.option) {
                self?.onHotKeyUp?()
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
