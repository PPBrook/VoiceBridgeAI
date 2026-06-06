import AppKit

@MainActor
final class CloudPanelView: NSView {
    // Tencent
    private let tencentAppId = FormBuilder.field(placeholder: "AppId")
    private let tencentSecretId = FormBuilder.field(placeholder: "SecretId", secure: true)
    private let tencentSecretKey = FormBuilder.field(placeholder: "SecretKey", secure: true)
    private let tencentEngine = FormBuilder.field(placeholder: "16k_en")
    private let tencentRegion = FormBuilder.field(placeholder: "ap-guangzhou")
    private let tencentProject = FormBuilder.field(placeholder: "0")

    // Qiniu
    private let qiniuKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let qiniuBase = FormBuilder.field(placeholder: "https://api.qnaigc.com/v1")
    private let qiniuModel = FormBuilder.field(placeholder: "qwen-turbo")

    // Aliyun
    private let aliyunKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let aliyunBase = FormBuilder.field(placeholder: "DashScope Base URL")
    private let aliyunModel = FormBuilder.field(placeholder: "qwen-turbo")

    // Baidu
    private let baiduAppId = FormBuilder.field(placeholder: "AppId")
    private let baiduSecret = FormBuilder.field(placeholder: "Secret Key", secure: true)

    // DeepL
    private let deeplKey = FormBuilder.field(placeholder: "…:fx（免费版）", secure: true)

    // DeepSeek
    private let deepseekKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let deepseekBase = FormBuilder.field(placeholder: "https://api.deepseek.com/v1")
    private let deepseekModel = FormBuilder.field(placeholder: "deepseek-chat")

    // OpenAI
    private let openaiKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let openaiBase = FormBuilder.field(placeholder: "https://api.openai.com/v1")
    private let openaiModel = FormBuilder.field(placeholder: "gpt-4o-mini")
    private let openaiAsrModel = FormBuilder.field(placeholder: "whisper-1")

