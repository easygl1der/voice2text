import SwiftUI

@main
struct Voice2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice2Text")
            button.action = #selector(toggleMenu)
            button.target = self
        }

        updateMenu()
    }

    @objc func toggleMenu() {
        statusItem?.button?.performClick(nil)
    }

    func updateMenu() {
        let menu = NSMenu()

        // Status
        let statusItem = NSMenuItem()
        let statusView = MenuBarView(appState: appState, onRecord: {}, onStop: {})
        statusItem.view = NSHostingView(rootView: statusView)
        menu.addItem(statusItem)

        self.statusItem?.menu = menu
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
