import Foundation

enum RepoRoot {
    /// 引擎仓库根目录：同时含 `run.sh` 与 `server/main.py`（排除 `desktop/macos/run.sh` 等子目录包装脚本）。
    static func find() -> URL? {
        if let env = ProcessInfo.processInfo.environment["VOICEBRIDGE_ROOT"] {
            let root = URL(fileURLWithPath: env)
            if isEngineRepoRoot(root) { return root }
        }

        if let marker = repoPathMarker(), isEngineRepoRoot(marker) {
            return marker
        }

        for start in searchStartDirectories() {
            if let root = walkUpForEngineRoot(from: start) {
                return root
            }
        }
        return nil
    }

    private static func isEngineRepoRoot(_ dir: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent("run.sh").path)
            && fm.fileExists(atPath: dir.appendingPathComponent("server/main.py").path)
    }

    private static func searchStartDirectories() -> [URL] {
        var starts: [URL] = []
        func add(_ url: URL) {
            if !starts.contains(url) { starts.append(url) }
        }
        add(URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent())
        add(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        return starts
    }

    private static func walkUpForEngineRoot(from start: URL) -> URL? {
        var dir = start
        for _ in 0..<10 {
            if isEngineRepoRoot(dir) { return dir }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    /// Written by `build-app.sh` beside the .app executable.
    private static func repoPathMarker() -> URL? {
        let exec = URL(fileURLWithPath: CommandLine.arguments[0])
        let marker = exec.deletingLastPathComponent().appendingPathComponent("voicebridge-repo-path")
        guard let text = try? String(contentsOf: marker, encoding: .utf8) else { return nil }
        let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
}

struct AppSettings {
    static let port = Int(ProcessInfo.processInfo.environment["VOICEBRIDGE_PORT"] ?? "8765") ?? 8765

    static var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    static var wsURL: URL {
        URL(string: "ws://127.0.0.1:\(port)/ws")!
    }
}