    private var testStatuses: [String: NSTextField] = [:]
    private let noteLabel = FormBuilder.label("")
    private let saveButton = NSButton(title: "保存配置", target: nil, action: nil)
    private let testAllButton = NSButton(title: "一键测试全部", target: nil, action: nil)
    private let guideDocButton = NSButton(title: "打开完整密钥文档", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        noteLabel.maximumNumberOfLines = 0
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.textColor = .secondaryLabelColor

        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.bezelStyle = .rounded
        testAllButton.target = self
        testAllButton.action = #selector(testAllClicked)
        testAllButton.bezelStyle = .rounded
        guideDocButton.target = self
        guideDocButton.action = #selector(openGuideDoc)
        guideDocButton.bezelStyle = .inline
        guideDocButton.font = .systemFont(ofSize: 11)

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14

        content.addArrangedSubview(FormBuilder.sectionHeader("接口配置"))
        noteLabel.stringValue = CloudProviderGuides.intro
        content.addArrangedSubview(noteLabel)
        content.addArrangedSubview(guideDocButton)

        content.addArrangedSubview(regionHeader("国内接口"))

        addProvider(content, title: "腾讯云", guide: CloudProviderGuides.tencent, rows: [
            FormBuilder.labeledRow(title: "AppId", field: tencentAppId),
            FormBuilder.labeledRow(title: "SecretId", field: tencentSecretId),
            FormBuilder.labeledRow(title: "SecretKey", field: tencentSecretKey),
            FormBuilder.labeledRow(title: "识别引擎", field: tencentEngine),
            FormBuilder.labeledRow(title: "TMT 区域", field: tencentRegion),
            FormBuilder.labeledRow(title: "TMT Project", field: tencentProject),
        ], tests: [
            ("识别", "asr", "tencent"),
            ("句中 TMT", "partial", "tmt"),
            ("句末 TMT", "final", "tmt"),
        ])

        addProvider(content, title: "七牛 AI", guide: CloudProviderGuides.qiniu, rows: [
            FormBuilder.labeledRow(title: "API Key", field: qiniuKey),
            FormBuilder.labeledRow(title: "Base URL", field: qiniuBase),
            FormBuilder.labeledRow(title: "Model", field: qiniuModel),
        ], tests: [
            ("句中", "partial", "qiniu"),
            ("句末", "final", "qiniu"),
        ])

        addProvider(content, title: "阿里云 DashScope", guide: CloudProviderGuides.aliyun, rows: [
            FormBuilder.labeledRow(title: "API Key", field: aliyunKey),
            FormBuilder.labeledRow(title: "Base URL", field: aliyunBase),
            FormBuilder.labeledRow(title: "Model", field: aliyunModel),
        ], tests: [
            ("句中", "partial", "aliyun"),
            ("句末", "final", "aliyun"),
        ])

        addProvider(content, title: "百度翻译", guide: CloudProviderGuides.baidu, rows: [
            FormBuilder.labeledRow(title: "AppId", field: baiduAppId),
            FormBuilder.labeledRow(title: "Secret Key", field: baiduSecret),
        ], tests: [
            ("句中", "partial", "baidu"),
            ("句末", "final", "baidu"),
        ])

        addProvider(content, title: "DeepSeek", guide: CloudProviderGuides.deepseek, rows: [
            FormBuilder.labeledRow(title: "API Key", field: deepseekKey),
            FormBuilder.labeledRow(title: "Base URL", field: deepseekBase),
            FormBuilder.labeledRow(title: "Model", field: deepseekModel),
        ], tests: [
            ("句中", "partial", "deepseek"),
            ("句末", "final", "deepseek"),
        ])

        content.addArrangedSubview(regionHeader("海外接口"))

        addProvider(content, title: "OpenAI", guide: CloudProviderGuides.openai, rows: [
            FormBuilder.labeledRow(title: "API Key", field: openaiKey),
            FormBuilder.labeledRow(title: "Base URL", field: openaiBase),
            FormBuilder.labeledRow(title: "Chat Model", field: openaiModel),
            FormBuilder.labeledRow(title: "ASR Model", field: openaiAsrModel),
        ], tests: [
            ("识别", "asr", "openai"),
            ("句中", "partial", "openai"),
            ("句末", "final", "openai"),
        ])

        addProvider(content, title: "DeepL", guide: CloudProviderGuides.deepl, rows: [
            FormBuilder.labeledRow(title: "API Key", field: deeplKey),
        ], tests: [
            ("句中", "partial", "deepl"),
            ("句末", "final", "deepl"),
        ])

        addProvider(content, title: "Google 在线", guide: CloudProviderGuides.google, rows: [], tests: [
            ("句中", "partial", "google"),
            ("句末", "final", "google"),
        ])

        let actions = NSStackView(views: [saveButton, testAllButton])
        actions.orientation = .horizontal
        actions.spacing = 8
        content.addArrangedSubview(actions)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -24),
        ])
    }

    private func regionHeader(_ title: String) -> NSTextField {
        let label = FormBuilder.label(title)
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }

    private func addProvider(
        _ stack: NSStackView,
        title: String,
        guide: ProviderGuide?,
        rows: [NSStackView],
        tests: [(String, String, String)]
    ) {
        stack.addArrangedSubview(FormBuilder.sectionHeader(title))
        if let guide {
            stack.addArrangedSubview(CloudProviderGuides.makeGuideView(guide))
        }
        for row in rows { stack.addArrangedSubview(row) }
        for (label, layer, provider) in tests {
            let key = "\(layer):\(provider)"
            let verified = SettingsStore.shared.isVerified(layer: layer, providerId: provider)
            let built = FormBuilder.testRow(
                title: label,
                verified: verified,
                action: #selector(testClicked(_:)),
                target: self
            )
            built.button.identifier = NSUserInterfaceItemIdentifier(key)
            testStatuses[key] = built.status
            stack.addArrangedSubview(built.row)
        }
    }

    func reload() {
        let health = SettingsStore.shared.health
        let t = health["tencent"] as? [String: Any] ?? [:]
        if let v = t["appId"] as? String { tencentAppId.stringValue = v }
        if let v = t["engine"] as? String { tencentEngine.stringValue = v }
        if let v = t["tmtRegion"] as? String { tencentRegion.stringValue = v }
        if let v = t["tmtProjectId"] as? String { tencentProject.stringValue = v }
        tencentSecretId.placeholderString = (t["hasSecretId"] as? Bool == true) ? "已配置，留空不修改" : "SecretId"
        tencentSecretKey.placeholderString = (t["hasSecretKey"] as? Bool == true) ? "已配置，留空不修改" : "SecretKey"

        let q = health["qiniu"] as? [String: Any] ?? [:]
        if let v = q["baseUrl"] as? String { qiniuBase.stringValue = v }
        if let v = q["model"] as? String { qiniuModel.stringValue = v }
        qiniuKey.placeholderString = (q["hasApiKey"] as? Bool == true) ? "已配置，留空不修改" : "API Key"

        let a = health["aliyun"] as? [String: Any] ?? [:]
        if let v = a["baseUrl"] as? String { aliyunBase.stringValue = v }
        if let v = a["model"] as? String { aliyunModel.stringValue = v }
        aliyunKey.placeholderString = (a["hasApiKey"] as? Bool == true) ? "已配置，留空不修改" : "API Key"

        let b = health["baidu"] as? [String: Any] ?? [:]
        if let v = b["appId"] as? String { baiduAppId.stringValue = v }
        baiduSecret.placeholderString = (b["hasSecretKey"] as? Bool == true) ? "已配置，留空不修改" : "Secret Key"

        let d = health["deepl"] as? [String: Any] ?? [:]
        deeplKey.placeholderString = (d["hasApiKey"] as? Bool == true) ? "已配置，留空不修改" : "API Key"

        let ds = health["deepseek"] as? [String: Any] ?? [:]
        if let v = ds["baseUrl"] as? String { deepseekBase.stringValue = v }
        if let v = ds["model"] as? String { deepseekModel.stringValue = v }
        deepseekKey.placeholderString = (ds["hasApiKey"] as? Bool == true) ? "已配置，留空不修改" : "API Key"

        let o = health["openai"] as? [String: Any] ?? [:]
        if let v = o["baseUrl"] as? String { openaiBase.stringValue = v }
        if let v = o["model"] as? String { openaiModel.stringValue = v }
        if let v = o["asrModel"] as? String { openaiAsrModel.stringValue = v }
        openaiKey.placeholderString = (o["hasApiKey"] as? Bool == true) ? "已配置，留空不修改" : "API Key"

        refreshTestStatuses()
    }

    @objc private func openGuideDoc() {
        CloudProviderGuides.openProviderKeysGuide()
    }

    private func refreshTestStatuses() {
        for (key, label) in testStatuses {
            let parts = key.split(separator: ":").map(String.init)
            guard parts.count == 2 else { continue }
            let ok = SettingsStore.shared.isVerified(layer: parts[0], providerId: parts[1])
            label.stringValue = ok ? "已通过" : "—"
            label.textColor = ok ? .systemGreen : .secondaryLabelColor
        }
    }

    private func collectPayload() -> [String: Any] {
        var payload: [String: Any] = [:]

        var tencent: [String: Any] = [:]
        put(&tencent, "appId", tencentAppId.stringValue)
        put(&tencent, "engine", tencentEngine.stringValue)
        put(&tencent, "tmtRegion", tencentRegion.stringValue)
        put(&tencent, "tmtProjectId", tencentProject.stringValue)
        put(&tencent, "secretId", tencentSecretId.stringValue)
        put(&tencent, "secretKey", tencentSecretKey.stringValue)
        if !tencent.isEmpty { payload["tencent"] = tencent }

        var qiniu: [String: Any] = [:]
        put(&qiniu, "apiKey", qiniuKey.stringValue)
        put(&qiniu, "baseUrl", qiniuBase.stringValue)
        put(&qiniu, "model", qiniuModel.stringValue)
        if !qiniu.isEmpty { payload["qiniu"] = qiniu }

        var aliyun: [String: Any] = [:]
        put(&aliyun, "apiKey", aliyunKey.stringValue)
        put(&aliyun, "baseUrl", aliyunBase.stringValue)
        put(&aliyun, "model", aliyunModel.stringValue)
        if !aliyun.isEmpty { payload["aliyun"] = aliyun }

        var baidu: [String: Any] = [:]
        put(&baidu, "appId", baiduAppId.stringValue)
        put(&baidu, "secretKey", baiduSecret.stringValue)
        if !baidu.isEmpty { payload["baidu"] = baidu }

        var deepl: [String: Any] = [:]
        put(&deepl, "apiKey", deeplKey.stringValue)
        if !deepl.isEmpty { payload["deepl"] = deepl }

        var deepseek: [String: Any] = [:]
        put(&deepseek, "apiKey", deepseekKey.stringValue)
        put(&deepseek, "baseUrl", deepseekBase.stringValue)
        put(&deepseek, "model", deepseekModel.stringValue)
        if !deepseek.isEmpty { payload["deepseek"] = deepseek }

        var openai: [String: Any] = [:]
        put(&openai, "apiKey", openaiKey.stringValue)
        put(&openai, "baseUrl", openaiBase.stringValue)
        put(&openai, "model", openaiModel.stringValue)
        put(&openai, "asrModel", openaiAsrModel.stringValue)
        if !openai.isEmpty { payload["openai"] = openai }

        return payload
    }

    private func put(_ dict: inout [String: Any], _ key: String, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty { dict[key] = v }
    }

    private func clearSecrets() {
        tencentSecretId.stringValue = ""
        tencentSecretKey.stringValue = ""
        qiniuKey.stringValue = ""
        aliyunKey.stringValue = ""
        baiduSecret.stringValue = ""
        deeplKey.stringValue = ""
        deepseekKey.stringValue = ""
        openaiKey.stringValue = ""
    }

    @objc private func saveClicked() {
        let payload = collectPayload()
        guard !payload.isEmpty else {
            noteLabel.stringValue = "没有可保存的内容（请填写至少一项）"
            noteLabel.textColor = .systemOrange
            return
        }
        saveButton.isEnabled = false
        Task { @MainActor in
            defer { saveButton.isEnabled = true }
            do {
                let msg = try await SettingsStore.shared.saveCloud(payload)
                clearSecrets()
                noteLabel.textColor = .systemGreen
                noteLabel.stringValue = msg
                reload()
                AppDelegate.shared?.control?.refreshEngineSummary()
            } catch {
                noteLabel.textColor = .systemRed
                noteLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc private func testAllClicked() {
        testAllButton.isEnabled = false
        Task { @MainActor in
            defer { testAllButton.isEnabled = true }
            let (msg, results) = await SettingsStore.shared.testAllCloud(collectPayload())
            noteLabel.textColor = .labelColor
            noteLabel.stringValue = msg
            for item in results {
                let key = "\(item["layer"] as? String ?? ""):\(item["providerId"] as? String ?? "")"
                if let label = testStatuses[key] {
                    let ok = item["ok"] as? Bool ?? false
                    label.stringValue = ok ? "已通过" : "失败"
                    label.textColor = ok ? .systemGreen : .systemRed
                }
            }
            reload()
        }
    }

    @objc private func testClicked(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count == 2 else { return }
        let status = testStatuses[key]
        status?.stringValue = "测试中…"
        Task { @MainActor in
            let (ok, msg) = await SettingsStore.shared.testCloud(
                layer: parts[0],
                providerId: parts[1],
                payload: collectPayload()
            )
            status?.stringValue = ok ? "已通过" : msg
            status?.textColor = ok ? .systemGreen : .systemRed
            reload()
        }
    }
}
