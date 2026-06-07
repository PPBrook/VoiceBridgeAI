import AppKit

@MainActor
final class LocalModelsPanelView: NSView {
    enum RowAction {
        case download
        case switchModel
        case none
    }

    struct ModelRow {
        let checkbox: NSButton
        let label: NSTextField
        let button: NSButton
        let deleteButton: NSButton
        let progressBar: NSProgressIndicator
        let actionStatus: NSTextField
        var pendingAction: RowAction = .download
    }

    let noteLabel = FormBuilder.label(
        "本地模型按需下载，后台进行并显示进度。勾选启用后可在「引擎」页选用；Whisper 安装后可切换规格。"
    )
    let dirLabel = FormBuilder.label("")
    let whisperModelPopup = NSPopUpButton()
    let whisperDetailLabel = FormBuilder.label("")
    var modelRows: [String: ModelRow] = [:]
    var downloadTasks: [String: Task<Void, Never>] = [:]
    var suppressCheckboxAction = false
    var suppressWhisperPopupAction = false

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

        whisperModelPopup.controlSize = .small
        whisperModelPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        whisperModelPopup.target = self
        whisperModelPopup.action = #selector(whisperModelChanged)

        whisperDetailLabel.font = .systemFont(ofSize: 10)
        whisperDetailLabel.textColor = .secondaryLabelColor
        whisperDetailLabel.maximumNumberOfLines = 0
        whisperDetailLabel.lineBreakMode = .byWordWrapping
        whisperDetailLabel.preferredMaxLayoutWidth = 480

        let whisperRow = NSStackView()
        whisperRow.orientation = .horizontal
        whisperRow.spacing = 8
        whisperRow.alignment = .centerY
        whisperRow.addArrangedSubview(NSTextField(labelWithString: "Whisper 规格"))
        whisperRow.addArrangedSubview(whisperModelPopup)

        let whisperBlock = NSStackView(views: [whisperRow, whisperDetailLabel])
        whisperBlock.orientation = .vertical
        whisperBlock.alignment = .leading
        whisperBlock.spacing = 4

