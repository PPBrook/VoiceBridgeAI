import AppKit

extension LocalModelsPanelView {
    func isDownloading(_ id: String) -> Bool {
        guard let task = downloadTasks[id] else { return false }
        return !task.isCancelled
    }

    func resumeActiveDownloadIfNeeded(from health: [String: Any]) {
        guard let jobDict = health["activeDownload"] as? [String: Any],
              let job = LocalModelDownloadJob.from(jobDict),
              job.status == "running" else { return }
        let rowId = job.modelId
        guard matchesActiveJob(job, rowId: rowId), !isDownloading(rowId) else { return }
        applyDownloadProgress(rowId, job: job)
        followDownloadJob(rowId: rowId, jobId: job.id)
    }

    func matchesActiveJob(_ job: LocalModelDownloadJob, rowId: String) -> Bool {
        guard job.modelId == rowId else { return false }
        if rowId == "whisper", let whisper = job.whisperModel, let selected = selectedWhisperModel() {
            return whisper == selected
        }
        return true
    }

    func applyDownloadProgress(_ id: String, job: LocalModelDownloadJob) {
        guard let row = modelRows[id] else { return }
        row.progressBar.isHidden = false
        row.progressBar.doubleValue = job.progress * 100
        row.button.isEnabled = false
        row.deleteButton.isEnabled = false
        setRowStatus(id, job.displayMessage)
        if id == "whisper" {
            whisperDetailLabel.stringValue = "后台下载中，可关闭此页面继续等待"
            whisperDetailLabel.textColor = .secondaryLabelColor
        }
    }

    func clearRowStatus(_ id: String) {
        setRowStatus(id, "")
    }

    func hideDownloadProgress(_ id: String) {
        guard let row = modelRows[id] else { return }
        row.progressBar.isHidden = true
        row.progressBar.doubleValue = 0
    }

    func followDownloadJob(rowId: String, jobId: String) {
        downloadTasks[rowId]?.cancel()
        downloadTasks[rowId] = Task { @MainActor in
            defer { downloadTasks[rowId] = nil }
            do {
                while !Task.isCancelled {
                    let job = try await SettingsStore.shared.pollLocalModelDownloadJob(id: jobId)
                    applyDownloadProgress(rowId, job: job)
                    if job.status == "done" {
                        hideDownloadProgress(rowId)
                        try await SettingsStore.shared.refresh()
                        reload()
                        setRowStatus(rowId, job.displayMessage, color: .systemGreen)
                        SettingsWindowController.shared?.reloadEnginePanel()
                        AppDelegate.shared?.control?.refreshEngineSummary()
                        return
                    }
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } catch {
                hideDownloadProgress(rowId)
                reload()
                setRowStatus(rowId, error.localizedDescription, color: .systemRed)
            }
        }
    }

    func setRowStatus(_ id: String, _ text: String, color: NSColor = .secondaryLabelColor) {
        guard let row = modelRows[id] else { return }
        row.actionStatus.stringValue = text
        row.actionStatus.textColor = color
        row.actionStatus.isHidden = text.isEmpty
    }

    func sizeHintForModel(id: String, whisperModel: String?) -> String {
        if id == "whisper", let whisperModel {
            return whisperSizeHint(for: whisperModel, fallback: "~75 MB")
        }
        guard let models = SettingsStore.shared.health["localModels"] as? [[String: Any]] else {
            return "—"
        }
        for item in models where (item["id"] as? String) == id {
            return item["sizeHint"] as? String ?? "—"
        }
        return "—"
    }

    func confirmDownload(id: String, whisperModel: String?) -> Bool {
        let sizeHint = sizeHintForModel(id: id, whisperModel: whisperModel)
        let alert = NSAlert()
        alert.messageText = "下载本地模型？"
        if id == "whisper", let model = whisperModel {
            alert.informativeText =
                "将后台下载 Whisper \(model)（\(sizeHint)）。\n建议 Wi-Fi 环境；可关闭设置页，下载会继续进行。"
        } else if id == "argos" {
            alert.informativeText =
                "将后台下载 Argos 英译中（\(sizeHint)）。\n建议 Wi-Fi 环境；可关闭设置页，下载会继续进行。"
        } else {
            alert.informativeText = "将后台下载（\(sizeHint)）。建议 Wi-Fi 环境。"
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func beginDownload(id: String, whisperModel: String?) async throws {
        let job = try await SettingsStore.shared.startLocalModelDownload(
            id: id,
            whisperModel: whisperModel
        )
        applyDownloadProgress(id, job: job)
        followDownloadJob(rowId: id, jobId: job.id)
    }
}
