import AppKit

@MainActor
private final class ControlWindow: NSWindow {
    override func miniaturize(_ sender: Any?) {
        MenuBarController.shared.collapseControlWindow()
    }
}

@MainActor
final class ControlWindowController: NSWindowController, NSWindowDelegate {
    private let statusLabel = NSTextField(labelWithString: "检测服务端…")
    private let engineLabel = NSTextField(wrappingLabelWithString: "引擎：—")
    private let revisePopup = NSPopUpButton()
    private let reviseHintLabel = NSTextField(wrappingLabelWithString: "")
    private let startButton = NSButton(title: "开始悬浮字幕", target: nil, action: nil)
    private let stopButton = NSButton(title: "停止", target: nil, action: nil)
    private let settingsButton = NSButton(title: "设置…", target: nil, action: nil)
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    private var suppressReviseAction = false

    init() {
        let window = ControlWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceBridgeAI"
        window.center()
        super.init(window: window)
        window.delegate = self
        window.standardWindowButton(.miniaturizeButton)?.toolTip = "收起到菜单栏"
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

        revisePopup.controlSize = .regular
        revisePopup.target = self
        revisePopup.action = #selector(reviseModeChanged)
        revisePopup.toolTip = "按观看内容选择断句策略"
        revisePopup.translatesAutoresizingMaskIntoConstraints = false
        revisePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true

        reviseHintLabel.font = .systemFont(ofSize: 10)
        reviseHintLabel.textColor = .secondaryLabelColor
        reviseHintLabel.maximumNumberOfLines = 2
        reviseHintLabel.lineBreakMode = .byWordWrapping
        reviseHintLabel.preferredMaxLayoutWidth = 340

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

        let subtitle = NSTextField(labelWithString: "macOS 原生客户端")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor

        let reviseTitle = FormBuilder.label("观看场景")
        reviseTitle.font = .systemFont(ofSize: 12)
        reviseTitle.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        reviseTitle.widthAnchor.constraint(equalToConstant: 88).isActive = true

        let reviseRow = NSStackView(views: [reviseTitle, revisePopup])
        reviseRow.orientation = .horizontal
        reviseRow.alignment = .centerY
        reviseRow.spacing = 12
        reviseRow.translatesAutoresizingMaskIntoConstraints = false
        reviseRow.widthAnchor.constraint(equalToConstant: 340).isActive = true

        let reviseBlock = NSStackView(views: [reviseRow, reviseHintLabel])
        reviseBlock.orientation = .vertical
        reviseBlock.alignment = .leading
        reviseBlock.spacing = 4

        let footnote = NSTextField(wrappingLabelWithString: "采集系统音频；ASR 与翻译在「设置」中配置。观看场景可在此快速切换。")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            subtitle, statusLabel, engineLabel, reviseBlock, startButton, stopButton, settingsButton, errorLabel, footnote,
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
        ])
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return true
    }

    func refresh() {
        Task { @MainActor in
            let ok = await ServerManager.shared.ping()
            let session = SessionController.shared
            let running = session.isRunning
            let starting = session.isStarting
            if running {
                statusLabel.stringValue = "● 字幕运行中"
                statusLabel.textColor = .systemBlue
            } else if starting {
                statusLabel.stringValue = "● 正在启动字幕…"
                statusLabel.textColor = .systemBlue
            } else if ok {
                statusLabel.stringValue = "● 服务端已连接"
                statusLabel.textColor = .systemGreen
            } else {
                statusLabel.stringValue = "● 服务端未连接（启动时将自动拉起）"
                statusLabel.textColor = .systemOrange
            }
            startButton.isEnabled = !running && !starting
            stopButton.isEnabled = running
            revisePopup.isEnabled = !starting
            MenuBarController.shared.rebuildMenu()
        }
    }

    func refreshEngineSummary() {
        let store = SettingsStore.shared
        engineLabel.stringValue = "引擎：\(store.engine.summary(from: store.health))"
        fillRevisePopup(selected: store.engine.reviseMode)
        updateReviseHint(selectedId: store.engine.reviseMode)
    }

    private func fillRevisePopup(selected: String) {
        suppressReviseAction = true
        defer { suppressReviseAction = false }
        ReviseModeGuides.fillPopup(
            revisePopup,
            health: SettingsStore.shared.health,
            selected: selected
        )
    }

    private func updateReviseHint(selectedId: String) {
        let health = SettingsStore.shared.health
        if let info = ReviseModeGuides.info(for: selectedId, health: health) {
            var parts: [String] = []
            if !info.polishNote.isEmpty { parts.append(info.polishNote) }
            if !info.examples.isEmpty { parts.append("示例：\(info.examples)") }
            reviseHintLabel.stringValue = parts.joined(separator: " · ")
        } else {
            reviseHintLabel.stringValue = ""
        }
    }

    func showError(_ text: String?) {
        if let text, !text.isEmpty {
            errorLabel.stringValue = text
            errorLabel.textColor = .systemRed
            errorLabel.isHidden = false
        } else {
            errorLabel.stringValue = ""
            errorLabel.isHidden = true
        }
    }

    private func showNotice(_ text: String) {
        errorLabel.stringValue = text
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.isHidden = false
    }

    @objc private func reviseModeChanged() {
        guard !suppressReviseAction,
              let id = EngineSelectGroups.selectedId(revisePopup) else { return }

        updateReviseHint(selectedId: id)
        revisePopup.isEnabled = false
        Task { @MainActor in
            defer {
                revisePopup.isEnabled = !SessionController.shared.isStarting
            }
            do {
                try await SessionController.shared.applyReviseMode(id)
                refreshEngineSummary()
                if SessionController.shared.isRunning {
                    showNotice("观看场景已更新，已应用到当前字幕")
                } else {
                    showError(nil)
                }
            } catch {
                showError(error.localizedDescription)
                fillRevisePopup(selected: SettingsStore.shared.engine.reviseMode)
                updateReviseHint(selectedId: SettingsStore.shared.engine.reviseMode)
            }
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
}
