import AppKit

extension CloudPanelView {
    func isStartupTestRunning() -> Bool {
        (SettingsStore.shared.health["startupTest"] as? [String: Any])?["running"] as? Bool == true
    }

    func activeTestKeys() -> [String] {
        CloudProviderRegistry.activeTestKeys(hidden: CloudProviderPreferences.hiddenProviders())
    }

    func updateSectionBadge(for id: String) {
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

    func refreshSectionBadges() {
        CloudProviderRegistry.allIds.forEach { updateSectionBadge(for: $0) }
    }

    func applyTestStatus(for key: String) {
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

    func finishSingleTest(key: String, ok: Bool, message: String) {
        inFlightTests.remove(key)
        lastTestResults[key] = (ok, message)
        applyTestStatus(for: key)
        testButtons[key]?.isEnabled = !isStartupTestRunning()
        if let cardId = CloudProviderRegistry.cardId(forTestKey: key) {
            updateSectionBadge(for: cardId)
        }
    }

    func refreshTestStatuses() {
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

    func setIndividualTestButtonsEnabled(_ enabled: Bool) {
        for (key, button) in testButtons {
            button.isEnabled = enabled && !inFlightTests.contains(key)
        }
    }

    func storeTestResult(from item: [String: Any]) {
        let layer = item["layer"] as? String ?? ""
        let providerId = item["providerId"] as? String ?? ""
        guard !layer.isEmpty, !providerId.isEmpty else { return }
        let ok = item["ok"] as? Bool ?? false
        let message = item["message"] as? String ?? (ok ? "已通过" : "失败")
        lastTestResults["\(layer):\(providerId)"] = (ok, message)
    }

    func applyStartupTest(_ health: [String: Any]) {
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

    func applyStartupTestResults(_ health: [String: Any]) {
        guard let st = health["startupTest"] as? [String: Any],
              let results = st["results"] as? [[String: Any]] else { return }
        results.forEach { storeTestResult(from: $0) }
    }

    func notifyEnginePanelOfHealthChange() {
        SettingsWindowController.shared?.reloadEnginePanel()
        AppDelegate.shared?.control?.refreshEngineSummary()
    }

    @objc func saveClicked() {
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
                notifyEnginePanelOfHealthChange()
            } catch {
                noteLabel.textColor = .systemRed
                noteLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc func testAllClicked() {
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
            notifyEnginePanelOfHealthChange()
        }
    }

    @objc func testClicked(_ sender: NSButton) {
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
            if ok {
                notifyEnginePanelOfHealthChange()
            } else {
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
