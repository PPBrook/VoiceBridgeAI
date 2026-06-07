import AppKit

@MainActor
final class OverlayPanelController {
    private enum Style {
        static let cornerRadius: CGFloat = 16
        static let zhPrimary = NSColor(white: 0.98, alpha: 1)
        static let zhHistory = NSColor(white: 0.78, alpha: 0.55)
        static let enPrimary = NSColor(white: 0.82, alpha: 0.88)
        static let enHistory = NSColor(white: 0.68, alpha: 0.45)
        static let chrome = NSColor(white: 0.72, alpha: 0.75)
        static let chromeMuted = NSColor(white: 0.55, alpha: 0.6)
        static let tint = NSColor.black.withAlphaComponent(0.52)
        static let border = NSColor.white.withAlphaComponent(0.14)
    }

    private final class StopHandler: NSObject {
        var onStop: (() -> Void)?
        @objc func clicked() { onStop?() }
    }

    private final class OpacityHandler: NSObject {
        var onChange: ((CGFloat) -> Void)?
        @MainActor @objc func changed(_ sender: NSSlider) {
            onChange?(CGFloat(sender.floatValue))
        }
    }

    private final class ToggleHandler: NSObject {
        var onToggleEnglish: (() -> Void)?
        @MainActor @objc func toggleEnglish(_ sender: NSButton) {
            onToggleEnglish?()
        }
    }

    private let panel: NSPanel
    private let stopHandler = StopHandler()
    private let opacityHandler = OpacityHandler()
    private let toggleHandler = ToggleHandler()
    private let opacitySlider = NSSlider(value: 0.78, minValue: 0.15, maxValue: 1.0, target: nil, action: nil)
    private let enToggleButton = NSButton(title: "EN", target: nil, action: nil)
    private var showEnglish = OverlayPreferences.showEnglish
    private let historyZhLabel = NSTextField(wrappingLabelWithString: "")
    private let historyEnLabel = NSTextField(wrappingLabelWithString: "")
    private let zhLabel = NSTextField(wrappingLabelWithString: "等待字幕…")
    private let enLabel = NSTextField(wrappingLabelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let container = NSView()
    private let clipView = NSView()
    private let backgroundView = NSVisualEffectView()
    private let tintView = NSView()

    var onStop: (() -> Void)?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 188),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        container.wantsLayer = true
        container.layer?.cornerRadius = Style.cornerRadius
        container.layer?.masksToBounds = false
        container.layer?.borderWidth = 1
        container.layer?.borderColor = Style.border.cgColor
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.38
        container.layer?.shadowRadius = 28
        container.layer?.shadowOffset = CGSize(width: 0, height: 10)
        container.translatesAutoresizingMaskIntoConstraints = false

        clipView.wantsLayer = true
        clipView.layer?.cornerRadius = Style.cornerRadius
        clipView.layer?.masksToBounds = true
        clipView.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.material = .popover
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = Style.tint.cgColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        applyBackgroundOpacity(OverlayPreferences.backgroundOpacity)

        let titleLabel = captionLabel("VoiceBridgeAI", size: 10, weight: .semibold, color: Style.chromeMuted)

        opacitySlider.floatValue = Float(OverlayPreferences.backgroundOpacity)
        opacitySlider.controlSize = .mini
        opacitySlider.widthAnchor.constraint(equalToConstant: 68).isActive = true
        opacitySlider.target = opacityHandler
        opacitySlider.action = #selector(OpacityHandler.changed(_:))
        opacitySlider.toolTip = "背景不透明度"

        let opacityHint = captionLabel("背景", size: 9, weight: .medium, color: Style.chromeMuted)

        let opacityStack = NSStackView(views: [opacityHint, opacitySlider])
        opacityStack.orientation = .horizontal
        opacityStack.spacing = 5
        opacityStack.alignment = .centerY

        enToggleButton.bezelStyle = .recessed
        enToggleButton.setButtonType(.toggle)
        enToggleButton.font = .systemFont(ofSize: 10, weight: .bold)
        enToggleButton.target = toggleHandler
        enToggleButton.action = #selector(ToggleHandler.toggleEnglish(_:))
        enToggleButton.toolTip = "切换英文显示"
        enToggleButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        enToggleButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        syncEnglishToggleAppearance()

