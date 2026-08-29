import type { Rect } from "./types";

/**
 * Pooled particle system.
 *
 * Everything is pre-allocated: `update`/`spawn` never allocate, so the render
 * loop produces no garbage. Ambient spawn rates are expressed per second and
 * integrated with dt, so density does not change with frame rate.
 */

export type AmbientFx = "motes" | "petals" | "dust" | "stars";

/** Drawn under the cat (ground contact) or over it (airborne). */
type Layer = "ground" | "air";

interface Particle {
  active: boolean;
  layer: Layer;
  x: number;
  y: number;
  vx: number;
  vy: number;
  /** seconds alive / lifetime */
  life: number;
  max: number;
  size: number;
  /** radians */
  rot: number;
  vrot: number;
  /** horizontal drift wobble */
  sway: number;
  swaySpeed: number;
  alpha: number;
  color: string;
  shape: "circle" | "petal" | "spark" | "star";
  gravity: number;
  drag: number;
}

const POOL_SIZE = 420;

/** Per-second spawn rates for each ambient style. */
const AMBIENT_RATE: Record<AmbientFx, number> = {
  motes: 9,
  petals: 5,
  dust: 7,
  stars: 3,
};

function makeParticle(): Particle {
  return {
    active: false,
    layer: "air",
    x: 0, y: 0, vx: 0, vy: 0,
    life: 0, max: 1,
    size: 2,
    rot: 0, vrot: 0,
    sway: 0, swaySpeed: 0,
    alpha: 1,
    color: "#fff",
    shape: "circle",
    gravity: 0,
    drag: 0,
  };
}

export class Particles {
  private pool: Particle[] = Array.from({ length: POOL_SIZE }, makeParticle);
  /** Round-robin cursor so a full pool recycles the oldest slots instead of stalling. */
  private cursor = 0;
  private ambientAcc = 0;

  clear() {
    for (const p of this.pool) p.active = false;
    this.ambientAcc = 0;
  }

  private take(): Particle {
    // Prefer a free slot; fall back to overwriting the next one in rotation.
    for (let i = 0; i < POOL_SIZE; i++) {
      const p = this.pool[this.cursor];
      this.cursor = (this.cursor + 1) % POOL_SIZE;
      if (!p.active) return p;
    }
    const p = this.pool[this.cursor];
    this.cursor = (this.cursor + 1) % POOL_SIZE;
    return p;
  }

  /** Puff of dust kicked up by running paws. */
  spawnFootDust(x: number, y: number) {
    const p = this.take();
    p.active = true;
    p.layer = "ground";
    p.x = x + (Math.random() - 0.5) * 14;
    p.y = y;
    p.vx = (Math.random() - 0.5) * 26;
    p.vy = -8 - Math.random() * 14;
    p.life = 0;
    p.max = 0.45 + Math.random() * 0.2;
    p.size = 4 + Math.random() * 4;
    p.rot = 0; p.vrot = 0;
    p.sway = 0; p.swaySpeed = 0;
    p.alpha = 0.5;
    p.color = "#d6c9b8";
    p.shape = "circle";
    p.gravity = 0;
    p.drag = 1.8;
  }

  /** Golden sparkle burst when an item is picked up. */
  burstPickup(x: number, y: number) {
    for (let i = 0; i < 16; i++) {
      const p = this.take();
      const a = (Math.PI * 2 * i) / 16 + Math.random() * 0.3;
      const speed = 70 + Math.random() * 90;
      p.active = true;
      p.layer = "air";
      p.x = x; p.y = y;
      p.vx = Math.cos(a) * speed;
      p.vy = Math.sin(a) * speed - 40;
      p.life = 0;
      p.max = 0.55 + Math.random() * 0.35;
      p.size = 2 + Math.random() * 3;
      p.rot = Math.random() * Math.PI;
      p.vrot = (Math.random() - 0.5) * 10;
      p.sway = 0; p.swaySpeed = 0;
      p.alpha = 1;
      p.color = i % 3 === 0 ? "#fff4c2" : i % 3 === 1 ? "#ffd76b" : "#ffb03a";
      p.shape = "spark";
      p.gravity = 190;
      p.drag = 1.1;
    }
  }

  /** Sharp red flick when the cat takes damage. */
  burstSting(x: number, y: number) {
    for (let i = 0; i < 12; i++) {
      const p = this.take();
      const a = Math.random() * Math.PI * 2;
      const speed = 90 + Math.random() * 110;
      p.active = true;
      p.layer = "air";
      p.x = x; p.y = y;
      p.vx = Math.cos(a) * speed;
      p.vy = Math.sin(a) * speed;
      p.life = 0;
      p.max = 0.35 + Math.random() * 0.25;
      p.size = 2 + Math.random() * 2.5;
      p.rot = a;
      p.vrot = 0;
      p.sway = 0; p.swaySpeed = 0;
      p.alpha = 1;
      p.color = i % 2 === 0 ? "#ff8a5b" : "#ffd0b0";
      p.shape = "spark";
      p.gravity = 60;
      p.drag = 2.4;
    }
  }

