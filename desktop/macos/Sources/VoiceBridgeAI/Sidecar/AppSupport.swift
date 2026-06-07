import Foundation

enum AppSupport {
    static var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(BundleVariant.appSupportFolderName, isDirectory: true)
    }

    static func ensureLayout() throws {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let env = dataDirectory.appendingPathComponent(".env")
        guard !FileManager.default.fileExists(atPath: env.path) else { return }
        if let bundled = bundledSeedText() {
            try bundled.write(to: env, atomically: true, encoding: .utf8)
            return
        }
        let seed = """
        # VoiceBridgeAI — 由 App 自动创建
        AUTO_TEST_ON_START=0
        VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=1
        """
        try seed.write(to: env, atomically: true, encoding: .utf8)
    }

    private static func bundledSeedText() -> String? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("bundle-seed.env"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static var serverLogURL: URL {
        dataDirectory.appendingPathComponent("server.log")
    }
}
