import Foundation

@MainActor
final class ServerManager {
    static let shared = ServerManager()

    private var process: Process?
    private let session = URLSession(configuration: .ephemeral)

    private init() {}

    func ping() async -> Bool {
        let url = AppSettings.baseURL.appendingPathComponent("api/health")
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func ensureRunning() async -> String? {
        if await ping() { return nil }

        guard let root = RepoRoot.find() else {
            return "找不到仓库根目录（需含 run.sh）。可设置环境变量 VOICEBRIDGE_ROOT。"
        }

        let runSh = root.appendingPathComponent("run.sh")
        guard FileManager.default.isExecutableFile(atPath: runSh.path) else {
            return "找不到可执行的 run.sh：\(runSh.path)"
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [runSh.path]
        proc.currentDirectoryURL = root
        var env = ProcessInfo.processInfo.environment
        env["VOICEBRIDGE_PORT"] = String(AppSettings.port)
        proc.environment = env
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return "启动服务端失败：\(error.localizedDescription)"
        }
        process = proc

        for _ in 0..<120 {
            if await ping() { return nil }

            if let process, !process.isRunning {
                let exitCode = process.terminationStatus
                self.process = nil
                if await ping() { return nil }
                return startupFailureMessage(exitCode: exitCode)
            }

            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        return "服务端启动超时（Whisper 首次加载可能较慢，请稍后重试）"
    }

    private func startupFailureMessage(exitCode: Int32) -> String {
        let port = AppSettings.port
        if exitCode == 1 {
            return """
            服务端启动失败（退出码 1）。常见原因：
            · 端口 \(port) 已被占用 — 关闭其他 VoiceBridgeAI 实例或执行 kill $(lsof -t -iTCP:\(port))
            · 仓库根 run.sh 无法启动 — 请在终端手动运行 ./run.sh 查看错误
            """
        }
        return "服务端启动失败（退出码 \(exitCode)）。请在终端于仓库根目录运行 ./run.sh 查看详情。"
    }

    func stopIfOwned() {
        process?.terminate()
        process = nil
    }
}
