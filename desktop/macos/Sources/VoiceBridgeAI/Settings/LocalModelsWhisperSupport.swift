import AppKit

extension LocalModelsPanelView {
    func jsonBool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? Int { return n != 0 }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }

    func whisperSizeHint(for modelId: String, fallback: String) -> String {
        for item in whisperChoices() {
            if (item["id"] as? String) == modelId {
                return item["sizeHint"] as? String ?? fallback
            }
        }
        return fallback
    }

    func whisperStatusText(
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

    func updateWhisperRow(
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

    func whisperChoices() -> [[String: Any]] {
        SettingsStore.shared.health["whisperChoices"] as? [[String: Any]] ?? []
    }

    func whisperId(forMenuTitle title: String) -> String? {
        for item in whisperChoices() {
            if (item["label"] as? String) == title { return item["id"] as? String }
            if (item["id"] as? String) == title { return item["id"] as? String }
        }
        if title.contains("tiny.en") { return "tiny.en" }
        if title.contains("base.en") { return "base.en" }
        return nil
    }

    func fillWhisperPopup(from health: [String: Any]) {
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

    func selectedWhisperModel() -> String? {
        if let id = whisperModelPopup.selectedItem?.representedObject as? String, !id.isEmpty {
            return id
        }
        if let title = whisperModelPopup.titleOfSelectedItem, !title.isEmpty {
            return whisperId(forMenuTitle: title) ?? title
        }
        return nil
    }
}