        let stack = NSStackView(views: [
            FormBuilder.sectionHeader("本地模型（可选下载）"),
            noteLabel,
            dirLabel,
            whisperBlock,
            modelListStack(),
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
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(enableToggled(_:)))
            checkbox.setButtonType(.switch)
            checkbox.identifier = NSUserInterfaceItemIdentifier(id)
            checkbox.state = .on

            let title = NSTextField(labelWithString: id == "whisper" ? "Whisper 语音识别" : "Argos 英译中")
            title.font = .systemFont(ofSize: 12, weight: .medium)

            let meta = NSTextField(labelWithString: "—")
            meta.font = .systemFont(ofSize: 10)
            meta.textColor = .secondaryLabelColor
            meta.setContentCompressionResistancePriority(.required, for: .horizontal)
            meta.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let button = NSButton(title: "下载", target: self, action: #selector(actionClicked(_:)))
            button.bezelStyle = .rounded
            button.identifier = NSUserInterfaceItemIdentifier(id)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)

            let deleteButton = NSButton(title: "删除", target: self, action: #selector(deleteClicked(_:)))
            deleteButton.bezelStyle = .rounded
            deleteButton.identifier = NSUserInterfaceItemIdentifier(id)
            deleteButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            deleteButton.isHidden = true

            let progressBar = NSProgressIndicator()
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = 100
            progressBar.isHidden = true
            progressBar.controlSize = .small
            progressBar.translatesAutoresizingMaskIntoConstraints = false
            progressBar.widthAnchor.constraint(equalToConstant: 110).isActive = true

            let actionStatus = NSTextField(labelWithString: "")
            actionStatus.font = .systemFont(ofSize: 10)
            actionStatus.textColor = .secondaryLabelColor
            actionStatus.lineBreakMode = .byWordWrapping
            actionStatus.maximumNumberOfLines = 2
            actionStatus.preferredMaxLayoutWidth = 180
            actionStatus.setContentHuggingPriority(.defaultLow, for: .horizontal)
            actionStatus.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            modelRows[id] = ModelRow(
                checkbox: checkbox,
                label: meta,
                button: button,
                deleteButton: deleteButton,
                progressBar: progressBar,
                actionStatus: actionStatus
            )

            let rowViews: [NSView]
            if id == "whisper" {
                rowViews = [checkbox, title, button, deleteButton, progressBar, actionStatus]
            } else {
                rowViews = [checkbox, title, meta, button, deleteButton, progressBar, actionStatus]
            }
            let row = NSStackView(views: rowViews)
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

        guard let models = health["localModels"] as? [[String: Any]], !models.isEmpty else {
            return
        }

        for item in models {
            guard let id = item["id"] as? String,
                  var row = modelRows[id] else { continue }
            let enabled = jsonBool(item["enabled"]) ?? true
            let hint = item["sizeHint"] as? String ?? ""
            let desc = item["description"] as? String ?? ""

            suppressCheckboxAction = true
            row.checkbox.state = enabled ? .on : .off
            suppressCheckboxAction = false

            if isDownloading(id) {
                modelRows[id] = row
                continue
            }

            clearRowStatus(id)

            if id == "whisper" {
                updateWhisperRow(&row, item: item, enabled: enabled)
                whisperDetailLabel.stringValue = whisperStatusText(item: item, hint: hint, desc: desc, enabled: enabled)
                whisperDetailLabel.textColor = whisperDetailLabel.stringValue.hasPrefix("已安装") ? .systemGreen : .secondaryLabelColor
            } else {
                let installed = jsonBool(item["installed"]) ?? false
                row.label.stringValue = installed
                    ? (enabled ? "已安装 · \(hint)" : "已安装 · 已禁用 · \(hint)")
                    : "未安装 · \(desc) · \(hint)"
                row.label.textColor = installed ? .systemGreen : .secondaryLabelColor
                row.pendingAction = installed ? .none : .download
                row.button.title = installed ? "已安装" : "下载"
                row.button.isEnabled = enabled && !installed
                row.deleteButton.isHidden = !installed
                row.deleteButton.isEnabled = installed
            }
            modelRows[id] = row
        }
        whisperModelPopup.isEnabled = modelRows["whisper"]?.checkbox.state == .on
        resumeActiveDownloadIfNeeded(from: health)
    }

    @objc func whisperModelChanged() {
        guard !suppressWhisperPopupAction else { return }
        reload()
    }

    @objc func enableToggled(_ sender: NSButton) {
        guard !suppressCheckboxAction, let id = sender.identifier?.rawValue else { return }
        let enabled = sender.state == .on
        setRowStatus(id, "正在保存…")
        Task { @MainActor in
            do {
                var body: [String: Any] = [:]
                if id == "whisper" { body["whisperEnabled"] = enabled }
                if id == "argos" { body["argosEnabled"] = enabled }
                let msg = try await SettingsStore.shared.updateLocalModelsSettings(body)
                try await SettingsStore.shared.refresh()
                reload()
                setRowStatus(id, msg, color: .systemGreen)
                SettingsWindowController.shared?.reloadEnginePanel()
                AppDelegate.shared?.control?.refreshEngineSummary()
            } catch {
                setRowStatus(id, error.localizedDescription, color: .systemRed)
                reload()
            }
        }
    }

    @objc func actionClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let row = modelRows[id] else { return }

        if id == "whisper", row.pendingAction == .switchModel {
            sender.isEnabled = false
            Task { @MainActor in
                do {
                    guard let model = selectedWhisperModel() else {
                        reload()
                        return
                    }
                    setRowStatus(id, "正在切换…")
                    let msg = try await SettingsStore.shared.updateLocalModelsSettings([
                        "whisperModel": model,
                        "action": "switch",
                    ])
                    try await SettingsStore.shared.refresh()
                    reload()
                    setRowStatus(id, msg, color: .systemGreen)
                    SettingsWindowController.shared?.reloadEnginePanel()
                    AppDelegate.shared?.control?.refreshEngineSummary()
                } catch {
                    setRowStatus(id, error.localizedDescription, color: .systemRed)
                    reload()
                }
            }
            return
        }

        var whisperModel: String?
        if id == "whisper" { whisperModel = selectedWhisperModel() }
        guard confirmDownload(id: id, whisperModel: whisperModel) else {
            reload()
            return
        }

        sender.isEnabled = false
        Task { @MainActor in
            do {
                try await beginDownload(id: id, whisperModel: whisperModel)
            } catch {
                hideDownloadProgress(id)
                setRowStatus(id, error.localizedDescription, color: .systemRed)
                reload()
            }
        }
    }

    @objc func deleteClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }

        let alert = NSAlert()
        alert.messageText = "删除本地模型？"
        if id == "whisper", let model = selectedWhisperModel() {
            alert.informativeText = "将删除 Whisper \(model) 的本地文件。删除后需重新下载才能使用。"
        } else if id == "argos" {
            alert.informativeText = "将删除 Argos 英译中语言包。删除后需重新下载才能使用。"
        } else {
            alert.informativeText = "删除后需重新下载才能使用。"
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        sender.isEnabled = false
        setRowStatus(id, "正在删除…")
        Task { @MainActor in
            do {
                var whisperModel: String?
                if id == "whisper" { whisperModel = selectedWhisperModel() }
                let msg = try await SettingsStore.shared.deleteLocalModel(id: id, whisperModel: whisperModel)
                try await SettingsStore.shared.refresh()
                reload()
                setRowStatus(id, msg, color: .systemGreen)
                SettingsWindowController.shared?.reloadEnginePanel()
                AppDelegate.shared?.control?.refreshEngineSummary()
            } catch {
                setRowStatus(id, error.localizedDescription, color: .systemRed)
                reload()
            }
        }
    }
}