  /** Spawn one ambient particle somewhere inside the visible area. */
  private spawnAmbient(fx: AmbientFx, view: Rect) {
    const p = this.take();
    p.active = true;
    p.layer = "air";
    p.life = 0;
    p.gravity = 0;
    p.rot = Math.random() * Math.PI * 2;
    p.sway = Math.random() * Math.PI * 2;
    // Enter from just above the view so particles drift in rather than pop in.
    p.x = view.x + Math.random() * view.w;
    p.y = view.y - 20 + Math.random() * view.h;

    switch (fx) {
      case "motes": // slow dust motes catching the light
        p.vx = 6 + Math.random() * 10;
        p.vy = 4 + Math.random() * 8;
        p.max = 6 + Math.random() * 4;
        p.size = 1.2 + Math.random() * 1.8;
        p.alpha = 0.35;
        p.color = "#ffe9b8";
        p.shape = "circle";
        p.vrot = 0;
        p.swaySpeed = 0.5 + Math.random() * 0.6;
        p.drag = 0;
        break;
      case "petals": // blossom drifting on a breeze
        p.vx = 18 + Math.random() * 26;
        p.vy = 16 + Math.random() * 20;
        p.max = 5 + Math.random() * 3;
        p.size = 3 + Math.random() * 3;
        p.alpha = 0.75;
        p.color = Math.random() < 0.5 ? "#ffc9dd" : "#fff0f5";
        p.shape = "petal";
        p.vrot = (Math.random() - 0.5) * 3;
        p.swaySpeed = 1.1 + Math.random() * 0.8;
        p.drag = 0;
        break;
      case "dust": // heavier attic dust falling straight down
        p.vx = (Math.random() - 0.5) * 6;
        p.vy = 10 + Math.random() * 14;
        p.max = 5 + Math.random() * 3;
        p.size = 1 + Math.random() * 1.6;
        p.alpha = 0.3;
        p.color = "#cfc3ae";
        p.shape = "circle";
        p.vrot = 0;
        p.swaySpeed = 0.35 + Math.random() * 0.4;
        p.drag = 0;
        break;
      case "stars": // slow twinkling night sparks
        p.vx = (Math.random() - 0.5) * 5;
        p.vy = -3 - Math.random() * 6;
        p.max = 4 + Math.random() * 3;
        p.size = 1.4 + Math.random() * 2;
        p.alpha = 0.9;
        p.color = Math.random() < 0.3 ? "#bcd6ff" : "#ffffff";
        p.shape = "star";
        p.vrot = 0.4 + Math.random();
        p.swaySpeed = 0.6 + Math.random() * 0.5;
        p.drag = 0;
        break;
    }
  }

  /**
   * Integrate every live particle and top up ambient density.
   * `view` is the visible world rect, used to seed and cull ambient particles.
   */
  update(dt: number, fx: AmbientFx | undefined, view: Rect) {
    if (fx) {
      this.ambientAcc += AMBIENT_RATE[fx] * dt;
      while (this.ambientAcc >= 1) {
        this.ambientAcc -= 1;
        this.spawnAmbient(fx, view);
      }
    }

    const cullPad = 160;
    for (const p of this.pool) {
      if (!p.active) continue;
      p.life += dt;
      if (p.life >= p.max) { p.active = false; continue; }

      if (p.drag > 0) {
        const d = Math.max(0, 1 - p.drag * dt);
        p.vx *= d;
        p.vy *= d;
      }
      if (p.gravity) p.vy += p.gravity * dt;
      if (p.swaySpeed) {
        p.sway += p.swaySpeed * dt;
        p.x += Math.sin(p.sway) * 14 * dt;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vrot * dt;

      // Ambient particles that drift far outside the view are recycled early.
      if (
        p.x < view.x - cullPad || p.x > view.x + view.w + cullPad ||
        p.y < view.y - cullPad || p.y > view.y + view.h + cullPad
      ) {
        p.active = false;
      }
    }
  }

  /** Draw one layer. Call with "ground" before the cat and "air" after. */
  draw(ctx: CanvasRenderingContext2D, layer: Layer) {
    for (const p of this.pool) {
      if (!p.active || p.layer !== layer) continue;
      const t = p.life / p.max;
      // Ease in briefly, then fade out — avoids particles blinking into existence.
      const fade = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85;
      const a = p.alpha * Math.max(0, fade);
      if (a <= 0.01) continue;

      ctx.save();
      ctx.globalAlpha = a;
      ctx.fillStyle = p.color;
      ctx.translate(p.x, p.y);

      switch (p.shape) {
        case "circle":
          ctx.beginPath();
          ctx.arc(0, 0, p.size * (1 + t * 0.6), 0, Math.PI * 2);
          ctx.fill();
          break;
        case "spark":
          ctx.rotate(p.rot);
          ctx.fillRect(-p.size, -p.size * 0.35, p.size * 2, p.size * 0.7);
          break;
        case "petal":
          ctx.rotate(p.rot);
          ctx.beginPath();
          ctx.ellipse(0, 0, p.size, p.size * 0.55, 0, 0, Math.PI * 2);
          ctx.fill();
          break;
        case "star": {
          // Four-point twinkle: two crossed slivers, scaled by a sine so it pulses.
          const s = p.size * (0.7 + 0.5 * Math.abs(Math.sin(p.rot)));
          ctx.beginPath();
          ctx.moveTo(0, -s * 2.2); ctx.lineTo(s * 0.5, 0);
          ctx.lineTo(0, s * 2.2); ctx.lineTo(-s * 0.5, 0);
          ctx.closePath();
          ctx.fill();
          ctx.beginPath();
          ctx.moveTo(-s * 2.2, 0); ctx.lineTo(0, s * 0.5);
          ctx.lineTo(s * 2.2, 0); ctx.lineTo(0, -s * 0.5);
          ctx.closePath();
          ctx.fill();
          break;
        }
      }
      ctx.restore();
    }
  }
}
