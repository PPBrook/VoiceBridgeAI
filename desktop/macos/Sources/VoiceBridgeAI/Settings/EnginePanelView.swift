import AppKit

@MainActor
final class EnginePanelView: NSView {
    private let asrPopup = EnginePopUpButton()
    private let partialPopup = EnginePopUpButton()
    private let finalPopup = EnginePopUpButton()
    private let revisePopup = EnginePopUpButton()
    private let reviseSceneNoteLabel = FormBuilder.label("")
    private let reviseDetailLabel = FormBuilder.label("")
    private let noteLabel = FormBuilder.label(
        "默认可直接用本地 Whisper + Argos，无需 Key。云端推荐句中 MT + 句末 LLM；请先在「接口密钥」填写并测试。"
    )
    private let saveButton = NSButton(title: "保存引擎", target: nil, action: nil)
    private let statusLabel = FormBuilder.label("")

    var onSaved: ((String) -> Void)?

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

        statusLabel.maximumNumberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.textColor = .secondaryLabelColor

        reviseSceneNoteLabel.maximumNumberOfLines = 0
        reviseSceneNoteLabel.lineBreakMode = .byWordWrapping
        reviseSceneNoteLabel.textColor = .secondaryLabelColor
        reviseSceneNoteLabel.font = .systemFont(ofSize: 11)

        reviseDetailLabel.maximumNumberOfLines = 0
        reviseDetailLabel.lineBreakMode = .byWordWrapping
        reviseDetailLabel.textColor = .secondaryLabelColor
        reviseDetailLabel.font = .systemFont(ofSize: 10)
        reviseDetailLabel.preferredMaxLayoutWidth = 420

        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.bezelStyle = .rounded

        asrPopup.target = self
        asrPopup.action = #selector(popupChanged)
        partialPopup.target = self
        partialPopup.action = #selector(popupChanged)
        finalPopup.target = self
        finalPopup.action = #selector(popupChanged)
        revisePopup.target = self
        revisePopup.action = #selector(popupChanged)

        for popup in [asrPopup, partialPopup, finalPopup, revisePopup] {
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
            popup.controlSize = .regular
        }

        let reviseBlock = NSStackView(views: [
            settingRow(title: "观看场景", recommend: "按内容选断句", popup: revisePopup),
            reviseDetailLabel,
        ])
        reviseBlock.orientation = .vertical
        reviseBlock.alignment = .leading
        reviseBlock.spacing = 4

