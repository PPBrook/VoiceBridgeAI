import AppKit

/// 云端厂商配置卡片（始终展开；由 CloudPanelView 移入主列表或「已隐藏」区）。
@MainActor
final class ProviderSectionView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let hideButton = NSButton(title: "隐藏", target: nil, action: nil)
    private let headerStack = NSStackView()
    private let bodyStack = NSStackView()
    private let baseTitle: String
    private var inHiddenPanel = false

    var onHiddenChanged: ((Bool) -> Void)?

    init(title: String) {
        baseTitle = title
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        titleLabel.stringValue = baseTitle
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        badgeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.isHidden = true

        hideButton.bezelStyle = .accessoryBarAction
        hideButton.controlSize = .small
        hideButton.font = .systemFont(ofSize: 11)
        hideButton.target = self
        hideButton.action = #selector(toggleHidden)

        bodyStack.orientation = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = 8
        bodyStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(badgeLabel)
        headerStack.addArrangedSubview(NSView())
        headerStack.addArrangedSubview(hideButton)

        addSubview(headerStack)
        addSubview(bodyStack)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            bodyStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bodyStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bodyStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            bodyStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    func configurePanelMode(inHiddenPanel: Bool) {
        self.inHiddenPanel = inHiddenPanel
        hideButton.title = inHiddenPanel ? "显示" : "隐藏"
        layer?.backgroundColor = inHiddenPanel
            ? NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
            : NSColor.controlBackgroundColor.cgColor
    }

    func setBadge(_ text: String?, ok: Bool?) {
        guard let text, !text.isEmpty else {
            badgeLabel.isHidden = true
            return
        }
        badgeLabel.isHidden = false
        badgeLabel.stringValue = text
        if let ok {
            badgeLabel.textColor = ok ? .systemGreen : .secondaryLabelColor
        } else {
            badgeLabel.textColor = .secondaryLabelColor
        }
    }

    func addGuide(_ view: NSView) {
        bodyStack.addArrangedSubview(view)
    }

    func addRow(_ row: NSView) {
        bodyStack.addArrangedSubview(row)
    }

    func addTestsHeader() {
        bodyStack.addArrangedSubview(FormBuilder.divider())
        let label = FormBuilder.label("连接测试")
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        bodyStack.addArrangedSubview(label)
    }

    @objc private func toggleHidden() {
        onHiddenChanged?(inHiddenPanel ? false : true)
    }
}
