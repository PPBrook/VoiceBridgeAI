/** Cross-browser display media capture helpers. */
const Capture = {
  browser() {
    const ua = navigator.userAgent;
    if (/Firefox\//i.test(ua)) return "firefox";
    if (/Edg\//i.test(ua)) return "edge";
    if (/Chrome\//i.test(ua)) return "chrome";
    if (/Safari\//i.test(ua) && !/Chrome|Chromium|Edg\//i.test(ua)) return "safari";
    return "other";
  },

  supported() {
    return typeof navigator.mediaDevices?.getDisplayMedia === "function";
  },

  diagnose() {
    if (this.supported()) {
      return { ok: true };
    }

    const parts = [];

    if (!window.isSecureContext) {
      parts.push("当前不是安全上下文（getDisplayMedia 需要 HTTPS 或 localhost）");
      if (location.hostname === "0.0.0.0") {
        parts.push("不要用 http://0.0.0.0:8765");
      } else if (location.protocol === "file:") {
        parts.push("不要用本地文件打开");
      } else if (/^\d+\.\d+\.\d+\.\d+$/.test(location.hostname) && location.hostname !== "127.0.0.1") {
        parts.push(`不要用局域网 IP（${location.hostname}）`);
      }
      parts.push("请用 Chrome 打开：http://127.0.0.1:8765");
    } else {
      parts.push(`当前浏览器（${this.browser()}）未提供 getDisplayMedia`);
      parts.push("请用桌面版 Chrome 或 Edge，不要用 Cursor 内置预览");
    }

    return { ok: false, message: parts.join("。") };
  },

  /** Chromium desktop only — Safari/Firefox ignore audio in getDisplayMedia. */
  canCaptureAudio() {
    const b = this.browser();
    return b === "chrome" || b === "edge";
  },

  constraints() {
    return {
      video: { displaySurface: "browser" },
      audio: true,
      selfBrowserSurface: "exclude",
      surfaceSwitching: "include",
    };
  },

  hint() {
    const tips = {
      chrome: "Chrome：选「标签页」并勾选「分享标签页音频」",
      edge: "Edge：选「标签页」并勾选「分享标签页音频」",
      firefox: "Firefox 不支持标签页/系统音频捕获，请改用 Chrome 或 Edge",
      safari: "Safari 不支持标签页/系统音频捕获，请改用 Chrome 或 Edge",
      other: "请使用 Chrome 或 Edge 捕获标签页音频",
    };
    return tips[this.browser()] || tips.other;
  },

  unsupportedMessage() {
    const b = this.browser();
    if (b === "safari") {
      return (
        "Safari 的 getDisplayMedia 不会返回音频轨（WebKit 限制），" +
        "选屏幕/窗口/标签页均无效。请复制 http://127.0.0.1:8765 到 Chrome 或 Edge 使用。"
      );
    }
    if (b === "firefox") {
      return "Firefox 不支持通过浏览器捕获标签页音频，请改用 Chrome 或 Edge。";
    }
    return "当前浏览器不支持标签页音频捕获，请使用 Chrome 或 Edge。";
  },

  noAudioMessage() {
    return "未检测到音频：请选「Chrome 标签页」并勾选「分享标签页音频」";
  },

  dropVideoTracks(stream) {
    stream.getVideoTracks().forEach((t) => t.stop());
  },
};
