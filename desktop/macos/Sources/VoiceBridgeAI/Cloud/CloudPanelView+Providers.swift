import AppKit

extension CloudPanelView {
    func registerProviders() {
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

    func configureVerticalStack(_ stack: NSStackView, spacing: CGFloat = 12) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
    }

    func addProvider(id: String, title: String, guide: ProviderGuide?, rows: [NSStackView]) {
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

    func setupHiddenSection() {
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

    @objc func toggleHiddenSection() {
        CloudProviderPreferences.hiddenSectionExpanded.toggle()
        updateHiddenSectionChrome()
    }

    func updateHiddenSectionChrome() {
        let hidden = CloudProviderPreferences.hiddenProviders()
        hiddenSectionContainer.isHidden = hidden.isEmpty
        guard !hidden.isEmpty else { return }
        let expanded = CloudProviderPreferences.hiddenSectionExpanded
        hiddenSectionToggle.title = "\(expanded ? "▾" : "▸")  已隐藏的接口（\(hidden.count)）"
        hiddenStack.isHidden = !expanded
    }

    func relayoutProviderSections() {
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

    func clearStack(_ stack: NSStackView) {
        while let view = stack.arrangedSubviews.first {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func attachSection(_ id: String, to stack: NSStackView) {
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

    func providerHiddenChanged(id: String, hidden: Bool) {
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
}
