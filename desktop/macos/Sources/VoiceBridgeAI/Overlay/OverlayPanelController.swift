import AppKit

@MainActor
final class OverlayPanelController {
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
    private let backgroundView = NSVisualEffectView()

    var onStop: (() -> Void)?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 168),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.material = .hudWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        applyBackgroundOpacity(OverlayPreferences.backgroundOpacity)

        let titleLabel = NSTextField(labelWithString: "VoiceBridgeAI")
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = NSColor(white: 0.7, alpha: 1)

        opacitySlider.floatValue = Float(OverlayPreferences.backgroundOpacity)
        opacitySlider.controlSize = .mini
        opacitySlider.widthAnchor.constraint(equalToConstant: 72).isActive = true
        opacitySlider.target = opacityHandler
        opacitySlider.action = #selector(OpacityHandler.changed(_:))
        opacitySlider.toolTip = "背景不透明度"

        let opacityHint = NSTextField(labelWithString: "背景")
        opacityHint.font = .systemFont(ofSize: 9)
        opacityHint.textColor = NSColor(white: 0.55, alpha: 1)

        let opacityStack = NSStackView(views: [opacityHint, opacitySlider])
        opacityStack.orientation = .horizontal
        opacityStack.spacing = 4
        opacityStack.alignment = .centerY

        enToggleButton.bezelStyle = .inline
        enToggleButton.setButtonType(.toggle)
        enToggleButton.font = .systemFont(ofSize: 11, weight: .semibold)
        enToggleButton.target = toggleHandler
        enToggleButton.action = #selector(ToggleHandler.toggleEnglish(_:))
        enToggleButton.toolTip = "切换英文显示"
        syncEnglishToggleAppearance()

        historyZhLabel.font = .systemFont(ofSize: 15, weight: .medium)
        historyZhLabel.textColor = NSColor(white: 0.72, alpha: 1)
        historyZhLabel.alignment = .center
        historyEnLabel.font = .systemFont(ofSize: 11)
        historyEnLabel.textColor = NSColor(white: 0.55, alpha: 1)
        historyEnLabel.alignment = .center

        zhLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        zhLabel.textColor = NSColor(white: 0.95, alpha: 1)
        zhLabel.alignment = .center

        enLabel.font = .systemFont(ofSize: 13)
        enLabel.textColor = NSColor(white: 0.68, alpha: 1)
        enLabel.alignment = .center

        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center

        let stopButton = NSButton(title: "×", target: nil, action: nil)
        stopButton.bezelStyle = .inline
        stopButton.font = .systemFont(ofSize: 14, weight: .bold)
        stopButton.target = stopHandler
        stopButton.action = #selector(StopHandler.clicked)

        let stack = NSStackView(views: [historyZhLabel, historyEnLabel, zhLabel, enLabel, errorLabel])
        stack.orientation = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [titleLabel, opacityStack, enToggleButton, NSView(), stopButton])
        header.orientation = .horizontal
        header.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(container)
        container.addSubview(backgroundView)
        container.addSubview(header)
        container.addSubview(stack)

        panel.contentView = root

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            container.topAnchor.constraint(equalTo: root.topAnchor),
            container.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            backgroundView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: container.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
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
        enToggleButton.alphaValue = showEnglish ? 1 : 0.45
    }

    private func applyBackgroundOpacity(_ value: CGFloat) {
        let clamped = min(1.0, max(0.15, value))
        OverlayPreferences.backgroundOpacity = clamped
        backgroundView.alphaValue = clamped
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
            zhLabel.alphaValue = 0.85
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
        historyZhLabel.alphaValue = 0.5
        historyEnLabel.alphaValue = 0.5
    }

    private func applyCurrentLine(_ cur: SubtitleSegment, prev: SubtitleSegment?) {
        let en = cur.text
        let zh = displayZH(cur, fallback: prev)

        if zh.isEmpty && cur.partial {
            zhLabel.stringValue = "…"
            zhLabel.textColor = NSColor(white: 0.75, alpha: 1)
        } else {
            zhLabel.stringValue = zh.isEmpty ? "…" : zh
            zhLabel.textColor = NSColor(white: 0.95, alpha: 1)
        }

        zhLabel.alphaValue = cur.partial ? 0.82 : 1

        if showEnglish, !en.isEmpty {
            enLabel.stringValue = en
            enLabel.isHidden = false
            enLabel.alphaValue = cur.partial ? 0.75 : 1
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
                self.zhLabel.animator().textColor = NSColor(white: 0.95, alpha: 1)
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
