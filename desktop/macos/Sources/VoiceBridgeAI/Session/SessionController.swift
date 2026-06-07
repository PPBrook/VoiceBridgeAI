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

    private init() {
        store.onChange = { [weak self] in
            guard let self else { return }
            AppDelegate.shared?.lastSubtitleStore = self.store
            AppDelegate.shared?.overlay.update(with: self.store)
        }

        webSocket.onASR = { [weak self] payload in
            Task { @MainActor in
                self?.store.applyASR(payload)
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
        store.reset()
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
        store.hide()
        AppDelegate.shared?.overlay.update(with: store)
        AppDelegate.shared?.refreshControlUI()
    }

    func applyReviseMode(_ mode: String) async throws {
        SettingsStore.shared.engine.reviseMode = mode
        _ = try await SettingsStore.shared.saveEngine()
        try await reconfigureEngine()
    }

    func reconfigureEngine() async throws {
        try await SettingsStore.shared.refresh()
        engineConfig = SettingsStore.shared.engine
        if isRunning {
            try await webSocket.reconfigure(config: engineConfig)
        }
    }
}
