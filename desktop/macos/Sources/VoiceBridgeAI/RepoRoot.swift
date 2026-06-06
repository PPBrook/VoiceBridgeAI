import Foundation

enum RepoRoot {
    static func find() -> URL? {
        if let env = ProcessInfo.processInfo.environment["VOICEBRIDGE_ROOT"] {
            let root = URL(fileURLWithPath: env)
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("run.sh").path) {
                return root
            }
        }

        if let marker = repoPathMarker() {
            return marker
        }

        var dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        for _ in 0..<8 {
            let runSh = dir.appendingPathComponent("run.sh")
            if FileManager.default.fileExists(atPath: runSh.path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }

        dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let runSh = dir.appendingPathComponent("run.sh")
            if FileManager.default.fileExists(atPath: runSh.path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
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
        let root = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("run.sh").path) else {
            return nil
        }
        return root
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
