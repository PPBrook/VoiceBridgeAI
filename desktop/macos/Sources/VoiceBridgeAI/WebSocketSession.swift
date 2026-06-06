import Foundation

final class WebSocketSession {
    var onASR: (([String: Any]) -> Void)?
    var onError: ((String) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let encoder = JSONSerialization.self
    private let readyTimeout: TimeInterval = 120

    func connect(config: EngineConfig) async throws {
        disconnect()

        let task = URLSession.shared.webSocketTask(with: AppSettings.wsURL)
        self.task = task
        task.resume()

        let payload = config.wsConfigPayload()
        let data = try encoder.data(withJSONObject: payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        try await send(text: text)
        try await waitForReady()
        startReceiving()
    }

    private func waitForReady() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                try await self.receiveUntilReady()
            }
            group.addTask { [readyTimeout] in
                try await Task.sleep(nanoseconds: UInt64(readyTimeout * 1_000_000_000))
                throw NSError(
                    domain: "VoiceBridgeAI",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "等待服务端就绪超时（Whisper 首次加载可能较慢，请稍后重试）",
                    ]
                )
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func receiveUntilReady() async throws {
        guard let task else { throw URLError(.notConnectedToInternet) }

        while true {
            let message = try await task.receive()
            switch message {
            case .string(let text):
                guard let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String else { continue }

                if type == "asrReady" { return }
                if type == "error" {
                    let msg = json["message"] as? String ?? "服务端错误"
                    throw NSError(domain: "VoiceBridgeAI", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
                }
            case .data:
                continue
            @unknown default:
                continue
            }
        }
    }

    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let task = self.task else { break }
                do {
                    let message = try await task.receive()
                    if case .string(let text) = message {
                        self.handle(text: text)
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.onError?(error.localizedDescription)
                        }
                    }
                    break
                }
            }
        }
    }

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "error" {
            let msg = json["message"] as? String ?? "服务端错误"
            onError?(msg)
            return
        }
        if type == "asr" {
            onASR?(json)
        }
    }

    func send(pcm: Data) async throws {
        guard let task else {
            throw URLError(.networkConnectionLost)
        }
        try await task.send(.data(pcm))
    }

    private func send(text: String) async throws {
        guard let task else { return }
        try await task.send(.string(text))
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}