        styleSubtitleLabel(
            historyZhLabel,
            size: 14,
            weight: .medium,
            color: Style.zhHistory
        )
        styleSubtitleLabel(
            historyEnLabel,
            size: 11,
            weight: .regular,
            color: Style.enHistory
        )
        styleSubtitleLabel(
            zhLabel,
            size: 24,
            weight: .semibold,
            color: Style.zhPrimary,
            shadow: true
        )
        styleSubtitleLabel(
            enLabel,
            size: 13,
            weight: .regular,
            color: Style.enPrimary
        )
        styleSubtitleLabel(
            errorLabel,
            size: 12,
            weight: .medium,
            color: NSColor.systemRed.withAlphaComponent(0.95)
        )

        let stopButton = iconButton(
            symbol: "xmark.circle.fill",
            fallback: "×",
            tooltip: "停止字幕",
            size: 15
        )
        stopButton.target = stopHandler
        stopButton.action = #selector(StopHandler.clicked)

        let subtitleStack = NSStackView(views: [historyZhLabel, historyEnLabel, zhLabel, enLabel, errorLabel])
        subtitleStack.orientation = .vertical
        subtitleStack.spacing = 5
        subtitleStack.setCustomSpacing(2, after: historyZhLabel)
        subtitleStack.setCustomSpacing(8, after: historyEnLabel)
        subtitleStack.setCustomSpacing(4, after: zhLabel)
        subtitleStack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [titleLabel, opacityStack, enToggleButton, NSView(), stopButton])
        header.orientation = .horizontal
        header.spacing = 8
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(container)
        container.addSubview(clipView)
        clipView.addSubview(backgroundView)
        clipView.addSubview(tintView)
        clipView.addSubview(header)
        clipView.addSubview(divider)
        clipView.addSubview(subtitleStack)

        panel.contentView = root

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            container.topAnchor.constraint(equalTo: root.topAnchor),
            container.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            clipView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            clipView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            clipView.topAnchor.constraint(equalTo: container.topAnchor),
            clipView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            backgroundView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: clipView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),

            tintView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: clipView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: clipView.bottomAnchor),

            header.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: clipView.topAnchor, constant: 10),

            divider.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: -12),
            divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),

            subtitleStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: 22),
            subtitleStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: -22),
            subtitleStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            subtitleStack.bottomAnchor.constraint(equalTo: clipView.bottomAnchor, constant: -16),
        ])

        positionBottomCenter()
        stopHandler.onStop = { [weak self] in self?.onStop?() }
        opacityHandler.onChange = { [weak self] value in
            self?.applyBackgroundOpacity(value)
        }
        toggleHandler.onToggleEnglish = { [weak self] in
            self?.toggleEnglish()
        }
    }

    private func captionLabel(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    private func styleSubtitleLabel(
        _ label: NSTextField,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        shadow: Bool = false
    ) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 680
        if shadow {
            label.shadow = NSShadow()
            label.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.45)
            label.shadow?.shadowOffset = NSSize(width: 0, height: -1)
            label.shadow?.shadowBlurRadius = 4
        }
    }

    private func iconButton(symbol: String, fallback: String, tooltip: String, size: CGFloat) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.contentTintColor = Style.chrome
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
            button.image = image.withSymbolConfiguration(config)
        } else {
            button.title = fallback
            button.font = .systemFont(ofSize: size, weight: .bold)
        }
        return button
    }

    private func toggleEnglish() {
        showEnglish.toggle()
        OverlayPreferences.showEnglish = showEnglish
        syncEnglishToggleAppearance()
        if let store = AppDelegate.shared?.lastSubtitleStore {
            update(with: store)
        } else {
            enLabel.isHidden = !showEnglish
            historyEnLabel.isHidden = !showEnglish
        }
    }

    private func syncEnglishToggleAppearance() {
        enToggleButton.state = showEnglish ? .on : .off
        enToggleButton.alphaValue = showEnglish ? 1 : 0.5
        enToggleButton.contentTintColor = showEnglish ? Style.zhPrimary : Style.chromeMuted
    }

    private func applyBackgroundOpacity(_ value: CGFloat) {
        let clamped = min(1.0, max(0.15, value))
        OverlayPreferences.backgroundOpacity = clamped
        tintView.alphaValue = clamped
        backgroundView.alphaValue = min(1, clamped + 0.08)
        opacitySlider.floatValue = Float(clamped)
    }

    func positionBottomCenter() {
        let screen = activeScreen() ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.visibleFrame
        var rect = panel.frame
        rect.origin.x = frame.midX - rect.width / 2
        rect.origin.y = frame.minY + frame.height * 0.12
        panel.setFrame(rect, display: true)
    }

    private func activeScreen() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    func update(with store: SubtitleStore) {
        if store.isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
            return
        }

        if let err = store.errorMessage, !err.isEmpty {
            errorLabel.stringValue = err
            errorLabel.isHidden = false
            historyZhLabel.stringValue = ""
            historyEnLabel.stringValue = ""
            historyZhLabel.isHidden = true
            historyEnLabel.isHidden = true
            zhLabel.stringValue = ""
            enLabel.stringValue = ""
            return
        }
        errorLabel.isHidden = true

        guard !store.segments.isEmpty else {
            historyZhLabel.isHidden = true
            historyEnLabel.isHidden = true
            zhLabel.stringValue = store.statusMessage
            zhLabel.textColor = Style.chrome
            zhLabel.alphaValue = 0.9
            enLabel.stringValue = ""
            enLabel.isHidden = true
            return
        }

        let lines = store.segments
        if lines.count >= 2 {
            let prev = lines[lines.count - 2]
            let cur = lines[lines.count - 1]
            applyHistoryLine(prev)
            applyCurrentLine(cur, prev: prev)
        } else if let cur = lines.last {
            historyZhLabel.isHidden = true
            historyEnLabel.isHidden = true
            applyCurrentLine(cur, prev: nil)
        }
    }

    private func applyHistoryLine(_ seg: SubtitleSegment) {
        let zh = displayZH(seg, fallback: nil)
        let en = seg.text
        let hasZh = !zh.isEmpty
        let hasEn = showEnglish && !en.isEmpty
        historyZhLabel.stringValue = hasZh ? zh : ""
        historyEnLabel.stringValue = hasEn ? en : ""
        historyZhLabel.isHidden = !hasZh
        historyEnLabel.isHidden = !hasEn
    }

    private func applyCurrentLine(_ cur: SubtitleSegment, prev: SubtitleSegment?) {
        let en = cur.text
        let zh = displayZH(cur, fallback: prev)

        if zh.isEmpty && cur.partial {
            zhLabel.stringValue = "…"
            zhLabel.textColor = Style.chrome
        } else {
            zhLabel.stringValue = zh.isEmpty ? "…" : zh
            zhLabel.textColor = Style.zhPrimary
        }

        zhLabel.alphaValue = cur.partial ? 0.78 : 1

        if showEnglish, !en.isEmpty {
            enLabel.stringValue = en
            enLabel.isHidden = false
            enLabel.alphaValue = cur.partial ? 0.72 : 0.92
        } else {
            enLabel.stringValue = ""
            enLabel.isHidden = true
        }

        if cur.revised {
            flashRevise(lookback: cur.lookback)
        }
    }

    private func flashRevise(lookback: Bool) {
        let accent = lookback ? NSColor.systemOrange : NSColor.systemBlue
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            zhLabel.animator().textColor = accent
        } completionHandler: { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                self.zhLabel.animator().textColor = Style.zhPrimary
            }
        }
    }

    private func displayZH(_ cur: SubtitleSegment, fallback: SubtitleSegment?) -> String {
        if !cur.translation.isEmpty { return cur.translation }
        if let fallback, !fallback.translation.isEmpty { return fallback.translation }
        if cur.partial { return "" }
        return cur.text
    }
}
