// Procedural Sound Manager using browser Web Audio API
// Synthesizes BGM and SFX in real-time so it works offline and requires no audio assets.

class SoundManager {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private bgmGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private beeGain: GainNode | null = null;
  private beeOsc: OscillatorNode | null = null;

  private currentBgmLevel: string | null = null;
  private bgmIntervalId: any = null;
  private volumeVal = 0.6;
  private mutedVal = false;
  private activeOscillators: Set<OscillatorNode> = new Set();

  constructor() {
    // Lazy initialized on first click/keypress
  }

  public init() {
    if (this.ctx) return;
    try {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      this.ctx = new AudioCtx();
      
      this.masterGain = this.ctx.createGain();
      this.bgmGain = this.ctx.createGain();
      this.sfxGain = this.ctx.createGain();
      this.beeGain = this.ctx.createGain();

      this.masterGain.connect(this.ctx.destination);
      this.bgmGain.connect(this.masterGain);
      this.sfxGain.connect(this.masterGain);
      this.beeGain.connect(this.masterGain);

      // Initialize volumes
      this.updateGainNodes();
      this.startBeeBuzzLoop();
    } catch (e) {
      console.warn("Web Audio API not supported", e);
    }
  }

  private updateGainNodes() {
    if (!this.masterGain || !this.bgmGain || !this.sfxGain || !this.beeGain) return;
    const targetMaster = this.mutedVal ? 0 : this.volumeVal;
    
    // Smooth transition
    const now = this.ctx!.currentTime;
    this.masterGain.gain.setTargetAtTime(targetMaster, now, 0.1);
    this.bgmGain.gain.setTargetAtTime(0.35, now, 0.1); // BGM slightly quieter
    this.sfxGain.gain.setTargetAtTime(0.8, now, 0.05); // SFX nice and crisp
  }

  public setVolume(vol: number) {
    this.volumeVal = Math.max(0, Math.min(1, vol));
    this.init();
    this.updateGainNodes();
  }

  public setMuted(muted: boolean) {
    this.mutedVal = muted;
    this.init();
    this.updateGainNodes();
  }

  // --- Sound Effects Synthesizers ---

  public playSFX(type: "pickup" | "talk" | "success" | "sting" | "click") {
    this.init();
    if (!this.ctx || this.ctx.state === "suspended") return;
    
    const now = this.ctx.currentTime;
    
    if (type === "pickup") {
      // Golden pop/chime: fast sweep from 480Hz to 1200Hz
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      
      osc.type = "sine";
      osc.frequency.setValueAtTime(480, now);
      osc.frequency.exponentialRampToValueAtTime(1200, now + 0.12);
      
      gain.gain.setValueAtTime(0.3, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
      
      osc.connect(gain);
      gain.connect(this.sfxGain!);
      
      osc.start(now);
      osc.stop(now + 0.15);
    } 
    else if (type === "talk") {
      // Synthesized cat meow! (M-E-O-W frequency and filter formant sweeps)
      const osc1 = this.ctx.createOscillator();
      const osc2 = this.ctx.createOscillator();
      const filter = this.ctx.createBiquadFilter();
      const gain = this.ctx.createGain();

      osc1.type = "triangle";
      osc2.type = "sawtooth";

      // Meow pitch curve (Mee-oww)
      osc1.frequency.setValueAtTime(320, now);
      osc1.frequency.linearRampToValueAtTime(560, now + 0.08);
      osc1.frequency.exponentialRampToValueAtTime(380, now + 0.28);

      osc2.frequency.setValueAtTime(320, now);
      osc2.frequency.linearRampToValueAtTime(560, now + 0.08);
      osc2.frequency.exponentialRampToValueAtTime(380, now + 0.28);

      // Lowpass sweeps downwards to create mouth-closing "oww" effect
      filter.type = "lowpass";
      filter.frequency.setValueAtTime(1500, now);
      filter.frequency.exponentialRampToValueAtTime(300, now + 0.28);
      filter.Q.setValueAtTime(6, now);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.linearRampToValueAtTime(0.2, now + 0.05); // Attack
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.3); // Decay

      osc1.connect(filter);
      osc2.connect(filter);
      filter.connect(gain);
      gain.connect(this.sfxGain!);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.3);
      osc2.stop(now + 0.3);
    } 
    else if (type === "success") {
      // Major Chord Chime: C4 -> E4 -> G4 -> C5
      const notes = [261.63, 329.63, 392.00, 523.25];
      notes.forEach((freq, idx) => {
        const timeOffset = idx * 0.08;
        const osc = this.ctx!.createOscillator();
        const gain = this.ctx!.createGain();

        osc.type = "sine";
        osc.frequency.setValueAtTime(freq, now + timeOffset);
        
        gain.gain.setValueAtTime(0.001, now + timeOffset);
        gain.gain.linearRampToValueAtTime(0.18, now + timeOffset + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, now + timeOffset + 0.45);

        osc.connect(gain);
        gain.connect(this.sfxGain!);

        osc.start(now + timeOffset);
        osc.stop(now + timeOffset + 0.5);
      });
    } 
    else if (type === "sting") {
      // discordant bee sting: minor-second clash + white noise pop
      const osc1 = this.ctx.createOscillator();
      const osc2 = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc1.type = "sawtooth";
      osc2.type = "sawtooth";
      
      osc1.frequency.setValueAtTime(110, now);
      osc1.frequency.linearRampToValueAtTime(80, now + 0.3);
      
      osc2.frequency.setValueAtTime(115, now);
      osc2.frequency.linearRampToValueAtTime(85, now + 0.3);

      gain.gain.setValueAtTime(0.4, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(this.sfxGain!);

      osc1.start(now);
      osc2.start(now);
      
      osc1.stop(now + 0.4);
      osc2.stop(now + 0.4);
    }
    else if (type === "click") {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(800, now);
      osc.frequency.exponentialRampToValueAtTime(200, now + 0.05);
      
      gain.gain.setValueAtTime(0.15, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);

      osc.connect(gain);
      gain.connect(this.sfxGain!);
      osc.start(now);
      osc.stop(now + 0.05);
    }
  }

