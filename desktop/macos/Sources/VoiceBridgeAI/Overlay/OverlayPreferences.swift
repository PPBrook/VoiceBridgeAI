import CoreGraphics
import Foundation

enum OverlayPreferences {
    private static let opacityKey = "overlayBackgroundOpacity"
    private static let showEnglishKey = "overlayShowEnglish"

    /// 背景不透明度，0.15（很透）～ 1.0（不透明）。默认 0.78，接近 Web 扩展 overlay。
    static var backgroundOpacity: CGFloat {
        get {
            let stored = UserDefaults.standard.object(forKey: opacityKey) as? Double
            if let stored, stored >= 0.15, stored <= 1.0 {
                return CGFloat(stored)
            }
            return 0.78
        }
        set {
            let clamped = min(1.0, max(0.15, newValue))
            UserDefaults.standard.set(Double(clamped), forKey: opacityKey)
        }
    }

    /// 是否在字幕下方显示英文原文。
    static var showEnglish: Bool {
        get {
            if UserDefaults.standard.object(forKey: showEnglishKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showEnglishKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showEnglishKey)
        }
    }
}
