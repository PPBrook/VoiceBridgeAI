import AppKit

@MainActor
final class CloudPanelView: NSView {
    // MARK: - Credential fields

    private let tencentAppId = FormBuilder.field(placeholder: "AppId")
    private let tencentSecretId = FormBuilder.field(placeholder: "SecretId", secure: true)
    private let tencentSecretKey = FormBuilder.field(placeholder: "SecretKey", secure: true)
    private let tencentEngine = FormBuilder.field(placeholder: "16k_en")
    private let tencentRegion = FormBuilder.field(placeholder: "ap-guangzhou")
    private let tencentProject = FormBuilder.field(placeholder: "0")

    private let qiniuKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let qiniuBase = FormBuilder.field(placeholder: "https://api.qnaigc.com/v1")
    private let qiniuModel = FormBuilder.field(placeholder: "qwen-turbo")

    private let aliyunKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let aliyunBase = FormBuilder.field(placeholder: "DashScope Base URL")
    private let aliyunModel = FormBuilder.field(placeholder: "qwen-turbo")

    private let baiduAppId = FormBuilder.field(placeholder: "AppId")
    private let baiduSecret = FormBuilder.field(placeholder: "Secret Key", secure: true)

    private let deeplKey = FormBuilder.field(placeholder: "…:fx（免费版）", secure: true)

    private let deepseekKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let deepseekBase = FormBuilder.field(placeholder: "https://api.deepseek.com/v1")
    private let deepseekModel = FormBuilder.field(placeholder: "deepseek-chat")

    private let openaiKey = FormBuilder.field(placeholder: "API Key", secure: true)
    private let openaiBase = FormBuilder.field(placeholder: "https://api.openai.com/v1")
    private let openaiModel = FormBuilder.field(placeholder: "gpt-4o-mini")
    private let openaiAsrModel = FormBuilder.field(placeholder: "whisper-1")

    // MARK: - UI state

    private var testStatuses: [String: NSTextField] = [:]
    private var testButtons: [String: NSButton] = [:]
    private var lastTestResults: [String: (ok: Bool, message: String)] = [:]
    private var inFlightTests: Set<String> = []
    private var providerSections: [String: ProviderSectionView] = [:]
    private var sectionWidthConstraints: [String: NSLayoutConstraint] = [:]

    private let domesticRegionHeader = FormBuilder.regionHeader("国内接口")
    private let overseasRegionHeader = FormBuilder.regionHeader("海外接口")
    private let domesticStack = NSStackView()
    private let overseasStack = NSStackView()
    private let hiddenSectionContainer = NSStackView()
    private let hiddenSectionToggle = NSButton(title: "", target: nil, action: nil)
    private let hiddenStack = NSStackView()

    private let noteLabel = FormBuilder.label("")
    private let saveButton = FormBuilder.primaryButton("保存配置")
    private let testAllButton = NSButton(title: "一键测试全部", target: nil, action: nil)
    private let scroll = NSScrollView()
    private let content = NSStackView()

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

