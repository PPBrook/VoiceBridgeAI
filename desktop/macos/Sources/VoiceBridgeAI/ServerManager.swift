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
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [runSh.path]
        proc.currentDirectoryURL = root
        var env = ProcessInfo.processInfo.environment
        env["VOICEBRIDGE_PORT"] = String(AppSettings.port)
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
        } catch {
            return "启动服务端失败：\(error.localizedDescription)"
        }
        process = proc

        for _ in 0..<120 {
            if await ping() { return nil }
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
        return "服务端启动超时（Whisper 首次加载可能较慢，请稍后重试）"
    }

    func stopIfOwned() {
        process?.terminate()
        process = nil
    }
}
