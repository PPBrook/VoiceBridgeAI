import AppKit
import UniformTypeIdentifiers

@MainActor
final class TranscriptSettingsPanelView: NSView {
    private let noteLabel = FormBuilder.label("")
    private let directoryLabel = FormBuilder.label("")
    private let prefixField = FormBuilder.field(placeholder: "字幕记录")
    private let templateField = FormBuilder.field(placeholder: "{prefix}_{datetime}")
    private let formatPopup = NSPopUpButton()
    private let layoutPopup = NSPopUpButton()
    private let convertLayoutPopup = NSPopUpButton()
    private let convertFormatPopup = NSPopUpButton()
    private let recordCheckbox = NSButton(checkboxWithTitle: "启用字幕记录", target: nil, action: nil)
    private let statusLabel = FormBuilder.label("")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        recordCheckbox.state = TranscriptPreferences.recordEnabled ? .on : .off
        prefixField.stringValue = TranscriptPreferences.filePrefix
        templateField.stringValue = TranscriptPreferences.filenameTemplate
        directoryLabel.stringValue = TranscriptPreferences.directoryDisplayPath
        noteLabel.stringValue =
            "每次开始悬浮字幕时创建新文件；仅保存定稿句。\(TranscriptPreferences.filenameTokenHelp)"

        fillPopup(formatPopup, cases: TranscriptPreferences.FileFormat.allCases.map { ($0.rawValue, $0.label) })
        selectPopup(formatPopup, raw: TranscriptPreferences.fileFormat.rawValue)

        fillPopup(layoutPopup, cases: TranscriptContentLayout.allCases.map { ($0.rawValue, $0.label) })
        selectPopup(layoutPopup, raw: TranscriptPreferences.contentLayout.rawValue)

        fillPopup(convertLayoutPopup, cases: TranscriptContentLayout.allCases.map { ($0.rawValue, $0.label) })
        selectPopup(convertLayoutPopup, raw: TranscriptPreferences.contentLayout.rawValue)

        fillPopup(convertFormatPopup, cases: TranscriptPreferences.FileFormat.allCases.map { ($0.rawValue, $0.label) })
        selectPopup(convertFormatPopup, raw: TranscriptPreferences.fileFormat.rawValue)

