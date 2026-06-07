import Foundation

/// 云端厂商卡片隐藏偏好，与服务器 `cloud-ui.json` 同步。
@MainActor
enum CloudProviderPreferences {
    private static let defaultsKey = "cloudHiddenProviders"
    private static let hiddenSectionExpandedKey = "cloudHiddenSectionExpanded"
    private static let prefsFileName = "cloud-ui.json"

    static var allProviderIds: [String] { CloudProviderRegistry.allIds }

    static var hiddenSectionExpanded: Bool {
        get {
            if UserDefaults.standard.object(forKey: hiddenSectionExpandedKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: hiddenSectionExpandedKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hiddenSectionExpandedKey) }
    }

    static func hiddenProviders() -> Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        return Set(stored.filter { allProviderIds.contains($0) })
    }

    static func isHidden(_ providerId: String) -> Bool {
        hiddenProviders().contains(providerId)
    }

    static func setHidden(_ providerId: String, hidden: Bool) {
        var ids = hiddenProviders()
        if hidden { ids.insert(providerId) } else { ids.remove(providerId) }
        persistLocally(ids)
        syncToDisk()
    }

    static func persistLocally(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: defaultsKey)
    }

    /// App 启动时：加载磁盘偏好在 sidecar 启动前写入 canonical 路径。
    static func bootstrap() {
        let canonical = canonicalPrefsURL()
        if FileManager.default.fileExists(atPath: canonical.path),
           let ids = readHidden(from: canonical) {
            persistLocally(ids)
            return
        }

        var merged = hiddenProviders()
        for url in legacyPrefsURLs() {
            guard let ids = readHidden(from: url) else { continue }
            merged.formUnion(ids)
        }
        persistLocally(merged)
        syncToDisk()
    }

    /// 合并 health.uiPrefs；服务端空列表不覆盖本地已有隐藏项。
    static func applyHealthPrefs(_ health: [String: Any]) {
        let local = hiddenProviders()
        if let uiPrefs = health["uiPrefs"] as? [String: Any],
           let list = uiPrefs["hiddenProviders"] as? [String] {
            let remote = Set(list.filter { allProviderIds.contains($0) })
            if !remote.isEmpty {
                persistLocally(remote)
                syncToDisk()
                return
            }
        }
        if !local.isEmpty {
            syncToDisk()
        } else {
            bootstrap()
        }
    }

    static func dataDirectory() -> URL {
        if let raw = ProcessInfo.processInfo.environment["VOICEBRIDGE_DATA_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            return URL(fileURLWithPath: raw)
        }
        if let root = RepoRoot.find() { return root }
        return AppSupport.dataDirectory
    }

    @discardableResult
    static func syncToDisk() -> Bool {
        do {
            try writePrefsFile(Array(hiddenProviders()).sorted())
            return true
        } catch {
            return false
        }
    }

    static func pushToServer() async {
        let sorted = Array(hiddenProviders()).sorted()
        do {
            _ = try await APIClient.postJSON(
                path: "api/cloud/ui-prefs",
                body: ["hiddenProviders": sorted]
            )
        } catch {
            // cloud-ui.json 已同步到磁盘
        }
    }

    // MARK: - Private

    private static func canonicalPrefsURL() -> URL {
        dataDirectory().appendingPathComponent(prefsFileName)
    }

    private static func legacyPrefsURLs() -> [URL] {
        var urls: [URL] = []
        func add(_ url: URL) {
            if !urls.contains(url) { urls.append(url) }
        }
        add(AppSupport.dataDirectory.appendingPathComponent(prefsFileName))
        if let root = ProcessInfo.processInfo.environment["VOICEBRIDGE_ROOT"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !root.isEmpty {
            add(URL(fileURLWithPath: root).appendingPathComponent(prefsFileName))
        }
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            add(dir.appendingPathComponent(prefsFileName))
            dir = dir.deletingLastPathComponent()
        }
        return urls.filter { $0 != canonicalPrefsURL() }
    }

    private static func readHidden(from url: URL) -> Set<String>? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["hiddenProviders"] as? [String] else { return nil }
        return Set(list.filter { allProviderIds.contains($0) })
    }

    private static func writePrefsFile(_ sorted: [String]) throws {
        let dir = dataDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload: [String: Any] = ["hiddenProviders": sorted]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        var text = String(data: data, encoding: .utf8) ?? "{}"
        if !text.hasSuffix("\n") { text += "\n" }
        try text.write(to: canonicalPrefsURL(), atomically: true, encoding: .utf8)
    }
}
