import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var showInMenuBar = AppSettings.showInMenuBar

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLogin.configureOnFirstLaunch()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
        center.addObserver(self, selector: #selector(defaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppSettings.showInMenuBar
    }

    private func hasVisibleWindow(excluding window: NSWindow? = nil) -> Bool {
        NSApp.windows.contains { $0 !== window && ($0.isVisible || $0.isMiniaturized) && $0.canBecomeMain }
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing.canBecomeMain else { return }
        guard AppSettings.showInMenuBar, !hasVisibleWindow(excluding: closing) else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    // Defaults can change on any thread, so hop to the main actor before touching NSApp.
    @objc private nonisolated func defaultsDidChange(_ notification: Notification) {
        Task { @MainActor in self.menuBarSettingDidChange() }
    }

    private func menuBarSettingDidChange() {
        let current = AppSettings.showInMenuBar
        guard current != showInMenuBar else { return }
        showInMenuBar = current
        // The menu bar item was the only way back into the app: behave as if the last window closed.
        if !current, NSApp.activationPolicy() == .accessory, !hasVisibleWindow() {
            NSApp.terminate(nil)
        }
    }
}
