import AppKit

extension CloudPanelView {
    func bindCredentials(from health: [String: Any]) {
        let t = health["tencent"] as? [String: Any] ?? [:]
        bindText(tencentAppId, from: t, key: "appId")
        bindText(tencentEngine, from: t, key: "engine")
        bindText(tencentRegion, from: t, key: "tmtRegion")
        bindText(tencentProject, from: t, key: "tmtProjectId")
        bindSecret(tencentSecretId, from: t, hasKey: "hasSecretId", placeholder: "SecretId")
        bindSecret(tencentSecretKey, from: t, hasKey: "hasSecretKey", placeholder: "SecretKey")

        let q = health["qiniu"] as? [String: Any] ?? [:]
        bindText(qiniuBase, from: q, key: "baseUrl")
        bindText(qiniuModel, from: q, key: "model")
        bindSecret(qiniuKey, from: q, hasKey: "hasApiKey", placeholder: "API Key")

        let a = health["aliyun"] as? [String: Any] ?? [:]
        bindText(aliyunBase, from: a, key: "baseUrl")
        bindText(aliyunModel, from: a, key: "model")
        bindSecret(aliyunKey, from: a, hasKey: "hasApiKey", placeholder: "API Key")

        let b = health["baidu"] as? [String: Any] ?? [:]
        bindText(baiduAppId, from: b, key: "appId")
        bindSecret(baiduSecret, from: b, hasKey: "hasSecretKey", placeholder: "Secret Key")

        let d = health["deepl"] as? [String: Any] ?? [:]
        bindSecret(deeplKey, from: d, hasKey: "hasApiKey", placeholder: "API Key")

        let ds = health["deepseek"] as? [String: Any] ?? [:]
        bindText(deepseekBase, from: ds, key: "baseUrl")
        bindText(deepseekModel, from: ds, key: "model")
        bindSecret(deepseekKey, from: ds, hasKey: "hasApiKey", placeholder: "API Key")

        let o = health["openai"] as? [String: Any] ?? [:]
        bindText(openaiBase, from: o, key: "baseUrl")
        bindText(openaiModel, from: o, key: "model")
        bindText(openaiAsrModel, from: o, key: "asrModel")
        bindSecret(openaiKey, from: o, hasKey: "hasApiKey", placeholder: "API Key")
    }

    func bindText(_ field: NSTextField, from dict: [String: Any], key: String) {
        field.stringValue = dict[key] as? String ?? ""
    }

    func bindSecret(_ field: NSTextField, from dict: [String: Any], hasKey: String, placeholder: String) {
        field.stringValue = ""
        field.placeholderString = (dict[hasKey] as? Bool == true) ? "已配置，留空不修改" : placeholder
    }

    func collectCredentials() -> [String: Any] {
        var payload: [String: Any] = [:]

        var tencent: [String: Any] = [:]
        put(&tencent, "appId", tencentAppId.stringValue)
        put(&tencent, "engine", tencentEngine.stringValue)
        put(&tencent, "tmtRegion", tencentRegion.stringValue)
        put(&tencent, "tmtProjectId", tencentProject.stringValue)
        put(&tencent, "secretId", tencentSecretId.stringValue)
        put(&tencent, "secretKey", tencentSecretKey.stringValue)
        if !tencent.isEmpty { payload["tencent"] = tencent }

        var qiniu: [String: Any] = [:]
        put(&qiniu, "apiKey", qiniuKey.stringValue)
        put(&qiniu, "baseUrl", qiniuBase.stringValue)
        put(&qiniu, "model", qiniuModel.stringValue)
        if !qiniu.isEmpty { payload["qiniu"] = qiniu }

        var aliyun: [String: Any] = [:]
        put(&aliyun, "apiKey", aliyunKey.stringValue)
        put(&aliyun, "baseUrl", aliyunBase.stringValue)
        put(&aliyun, "model", aliyunModel.stringValue)
        if !aliyun.isEmpty { payload["aliyun"] = aliyun }

        var baidu: [String: Any] = [:]
        put(&baidu, "appId", baiduAppId.stringValue)
        put(&baidu, "secretKey", baiduSecret.stringValue)
        if !baidu.isEmpty { payload["baidu"] = baidu }

        var deepl: [String: Any] = [:]
        put(&deepl, "apiKey", deeplKey.stringValue)
        if !deepl.isEmpty { payload["deepl"] = deepl }

        var deepseek: [String: Any] = [:]
        put(&deepseek, "apiKey", deepseekKey.stringValue)
        put(&deepseek, "baseUrl", deepseekBase.stringValue)
        put(&deepseek, "model", deepseekModel.stringValue)
        if !deepseek.isEmpty { payload["deepseek"] = deepseek }

        var openai: [String: Any] = [:]
        put(&openai, "apiKey", openaiKey.stringValue)
        put(&openai, "baseUrl", openaiBase.stringValue)
        put(&openai, "model", openaiModel.stringValue)
        put(&openai, "asrModel", openaiAsrModel.stringValue)
        if !openai.isEmpty { payload["openai"] = openai }

        return payload
    }

    func collectTestPayload() -> [String: Any] {
        var payload = collectCredentials()
        payload["hiddenProviders"] = Array(CloudProviderPreferences.hiddenProviders()).sorted()
        return payload
    }

    func put(_ dict: inout [String: Any], _ key: String, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.isEmpty { dict[key] = v }
    }

    func clearSecrets() {
        [tencentSecretId, tencentSecretKey, qiniuKey, aliyunKey, baiduSecret, deeplKey, deepseekKey, openaiKey]
            .forEach { $0.stringValue = "" }
    }
}
