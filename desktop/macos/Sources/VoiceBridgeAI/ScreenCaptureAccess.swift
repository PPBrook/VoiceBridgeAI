import AppKit
import CoreGraphics

enum ScreenCaptureAccess {
    static func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func ensureAccess() -> Bool {
        if hasAccess() { return true }
        requestAccess()
        return hasAccess()
    }

    static func openSystemSettings() {
        let urlString =
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
