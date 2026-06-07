import Foundation

struct LocalModelDownloadJob {
    let id: String
    let modelId: String
    let whisperModel: String?
    let label: String?
    let status: String
    let progress: Double
    let message: String
    let error: String?

    static func from(_ dict: [String: Any]) -> LocalModelDownloadJob? {
        guard let id = dict["id"] as? String,
              let modelId = dict["modelId"] as? String,
              let status = dict["status"] as? String else { return nil }
        let progress: Double
        if let value = dict["progress"] as? Double {
            progress = value
        } else if let value = dict["progress"] as? NSNumber {
            progress = value.doubleValue
        } else {
            progress = 0
        }
        return LocalModelDownloadJob(
            id: id,
            modelId: modelId,
            whisperModel: dict["whisperModel"] as? String,
            label: dict["label"] as? String,
            status: status,
            progress: progress,
            message: dict["message"] as? String ?? "",
            error: dict["error"] as? String
        )
    }

    var displayMessage: String {
        if !message.isEmpty { return message }
        if let label, !label.isEmpty {
            let pct = Int(progress * 100)
            if status == "running", pct > 0, pct < 100 {
                return "\(label) · 正在下载 \(pct)%"
            }
            return label
        }
        return status == "done" ? "下载完成" : "正在下载…"
    }

    var isFinished: Bool { status == "done" || status == "error" }
}

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

    func startLocalModelDownload(id: String, whisperModel: String?) async throws -> LocalModelDownloadJob {
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
        guard let jobDict = json["job"] as? [String: Any],
              let job = LocalModelDownloadJob.from(jobDict) else {
            throw NSError(
                domain: "VoiceBridgeAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法创建下载任务"]
            )
        }
        return job
    }

    func pollLocalModelDownloadJob(id jobId: String) async throws -> LocalModelDownloadJob {
        let json = try await APIClient.getJSON(path: "api/models/local/download/\(jobId)")
        health.merge(json) { _, new in new }
        engine = EngineConfig.from(health: health)
        guard let jobDict = json["job"] as? [String: Any],
              let job = LocalModelDownloadJob.from(jobDict) else {
            throw NSError(
                domain: "VoiceBridgeAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: json["message"] as? String ?? "下载状态无效"]
            )
        }
        if job.status == "error" || json["ok"] as? Bool == false {
            throw NSError(
                domain: "VoiceBridgeAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: job.error ?? job.message]
            )
        }
        return job
    }

    func updateLocalModelsSettings(_ body: [String: Any]) async throws -> String {
        let json = try await APIClient.postJSON(path: "api/models/local/settings", body: body)
        health.merge(json) { _, new in new }
        engine = EngineConfig.from(health: health)
        if json["ok"] as? Bool == false {
            throw NSError(
                domain: "VoiceBridgeAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: json["message"] as? String ?? "保存失败"]
            )
        }
        return json["message"] as? String ?? "已保存"
    }

    func deleteLocalModel(id: String, whisperModel: String?) async throws -> String {
        var body: [String: Any] = ["id": id]
        if let whisperModel, !whisperModel.isEmpty {
            body["whisperModel"] = whisperModel
        }
        let json = try await APIClient.postJSON(path: "api/models/local/delete", body: body)
        health.merge(json) { _, new in new }
        engine = EngineConfig.from(health: health)
        if json["ok"] as? Bool == false {
            throw NSError(
                domain: "VoiceBridgeAI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: json["message"] as? String ?? "删除失败"]
            )
        }
        return json["message"] as? String ?? "已删除"
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
