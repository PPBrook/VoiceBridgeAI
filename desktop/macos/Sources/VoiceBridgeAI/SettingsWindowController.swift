import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    static var shared: SettingsWindowController?

    private let tabView = NSTabView()
    private let enginePanel = EnginePanelView(frame: .zero)
    private let cloudPanel = CloudPanelView(frame: .zero)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceBridgeAI 设置"
        window.center()
        window.minSize = NSSize(width: 480, height: 420)
        window.setContentSize(NSSize(width: 480, height: 520))
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

        tabView.addTabViewItem(engineItem)
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
            do {
                try await SettingsStore.shared.refresh()
                enginePanel.reload()
                cloudPanel.reload()
            } catch {
                let alert = NSAlert()
                alert.messageText = "无法加载设置"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}