  // --- Bee Buzz Ambient Warning ---

  private startBeeBuzzLoop() {
    if (!this.ctx || this.beeOsc) return;

    const now = this.ctx.currentTime;
    this.beeOsc = this.ctx.createOscillator();
    
    // Buzz wave
    this.beeOsc.type = "sawtooth";
    this.beeOsc.frequency.setValueAtTime(130, now);

    // LFO vibrato to simulate flapping wings
    const lfo = this.ctx.createOscillator();
    const lfoGain = this.ctx.createGain();
    
    lfo.frequency.setValueAtTime(18, now); // 18Hz flap rate
    lfoGain.gain.setValueAtTime(8, now);   // Pitch drift range

    lfo.connect(lfoGain);
    lfoGain.connect(this.beeOsc.frequency);
    
    this.beeGain!.gain.setValueAtTime(0, now); // start quiet
    this.beeOsc.connect(this.beeGain!);
    
    lfo.start(now);
    this.beeOsc.start(now);
  }

  public updateBeeWarning(distance: number, radius = 280) {
    this.init();
    if (!this.ctx || !this.beeGain) return;

    const maxVolume = 0.35;
    let volume = 0;
    
    if (distance < radius) {
      // Volume scales quadratically closer to bee
      const ratio = 1 - (distance / radius);
      volume = ratio * ratio * maxVolume;
    }

    const now = this.ctx.currentTime;
    this.beeGain.gain.setTargetAtTime(volume, now, 0.1);
  }

  // --- Procedural BGM Generation ---

  public playBGM(levelId: string) {
    this.init();
    if (this.currentBgmLevel === levelId) return;

    this.stopBGM();
    this.currentBgmLevel = levelId;
    if (!this.ctx || this.ctx.state === "suspended") return;

    const scheduleNextChord = () => {
      if (this.currentBgmLevel !== levelId) return;
      this.playProceduralBgmChord(levelId);
      
      // Cozy slow rhythm: play chord every 4.5 seconds
      this.bgmIntervalId = setTimeout(scheduleNextChord, 4500);
    };
    
    scheduleNextChord();
  }

  public stopBGM() {
    if (this.bgmIntervalId) {
      clearTimeout(this.bgmIntervalId);
      this.bgmIntervalId = null;
    }
    this.currentBgmLevel = null;
    
    // Fade out running active oscillators
    if (this.ctx) {
      const now = this.ctx.currentTime;
      this.activeOscillators.forEach((osc) => {
        try {
          osc.frequency.cancelScheduledValues(now);
        } catch(e){}
      });
      this.activeOscillators.clear();
    }
  }

