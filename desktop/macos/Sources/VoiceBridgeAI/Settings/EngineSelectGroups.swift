import AppKit

/// 引擎下拉分组逻辑（原 Web engine-select.js 对齐）
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
            menu.addItem(sectionHeaderItem(title: group.label))
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
        guard let item = popup.selectedItem, isSelectableItem(item) else { return nil }
        return item.representedObject as? String
    }

    /// 分组标题等非选项被点后，恢复到 fallbackId 或第一个可选项。
    static func ensureValidSelection(_ popup: NSPopUpButton, fallbackId: String) {
        if selectedId(popup) != nil { return }
        reselect(popup, providerId: fallbackId)
    }

    private static let nonSelectableTag = -1

    static func isSelectableMenuItem(_ item: NSMenuItem) -> Bool {
        item.tag != nonSelectableTag && !item.isSeparatorItem && item.representedObject is String
    }

    private static func sectionHeaderItem(title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.tag = nonSelectableTag
        item.isEnabled = false

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail

        let width: CGFloat = 320
        let height: CGFloat = 22
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        label.frame = NSRect(x: 16, y: 3, width: width - 24, height: height - 6)
        label.autoresizingMask = [.width, .minYMargin]
        container.addSubview(label)
        item.view = container
        return item
    }

    private static func isSelectableItem(_ item: NSMenuItem) -> Bool {
        isSelectableMenuItem(item)
    }

    private static func select(_ popup: NSPopUpButton, providerId: String, providers: [ProviderOption]) {
        reselect(popup, providerId: providerId)
        if selectedId(popup) != nil { return }
        if let fallback = providers.first?.id {
            reselect(popup, providerId: fallback)
        }
    }

    private static func reselect(_ popup: NSPopUpButton, providerId: String) {
        for item in popup.itemArray where isSelectableItem(item) {
            if item.representedObject as? String == providerId {
                popup.select(item)
                return
            }
        }
        if let first = popup.itemArray.first(where: isSelectableItem) {
            popup.select(first)
        }
    }
}
