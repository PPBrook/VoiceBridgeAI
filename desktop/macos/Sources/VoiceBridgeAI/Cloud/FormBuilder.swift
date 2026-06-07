import AppKit

@MainActor
enum FormBuilder {
    static let labelColumnWidth: CGFloat = 92
    static let fieldWidth: CGFloat = 300

    static func label(_ text: String, bold: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = bold ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 12)
        return field
    }

    static func field(placeholder: String = "", secure: Bool = false) -> NSTextField {
        let field = secure ? NSSecureTextField(string: "") : NSTextField(string: "")
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13)
        field.controlSize = .regular
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: fieldWidth).isActive = true
        return field
    }

    static func labeledRow(title: String, field: NSTextField) -> NSStackView {
        formRow(title: title, trailing: field)
    }

    static func formRow(title: String, trailing: NSView) -> NSStackView {
        let titleLabel = label(title)
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.widthAnchor.constraint(equalToConstant: labelColumnWidth).isActive = true

        let row = NSStackView(views: [titleLabel, trailing])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        return row
    }

    static func sectionHeader(_ title: String) -> NSTextField {
        let h = label(title, bold: true)
        h.font = .systemFont(ofSize: 15, weight: .semibold)
        return h
    }

    static func regionHeader(_ title: String) -> NSTextField {
        let h = label(title)
        h.font = .systemFont(ofSize: 12, weight: .semibold)
        h.textColor = .tertiaryLabelColor
        return h
    }

    static func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        box.widthAnchor.constraint(greaterThanOrEqualToConstant: fieldWidth + labelColumnWidth).isActive = true
        return box
    }

    static func banner(text: String) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 8
        box.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
        box.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.25)
        box.borderWidth = 1

        let label = label(text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false

        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
        ])
        return box
    }

    static func testRow(
        title: String,
        verified: Bool,
        action: Selector,
        target: AnyObject
    ) -> (row: NSStackView, status: NSTextField, button: NSButton) {
        let status = copyableTestStatus(
            verified: verified ? true : nil,
            text: verified ? "已通过" : "未测试"
        )

        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

        let row = NSStackView(views: [button, status])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .firstBaseline
        row.translatesAutoresizingMaskIntoConstraints = false
        status.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        return (row, status, button)
    }

    /// 可选中、⌘C 复制的测试结果（只读，自动换行）。
    static func copyableTestStatus(verified: Bool?, text: String) -> NSTextField {
        let field = NSTextField(string: text)
        field.font = .systemFont(ofSize: 10)
        field.isEditable = false
        field.isSelectable = true
        field.isBezeled = false
        field.drawsBackground = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        if let cell = field.cell as? NSTextFieldCell {
            cell.wraps = true
            cell.isScrollable = false
        }
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyTestStatusColor(field, verified: verified)
        return field
    }

    static func applyTestStatusColor(_ field: NSTextField, verified: Bool?) {
        if let verified {
            field.textColor = verified ? .systemGreen : .systemRed
        } else {
            field.textColor = .secondaryLabelColor
        }
    }

    static func primaryButton(_ title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.keyEquivalent = ""
        button.controlSize = .large
        return button
    }
}
