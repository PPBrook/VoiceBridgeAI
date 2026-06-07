import AppKit

/// 引擎下拉：拦截对分组标题等非选项的选中与 action。
@MainActor
final class EnginePopUpButton: NSPopUpButton {
    private var lastSelectableItem: NSMenuItem?
    private let menuHandler = MenuHandler()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect, pullsDown: false)
        menuHandler.popup = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        menuHandler.popup = self
    }

    override var menu: NSMenu? {
        didSet {
            menu?.delegate = menuHandler
            lastSelectableItem = itemArray.first(where: EngineSelectGroups.isSelectableMenuItem)
        }
    }

    override func select(_ item: NSMenuItem?) {
        if let item, !EngineSelectGroups.isSelectableMenuItem(item) {
            if let last = lastSelectableItem { super.select(last) }
            return
        }
        super.select(item)
        if let item, EngineSelectGroups.isSelectableMenuItem(item) {
            lastSelectableItem = item
        }
    }

    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard let item = selectedItem, EngineSelectGroups.isSelectableMenuItem(item) else {
            if let last = lastSelectableItem { select(last) }
            return false
        }
        return super.sendAction(action, to: target)
    }

    private final class MenuHandler: NSObject, NSMenuDelegate {
        weak var popup: EnginePopUpButton?

        func menuWillOpen(_ menu: NSMenu) {
            if let item = popup?.selectedItem, EngineSelectGroups.isSelectableMenuItem(item) {
                popup?.lastSelectableItem = item
            }
        }

        func menu(_ menu: NSMenu, willSendAction action: Selector?, to target: Any?, from item: NSMenuItem?) -> Bool {
            guard let item else { return true }
            return EngineSelectGroups.isSelectableMenuItem(item)
        }
    }
}