        let stack = NSStackView(views: [
            FormBuilder.sectionHeader("引擎设置"),
            noteLabel,
            settingRow(title: "语音识别", recommend: nil, popup: asrPopup),
            settingRow(title: "句中翻译", recommend: "推荐 MT", popup: partialPopup),
            settingRow(title: "句末润色", recommend: "推荐 LLM", popup: finalPopup),
            FormBuilder.sectionHeader("观看场景"),
            reviseSceneNoteLabel,
            reviseBlock,
            saveButton,
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
            saveButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    /// 与 Web `label.setting` 布局一致：左侧标签（含推荐小字），右侧下拉。
    private func settingRow(title: String, recommend: String?, popup: EnginePopUpButton) -> NSView {
        let labelColumn = NSStackView()
        labelColumn.orientation = .vertical
        labelColumn.alignment = .leading
        labelColumn.spacing = 1

        let titleLabel = FormBuilder.label(title)
        titleLabel.font = .systemFont(ofSize: 12)
        labelColumn.addArrangedSubview(titleLabel)

        if let recommend {
            let rec = FormBuilder.label(recommend)
            rec.font = .systemFont(ofSize: 10)
            rec.textColor = .secondaryLabelColor
            labelColumn.addArrangedSubview(rec)
        }

        labelColumn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        labelColumn.widthAnchor.constraint(equalToConstant: 88).isActive = true

        let row = NSStackView(views: [labelColumn, popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 420).isActive = true
        return row
    }

    func reload() {
        let store = SettingsStore.shared
        let health = store.health

        EngineSelectGroups.fillFlatPopup(
            asrPopup,
            providers: ProviderOption.list(from: health, key: "asrModes"),
            selected: store.engine.asrProvider
        )
        fillRevisePopup(from: health, selected: store.engine.reviseMode)
        reviseSceneNoteLabel.stringValue = ReviseModeGuides.intro(from: health)
        updateReviseDetail(from: health)
        reconcileAndFillPopups()
        var status = "当前：\(store.engine.summary(from: health))"
        if let rules = health["engineRules"] as? [String: Any],
           let pairNote = rules["pairNote"] as? String,
           !pairNote.isEmpty {
            status += "\n\(pairNote)"
        }
        statusLabel.stringValue = status
    }

    private func fillRevisePopup(from health: [String: Any], selected: String) {
        ReviseModeGuides.fillPopup(revisePopup, health: health, selected: selected)
    }

    private func updateReviseDetail(from health: [String: Any]) {
        let id = EngineSelectGroups.selectedId(revisePopup)
            ?? SettingsStore.shared.engine.reviseMode
        reviseDetailLabel.stringValue = ReviseModeGuides.detailText(for: id, health: health)
    }

    private func reconcileAndFillPopups() {
        let store = SettingsStore.shared
        let health = store.health
        let pair = EnginePicker.reconcile(
            asr: store.engine.asrProvider,
            partial: store.engine.partialProvider,
            final: store.engine.finalProvider,
            health: health
        )
        store.engine.partialProvider = pair.partial
        store.engine.finalProvider = pair.final

        let partialList = EnginePicker.filterPartial(
            ProviderOption.list(from: health, key: "partialProviders"),
            finalId: pair.final
        )
        let finalList = EnginePicker.filterFinal(
            ProviderOption.list(from: health, key: "finalProviders"),
            partialId: pair.partial
        )

        EngineSelectGroups.fillPopup(
            partialPopup,
            providers: partialList,
            groups: EngineSelectGroups.partialGroups,
            selected: pair.partial
        )
        EngineSelectGroups.fillPopup(
            finalPopup,
            providers: finalList,
            groups: EngineSelectGroups.finalGroups,
            selected: pair.final
        )
    }

    @objc private func popupChanged() {
        let store = SettingsStore.shared
        EngineSelectGroups.ensureValidSelection(asrPopup, fallbackId: store.engine.asrProvider)
        EngineSelectGroups.ensureValidSelection(partialPopup, fallbackId: store.engine.partialProvider)
        EngineSelectGroups.ensureValidSelection(finalPopup, fallbackId: store.engine.finalProvider)
        EngineSelectGroups.ensureValidSelection(revisePopup, fallbackId: store.engine.reviseMode)
        if let id = EngineSelectGroups.selectedId(asrPopup) { store.engine.asrProvider = id }
        if let id = EngineSelectGroups.selectedId(partialPopup) { store.engine.partialProvider = id }
        if let id = EngineSelectGroups.selectedId(finalPopup) { store.engine.finalProvider = id }
        if let id = EngineSelectGroups.selectedId(revisePopup) { store.engine.reviseMode = id }
        reconcileAndFillPopups()
        updateReviseDetail(from: SettingsStore.shared.health)
    }

    @objc private func saveClicked() {
        let store = SettingsStore.shared
        if let id = EngineSelectGroups.selectedId(asrPopup) { store.engine.asrProvider = id }
        if let id = EngineSelectGroups.selectedId(partialPopup) { store.engine.partialProvider = id }
        if let id = EngineSelectGroups.selectedId(finalPopup) { store.engine.finalProvider = id }
        if let id = EngineSelectGroups.selectedId(revisePopup) { store.engine.reviseMode = id }

        saveButton.isEnabled = false
        Task { @MainActor in
            defer { saveButton.isEnabled = true }
            do {
                let msg = try await store.saveEngine()
                if SessionController.shared.isRunning {
                    try await SessionController.shared.reconfigureEngine()
                    statusLabel.stringValue =
                        "\(msg)；观看场景与断句已应用到当前字幕。若更换 ASR 或翻译接口，请停止后重新开始"
                } else {
                    statusLabel.stringValue = msg
                }
                statusLabel.textColor = .systemGreen
                reload()
                onSaved?(msg)
                AppDelegate.shared?.control?.refreshEngineSummary()
            } catch {
                statusLabel.stringValue = error.localizedDescription
                statusLabel.textColor = .systemRed
            }
        }
    }
}
