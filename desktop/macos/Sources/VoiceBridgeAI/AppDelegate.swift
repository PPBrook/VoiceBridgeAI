import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let overlay = OverlayPanelController()
    var control: ControlWindowController?
    private var controlWindow: ControlWindowController?
    var lastSubtitleStore: SubtitleStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        overlay.onStop = { SessionController.shared.stop() }

        _ = MenuBarController.shared
        controlWindow = ControlWindowController()
        control = controlWindow
        controlWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshControlUI()
            }
        }
    }

    func refreshControlUI() {
        control?.refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionController.shared.stop()
        ServerManager.shared.stopIfOwned()
    }
}
