/** Offscreen document: tab audio → PCM → WebSocket → forward subtitles. */

let ws = null;
let audioCtx = null;
let mediaStream = null;
let captureTabId = null;

function wsUrl(base) {
  const u = new URL(base || "http://127.0.0.1:8765");
  const proto = u.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${u.host}/ws`;
}

function connectWs(sampleRate, config) {
  return new Promise((resolve, reject) => {
    let settled = false;
    ws = new WebSocket(wsUrl(config.serverUrl));
    ws.binaryType = "arraybuffer";

    ws.onmessage = (ev) => {
      if (typeof ev.data !== "string") return;
      try {
        const msg = JSON.parse(ev.data);
        if (msg.type === "error") {
          if (!settled) {
            settled = true;
            reject(new Error(msg.message || "server error"));
          }
          chrome.runtime.sendMessage({
            type: "CAPTURE_ERROR",
            tabId: captureTabId,
            message: msg.message || "服务端错误",
          });
          return;
        }
        if (msg.type === "asrReady") {
          if (!settled) {
            settled = true;
            resolve();
          }
          return;
        }
        if (msg.type === "asr") {
          chrome.runtime.sendMessage({
            type: "ASR_SEGMENT",
            tabId: captureTabId,
            payload: msg,
          });
        }
      } catch {
        /* ignore malformed */
      }
    };

    ws.onopen = () => {
      ws.send(
        JSON.stringify({
          type: "config",
          sampleRate,
          asrMode: config.asrProvider || config.asrMode,
          asrProvider: config.asrProvider || config.asrMode,
          partialProvider: config.partialProvider,
          finalProvider: config.finalProvider,
          reviseMode: config.reviseMode,
        })
      );
    };

    ws.onerror = () => {
      if (!settled) {
        settled = true;
        reject(new Error("WebSocket 连接失败"));
      }
    };

    ws.onclose = () => {
      if (!settled) {
        settled = true;
        reject(new Error("WebSocket 已关闭"));
      }
    };
  });
}

function closeWs() {
  if (ws) {
    ws.close();
    ws = null;
  }
}

function stopMediaStream() {
  if (mediaStream) {
    for (const track of mediaStream.getTracks()) {
      track.onended = null;
      track.stop();
    }
    mediaStream = null;
  }
}

/** tabCapture 会静音原标签页，必须把流接回 AudioContext.destination 才能继续出声。 */
async function attachPlayback(stream) {
  audioCtx = new AudioContext();
  if (audioCtx.state === "suspended") await audioCtx.resume();
  const src = audioCtx.createMediaStreamSource(stream);
  src.connect(audioCtx.destination);
  return src;
}

async function pumpWithWorklet(sourceNode) {
  const tap = audioCtx.createGain();
  tap.gain.value = 1;

  await audioCtx.audioWorklet.addModule(chrome.runtime.getURL("pcm-processor.js"));
  const node = new AudioWorkletNode(audioCtx, "pcm-processor");
  node.port.onmessage = (ev) => {
    if (ws?.readyState === WebSocket.OPEN) ws.send(ev.data);
  };
  sourceNode.connect(tap);
  tap.connect(node);
  // 仅用于驱动 worklet，不再接到 destination（playback 已单独连接）
  const sink = audioCtx.createGain();
  sink.gain.value = 0;
  node.connect(sink);
  sink.connect(audioCtx.destination);
}

async function startCapture({ streamId, tabId, config }) {
  await stopCapture(false);
  captureTabId = tabId;

  const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      mandatory: {
        chromeMediaSource: "tab",
        chromeMediaSourceId: streamId,
      },
    },
    video: false,
  });

  mediaStream = stream;
  const audioTrack = stream.getAudioTracks()[0];
  if (!audioTrack) {
    stopMediaStream();
    throw new Error("未获取到音频轨");
  }
  audioTrack.onended = () => stopCapture(true);

  const settings = audioTrack.getSettings();
  const sampleRate = settings.sampleRate || 48000;

  const playbackSrc = await attachPlayback(stream);
  await connectWs(sampleRate, config);

  // 从同一音频源分流：playback 已接 destination，worklet 负责送 PCM
  await pumpWithWorklet(playbackSrc);

  chrome.runtime.sendMessage({ type: "CAPTURE_STARTED", tabId });
}

async function stopCapture(notify = true) {
  closeWs();
  stopMediaStream();
  if (audioCtx) {
    await audioCtx.close().catch(() => {});
    audioCtx = null;
  }
  const tabId = captureTabId;
  captureTabId = null;
  if (notify && tabId != null) {
    chrome.runtime.sendMessage({ type: "CAPTURE_STOPPED", tabId });
  }
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.target !== "offscreen") return;

  if (msg.type === "START_CAPTURE") {
    startCapture(msg)
      .then(() => sendResponse({ ok: true }))
      .catch((err) => sendResponse({ ok: false, error: err.message }));
    return true;
  }

  if (msg.type === "STOP_CAPTURE") {
    stopCapture(true)
      .then(() => sendResponse({ ok: true }))
      .catch((err) => sendResponse({ ok: false, error: err.message }));
    return true;
  }

  if (msg.type === "RELEASE_CAPTURE") {
    stopCapture(false)
      .then(() => sendResponse({ ok: true }))
      .catch((err) => sendResponse({ ok: false, error: err.message }));
    return true;
  }
});