    private func registerProviders() {
        addProvider(id: "tencent", title: "腾讯云", guide: CloudProviderGuides.tencent, rows: [
            FormBuilder.labeledRow(title: "AppId", field: tencentAppId),
            FormBuilder.labeledRow(title: "SecretId", field: tencentSecretId),
            FormBuilder.labeledRow(title: "SecretKey", field: tencentSecretKey),
            FormBuilder.labeledRow(title: "识别引擎", field: tencentEngine),
            FormBuilder.labeledRow(title: "TMT 区域", field: tencentRegion),
            FormBuilder.labeledRow(title: "Project", field: tencentProject),
        ])
        addProvider(id: "qiniu", title: "七牛 AI", guide: CloudProviderGuides.qiniu, rows: [
            FormBuilder.labeledRow(title: "API Key", field: qiniuKey),
            FormBuilder.labeledRow(title: "Base URL", field: qiniuBase),
            FormBuilder.labeledRow(title: "Model", field: qiniuModel),
        ])
        addProvider(id: "aliyun", title: "阿里云", guide: CloudProviderGuides.aliyun, rows: [
            FormBuilder.labeledRow(title: "API Key", field: aliyunKey),
            FormBuilder.labeledRow(title: "Base URL", field: aliyunBase),
            FormBuilder.labeledRow(title: "Model", field: aliyunModel),
        ])
        addProvider(id: "baidu", title: "百度翻译", guide: CloudProviderGuides.baidu, rows: [
            FormBuilder.labeledRow(title: "AppId", field: baiduAppId),
            FormBuilder.labeledRow(title: "Secret", field: baiduSecret),
        ])
        addProvider(id: "deepseek", title: "DeepSeek", guide: CloudProviderGuides.deepseek, rows: [
            FormBuilder.labeledRow(title: "API Key", field: deepseekKey),
            FormBuilder.labeledRow(title: "Base URL", field: deepseekBase),
            FormBuilder.labeledRow(title: "Model", field: deepseekModel),
        ])
        addProvider(id: "openai", title: "OpenAI", guide: CloudProviderGuides.openai, rows: [
            FormBuilder.labeledRow(title: "API Key", field: openaiKey),
            FormBuilder.labeledRow(title: "Base URL", field: openaiBase),
            FormBuilder.labeledRow(title: "Chat", field: openaiModel),
            FormBuilder.labeledRow(title: "ASR", field: openaiAsrModel),
        ])
        addProvider(id: "deepl", title: "DeepL", guide: CloudProviderGuides.deepl, rows: [
            FormBuilder.labeledRow(title: "API Key", field: deeplKey),
        ])
        addProvider(id: "google", title: "Google 在线", guide: CloudProviderGuides.google, rows: [])
    }

