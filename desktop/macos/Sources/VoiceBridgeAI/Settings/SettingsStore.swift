import Foundation

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private(set) var health: [String: Any] = [:]
    var engine = EngineConfig()

    private init() {}

    func refresh() async throws {
        _ = await ServerManager.shared.ensureRunning()
        health = try await APIClient.getJSON(path: "api/health")
        engine = EngineConfig.from(health: health)
    }

    func saveEngine() async throws -> String {
        let json = try await APIClient.postJSON(path: "api/engine/settings", body: engine.enginePayload())
        health.merge(json) { _, new in new }
        engine = EngineConfig.from(health: health)
        return "引擎已保存"
    }

    func saveCloud(_ payload: [String: Any]) async throws -> String {
        let json = try await APIClient.postJSON(path: "api/cloud/settings", body: payload)
        health.merge(json) { _, new in new }
        engine = EngineConfig.from(health: health)
        return "密钥已保存到 .env"
    }

    func downloadLocalModel(id: String, whisperModel: String?) async throws -> String {
        var body: [String: Any] = ["id": id]
        if let whisperModel, !whisperModel.isEmpty {
            body["whisperModel"] = whisperModel
        }
        let json = try await APIClient.postJSON(path: "api/models/local/download", body: body)
        health.merge(json) { _, new in new }
        engine = EngineConfig.from(health: health)
        if json["ok"] as? Bool == false {
            throw NSError(
                domain: "VoiceBridgeAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: json["message"] as? String ?? "下载失败"]
            )
        }
        return json["message"] as? String ?? "下载完成"
    }

    func testCloud(layer: String, providerId: String, payload: [String: Any]) async -> (Bool, String) {
        var body = payload
        body["layer"] = layer
        body["providerId"] = providerId
        do {
            let json = try await APIClient.postJSON(path: "api/cloud/test", body: body)
            health.merge(json) { _, new in new }
            let ok = json["ok"] as? Bool ?? false
            let msg = json["message"] as? String ?? (ok ? "已通过" : "失败")
            return (ok, msg)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    func testAllCloud(_ payload: [String: Any]) async -> (String, [[String: Any]]) {
        do {
            let json = try await APIClient.postJSON(path: "api/cloud/test-all", body: payload)
            health.merge(json) { _, new in new }
            let msg = json["message"] as? String ?? "测试完成"
            let results = json["results"] as? [[String: Any]] ?? []
            return (msg, results)
        } catch {
            return (error.localizedDescription, [])
        }
    }

    func isVerified(layer: String, providerId: String) -> Bool {
        guard let verified = health["verified"] as? [String: Any],
              let list = verified[layer] as? [String] else { return false }
        return list.contains(providerId)
    }
}
