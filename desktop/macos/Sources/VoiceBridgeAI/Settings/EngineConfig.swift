import Foundation

enum APIClient {
    private static let session = URLSession.shared

    static func getJSON(path: String) async throws -> [String: Any] {
        let url = AppSettings.baseURL.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    static func postJSON(path: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: AppSettings.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if http.statusCode >= 400, json["ok"] as? Bool != true {
            if let errors = json["errors"] as? [String], !errors.isEmpty {
                throw NSError(domain: "VoiceBridgeAI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: errors.joined(separator: " · "),
                ])
            }
            throw NSError(domain: "VoiceBridgeAI", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: json["message"] as? String ?? "请求失败",
            ])
        }
        return json
    }
}

struct ProviderOption {
    let id: String
    let label: String

    static func list(from health: [String: Any], key: String) -> [ProviderOption] {
        guard let raw = health[key] as? [[String: Any]] else { return [] }
        return raw.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let label = item["label"] as? String ?? id
            return ProviderOption(id: id, label: label)
        }
    }
}

enum EnginePicker {
    static let llmProviders: Set<String> = ["qiniu", "aliyun", "deepseek", "openai"]
    static let repeatMT: Set<String> = ["argos"]

    static func allowsSameLayer(_ id: String) -> Bool {
        llmProviders.contains(id) || repeatMT.contains(id)
    }

    static func filterFinal(_ providers: [ProviderOption], partialId: String) -> [ProviderOption] {
        if partialId.isEmpty || allowsSameLayer(partialId) { return providers }
        let others = providers.filter { $0.id != partialId }
        return others.isEmpty ? providers : others
    }

    static func filterPartial(_ providers: [ProviderOption], finalId: String) -> [ProviderOption] {
        if finalId.isEmpty || finalId == "none" || allowsSameLayer(finalId) { return providers }
        let others = providers.filter { $0.id != finalId }
        return others.isEmpty ? providers : others
    }

    static func reconcile(
        asr: String,
        partial: String,
        final: String,
        health: [String: Any]
    ) -> (partial: String, final: String) {
        let partialList = filterPartial(ProviderOption.list(from: health, key: "partialProviders"), finalId: final)
        var partialId = partial
        if !partialList.contains(where: { $0.id == partialId }) {
            partialId = partialList.first?.id ?? partial
        }
        let finalList = filterFinal(ProviderOption.list(from: health, key: "finalProviders"), partialId: partialId)
        var finalId = final
        if !finalId.isEmpty, finalId == partialId, !allowsSameLayer(partialId) {
            finalId = finalList.first(where: { $0.id != partialId })?.id ?? finalId
        }
        if !finalList.contains(where: { $0.id == finalId }) {
            finalId = finalList.first?.id ?? finalId
        }
        return (partialId, finalId)
    }
}

struct EngineConfig {
    var inputMode: String = "audio"
    var asrProvider: String = "local"
    var partialProvider: String = "argos"
    var finalProvider: String = "argos"
    var reviseMode: String = "balanced"
    var sampleRate: Int = 48000

    static func from(health: [String: Any]) -> EngineConfig {
        var cfg = EngineConfig()
        if let v = health["asrProvider"] as? String ?? health["asrMode"] as? String {
            cfg.asrProvider = v
        }
        if let v = health["partialProvider"] as? String { cfg.partialProvider = v }
        if let v = health["finalProvider"] as? String { cfg.finalProvider = v }
        if let v = health["reviseMode"] as? String { cfg.reviseMode = v }
        let pair = EnginePicker.reconcile(
            asr: cfg.asrProvider,
            partial: cfg.partialProvider,
            final: cfg.finalProvider,
            health: health
        )
        cfg.partialProvider = pair.partial
        cfg.finalProvider = pair.final
        return cfg
    }

    func enginePayload() -> [String: Any] {
        [
            "asrMode": asrProvider,
            "asrProvider": asrProvider,
            "partialProvider": partialProvider,
            "finalProvider": finalProvider,
            "reviseMode": reviseMode,
        ]
    }

    func wsConfigPayload() -> [String: Any] {
        [
            "type": "config",
            "sampleRate": sampleRate,
            "inputMode": inputMode,
            "asrMode": asrProvider,
            "asrProvider": asrProvider,
            "partialProvider": partialProvider,
            "finalProvider": finalProvider,
            "reviseMode": reviseMode,
        ]
    }

    func summary(from health: [String: Any]) -> String {
        let asr = ProviderOption.list(from: health, key: "asrModes").first { $0.id == asrProvider }?.label ?? asrProvider
        let partial = ProviderOption.list(from: health, key: "partialProviders").first { $0.id == partialProvider }?.label ?? partialProvider
        let final = ProviderOption.list(from: health, key: "finalProviders").first { $0.id == finalProvider }?.label ?? finalProvider
        let revise = ProviderOption.list(from: health, key: "reviseModes").first { $0.id == reviseMode }?.label ?? reviseMode
        return "\(shortName(asr)) → \(shortName(partial)) → \(shortName(final)) · \(shortName(revise))"
    }

    private func shortName(_ label: String) -> String {
        label.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? label
    }
}