    private func configureVerticalStack(_ stack: NSStackView, spacing: CGFloat = 12) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
    }

    private func addProvider(id: String, title: String, guide: ProviderGuide?, rows: [NSStackView]) {
        let section = ProviderSectionView(title: title)
        section.translatesAutoresizingMaskIntoConstraints = false
        if let guide { section.addGuide(CloudProviderGuides.makeGuideView(guide)) }
        rows.forEach { section.addRow($0) }

        let tests = CloudProviderRegistry.tests(for: id)
        if !tests.isEmpty {
            section.addTestsHeader()
            for test in tests {
                let verified = SettingsStore.shared.isVerified(layer: test.layer, providerId: test.providerId)
                let built = FormBuilder.testRow(
                    title: test.label,
                    verified: verified,
                    action: #selector(testClicked(_:)),
                    target: self
                )
                built.button.identifier = NSUserInterfaceItemIdentifier(test.key)
                testStatuses[test.key] = built.status
                testButtons[test.key] = built.button
                section.addRow(built.row)
                built.row.widthAnchor.constraint(equalTo: section.widthAnchor, constant: -24).isActive = true
            }
        }

        providerSections[id] = section
        updateSectionBadge(for: id)
    }

    // MARK: - Hidden section

    private func setupHiddenSection() {
        hiddenSectionContainer.orientation = .vertical
        hiddenSectionContainer.alignment = .leading
        hiddenSectionContainer.spacing = 8

        hiddenSectionToggle.setButtonType(.momentaryChange)
        hiddenSectionToggle.isBordered = false
        hiddenSectionToggle.alignment = .left
        hiddenSectionToggle.font = .systemFont(ofSize: 12, weight: .semibold)
        hiddenSectionToggle.contentTintColor = .secondaryLabelColor
        hiddenSectionToggle.target = self
        hiddenSectionToggle.action = #selector(toggleHiddenSection)

        hiddenSectionContainer.addArrangedSubview(hiddenSectionToggle)
        hiddenSectionContainer.addArrangedSubview(hiddenStack)
        hiddenStack.widthAnchor.constraint(equalTo: hiddenSectionContainer.widthAnchor).isActive = true
    }

    @objc private func toggleHiddenSection() {
        CloudProviderPreferences.hiddenSectionExpanded.toggle()
        updateHiddenSectionChrome()
    }

    private func updateHiddenSectionChrome() {
        let hidden = CloudProviderPreferences.hiddenProviders()
        hiddenSectionContainer.isHidden = hidden.isEmpty
        guard !hidden.isEmpty else { return }
        let expanded = CloudProviderPreferences.hiddenSectionExpanded
        hiddenSectionToggle.title = "\(expanded ? "▾" : "▸")  已隐藏的接口（\(hidden.count)）"
        hiddenStack.isHidden = !expanded
    }

    private func relayoutProviderSections() {
        let hidden = CloudProviderPreferences.hiddenProviders()
        clearStack(domesticStack)
        clearStack(overseasStack)
        clearStack(hiddenStack)

        for id in CloudProviderRegistry.domesticOrder where !hidden.contains(id) {
            attachSection(id, to: domesticStack)
        }
        for id in CloudProviderRegistry.overseasOrder where !hidden.contains(id) {
            attachSection(id, to: overseasStack)
        }
        for id in CloudProviderRegistry.allIds where hidden.contains(id) {
            attachSection(id, to: hiddenStack)
        }

        domesticRegionHeader.isHidden = CloudProviderRegistry.domesticOrder.allSatisfy { hidden.contains($0) }
        overseasRegionHeader.isHidden = CloudProviderRegistry.overseasOrder.allSatisfy { hidden.contains($0) }
        updateHiddenSectionChrome()
        refreshSectionBadges()
    }

    private func clearStack(_ stack: NSStackView) {
        while let view = stack.arrangedSubviews.first {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func attachSection(_ id: String, to stack: NSStackView) {
        guard let section = providerSections[id] else { return }
        section.configurePanelMode(inHiddenPanel: stack === hiddenStack)
        section.onHiddenChanged = { [weak self] hidden in
            self?.providerHiddenChanged(id: id, hidden: hidden)
        }
        stack.addArrangedSubview(section)
        sectionWidthConstraints[id]?.isActive = false
        let width = section.widthAnchor.constraint(equalTo: stack.widthAnchor)
        width.isActive = true
        sectionWidthConstraints[id] = width
        updateSectionBadge(for: id)
    }

    private func providerHiddenChanged(id: String, hidden: Bool) {
        CloudProviderPreferences.setHidden(id, hidden: hidden)
        relayoutProviderSections()
        Task { @MainActor in
            guard CloudProviderPreferences.syncToDisk() else {
                noteLabel.textColor = .systemOrange
                noteLabel.stringValue = "隐藏偏好写入失败"
                return
            }
            await CloudProviderPreferences.pushToServer()
        }
    }

    // MARK: - Test badges & status

    private func isStartupTestRunning() -> Bool {
        (SettingsStore.shared.health["startupTest"] as? [String: Any])?["running"] as? Bool == true
    }

    private func activeTestKeys() -> [String] {
        CloudProviderRegistry.activeTestKeys(hidden: CloudProviderPreferences.hiddenProviders())
    }

    private func updateSectionBadge(for id: String) {
        let tests = CloudProviderRegistry.tests(for: id)
        guard let section = providerSections[id], !tests.isEmpty else { return }
        if CloudProviderPreferences.isHidden(id) {
            section.setBadge(nil, ok: nil)
            return
        }

        let keys = tests.map(\.key)
        let inFlightCount = keys.filter { inFlightTests.contains($0) }.count
        let failedCount = keys.filter { lastTestResults[$0]?.ok == false }.count

        if inFlightCount > 0 {
            let text = inFlightCount == keys.count ? "测试中…" : "\(inFlightCount)/\(keys.count) 测试中…"
            section.setBadge(text, ok: nil)
            return
        }
        if isStartupTestRunning() && failedCount == 0 {
            section.setBadge("测试中…", ok: nil)
            return
        }

        let verifiedCount = tests.filter {
            SettingsStore.shared.isVerified(layer: $0.layer, providerId: $0.providerId)
        }.count

        if failedCount > 0 {
            section.setBadge("\(verifiedCount)/\(tests.count) 已通过", ok: nil)
        } else if verifiedCount == tests.count {
            section.setBadge("全部通过", ok: true)
        } else if verifiedCount > 0 {
            section.setBadge("\(verifiedCount)/\(tests.count) 已通过", ok: nil)
        } else {
            section.setBadge(nil, ok: nil)
        }
    }

    private func refreshSectionBadges() {
        CloudProviderRegistry.allIds.forEach { updateSectionBadge(for: $0) }
    }

    private func applyTestStatus(for key: String) {
        guard let label = testStatuses[key] else { return }
        if inFlightTests.contains(key) {
            label.stringValue = "测试中…"
            FormBuilder.applyTestStatusColor(label, verified: nil)
            return
        }
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count == 2 else { return }

        if let last = lastTestResults[key], !last.ok {
            label.stringValue = last.message
            FormBuilder.applyTestStatusColor(label, verified: false)
            return
        }
        if SettingsStore.shared.isVerified(layer: parts[0], providerId: parts[1]) {
            label.stringValue = lastTestResults[key]?.message.nilIfEmpty ?? "已通过"
            FormBuilder.applyTestStatusColor(label, verified: true)
        } else if let last = lastTestResults[key] {
            label.stringValue = last.ok ? (last.message.nilIfEmpty ?? "已通过") : last.message
            FormBuilder.applyTestStatusColor(label, verified: last.ok)
        } else {
            label.stringValue = "未测试"
            FormBuilder.applyTestStatusColor(label, verified: nil)
        }
    }

    private func finishSingleTest(key: String, ok: Bool, message: String) {
        inFlightTests.remove(key)
        lastTestResults[key] = (ok, message)
        applyTestStatus(for: key)
        testButtons[key]?.isEnabled = !isStartupTestRunning()
        if let cardId = CloudProviderRegistry.cardId(forTestKey: key) {
            updateSectionBadge(for: cardId)
        }
    }

    private func refreshTestStatuses() {
        if isStartupTestRunning() {
            for key in activeTestKeys() where inFlightTests.contains(key) || lastTestResults[key] == nil {
                guard let label = testStatuses[key] else { continue }
                label.stringValue = "测试中…"
                FormBuilder.applyTestStatusColor(label, verified: nil)
            }
            for key in activeTestKeys() where !inFlightTests.contains(key) && lastTestResults[key] != nil {
                applyTestStatus(for: key)
            }
        } else {
            testStatuses.keys.forEach { applyTestStatus(for: $0) }
        }
        setIndividualTestButtonsEnabled(!isStartupTestRunning())
        refreshSectionBadges()
    }

    private func setIndividualTestButtonsEnabled(_ enabled: Bool) {
        for (key, button) in testButtons {
            button.isEnabled = enabled && !inFlightTests.contains(key)
        }
    }

    private func storeTestResult(from item: [String: Any]) {
        let layer = item["layer"] as? String ?? ""
        let providerId = item["providerId"] as? String ?? ""
        guard !layer.isEmpty, !providerId.isEmpty else { return }
        let ok = item["ok"] as? Bool ?? false
        let message = item["message"] as? String ?? (ok ? "已通过" : "失败")
        lastTestResults["\(layer):\(providerId)"] = (ok, message)
    }

    private func applyStartupTest(_ health: [String: Any]) {
        guard let st = health["startupTest"] as? [String: Any] else { return }
        if st["running"] as? Bool == true {
            noteLabel.stringValue = (st["summary"] as? String) ?? "正在启动测试…"
            noteLabel.textColor = .secondaryLabelColor
            testAllButton.isEnabled = false
            setIndividualTestButtonsEnabled(false)
            return
        }
        testAllButton.isEnabled = true
        setIndividualTestButtonsEnabled(true)
        guard st["done"] as? Bool == true, let summary = st["summary"] as? String, !summary.isEmpty else {
            if CloudProviderPreferences.hiddenProviders().isEmpty { noteLabel.stringValue = "" }
            return
        }
        noteLabel.stringValue = summary
        if summary.contains("没有可测试") {
            noteLabel.textColor = .secondaryLabelColor
        } else if let results = st["results"] as? [[String: Any]],
                  results.contains(where: { ($0["ok"] as? Bool) != true }) {
            noteLabel.textColor = .systemOrange
        } else {
            noteLabel.textColor = .secondaryLabelColor
        }
    }

    private func applyStartupTestResults(_ health: [String: Any]) {
        guard let st = health["startupTest"] as? [String: Any],
              let results = st["results"] as? [[String: Any]] else { return }
        results.forEach { storeTestResult(from: $0) }
    }

    // MARK: - Credentials reload & save

    private func bindCredentials(from health: [String: Any]) {
        let t = health["tencent"] as? [String: Any] ?? [:]
        bindText(tencentAppId, from: t, key: "appId")
        bindText(tencentEngine, from: t, key: "engine")
        bindText(tencentRegion, from: t, key: "tmtRegion")
        bindText(tencentProject, from: t, key: "tmtProjectId")
        bindSecret(tencentSecretId, from: t, hasKey: "hasSecretId", placeholder: "SecretId")
        bindSecret(tencentSecretKey, from: t, hasKey: "hasSecretKey", placeholder: "SecretKey")

        let q = health["qiniu"] as? [String: Any] ?? [:]
        bindText(qiniuBase, from: q, key: "baseUrl")
        bindText(qiniuModel, from: q, key: "model")
        bindSecret(qiniuKey, from: q, hasKey: "hasApiKey", placeholder: "API Key")

        let a = health["aliyun"] as? [String: Any] ?? [:]
        bindText(aliyunBase, from: a, key: "baseUrl")
        bindText(aliyunModel, from: a, key: "model")
        bindSecret(aliyunKey, from: a, hasKey: "hasApiKey", placeholder: "API Key")

        let b = health["baidu"] as? [String: Any] ?? [:]
        bindText(baiduAppId, from: b, key: "appId")
        bindSecret(baiduSecret, from: b, hasKey: "hasSecretKey", placeholder: "Secret Key")

        let d = health["deepl"] as? [String: Any] ?? [:]
        bindSecret(deeplKey, from: d, hasKey: "hasApiKey", placeholder: "API Key")

        let ds = health["deepseek"] as? [String: Any] ?? [:]
        bindText(deepseekBase, from: ds, key: "baseUrl")
        bindText(deepseekModel, from: ds, key: "model")
        bindSecret(deepseekKey, from: ds, hasKey: "hasApiKey", placeholder: "API Key")

        let o = health["openai"] as? [String: Any] ?? [:]
        bindText(openaiBase, from: o, key: "baseUrl")
        bindText(openaiModel, from: o, key: "model")
        bindText(openaiAsrModel, from: o, key: "asrModel")
        bindSecret(openaiKey, from: o, hasKey: "hasApiKey", placeholder: "API Key")
    }

    private func bindText(_ field: NSTextField, from dict: [String: Any], key: String) {
        field.stringValue = dict[key] as? String ?? ""
    }

    private func bindSecret(_ field: NSTextField, from dict: [String: Any], hasKey: String, placeholder: String) {
        field.stringValue = ""
        field.placeholderString = (dict[hasKey] as? Bool == true) ? "已配置，留空不修改" : placeholder
    }

    private func collectCredentials() -> [String: Any] {
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

    private func collectTestPayload() -> [String: Any] {
        var payload = collectCredentials()
        payload["hiddenProviders"] = Array(CloudProviderPreferences.hiddenProviders()).sorted()
        return payload
    }

    private func put(_ dict: inout [String: Any], _ key: String, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty { dict[key] = v }
    }

    private func clearSecrets() {
        [tencentSecretId, tencentSecretKey, qiniuKey, aliyunKey, baiduSecret, deeplKey, deepseekKey, openaiKey]
            .forEach { $0.stringValue = "" }
    }

    // MARK: - Actions

    @objc private func saveClicked() {
        let payload = collectCredentials()
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
        let keys = activeTestKeys()
        inFlightTests.formUnion(keys)
        keys.forEach { applyTestStatus(for: $0) }
        refreshSectionBadges()

        Task { @MainActor in
            defer {
                inFlightTests.subtract(keys)
                testAllButton.isEnabled = true
                refreshTestStatuses()
            }
            if let err = await ServerManager.shared.ensureRunning() {
                noteLabel.textColor = .systemRed
                noteLabel.stringValue = err
                keys.forEach { lastTestResults[$0] = (false, err) }
                return
            }
            let (msg, results) = await SettingsStore.shared.testAllCloud(collectTestPayload())
            noteLabel.textColor = .labelColor
            noteLabel.stringValue = msg
            results.forEach { storeTestResult(from: $0) }
        }
    }

    @objc private func testClicked(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count == 2, !inFlightTests.contains(key) else { return }

        inFlightTests.insert(key)
        sender.isEnabled = false
        applyTestStatus(for: key)
        if let cardId = CloudProviderRegistry.cardId(forTestKey: key) {
            updateSectionBadge(for: cardId)
        }

        Task { @MainActor in
            if let err = await ServerManager.shared.ensureRunning() {
                finishSingleTest(key: key, ok: false, message: err)
                noteLabel.textColor = .systemRed
                noteLabel.stringValue = err
                return
            }
            let (ok, msg) = await SettingsStore.shared.testCloud(
                layer: parts[0],
                providerId: parts[1],
                payload: collectTestPayload()
            )
            finishSingleTest(key: key, ok: ok, message: msg)
            if !ok {
                noteLabel.textColor = .systemRed
                noteLabel.stringValue = msg
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
