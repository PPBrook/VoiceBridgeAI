import AppKit

@MainActor
final class LocalModelsPanelView: NSView {
    private let noteLabel = FormBuilder.label(
        "本地模型按需下载，不随 App 打包，可显著减小安装体积。下载目录见下方路径。"
    )
    private let dirLabel = FormBuilder.label("")
    private let whisperModelPopup = NSPopUpButton()
    private let statusLabel = FormBuilder.label("")
    private var modelRows: [String: (label: NSTextField, button: NSButton)] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        noteLabel.maximumNumberOfLines = 0
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.font = .systemFont(ofSize: 11)

        dirLabel.font = .systemFont(ofSize: 10)
        dirLabel.textColor = .tertiaryLabelColor
        dirLabel.lineBreakMode = .byCharWrapping
        dirLabel.maximumNumberOfLines = 2

        statusLabel.maximumNumberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.textColor = .secondaryLabelColor

        whisperModelPopup.controlSize = .small
        whisperModelPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        let whisperRow = NSStackView()
        whisperRow.orientation = .horizontal
        whisperRow.spacing = 8
        whisperRow.alignment = .centerY
        whisperRow.addArrangedSubview(NSTextField(labelWithString: "Whisper 规格"))
        whisperRow.addArrangedSubview(whisperModelPopup)

        let stack = NSStackView(views: [
            FormBuilder.sectionHeader("本地模型（可选下载）"),
            noteLabel,
            dirLabel,
            whisperRow,
            modelListStack(),
            statusLabel,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
        ])
    }

    private func modelListStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        for id in ["whisper", "argos"] {
            let title = NSTextField(labelWithString: id == "whisper" ? "Whisper 语音识别" : "Argos 英译中")
            title.font = .systemFont(ofSize: 12, weight: .medium)
            let meta = NSTextField(labelWithString: "—")
            meta.font = .systemFont(ofSize: 10)
            meta.textColor = .secondaryLabelColor
            let button = NSButton(title: "下载", target: self, action: #selector(downloadClicked(_:)))
            button.bezelStyle = .rounded
            button.identifier = NSUserInterfaceItemIdentifier(id)
            modelRows[id] = (meta, button)
            let row = NSStackView(views: [title, meta, button])
            row.orientation = .horizontal
            row.spacing = 10
            row.alignment = .centerY
            stack.addArrangedSubview(row)
        }
        return stack
    }

    func reload() {
        let health = SettingsStore.shared.health
        dirLabel.stringValue = "目录：\(health["modelsDir"] as? String ?? "—")"

        fillWhisperPopup(from: health)

        if let models = health["localModels"] as? [[String: Any]] {
            for item in models {
                guard let id = item["id"] as? String,
                      let row = modelRows[id] else { continue }
                let installed = item["installed"] as? Bool ?? false
                let hint = item["sizeHint"] as? String ?? ""
                let desc = item["description"] as? String ?? ""
                row.label.stringValue = installed ? "已安装 · \(hint)" : "未安装 · \(desc) · \(hint)"
                row.label.textColor = installed ? .systemGreen : .secondaryLabelColor
                row.button.title = installed ? "已安装" : "下载"
                row.button.isEnabled = !installed
            }
        }
    }

    private func fillWhisperPopup(from health: [String: Any]) {
        whisperModelPopup.removeAllItems()
        let choices = health["whisperChoices"] as? [[String: Any]] ?? []
        let current = health["whisperModel"] as? String ?? "tiny.en"
        if choices.isEmpty {
            whisperModelPopup.addItem(withTitle: "tiny.en")
        } else {
            for item in choices {
                if let id = item["id"] as? String {
                    whisperModelPopup.addItem(withTitle: item["label"] as? String ?? id)
                    whisperModelPopup.lastItem?.representedObject = id
                }
            }
        }
        if let idx = (0..<whisperModelPopup.numberOfItems).first(where: {
            (whisperModelPopup.item(at: $0)?.representedObject as? String ?? whisperModelPopup.titleOfSelectedItem) == current
        }) {
            whisperModelPopup.selectItem(at: idx)
        }
    }

    @objc private func downloadClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        sender.isEnabled = false
        statusLabel.stringValue = "正在下载…"
        statusLabel.textColor = .secondaryLabelColor
        Task { @MainActor in
            defer { reload() }
            do {
                var whisperModel: String?
                if id == "whisper" {
                    whisperModel = whisperModelPopup.selectedItem?.representedObject as? String
                        ?? whisperModelPopup.titleOfSelectedItem
                }
                let msg = try await SettingsStore.shared.downloadLocalModel(id: id, whisperModel: whisperModel)
                statusLabel.stringValue = msg
                statusLabel.textColor = .systemGreen
                enginePanelRefresh()
            } catch {
                statusLabel.stringValue = error.localizedDescription
                statusLabel.textColor = .systemRed
            }
        }
    }

    private func enginePanelRefresh() {
        Task { @MainActor in
            try? await SettingsStore.shared.refresh()
            reload()
            SettingsWindowController.shared?.reloadEnginePanel()
            AppDelegate.shared?.control?.refreshEngineSummary()
        }
    }
}