        updatePreview()
    }

    private func setup() {
        noteLabel.maximumNumberOfLines = 0
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.font = .systemFont(ofSize: 11)

        directoryLabel.font = .systemFont(ofSize: 10)
        directoryLabel.textColor = .tertiaryLabelColor
        directoryLabel.lineBreakMode = .byCharWrapping
        directoryLabel.maximumNumberOfLines = 3

        prefixField.target = self
        prefixField.action = #selector(fieldChanged)
        templateField.target = self
        templateField.action = #selector(fieldChanged)

        for popup in [formatPopup, layoutPopup, convertLayoutPopup, convertFormatPopup] {
            popup.controlSize = .regular
            popup.target = self
        }
        formatPopup.action = #selector(formatChanged)
        layoutPopup.action = #selector(layoutChanged)
        convertLayoutPopup.action = #selector(convertOptionChanged)
        convertFormatPopup.action = #selector(convertOptionChanged)

        recordCheckbox.target = self
        recordCheckbox.action = #selector(recordToggled)

        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 3
        statusLabel.lineBreakMode = .byWordWrapping

        let chooseButton = NSButton(title: "选择目录…", target: self, action: #selector(chooseDirectory))
        chooseButton.bezelStyle = .rounded
        let resetButton = NSButton(title: "恢复默认目录", target: self, action: #selector(resetDirectory))
        resetButton.bezelStyle = .rounded
        let openButton = NSButton(title: "在 Finder 中打开", target: self, action: #selector(openDirectory))
        openButton.bezelStyle = .rounded

        let dirButtons = NSStackView(views: [chooseButton, resetButton, openButton])
        dirButtons.orientation = .horizontal
        dirButtons.spacing = 8
        dirButtons.alignment = .centerY

        let convertHint = FormBuilder.label("将已有 .md / .txt 记录转为其他内容形式，生成新文件（原文件保留）。")
        convertHint.font = .systemFont(ofSize: 10)
        convertHint.textColor = .secondaryLabelColor
        convertHint.maximumNumberOfLines = 0
        convertHint.lineBreakMode = .byWordWrapping

        let convertButton = NSButton(title: "转换已有文件…", target: self, action: #selector(convertExistingFile))
        convertButton.bezelStyle = .rounded

        let convertBlock = NSStackView(views: [
            FormBuilder.sectionHeader("转换已有记录"),
            convertHint,
            FormBuilder.formRow(title: "目标形式", trailing: convertLayoutPopup),
            FormBuilder.formRow(title: "目标格式", trailing: convertFormatPopup),
            convertButton,
        ])
        convertBlock.orientation = .vertical
        convertBlock.alignment = .leading
        convertBlock.spacing = 8

        let stack = NSStackView(views: [
            FormBuilder.sectionHeader("字幕记录"),
            noteLabel,
            recordCheckbox,
            FormBuilder.labeledRow(title: "保存目录", field: directoryLabel),
            dirButtons,
            FormBuilder.labeledRow(title: "文件名前缀", field: prefixField),
            FormBuilder.labeledRow(title: "文件名模板", field: templateField),
            FormBuilder.formRow(title: "文件格式", trailing: formatPopup),
            FormBuilder.formRow(title: "内容形式", trailing: layoutPopup),
            statusLabel,
            convertBlock,
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
            prefixField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            templateField.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            formatPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            layoutPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            convertLayoutPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            convertFormatPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }

    private func fillPopup(_ popup: NSPopUpButton, cases: [(String, String)]) {
        popup.removeAllItems()
        for item in cases {
            popup.addItem(withTitle: item.1)
            popup.lastItem?.representedObject = item.0
        }
    }

    private func selectPopup(_ popup: NSPopUpButton, raw: String) {
        if let idx = (0..<popup.numberOfItems).first(where: {
            (popup.item(at: $0)?.representedObject as? String) == raw
        }) {
            popup.selectItem(at: idx)
        }
    }

    private func updatePreview() {
        let sample = TranscriptPreferences.sessionFilename(started: Date(), modeId: "speech")
        let layout = TranscriptPreferences.contentLayout.label
        statusLabel.stringValue = "示例文件名：\(sample) · 内容：\(layout)"
        statusLabel.textColor = .secondaryLabelColor
    }

    private func persistFields() {
        TranscriptPreferences.filePrefix = prefixField.stringValue
        TranscriptPreferences.filenameTemplate = templateField.stringValue
        updatePreview()
    }

    @objc private func recordToggled() {
        TranscriptPreferences.recordEnabled = recordCheckbox.state == .on
    }

    @objc private func fieldChanged() {
        persistFields()
    }

    @objc private func formatChanged() {
        guard let raw = formatPopup.selectedItem?.representedObject as? String,
              let format = TranscriptPreferences.FileFormat(rawValue: raw) else { return }
        TranscriptPreferences.fileFormat = format
        updatePreview()
    }

    @objc private func layoutChanged() {
        guard let raw = layoutPopup.selectedItem?.representedObject as? String,
              let layout = TranscriptContentLayout(rawValue: raw) else { return }
        TranscriptPreferences.contentLayout = layout
        updatePreview()
    }

    @objc private func convertOptionChanged() {}

    @objc private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        panel.message = "选择字幕记录保存目录"
        panel.directoryURL = TranscriptPreferences.storageDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        TranscriptPreferences.storageDirectory = url
        directoryLabel.stringValue = TranscriptPreferences.directoryDisplayPath
        statusLabel.stringValue = "已设置保存目录"
        statusLabel.textColor = .systemGreen
    }

    @objc private func resetDirectory() {
        TranscriptPreferences.resetDirectoryToDefault()
        directoryLabel.stringValue = TranscriptPreferences.directoryDisplayPath
        statusLabel.stringValue = "已恢复默认目录"
        statusLabel.textColor = .systemGreen
    }

    @objc private func openDirectory() {
        TranslationRecorder.shared.openTranscriptsDirectory()
    }

    @objc private func convertExistingFile() {
        guard let layoutRaw = convertLayoutPopup.selectedItem?.representedObject as? String,
              let layout = TranscriptContentLayout(rawValue: layoutRaw),
              let formatRaw = convertFormatPopup.selectedItem?.representedObject as? String,
              let format = TranscriptPreferences.FileFormat(rawValue: formatRaw) else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.directoryURL = TranscriptPreferences.storageDirectory
        panel.message = "选择要转换的字幕记录文件"
        guard panel.runModal() == .OK, let source = panel.url else { return }

        do {
            let dest = try TranslationRecorder.convertFile(at: source, layout: layout, format: format)
            statusLabel.stringValue = "已生成：\(dest.lastPathComponent)"
            statusLabel.textColor = .systemGreen
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
    }
}
