let ctx: AudioContext | null = null;

function getCtx(): AudioContext | null {
  if (typeof window === "undefined") return null;
  const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AC) return null;
  if (!ctx) ctx = new AC();
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

/** Short sine blip; `gain` is the peak amplitude (already volume-scaled). */
export function playPing(freq: number, gain: number, durationMs = 140) {
  if (gain <= 0.0005) return;
  const ac = getCtx();
  if (!ac) return;
  const now = ac.currentTime;
  const osc = ac.createOscillator();
  const amp = ac.createGain();
  osc.type = "sine";
  osc.frequency.setValueAtTime(freq, now);
  osc.frequency.exponentialRampToValueAtTime(freq * 1.16, now + durationMs / 1000);
  amp.gain.setValueAtTime(0.0001, now);
  amp.gain.exponentialRampToValueAtTime(gain, now + 0.012);
  amp.gain.exponentialRampToValueAtTime(0.0001, now + durationMs / 1000);
  osc.connect(amp).connect(ac.destination);
  osc.start(now);
  osc.stop(now + durationMs / 1000 + 0.02);
}
