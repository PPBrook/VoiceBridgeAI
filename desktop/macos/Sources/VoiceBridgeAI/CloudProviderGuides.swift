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
        "离线默认可直接用（Whisper + Argos），无需填写。云端：填写密钥 → 保存（写入 .env）→ 测试。不知道去哪申请 Key？见下方各厂商指南或打开完整密钥文档。"

    static let tencent = ProviderGuide(
        links: [
            .init(title: "腾讯云", url: "https://cloud.tencent.com/"),
            .init(title: "ASR 控制台", url: "https://console.cloud.tencent.com/asr"),
            .init(title: "TMT 控制台", url: "https://console.cloud.tencent.com/tmt"),
            .init(title: "API 密钥", url: "https://console.cloud.tencent.com/cam/capi"),
        ],
        keyHint: "AppId（语音识别应用）+ SecretId / SecretKey（CAM 密钥，识别与 TMT 共用）· 可选：识别引擎、TMT 区域"
    )

    static let qiniu = ProviderGuide(
        links: [
            .init(title: "七牛 AI", url: "https://www.qiniu.com/ai"),
            .init(title: "API Key", url: "https://portal.qiniu.com/ai-inference/api-key"),
            .init(title: "模型广场", url: "https://www.qiniu.com/ai/models"),
        ],
        keyHint: "API Key（必填）· 模型名须与模型广场 API 参数一致（如 qwen-turbo）"
    )

    static let aliyun = ProviderGuide(
        links: [
            .init(title: "阿里云百炼", url: "https://dashscope.aliyun.com/"),
            .init(title: "API Key", url: "https://bailian.console.aliyun.com/?tab=model#/api-key"),
        ],
        keyHint: "DashScope API Key（必填）· OpenAI 兼容 Chat 接口"
    )

    static let baidu = ProviderGuide(
        links: [
            .init(title: "百度翻译开放平台", url: "https://fanyi-api.baidu.com/"),
            .init(title: "管理控制台", url: "https://fanyi-api.baidu.com/manage/developer"),
        ],
        keyHint: "创建「通用翻译 API」应用 → AppId + 密钥（Secret Key）"
    )

    static let deepseek = ProviderGuide(
        links: [
            .init(title: "DeepSeek", url: "https://www.deepseek.com/"),
            .init(title: "API Keys", url: "https://platform.deepseek.com/api_keys"),
        ],
        keyHint: "API Key（必填）· 默认模型 deepseek-chat"
    )

    static let openai = ProviderGuide(
        links: [
            .init(title: "OpenAI Platform", url: "https://platform.openai.com/"),
            .init(title: "API Keys", url: "https://platform.openai.com/api-keys"),
        ],
        keyHint: "API Key（识别 Whisper 与翻译共用）· 需海外网络或代理"
    )

    static let deepl = ProviderGuide(
        links: [
            .init(title: "DeepL API", url: "https://www.deepl.com/pro-api"),
            .init(title: "Account Keys", url: "https://www.deepl.com/your-account/keys"),
        ],
        keyHint: "API Key · 免费版 Key 以 :fx 结尾"
    )

    static let google = ProviderGuide(
        links: [
            .init(title: "Google 翻译", url: "https://translate.google.com/"),
        ],
        keyHint: "无需密钥 · 非官方 Cloud API，网页兜底 · 需能访问 Google，适合测试/兜底"
    )

    static func makeGuideView(_ guide: ProviderGuide) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 4
        box.fillColor = NSColor(white: 0.08, alpha: 1)

        let accent = NSView()
        accent.wantsLayer = true
        accent.layer?.backgroundColor = NSColor(white: 0.35, alpha: 1).cgColor
        accent.translatesAutoresizingMaskIntoConstraints = false

        let linksLabel = FormBuilder.label("官网")
        linksLabel.font = .boldSystemFont(ofSize: 11)
        linksLabel.textColor = NSColor(white: 0.62, alpha: 1)

        let linksRow = NSStackView()
        linksRow.orientation = .horizontal
        linksRow.spacing = 2
        linksRow.alignment = .centerY
        linksRow.addArrangedSubview(linksLabel)

        for (index, link) in guide.links.enumerated() {
            if index > 0 {
                linksRow.addArrangedSubview(mutedLabel("·"))
            }
            linksRow.addArrangedSubview(linkButton(link.title, url: link.url))
        }

        let keyLabel = FormBuilder.label("密钥  \(guide.keyHint)")
        keyLabel.font = .systemFont(ofSize: 11)
        keyLabel.textColor = NSColor(white: 0.52, alpha: 1)
        keyLabel.maximumNumberOfLines = 0
        keyLabel.lineBreakMode = .byWordWrapping
        keyLabel.preferredMaxLayoutWidth = 400

        let textStack = NSStackView(views: [linksRow, keyLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(accent)
        box.addSubview(textStack)

        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            accent.topAnchor.constraint(equalTo: box.topAnchor),
            accent.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            accent.widthAnchor.constraint(equalToConstant: 3),
            textStack.leadingAnchor.constraint(equalTo: accent.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: box.topAnchor, constant: 6),
            textStack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -6),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),
        ])

        return box
    }

    static func openProviderKeysGuide() {
        NSWorkspace.shared.open(AppSettings.baseURL.appendingPathComponent("guide/provider-keys"))
    }

    private static func mutedLabel(_ text: String) -> NSTextField {
        let label = FormBuilder.label(text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = NSColor(white: 0.45, alpha: 1)
        return label
    }

    private static func linkButton(_ title: String, url: String) -> NSButton {
        let button = NSButton(title: title, target: LinkOpener.shared, action: #selector(LinkOpener.open(_:)))
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = .systemFont(ofSize: 11)
        button.contentTintColor = .linkColor
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
