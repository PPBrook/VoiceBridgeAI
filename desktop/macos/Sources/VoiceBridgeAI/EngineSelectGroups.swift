import AppKit

/// 与 `static/js/engine-select.js` 对齐的分组下拉逻辑。
enum EngineSelectGroups {
    struct Group {
        let label: String
        let ids: [String]
    }

    static let partialGroups: [Group] = [
        Group(label: "机器翻译 MT · 推荐句中", ids: ["tmt", "baidu", "deepl", "google", "argos"]),
        Group(label: "LLM 快译", ids: ["qiniu", "aliyun", "deepseek", "openai"]),
    ]

    static let finalGroups: [Group] = [
        Group(label: "LLM 润色 · 推荐句末", ids: ["qiniu", "aliyun", "deepseek", "openai"]),
        Group(label: "机器翻译 MT", ids: ["tmt", "baidu", "deepl", "google", "argos"]),
        Group(label: "其它", ids: ["none"]),
    ]

    static func fillPopup(
        _ popup: NSPopUpButton,
        providers: [ProviderOption],
        groups: [Group],
        selected: String
    ) {
        let menu = NSMenu()
        let byId = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        var placed = Set<String>()

        for group in groups {
            let items = group.ids.compactMap { byId[$0] }
            if items.isEmpty { continue }
            if !menu.items.isEmpty {
                menu.addItem(.separator())
            }
            let header = NSMenuItem(title: group.label, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for provider in items {
                let item = NSMenuItem(title: provider.label, action: nil, keyEquivalent: "")
                item.representedObject = provider.id
                menu.addItem(item)
                placed.insert(provider.id)
            }
        }

        for provider in providers where !placed.contains(provider.id) {
            let item = NSMenuItem(title: provider.label, action: nil, keyEquivalent: "")
            item.representedObject = provider.id
            menu.addItem(item)
        }

        popup.menu = menu
        select(popup, providerId: selected, providers: providers)
    }

    static func fillFlatPopup(_ popup: NSPopUpButton, providers: [ProviderOption], selected: String) {
        let menu = NSMenu()
        for provider in providers {
            let item = NSMenuItem(title: provider.label, action: nil, keyEquivalent: "")
            item.representedObject = provider.id
            menu.addItem(item)
        }
        popup.menu = menu
        select(popup, providerId: selected, providers: providers)
    }

    static func selectedId(_ popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private static func select(_ popup: NSPopUpButton, providerId: String, providers: [ProviderOption]) {
        for item in popup.itemArray {
            if item.representedObject as? String == providerId {
                popup.select(item)
                return
            }
        }
        let fallback = providers.first?.id ?? providerId
        for item in popup.itemArray {
            if item.representedObject as? String == fallback {
                popup.select(item)
                return
            }
        }
    }
}
