const healthEl = document.getElementById("health");
const statusEl = document.getElementById("status");
const captureBtn = document.getElementById("capture");

let stream = null;
let audioCtx = null;

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

function stopCapture() {
  stream?.getTracks().forEach((t) => t.stop());
  stream = null;
  audioCtx?.close();
  audioCtx = null;
  captureBtn.disabled = false;
  captureBtn.textContent = "捕获标签页音频";
  setStatus("idle");
}

async function startCapture() {
  captureBtn.disabled = true;
  setStatus("requesting…");

  try {
    stream = await navigator.mediaDevices.getDisplayMedia({
      video: true,
      audio: true,
    });

    if (!stream.getAudioTracks().length) {
      setStatus("error: no audio (share tab audio)");
      stopCapture();
      return;
    }

    stream.getVideoTracks().forEach((t) => t.stop());
    stream.getAudioTracks()[0].onended = () => stopCapture();

    audioCtx = new AudioContext();
    await audioCtx.audioWorklet.addModule("/static/js/pcm-processor.js");

    const src = audioCtx.createMediaStreamSource(stream);
    const node = new AudioWorkletNode(audioCtx, "pcm-processor");
    src.connect(node);

    captureBtn.disabled = false;
    captureBtn.textContent = "停止";
    setStatus(`capturing · ${audioCtx.sampleRate} Hz`);
  } catch (err) {
    setStatus(err.name === "NotAllowedError" ? "cancelled" : `error: ${err.message}`);
    stopCapture();
  }
}

captureBtn.addEventListener("click", () => {
  if (stream) {
    stopCapture();
  } else {
    startCapture();
  }
});
