import Foundation

struct SidecarLaunch {
    struct Plan {
        let executable: URL
        let arguments: [String]
        let workingDirectory: URL
        let environment: [String: String]
        let modeLabel: String
    }

    static func plan() -> Plan? {
        if let bundled = bundledPlan() { return bundled }
        return devPlan()
    }

    private static func bundledPlan() -> Plan? {
        guard Bundle.main.bundlePath.hasSuffix(".app"),
              let resources = Bundle.main.resourceURL else { return nil }
        let script = resources.appendingPathComponent("run-server.sh")
        let venvPython = resources.appendingPathComponent("python-venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: script.path),
              FileManager.default.isExecutableFile(atPath: venvPython.path) else {
            return nil
        }
        do {
            try AppSupport.ensureLayout()
        } catch {
            return nil
        }
        var env = ProcessInfo.processInfo.environment
        env["VOICEBRIDGE_DATA_DIR"] = AppSupport.dataDirectory.path
        env["VOICEBRIDGE_PORT"] = String(AppSettings.port)
        env["VOICEBRIDGE_OPTIONAL_LOCAL_MODELS"] = "1"
        return Plan(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [script.path],
            workingDirectory: resources,
            environment: env,
            modeLabel: "bundled"
        )
    }

    private static func devPlan() -> Plan? {
        guard let root = RepoRoot.find() else { return nil }
        let runSh = root.appendingPathComponent("run.sh")
        guard FileManager.default.isExecutableFile(atPath: runSh.path) else { return nil }
        var env = ProcessInfo.processInfo.environment
        env["VOICEBRIDGE_PORT"] = String(AppSettings.port)
        env["VOICEBRIDGE_DATA_DIR"] = root.path
        env["VOICEBRIDGE_OPTIONAL_LOCAL_MODELS"] = "1"
        return Plan(
            executable: URL(fileURLWithPath: "/bin/bash"),
            arguments: [runSh.path],
            workingDirectory: root,
            environment: env,
            modeLabel: "dev"
        )
    }
}
