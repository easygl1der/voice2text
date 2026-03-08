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

        hotKey?.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            self.isKeyDown = true
            self.onHotKeyDown?()
        }

        hotKey?.keyUpHandler = { [weak self] in
            guard let self = self else { return }
            self.isKeyDown = false
            self.onHotKeyUp?()
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
