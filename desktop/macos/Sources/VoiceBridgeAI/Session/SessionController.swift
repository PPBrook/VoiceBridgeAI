import AppKit

@MainActor
final class SessionController {
    static let shared = SessionController()

    let store = SubtitleStore()
    private(set) var isRunning = false
    private(set) var isStarting = false

    private let webSocket = WebSocketSession()
    private var capture: SystemAudioCapture?
    private var engineConfig = EngineConfig()
    private var silenceMonitor = PcmSilenceMonitor()

    private init() {
        store.onChange = { [weak self] in
            guard let self else { return }
            AppDelegate.shared?.lastSubtitleStore = self.store
            AppDelegate.shared?.overlay.update(with: self.store)
        }

        webSocket.onASR = { [weak self] payload in
            Task { @MainActor in
                self?.silenceMonitor.reset()
                self?.store.applyASR(payload)
                self?.recordTranslationIfNeeded(payload)
            }
        }
        webSocket.onError = { [weak self] message in
            Task { @MainActor in
                self?.store.showError(message)
                self?.stop()
            }
        }
    }

    func start() async -> String? {
        if isRunning || isStarting { return nil }

        isStarting = true
        AppDelegate.shared?.refreshControlUI()
        defer {
            isStarting = false
            AppDelegate.shared?.refreshControlUI()
        }

        let serverErr = await ServerManager.shared.ensureRunning()
        if let serverErr {
            return serverErr
        }

        do {
            try await SettingsStore.shared.refresh()
            engineConfig = SettingsStore.shared.engine
        } catch {
            return "无法读取引擎配置"
        }

        do {
            try await webSocket.connect(config: engineConfig)
        } catch {
            return error.localizedDescription
        }

        if #available(macOS 13.0, *) {
            if !ScreenCaptureAccess.ensureAccess() {
                webSocket.disconnect()
                ScreenCaptureAccess.openSystemSettings()
                return "需要屏幕录制权限才能采集系统音频。已尝试打开系统设置，请允许 VoiceBridgeAI 后重试。"
            }

            let cap = SystemAudioCapture()
            cap.onPCM = { [weak self] data in
                Task { @MainActor in
                    guard let self, self.isRunning else { return }
                    if self.silenceMonitor.feed(pcm: data), !self.store.segments.isEmpty {
                        self.store.clearDisplay()
                        self.silenceMonitor.reset()
                    }
                    do {
                        try await self.webSocket.send(pcm: data)
                    } catch {
                        self.store.showError("音频发送失败：\(error.localizedDescription)")
                        self.stop()
                    }
                }
            }
            cap.onFailure = { [weak self] message in
                Task { @MainActor in
                    self?.store.showError(message)
                    self?.stop()
                }
            }
            do {
                try await cap.start()
                capture = cap
            } catch {
                webSocket.disconnect()
                return "音频采集失败：\(error.localizedDescription)。请在 系统设置 → 隐私 → 屏幕录制 中允许本应用。"
            }
        } else {
            webSocket.disconnect()
            return "需要 macOS 13 或更高版本"
        }

        isRunning = true
        silenceMonitor.reset()
        store.reset()
        beginTranslationRecordingIfNeeded()
        AppDelegate.shared?.overlay.update(with: store)
        return nil
    }

    func stop() {
        if #available(macOS 13.0, *) {
            capture?.stop()
        }
        capture = nil
        webSocket.disconnect()
        isRunning = false
        isStarting = false
        TranslationRecorder.shared.endSession()
        store.hide()
        AppDelegate.shared?.overlay.update(with: store)
        AppDelegate.shared?.refreshControlUI()
    }

    func applyReviseMode(_ mode: String) async throws {
        SettingsStore.shared.engine.reviseMode = mode
        _ = try await SettingsStore.shared.saveEngine()
        try await reconfigureEngine()
        AppDelegate.shared?.overlay.update(with: store)
    }

    func reconfigureEngine() async throws {
        try await SettingsStore.shared.refresh()
        engineConfig = SettingsStore.shared.engine
        if isRunning {
            try await webSocket.reconfigure(config: engineConfig)
            AppDelegate.shared?.overlay.update(with: store)
        }
    }

    private func beginTranslationRecordingIfNeeded() {
        guard TranscriptPreferences.recordEnabled else { return }
        let health = SettingsStore.shared.health
        let modeId = engineConfig.reviseMode
        let label = ReviseModeGuides.info(for: modeId, health: health)?.label ?? modeId
        TranslationRecorder.shared.beginSession(reviseModeId: modeId, reviseModeLabel: label)
    }

    private func recordTranslationIfNeeded(_ payload: [String: Any]) {
        guard TranscriptPreferences.recordEnabled else { return }
        guard payload["final"] as? Bool == true else { return }
        let english = (payload["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !english.isEmpty else { return }
        let segmentId = String(describing: payload["segmentId"] ?? "")
        let chinese = (payload["translation"] as? String) ?? ""
        let revised = (payload["revise"] as? Bool ?? false) || (payload["lookback"] as? Bool ?? false)
        TranslationRecorder.shared.record(
            segmentId: segmentId,
            english: english,
            chinese: chinese,
            revised: revised
        )
    }
}
