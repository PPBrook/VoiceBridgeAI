import AppKit

@MainActor
final class ControlWindowController: NSWindowController, NSWindowDelegate {
    private let statusLabel = NSTextField(labelWithString: "检测服务端…")
    private let engineLabel = NSTextField(wrappingLabelWithString: "引擎：—")
    private let startButton = NSButton(title: "开始悬浮字幕", target: nil, action: nil)
    private let stopButton = NSButton(title: "停止", target: nil, action: nil)
    private let settingsButton = NSButton(title: "设置…", target: nil, action: nil)
    private let collapseButton = NSButton(title: "收起到菜单栏", target: nil, action: nil)
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceBridgeAI"
        window.center()
        super.init(window: window)
        window.delegate = self
        setupUI()
        refresh()
        Task { try? await SettingsStore.shared.refresh(); refreshEngineSummary() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        statusLabel.font = .systemFont(ofSize: 13)
        engineLabel.font = .systemFont(ofSize: 11)
        engineLabel.textColor = .secondaryLabelColor
        engineLabel.maximumNumberOfLines = 2

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.isHidden = true

        startButton.target = self
        startButton.action = #selector(startClicked)
        startButton.bezelStyle = .rounded

        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        stopButton.bezelStyle = .rounded
        stopButton.isEnabled = false

        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.bezelStyle = .rounded

        collapseButton.target = self
        collapseButton.action = #selector(collapseToMenuBar)
        collapseButton.bezelStyle = .rounded

        let subtitle = NSTextField(labelWithString: "macOS 原生客户端")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor

        let footnote = NSTextField(wrappingLabelWithString: "采集系统音频；引擎与密钥在「设置」中配置。需要屏幕录制权限。")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            subtitle, statusLabel, engineLabel, startButton, stopButton, settingsButton, collapseButton, errorLabel, footnote,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),
            startButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            stopButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            settingsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            collapseButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        MenuBarController.shared.collapseControlWindow()
        return false
    }

    func refresh() {
        Task { @MainActor in
            let ok = await ServerManager.shared.ping()
            let running = SessionController.shared.isRunning
            if running {
                statusLabel.stringValue = "● 字幕运行中"
                statusLabel.textColor = .systemBlue
            } else if ok {
                statusLabel.stringValue = "● 服务端已连接"
                statusLabel.textColor = .systemGreen
            } else {
                statusLabel.stringValue = "● 服务端未连接（启动时将自动拉起）"
                statusLabel.textColor = .systemOrange
            }
            startButton.isEnabled = !running
            stopButton.isEnabled = running
            MenuBarController.shared.rebuildMenu()
        }
    }

    func refreshEngineSummary() {
        let store = SettingsStore.shared
        engineLabel.stringValue = "引擎：\(store.engine.summary(from: store.health))"
    }

    func showError(_ text: String?) {
        if let text, !text.isEmpty {
            errorLabel.stringValue = text
            errorLabel.isHidden = false
        } else {
            errorLabel.stringValue = ""
            errorLabel.isHidden = true
        }
    }

    @objc private func startClicked() {
        showError(nil)
        startButton.isEnabled = false
        Task { @MainActor in
            if let err = await SessionController.shared.start() {
                showError(err)
            }
            refresh()
        }
    }

    @objc private func stopClicked() {
        SessionController.shared.stop()
        showError(nil)
        refresh()
    }

    @objc private func openSettings() {
        if SettingsWindowController.shared == nil {
            _ = SettingsWindowController()
        }
        SettingsWindowController.shared?.showAndLoad()
    }

    @objc private func collapseToMenuBar() {
        MenuBarController.shared.collapseControlWindow()
    }
}
