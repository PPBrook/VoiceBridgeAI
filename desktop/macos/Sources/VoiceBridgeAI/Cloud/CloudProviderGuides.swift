import AppKit

struct ProviderGuide {
    struct Link {
        let title: String
        let url: String
    }

    let links: [Link]
    let keyHint: String
}

@MainActor
enum CloudProviderGuides {
    static let intro =
        "填写密钥 → 保存 → 测试通过后，该接口会出现在「引擎」页。不用的接口可点「隐藏」，移至下方「已隐藏的接口」。"

    static let tencent = ProviderGuide(
        links: [
            .init(title: "控制台", url: "https://console.cloud.tencent.com/"),
            .init(title: "ASR", url: "https://console.cloud.tencent.com/asr"),
            .init(title: "API 密钥", url: "https://console.cloud.tencent.com/cam/capi"),
        ],
        keyHint: "AppId + SecretId / SecretKey（识别与 TMT 共用）"
    )

    static let qiniu = ProviderGuide(
        links: [
            .init(title: "七牛 AI", url: "https://www.qiniu.com/ai"),
            .init(title: "API Key", url: "https://portal.qiniu.com/ai-inference/api-key"),
        ],
        keyHint: "API Key · 模型如 qwen-turbo"
    )

    static let aliyun = ProviderGuide(
        links: [
            .init(title: "百炼", url: "https://dashscope.aliyun.com/"),
            .init(title: "API Key", url: "https://bailian.console.aliyun.com/?tab=model#/api-key"),
        ],
        keyHint: "DashScope API Key"
    )

    static let baidu = ProviderGuide(
        links: [
            .init(title: "百度翻译", url: "https://fanyi-api.baidu.com/"),
            .init(title: "控制台", url: "https://fanyi-api.baidu.com/manage/developer"),
        ],
        keyHint: "AppId + Secret Key"
    )

    static let deepseek = ProviderGuide(
        links: [
            .init(title: "DeepSeek", url: "https://platform.deepseek.com/api_keys"),
        ],
        keyHint: "API Key · deepseek-chat"
    )

    static let openai = ProviderGuide(
        links: [
            .init(title: "OpenAI", url: "https://platform.openai.com/api-keys"),
        ],
        keyHint: "API Key · 识别与 Chat 共用"
    )

    static let deepl = ProviderGuide(
        links: [
            .init(title: "DeepL Keys", url: "https://www.deepl.com/your-account/keys"),
        ],
        keyHint: "免费版 Key 以 :fx 结尾"
    )

    static let google = ProviderGuide(
        links: [
            .init(title: "Google 翻译", url: "https://translate.google.com/"),
        ],
        keyHint: "无需密钥 · 网页兜底"
    )

    static func makeGuideView(_ guide: ProviderGuide) -> NSView {
        let wrap = NSStackView()
        wrap.orientation = .vertical
        wrap.alignment = .leading
        wrap.spacing = 4

        let linksRow = NSStackView()
        linksRow.orientation = .horizontal
        linksRow.spacing = 6
        linksRow.alignment = .centerY

        for link in guide.links {
            linksRow.addArrangedSubview(linkButton(link.title, url: link.url))
        }

        let hint = FormBuilder.label(guide.keyHint)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 2
        hint.lineBreakMode = .byWordWrapping

        wrap.addArrangedSubview(linksRow)
        wrap.addArrangedSubview(hint)
        return wrap
    }

    private static func linkButton(_ title: String, url: String) -> NSButton {
        let button = NSButton(title: title, target: LinkOpener.shared, action: #selector(LinkOpener.open(_:)))
        button.bezelStyle = .recessed
        button.controlSize = .mini
        button.font = .systemFont(ofSize: 10)
        button.identifier = NSUserInterfaceItemIdentifier(url)
        return button
    }
}

private final class LinkOpener: NSObject {
    static let shared = LinkOpener()

    @objc func open(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
