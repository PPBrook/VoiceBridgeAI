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

        guard let plan = SidecarLaunch.plan() else {
            return """
            无法启动引擎侧车。
            · 若使用 .app：请重新运行 build-app.sh 完整打包（含 Python 环境）
            · 若开发模式：设置 VOICEBRIDGE_ROOT 指向含 run.sh 的仓库根
            """
        }

        let proc = Process()
        proc.executableURL = plan.executable
        proc.arguments = plan.arguments
        proc.currentDirectoryURL = plan.workingDirectory
        proc.environment = plan.environment
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return "启动引擎侧车失败：\(error.localizedDescription)"
        }
        process = proc

        for _ in 0..<120 {
            if await ping() { return nil }

            if let process, !process.isRunning {
                let exitCode = process.terminationStatus
                self.process = nil
                if await ping() { return nil }
                return startupFailureMessage(exitCode: exitCode, plan: plan)
            }

            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        return startupFailureMessage(exitCode: nil, plan: plan, timedOut: true)
    }

    private func startupFailureMessage(
        exitCode: Int32?,
        plan: SidecarLaunch.Plan,
        timedOut: Bool = false
    ) -> String {
        let port = AppSettings.port
        var lines: [String] = []
        if timedOut {
            lines.append("引擎侧车启动超时（端口 \(port)）。")
        } else if let exitCode {
            lines.append("引擎侧车启动失败（退出码 \(exitCode)）。")
        }
        if exitCode == 1 {
            lines.append("· 端口 \(port) 可能被占用")
        }
        if plan.modeLabel == "bundled" {
            lines.append("· 查看日志：\(AppSupport.serverLogURL.path)")
            lines.append("· 可尝试删除后重启 App，或重新 build-app.sh 打包")
        } else {
            lines.append("· 在仓库根目录手动 ./run.sh 查看错误")
        }
        return lines.joined(separator: "\n")
    }

    func stopIfOwned() {
        process?.terminate()
        process = nil
    }
}