  private playProceduralBgmChord(levelId: string) {
    if (!this.ctx || !this.bgmGain) return;
    const now = this.ctx.currentTime;

    let chords: number[][] = [];
    let oscType: OscillatorType = "sine";
    let attack = 0.8;
    let decay = 3.5;
    let volumeMul = 0.15;

    if (levelId === "1") {
      // SALON: Cozy warm Major chords (Cmaj7, Fmaj7, G6)
      chords = [
        [130.81, 164.81, 196.00, 246.94], // Cmaj7 (C3, E3, G3, B3)
        [174.61, 220.00, 261.63, 329.63], // Fmaj7 (F3, A3, C4, E4)
        [196.00, 246.94, 293.66, 392.00], // G6 (G3, B3, D4, G4)
      ];
      oscType = "triangle";
      attack = 1.0;
      decay = 3.0;
      volumeMul = 0.22;
    } 
    else if (levelId === "2") {
      // OGROD: Bright plucks (C major / A pentatonic style)
      chords = [
        [130.81, 261.63, 329.63, 440.00], // C6 (C3, C4, E4, A4)
        [146.83, 293.66, 392.00, 493.88], // Gsus4 (D3, D4, G4, B4)
        [110.00, 220.00, 329.63, 440.00], // Amin7 (A2, A3, E4, A4)
      ];
      oscType = "sine";
      attack = 0.2; // faster plucks
      decay = 2.5;
      volumeMul = 0.25;

      // Add a tiny random melody chime note
      setTimeout(() => {
        if (this.currentBgmLevel === "2" && Math.random() > 0.3) {
          const melodyFreqs = [523.25, 587.33, 659.25, 783.99, 880.00];
          const melodyNote = melodyFreqs[Math.floor(Math.random() * melodyFreqs.length)];
          this.playSingleChime(melodyNote, 0.12, 1.2, "sine");
        }
      }, 1500);
    } 
    else if (levelId === "3") {
      // STRYCH: Mysterious low minor drone (Amin9, Dmin6, E7sus4)
      chords = [
        [110.00, 164.81, 220.00, 293.66], // Amin11 (A2, E3, A3, D4)
        [146.83, 196.00, 246.94, 311.13], // Dmin6-ish (D3, G3, B3, Eb4)
        [82.41, 164.81, 220.00, 293.66],   // Esus4 (E2, E3, A3, D4)
      ];
      oscType = "sawtooth"; // deep analog pad feel
      attack = 1.8; // extremely slow swell
      decay = 4.2;
      volumeMul = 0.08; // very quiet since sawtooth is buzzy
    } 
    else if (levelId === "4") {
      // DACH: Dreamy high synth sparkles / Lydian spaces
      chords = [
        [164.81, 246.94, 369.99, 493.88], // Eadd9 (E3, B3, F#4, B4)
        [185.00, 277.18, 415.30, 554.37], // F#add9 (F#3, C#4, G#4, C#5)
        [220.00, 329.63, 440.00, 587.33], // Aadd9 (A3, E4, A4, D#5) Lydian
      ];
      oscType = "triangle";
      attack = 1.4;
      decay = 4.5;
      volumeMul = 0.14;

      // Sparkling high star sparkles
      for (let i = 0; i < 3; i++) {
        setTimeout(() => {
          if (this.currentBgmLevel === "4" && Math.random() > 0.25) {
            const highFreq = 1000 + Math.random() * 2000;
            this.playSingleChime(highFreq, 0.06, 2.0, "sine");
          }
        }, 1000 + i * 1200);
      }
    }

    if (chords.length === 0) return;

    // Pick a random chord from level bank
    const chord = chords[Math.floor(Math.random() * chords.length)];
    
    // Play notes in unison
    chord.forEach((freq) => {
      const osc = this.ctx!.createOscillator();
      const gain = this.ctx!.createGain();
      const filter = this.ctx!.createBiquadFilter();

      osc.type = oscType;
      osc.frequency.setValueAtTime(freq, now);

      // Add a bit of detune for warm analog thickness
      osc.detune.setValueAtTime((Math.random() - 0.5) * 8, now);

      // Lowpass filter for cozy pads
      filter.type = "lowpass";
      filter.frequency.setValueAtTime(oscType === "sawtooth" ? 380 : 800, now);

      // Envelope
      gain.gain.setValueAtTime(0.001, now);
      gain.gain.linearRampToValueAtTime(volumeMul / chord.length, now + attack);
      gain.gain.exponentialRampToValueAtTime(0.001, now + attack + decay);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(this.bgmGain!);

      osc.start(now);
      this.activeOscillators.add(osc);
      
      osc.stop(now + attack + decay + 0.5);
      setTimeout(() => this.activeOscillators.delete(osc), (attack + decay + 1) * 1000);
    });
  }

  private playSingleChime(freq: number, attack: number, decay: number, type: OscillatorType) {
    if (!this.ctx || !this.bgmGain) return;
    const now = this.ctx.currentTime;
    
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);

    gain.gain.setValueAtTime(0.001, now);
    gain.gain.linearRampToValueAtTime(0.04, now + attack);
    gain.gain.exponentialRampToValueAtTime(0.001, now + attack + decay);

    osc.connect(gain);
    gain.connect(this.bgmGain);

    osc.start(now);
    this.activeOscillators.add(osc);
    osc.stop(now + attack + decay + 0.2);
    setTimeout(() => this.activeOscillators.delete(osc), (attack + decay + 0.5) * 1000);
  }
}

export const soundManager = new SoundManager();
