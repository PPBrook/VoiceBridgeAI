import AppKit

@MainActor
final class MenuBarController {
    static let shared = MenuBarController()

    private let statusItem: NSStatusItem
    private var menu: NSMenu?

    private init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton()
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let showItem = NSMenuItem(title: "显示主窗口", action: #selector(showControlWindowAction), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let running = SessionController.shared.isRunning
        let starting = SessionController.shared.isStarting
        let toggleTitle = running ? "停止悬浮字幕" : (starting ? "正在启动…" : "开始悬浮字幕")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleSession), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = !starting
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 VoiceBridgeAI", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        statusItem.menu = menu
        updateStatusIcon(running: running)
    }

    func updateStatusIcon(running: Bool) {
        guard let button = statusItem.button else { return }
        let symbol = running ? "waveform.circle.fill" : "waveform.circle"
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "VoiceBridgeAI") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "VB"
        }
        button.toolTip = running ? "VoiceBridgeAI · 字幕运行中" : "VoiceBridgeAI"
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        updateStatusIcon(running: false)
    }

    func collapseControlWindow() {
        AppDelegate.shared?.control?.window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func showControlWindow() {
        NSApp.setActivationPolicy(.regular)
        guard let window = AppDelegate.shared?.control?.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showControlWindowAction() {
        showControlWindow()
    }

    @objc private func toggleSession() {
        Task { @MainActor in
            let session = SessionController.shared
            if session.isStarting { return }
            if session.isRunning {
                session.stop()
            } else if let err = await session.start() {
                AppDelegate.shared?.control?.showError(err)
                showControlWindow()
            }
            AppDelegate.shared?.refreshControlUI()
            rebuildMenu()
        }
    }

    @objc private func openSettings() {
        if SettingsWindowController.shared == nil {
            _ = SettingsWindowController()
        }
        SettingsWindowController.shared?.showAndLoad()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
