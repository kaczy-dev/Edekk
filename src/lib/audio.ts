export class SimpleAudio {
  ctx: AudioContext | null = null;

  private getContext(): AudioContext {
    if (!this.ctx) {
      this.ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    return this.ctx;
  }

  /** Play a simple sine wave tone. */
  playTone(freq: number, duration: number, volume: number) {
    if (volume <= 0) return;
    const ctx = this.getContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.frequency.value = freq;
    osc.type = "sine";

    gain.gain.setValueAtTime(volume, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration / 1000);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration / 1000);
  }

  /** Pickup sound: ascending chirp. */
  playPickup(volume: number) {
    this.playTone(440, 100, volume * 0.4); // A4
    setTimeout(() => this.playTone(659, 100, volume * 0.4), 60); // E5
  }

  /** Completion sound: bell chord (major triad). */
  playCompletion(volume: number) {
    this.playTone(523, 200, volume * 0.3); // C5
    this.playTone(659, 200, volume * 0.3); // E5
    this.playTone(784, 200, volume * 0.3); // G5
  }

  /** Danger sound: warning buzz. */
  playDanger(volume: number) {
    this.playTone(220, 80, volume * 0.4); // A3
    setTimeout(() => this.playTone(220, 80, volume * 0.4), 100);
  }
}

export const audio = new SimpleAudio();
