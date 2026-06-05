const healthEl = document.getElementById("health");
const statusEl = document.getElementById("status");
const hintEl = document.getElementById("hint");
const captureBtn = document.getElementById("capture");

let stream = null;
let audioCtx = null;
let analyser = null;
let ws = null;
let levelTimer = null;
let sentBytes = 0;
let lastLevel = 0;
let pumpTask = null;
let active = false;

fetch("/api/health")
  .then((r) => r.json())
  .then((d) => {
    healthEl.textContent = JSON.stringify(d);
    healthEl.classList.add("ok");
  })
  .catch(() => {
    healthEl.textContent = "offline";
    healthEl.classList.add("err");
  });

function setStatus(text) {
  statusEl.textContent = text;
}

if (!Capture.supported()) {
  const diag = Capture.diagnose();
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = diag.message;
  setStatus("unsupported: getDisplayMedia");
} else if (!Capture.canCaptureAudio()) {
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = Capture.unsupportedMessage();
  setStatus("unsupported: no audio capture");
} else {
  hintEl.textContent = Capture.hint();
}

function wsUrl() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}/ws`;
}

function connectWs(sampleRate) {
  return new Promise((resolve, reject) => {
    ws = new WebSocket(wsUrl());
    ws.binaryType = "arraybuffer";
    ws.onopen = () => {
      ws.send(JSON.stringify({ type: "config", sampleRate }));
      resolve();
    };
    ws.onerror = () => reject(new Error("websocket failed"));
  });
}

function closeWs() {
  if (ws) {
    ws.close();
    ws = null;
  }
  sentBytes = 0;
}

function stopLevelMonitor() {
  if (levelTimer) {
    clearInterval(levelTimer);
    levelTimer = null;
  }
  analyser = null;
  lastLevel = 0;
}

function startLevelMonitor() {
  stopLevelMonitor();
  let tickBytes = sentBytes;
  const buf = analyser ? new Uint8Array(analyser.fftSize) : null;

  levelTimer = setInterval(() => {
    if (analyser && buf) {
      analyser.getByteTimeDomainData(buf);
      let sum = 0;
      for (let i = 0; i < buf.length; i++) {
        const v = (buf[i] - 128) / 128;
        sum += v * v;
      }
      lastLevel = Math.min(100, Math.round(Math.sqrt(sum / buf.length) * 400));
    }
    const kbps = Math.round(((sentBytes - tickBytes) * 8) / 1024);
    tickBytes = sentBytes;
    setStatus(`capturing · level ${lastLevel}% · ↑${kbps} kb/s`);
  }, 1000);
}

function stopPump() {
  pumpTask = null;
}

async function pumpWithProcessor(track) {
  const processor = new MediaStreamTrackProcessor({ track });
  const reader = processor.readable.getReader();
  pumpTask = reader;

  try {
    while (reader === pumpTask) {
      const { value, done } = await reader.read();
      if (done) break;

      const n = value.numberOfFrames;
      const f32 = new Float32Array(n);
      value.copyTo(f32, { planeIndex: 0 });
      value.close();

      let sum = 0;
      const int16 = new Int16Array(n);
      for (let i = 0; i < n; i++) {
        sum += f32[i] * f32[i];
        const s = Math.max(-1, Math.min(1, f32[i]));
        int16[i] = s < 0 ? s * 32768 : s * 32767;
      }
      lastLevel = Math.min(100, Math.round(Math.sqrt(sum / n) * 400));

      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(int16.buffer);
        sentBytes += int16.byteLength;
      }
    }
  } finally {
    reader.releaseLock();
    if (active) stopCapture();
  }
}

async function pumpWithWorklet(mediaStream, sampleRate) {
  audioCtx = new AudioContext();
  if (audioCtx.state === "suspended") await audioCtx.resume();

  const src = audioCtx.createMediaStreamSource(mediaStream);
  const silent = audioCtx.createGain();
  silent.gain.value = 0;

  analyser = audioCtx.createAnalyser();
  analyser.fftSize = 2048;
  src.connect(analyser);
  analyser.connect(silent);

  await audioCtx.audioWorklet.addModule("/static/js/pcm-processor.js");
  const node = new AudioWorkletNode(audioCtx, "pcm-processor");
  node.port.onmessage = (ev) => {
    if (ws?.readyState !== WebSocket.OPEN) return;
    ws.send(ev.data);
    sentBytes += ev.data.byteLength;
  };
  src.connect(node);
  node.connect(silent);
  silent.connect(audioCtx.destination);

  startLevelMonitor();
}

function stopCapture() {
  if (!active) return;
  active = false;
  stopPump();
  stopLevelMonitor();
  closeWs();
  stream?.getTracks().forEach((t) => t.stop());
  stream = null;
  audioCtx?.close();
  audioCtx = null;
  captureBtn.disabled = false;
  captureBtn.textContent = "捕获音频";
  setStatus("idle");
}

async function startCapture() {
  captureBtn.disabled = true;
  setStatus("requesting…");

  try {
    stream = await navigator.mediaDevices.getDisplayMedia(Capture.constraints());

    if (!stream.getAudioTracks().length) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
      captureBtn.disabled = false;
      captureBtn.textContent = "重试";
      setStatus(`error: ${Capture.noAudioMessage()}`);
      return;
    }

    stream.getVideoTracks().forEach((t) => t.stop());
    const audioTrack = stream.getAudioTracks()[0];
    audioTrack.onended = () => stopCapture();

    const settings = audioTrack.getSettings();
    const sampleRate = settings.sampleRate || 48000;
    await connectWs(sampleRate);
    active = true;

    if (typeof MediaStreamTrackProcessor !== "undefined") {
      startLevelMonitor();
      pumpWithProcessor(audioTrack);
    } else {
      await pumpWithWorklet(stream, sampleRate);
    }

    captureBtn.disabled = false;
    captureBtn.textContent = "停止";
  } catch (err) {
    if (stream || ws) {
      active = true;
      stopCapture();
    }
    captureBtn.disabled = false;
    if (err.name === "NotAllowedError") {
      setStatus("cancelled");
    } else if (err.name === "NotSupportedError") {
      setStatus("unsupported: " + err.message);
    } else {
      setStatus(`error: ${err.message}`);
    }
  }
}

captureBtn.addEventListener("click", () => {
  if (stream) {
    stopCapture();
  } else {
    startCapture();
  }
});
