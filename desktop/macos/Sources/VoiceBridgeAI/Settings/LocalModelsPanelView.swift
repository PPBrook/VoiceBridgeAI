import AppKit

@MainActor
final class LocalModelsPanelView: NSView {
    private enum RowAction {
        case download
        case switchModel
        case none
    }

    private struct ModelRow {
        let checkbox: NSButton
        let label: NSTextField
        let button: NSButton
        let deleteButton: NSButton
        let progressBar: NSProgressIndicator
        let actionStatus: NSTextField
        var pendingAction: RowAction = .download
    }

    private let noteLabel = FormBuilder.label(
        "本地模型按需下载，后台进行并显示进度。勾选启用后可在「引擎」页选用；Whisper 安装后可切换规格。"
    )
    private let dirLabel = FormBuilder.label("")
    private let whisperModelPopup = NSPopUpButton()
    private let whisperDetailLabel = FormBuilder.label("")
    private var modelRows: [String: ModelRow] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var suppressCheckboxAction = false
    private var suppressWhisperPopupAction = false

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

    private func isDownloading(_ id: String) -> Bool {
        guard let task = downloadTasks[id] else { return false }
        return !task.isCancelled
    }

    private func resumeActiveDownloadIfNeeded(from health: [String: Any]) {
        guard let jobDict = health["activeDownload"] as? [String: Any],
              let job = LocalModelDownloadJob.from(jobDict),
              job.status == "running" else { return }
        let rowId = job.modelId
        guard matchesActiveJob(job, rowId: rowId), !isDownloading(rowId) else { return }
        applyDownloadProgress(rowId, job: job)
        followDownloadJob(rowId: rowId, jobId: job.id)
    }

    private func matchesActiveJob(_ job: LocalModelDownloadJob, rowId: String) -> Bool {
        guard job.modelId == rowId else { return false }
        if rowId == "whisper", let whisper = job.whisperModel, let selected = selectedWhisperModel() {
            return whisper == selected
        }
        return true
    }

    private func applyDownloadProgress(_ id: String, job: LocalModelDownloadJob) {
        guard let row = modelRows[id] else { return }
        row.progressBar.isHidden = false
        row.progressBar.doubleValue = job.progress * 100
        row.button.isEnabled = false
        row.deleteButton.isEnabled = false
        setRowStatus(id, job.displayMessage)
        if id == "whisper" {
            whisperDetailLabel.stringValue = "后台下载中，可关闭此页面继续等待"
            whisperDetailLabel.textColor = .secondaryLabelColor
        }
    }

    private func clearRowStatus(_ id: String) {
        setRowStatus(id, "")
    }

    private func hideDownloadProgress(_ id: String) {
        guard let row = modelRows[id] else { return }
        row.progressBar.isHidden = true
        row.progressBar.doubleValue = 0
    }

