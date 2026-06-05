class PcmProcessor extends AudioWorkletProcessor {
  process(inputs) {
    const ch = inputs[0]?.[0];
    if (ch?.length) {
      this.port.postMessage({ n: ch.length });
    }
    return true;
  }
}

registerProcessor("pcm-processor", PcmProcessor);
