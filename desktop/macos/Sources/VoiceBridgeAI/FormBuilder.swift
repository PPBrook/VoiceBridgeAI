import AppKit

@MainActor
enum FormBuilder {
    static func label(_ text: String, bold: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = bold ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 12)
        return field
    }

    static func field(placeholder: String = "", secure: Bool = false) -> NSTextField {
        let field = secure ? NSSecureTextField(string: "") : NSTextField(string: "")
        field.placeholderString = placeholder
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        return field
    }

    static func labeledRow(title: String, field: NSTextField) -> NSStackView {
        let titleLabel = label(title)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        let row = NSStackView(views: [titleLabel, field])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    static func sectionHeader(_ title: String) -> NSTextField {
        let h = label(title, bold: true)
        h.font = .boldSystemFont(ofSize: 14)
        return h
    }

    static func testRow(
        title: String,
        verified: Bool,
        action: Selector,
        target: AnyObject
    ) -> (row: NSStackView, status: NSTextField, button: NSButton) {
        let status = label(verified ? "已通过" : "—")
        status.textColor = verified ? .systemGreen : .secondaryLabelColor
        status.font = .systemFont(ofSize: 11)

        let button = NSButton(title: "测试 \(title)", target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small

        let row = NSStackView(views: [button, status])
        row.orientation = .horizontal
        row.spacing = 8
        return (row, status, button)
    }
}