    private func followDownloadJob(rowId: String, jobId: String) {
        downloadTasks[rowId]?.cancel()
        downloadTasks[rowId] = Task { @MainActor in
            defer { downloadTasks[rowId] = nil }
            do {
                while !Task.isCancelled {
                    let job = try await SettingsStore.shared.pollLocalModelDownloadJob(id: jobId)
                    applyDownloadProgress(rowId, job: job)
                    if job.status == "done" {
                        hideDownloadProgress(rowId)
                        try await SettingsStore.shared.refresh()
                        reload()
                        setRowStatus(rowId, job.displayMessage, color: .systemGreen)
                        SettingsWindowController.shared?.reloadEnginePanel()
                        AppDelegate.shared?.control?.refreshEngineSummary()
                        return
                    }
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } catch {
                hideDownloadProgress(rowId)
                reload()
                setRowStatus(rowId, error.localizedDescription, color: .systemRed)
            }
        }
    }

    private func setRowStatus(_ id: String, _ text: String, color: NSColor = .secondaryLabelColor) {
        guard let row = modelRows[id] else { return }
        row.actionStatus.stringValue = text
        row.actionStatus.textColor = color
        row.actionStatus.isHidden = text.isEmpty
    }

    private func sizeHintForModel(id: String, whisperModel: String?) -> String {
        if id == "whisper", let whisperModel {
            return whisperSizeHint(for: whisperModel, fallback: "~75 MB")
        }
        guard let models = SettingsStore.shared.health["localModels"] as? [[String: Any]] else {
            return "—"
        }
        for item in models where (item["id"] as? String) == id {
            return item["sizeHint"] as? String ?? "—"
        }
        return "—"
    }

    private func confirmDownload(id: String, whisperModel: String?) -> Bool {
        let sizeHint = sizeHintForModel(id: id, whisperModel: whisperModel)
        let alert = NSAlert()
        alert.messageText = "下载本地模型？"
        if id == "whisper", let model = whisperModel {
            alert.informativeText =
                "将后台下载 Whisper \(model)（\(sizeHint)）。\n建议 Wi-Fi 环境；可关闭设置页，下载会继续进行。"
        } else if id == "argos" {
            alert.informativeText =
                "将后台下载 Argos 英译中（\(sizeHint)）。\n建议 Wi-Fi 环境；可关闭设置页，下载会继续进行。"
        } else {
            alert.informativeText = "将后台下载（\(sizeHint)）。建议 Wi-Fi 环境。"
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func beginDownload(id: String, whisperModel: String?) async throws {
        let job = try await SettingsStore.shared.startLocalModelDownload(
            id: id,
            whisperModel: whisperModel
        )
        applyDownloadProgress(id, job: job)
        followDownloadJob(rowId: id, jobId: job.id)
    }

    private func jsonBool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? Int { return n != 0 }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }

    private func whisperSizeHint(for modelId: String, fallback: String) -> String {
        for item in whisperChoices() {
            if (item["id"] as? String) == modelId {
                return item["sizeHint"] as? String ?? fallback
            }
        }
        return fallback
    }

    private func whisperStatusText(
        item: [String: Any],
        hint: String,
        desc: String,
        enabled: Bool
    ) -> String {
        let installedModels = Set(item["installedModels"] as? [String] ?? [])
        let active = item["activeModel"] as? String ?? SettingsStore.shared.health["whisperModel"] as? String ?? "tiny.en"
        let selected = selectedWhisperModel() ?? active
        let selectedHint = whisperSizeHint(for: selected, fallback: hint)
        let installedOverall = jsonBool(item["installed"]) ?? false
        let activeInstalled = jsonBool(item["activeInstalled"]) ?? false
        let anyInstalled = installedOverall || activeInstalled || !installedModels.isEmpty
        let selectedInstalled = installedModels.contains(selected)
            || (activeInstalled && selected == active)
            || (installedOverall && selected == active)

        if selectedInstalled {
            if selected == active {
                return enabled
                    ? "已安装 · 当前使用 \(selected) · \(selectedHint)"
                    : "已安装 · 当前使用 \(selected) · 已禁用"
            }
            return enabled
                ? "已安装 \(selected) · \(selectedHint)（当前使用 \(active)，点「切换」生效）"
                : "已安装 \(selected) · 已禁用"
        }
        if anyInstalled {
            return "未下载 \(selected) · \(selectedHint)（当前使用 \(active)）"
        }
        return "未安装 · \(desc) · \(selectedHint)"
    }

    private func updateWhisperRow(
        _ row: inout ModelRow,
        item: [String: Any],
        enabled: Bool
    ) {
        let installedModels = Set(item["installedModels"] as? [String] ?? [])
        let active = item["activeModel"] as? String ?? SettingsStore.shared.health["whisperModel"] as? String ?? "tiny.en"
        let selected = selectedWhisperModel() ?? active
        let installedOverall = jsonBool(item["installed"]) ?? false
        let activeInstalled = jsonBool(item["activeInstalled"]) ?? false
        let selectedInstalled = installedModels.contains(selected)
            || (activeInstalled && selected == active)
            || (installedOverall && selected == active)

        if selectedInstalled {
            row.deleteButton.isHidden = false
            row.deleteButton.isEnabled = true
            if selected == active {
                row.pendingAction = .none
                row.button.title = "已安装"
                row.button.isEnabled = false
            } else {
                row.pendingAction = .switchModel
                row.button.title = "切换"
                row.button.isEnabled = enabled
            }
        } else {
            row.deleteButton.isHidden = true
            row.deleteButton.isEnabled = false
            row.pendingAction = .download
            row.button.title = "下载"
            row.button.isEnabled = enabled
        }
    }

    private func whisperChoices() -> [[String: Any]] {
        SettingsStore.shared.health["whisperChoices"] as? [[String: Any]] ?? []
    }

    private func whisperId(forMenuTitle title: String) -> String? {
        for item in whisperChoices() {
            if (item["label"] as? String) == title { return item["id"] as? String }
            if (item["id"] as? String) == title { return item["id"] as? String }
        }
        if title.contains("tiny.en") { return "tiny.en" }
        if title.contains("base.en") { return "base.en" }
        return nil
    }

    private func fillWhisperPopup(from health: [String: Any]) {
        suppressWhisperPopupAction = true
        defer { suppressWhisperPopupAction = false }

        let previous = selectedWhisperModel()
        whisperModelPopup.removeAllItems()
        let choices = health["whisperChoices"] as? [[String: Any]] ?? []
        let current = health["whisperModel"] as? String ?? "tiny.en"
        let selectId = previous ?? current
        if choices.isEmpty {
            whisperModelPopup.addItem(withTitle: "tiny.en")
            whisperModelPopup.item(at: 0)?.representedObject = "tiny.en"
        } else {
            for item in choices {
                guard let id = item["id"] as? String else { continue }
                let label = item["label"] as? String ?? id
                whisperModelPopup.addItem(withTitle: label)
                let idx = whisperModelPopup.numberOfItems - 1
                whisperModelPopup.item(at: idx)?.representedObject = id
            }
        }
        if let idx = (0..<whisperModelPopup.numberOfItems).first(where: {
            (whisperModelPopup.item(at: $0)?.representedObject as? String ?? "") == selectId
        }) {
            whisperModelPopup.selectItem(at: idx)
        } else if let idx = (0..<whisperModelPopup.numberOfItems).first(where: {
            (whisperModelPopup.item(at: $0)?.representedObject as? String ?? "") == current
        }) {
            whisperModelPopup.selectItem(at: idx)
        }
    }

    private func selectedWhisperModel() -> String? {
        if let id = whisperModelPopup.selectedItem?.representedObject as? String, !id.isEmpty {
            return id
        }
        if let title = whisperModelPopup.titleOfSelectedItem, !title.isEmpty {
            return whisperId(forMenuTitle: title) ?? title
        }
        return nil
    }

    @objc private func whisperModelChanged() {
        guard !suppressWhisperPopupAction else { return }
        reload()
    }

    @objc private func enableToggled(_ sender: NSButton) {
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

    @objc private func actionClicked(_ sender: NSButton) {
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

    @objc private func deleteClicked(_ sender: NSButton) {
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
