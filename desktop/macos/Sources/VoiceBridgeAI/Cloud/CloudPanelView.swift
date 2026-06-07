import AppKit

@MainActor
final class CloudPanelView: NSView {
    // MARK: - Credential fields

    let tencentAppId = FormBuilder.field(placeholder: "AppId")
    let tencentSecretId = FormBuilder.field(placeholder: "SecretId", secure: true)
    let tencentSecretKey = FormBuilder.field(placeholder: "SecretKey", secure: true)
    let tencentEngine = FormBuilder.field(placeholder: "16k_en")
    let tencentRegion = FormBuilder.field(placeholder: "ap-guangzhou")
    let tencentProject = FormBuilder.field(placeholder: "0")

    let qiniuKey = FormBuilder.field(placeholder: "API Key", secure: true)
    let qiniuBase = FormBuilder.field(placeholder: "https://api.qnaigc.com/v1")
    let qiniuModel = FormBuilder.field(placeholder: "qwen-turbo")

    let aliyunKey = FormBuilder.field(placeholder: "API Key", secure: true)
    let aliyunBase = FormBuilder.field(placeholder: "DashScope Base URL")
    let aliyunModel = FormBuilder.field(placeholder: "qwen-turbo")

    let baiduAppId = FormBuilder.field(placeholder: "AppId")
    let baiduSecret = FormBuilder.field(placeholder: "Secret Key", secure: true)

    let deeplKey = FormBuilder.field(placeholder: "…:fx（免费版）", secure: true)

    let deepseekKey = FormBuilder.field(placeholder: "API Key", secure: true)
    let deepseekBase = FormBuilder.field(placeholder: "https://api.deepseek.com/v1")
    let deepseekModel = FormBuilder.field(placeholder: "deepseek-chat")

    let openaiKey = FormBuilder.field(placeholder: "API Key", secure: true)
    let openaiBase = FormBuilder.field(placeholder: "https://api.openai.com/v1")
    let openaiModel = FormBuilder.field(placeholder: "gpt-4o-mini")
    let openaiAsrModel = FormBuilder.field(placeholder: "whisper-1")

    // MARK: - UI state

    var testStatuses: [String: NSTextField] = [:]
    var testButtons: [String: NSButton] = [:]
    var lastTestResults: [String: (ok: Bool, message: String)] = [:]
    var inFlightTests: Set<String> = []
    var providerSections: [String: ProviderSectionView] = [:]
    var sectionWidthConstraints: [String: NSLayoutConstraint] = [:]

    let domesticRegionHeader = FormBuilder.regionHeader("国内接口")
    let overseasRegionHeader = FormBuilder.regionHeader("海外接口")
    let domesticStack = NSStackView()
    let overseasStack = NSStackView()
    let hiddenSectionContainer = NSStackView()
    let hiddenSectionToggle = NSButton(title: "", target: nil, action: nil)
    let hiddenStack = NSStackView()

    let noteLabel = FormBuilder.label("")
    let saveButton = FormBuilder.primaryButton("保存配置")
    let testAllButton = NSButton(title: "一键测试全部", target: nil, action: nil)
    let scroll = NSScrollView()
    let content = NSStackView()

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        let health = SettingsStore.shared.health
        CloudProviderPreferences.applyHealthPrefs(health)
        relayoutProviderSections()
        applyStartupTest(health)
        applyStartupTestResults(health)
        bindCredentials(from: health)
        refreshTestStatuses()
    }

    // MARK: - Setup

    private func setup() {
        noteLabel.maximumNumberOfLines = 0
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.font = .systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor

        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        testAllButton.target = self
        testAllButton.action = #selector(testAllClicked)
        testAllButton.bezelStyle = .rounded
        testAllButton.controlSize = .large

        configureVerticalStack(content, spacing: 12)

        let intro = FormBuilder.banner(text: CloudProviderGuides.intro)
        content.addArrangedSubview(intro)
        content.addArrangedSubview(noteLabel)
        intro.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        configureVerticalStack(domesticStack)
        configureVerticalStack(overseasStack)
        configureVerticalStack(hiddenStack)

        content.addArrangedSubview(domesticRegionHeader)
        content.addArrangedSubview(domesticStack)
        domesticStack.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        content.addArrangedSubview(overseasRegionHeader)
        content.addArrangedSubview(overseasStack)
        overseasStack.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        registerProviders()
        setupHiddenSection()
        content.addArrangedSubview(hiddenSectionContainer)
        hiddenSectionContainer.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.documentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = NSBox()
        bottomBar.boxType = .custom
        bottomBar.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        bottomBar.borderColor = NSColor.separatorColor
        bottomBar.borderWidth = 1
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let actions = NSStackView(views: [saveButton, testAllButton])
        actions.orientation = .horizontal
        actions.spacing = 10
        actions.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(actions)

        addSubview(scroll)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 52),
            actions.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            actions.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor, constant: 12),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])

        relayoutProviderSections()
    }
}
