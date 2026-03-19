let whisperStream = null;
let whisperRecorder = null;
let whisperChunks = [];
let whisperStartTime = 0;
let whisperTimer = null;

function formatTime(seconds) {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

function stopWhisperStream({ keepBar = false } = {}) {
  whisperStream?.getTracks().forEach(t => t.stop());
  whisperStream = null;
  clearInterval(whisperTimer);

  const waveform = document.getElementById("whisper-waveform");
  if (waveform) waveform.innerHTML = "";

  const durationEl = document.getElementById("whisper-duration");
  if (durationEl) {
    durationEl.classList.remove("recording", "spinner");
    durationEl.textContent = "0:00";
  }

  const inputArea = document.getElementById("chat-input-area");
  const whisperBar = document.getElementById("whisper-bar");

  if (inputArea) {
    inputArea.style.visibility = "visible";
    inputArea.style.position = "relative";
    inputArea.style.pointerEvents = "auto";
  }

  if (!keepBar && whisperBar) whisperBar.classList.remove("active");
}

function initVisualizer(stream) {
  const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  const source = audioCtx.createMediaStreamSource(stream);
  const analyser = audioCtx.createAnalyser();
  analyser.fftSize = 256;

  const bufferLength = analyser.frequencyBinCount;
  const dataArray = new Uint8Array(bufferLength);
  source.connect(analyser);

  const container = document.getElementById("whisper-waveform");

  function draw() {
    analyser.getByteFrequencyData(dataArray);
    let sum = 0;
    for (let i = 0; i < dataArray.length; i++) sum += dataArray[i];
    const avg = sum / dataArray.length;
    const height = Math.max(10, Math.min(100, (avg / 255) * 100));

    const bar = document.createElement("div");
    bar.className = "waveform-bar";
    bar.style.height = `${height}%`;
    container.appendChild(bar);

    if (container.children.length > 50) container.removeChild(container.firstChild);
    requestAnimationFrame(draw);
  }

  draw();
}

async function startWhisperBar() {
  try {
    whisperStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch (err) {
    alert("🎤 Kein Mikrofonzugriff.");
    return;
  }

  const inputArea = document.getElementById("chat-input-area");
  const whisperBar = document.getElementById("whisper-bar");
  const durationEl = document.getElementById("whisper-duration");

  if (inputArea) {
    inputArea.style.visibility = "hidden";
    inputArea.style.position = "absolute";
    inputArea.style.pointerEvents = "none";
  }

  if (whisperBar) whisperBar.classList.add("active");

  if (durationEl) {
    durationEl.classList.remove("spinner");
    durationEl.classList.add("recording");
  }

  initVisualizer(whisperStream);

  whisperChunks = [];
  whisperStartTime = 0;

  whisperRecorder = new MediaRecorder(whisperStream);
  whisperRecorder.ondataavailable = e => whisperChunks.push(e.data);

  whisperRecorder.onstop = async () => {
    if (durationEl) {
      durationEl.classList.remove("recording");
      durationEl.classList.add("spinner");
      durationEl.textContent = "";
    }

    const audioBlob = new Blob(whisperChunks, { type: "audio/mp3" });
    const text = await uploadWhisperAudio(audioBlob);
    const input = document.getElementById("chat-input");
    if (text && input) input.value = (input.value + " " + text).trim();

    stopWhisperStream();
  };

  whisperRecorder.start();

  whisperTimer = setInterval(() => {
    whisperStartTime++;
    if (durationEl && !durationEl.classList.contains("spinner")) {
      durationEl.textContent = formatTime(whisperStartTime);
    }
  }, 1000);
}

async function uploadWhisperAudio(blob) {
  const formData = new FormData();
  formData.append("audio", blob, "speech.mp3");

  try {
    const response = await fetch("https://cloudflareworker.stefan-obholz.workers.dev/whisper", {
      method: "POST",
      body: formData
    });

    const result = await response.json();
    if (result && result.text) {
      return result.text;
    } else {
      throw new Error("Keine Transkription erhalten");
    }
  } catch (err) {
    alert("Whisper-Fehler: " + err.message);
    return null;
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const micBtn = document.getElementById("mic-btn");
  if (micBtn) micBtn.onclick = startWhisperBar;

  const stopBtn = document.getElementById("whisper-stop");
  if (stopBtn) stopBtn.onclick = () => {
    if (whisperRecorder?.state === "recording") {
      whisperRecorder.stop();
    }
  };

  const cancelBtn = document.getElementById("whisper-cancel");
  if (cancelBtn) cancelBtn.onclick = () => {
    if (whisperRecorder?.state === "recording") {
      whisperRecorder.stop();
    }
    stopWhisperStream();
  };
});