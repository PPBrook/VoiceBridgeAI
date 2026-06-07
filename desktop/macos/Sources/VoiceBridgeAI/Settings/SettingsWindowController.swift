import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    static var shared: SettingsWindowController?

    private let tabView = NSTabView()
    private let enginePanel = EnginePanelView(frame: .zero)
    private let cloudPanel = CloudPanelView(frame: .zero)
    private let localModelsPanel = LocalModelsPanelView(frame: .zero)
    private let transcriptPanel = TranscriptSettingsPanelView(frame: .zero)
    private var startupPollTask: Task<Void, Never>?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceBridgeAI 设置"
        window.center()
        window.minSize = NSSize(width: 520, height: 520)
        window.setContentSize(NSSize(width: 540, height: 660))
        super.init(window: window)
        Self.shared = self
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        tabView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(tabView)

        let engineItem = NSTabViewItem(identifier: "engine")
        engineItem.label = "引擎"
        engineItem.view = enginePanel

        let cloudItem = NSTabViewItem(identifier: "cloud")
        cloudItem.label = "接口密钥"
        cloudItem.view = cloudPanel

        let modelsItem = NSTabViewItem(identifier: "models")
        modelsItem.label = "本地模型"
        modelsItem.view = localModelsPanel

        let transcriptItem = NSTabViewItem(identifier: "transcript")
        transcriptItem.label = "字幕记录"
        transcriptItem.view = transcriptPanel

        tabView.addTabViewItem(engineItem)
        tabView.addTabViewItem(modelsItem)
        tabView.addTabViewItem(transcriptItem)
        tabView.addTabViewItem(cloudItem)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: content.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        enginePanel.onSaved = { _ in
            AppDelegate.shared?.control?.refreshEngineSummary()
        }
    }

    func showAndLoad() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            await reloadSettings()
        }
    }

    private func reloadSettings() async {
        CloudProviderPreferences.bootstrap()
        do {
            try await SettingsStore.shared.refresh()
            CloudProviderPreferences.applyHealthPrefs(SettingsStore.shared.health)
            enginePanel.reload()
            localModelsPanel.reload()
            transcriptPanel.reload()
            cloudPanel.reload()
            scheduleStartupPollIfNeeded()
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法加载设置"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func scheduleStartupPollIfNeeded() {
        startupPollTask?.cancel()
        startupPollTask = nil
        guard let st = SettingsStore.shared.health["startupTest"] as? [String: Any],
              st["running"] as? Bool == true else { return }

        startupPollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                try? await SettingsStore.shared.refresh()
                enginePanel.reload()
                localModelsPanel.reload()
                transcriptPanel.reload()
                cloudPanel.reload()
                let running = (SettingsStore.shared.health["startupTest"] as? [String: Any])?["running"] as? Bool == true
                if !running { break }
            }
            startupPollTask = nil
        }
    }

    func reloadEnginePanel() {
        enginePanel.reload()
    }
}
