import Foundation

enum RepoRoot {
    static func find() -> URL? {
        if let env = ProcessInfo.processInfo.environment["VOICEBRIDGE_ROOT"],
           FileManager.default.fileExists(atPath: URL(fileURLWithPath: env).appendingPathComponent("run.sh").path) {
            return URL(fileURLWithPath: env)
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

        // desktop/macos/.build/debug/VoiceBridgeAI → repo root
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
