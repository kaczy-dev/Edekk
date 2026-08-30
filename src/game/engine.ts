import type { LevelDef, LevelObject, Rect, Vec2 } from "./types";
import { InputState } from "./input";
import { Particles } from "./particles";
import { ITEMS } from "./items";
import { DIFFICULTIES, type Difficulty, type DifficultyConfig } from "@/store/gameStore";

const CAT_SIZE = 64;
const WALK_SPEED = 230; // px/sec
const RUN_SPEED = 380;
const ACCEL = 2200;     // snappier start
const FRICTION = 2400;  // crisp stop
const INTERACT_RADIUS = 100;
const SPRINT_DRAIN = 6;   // energy/sec while sprinting (base, scaled by difficulty)
const REST_RECOVER = 4;   // energy/sec while not sprinting (base, scaled by difficulty)

function rectsOverlap(a: Rect, b: Rect) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function dist(a: Vec2, b: Vec2) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

/** Compass direction the cat is drawn facing; indexes rows in the sprite sheet. */
export type Direction = "down" | "left" | "right" | "up";

/**
 * Bucket a facing angle (radians, 0 = up per `facingAngle`'s convention) into
 * one of 4 compass directions. A hysteresis band biased toward the current
 * direction stops the sprite flickering when movement sits near a boundary
 * (e.g. a diagonal drifting across the up/right split).
 */
function resolveDirection(angle: number, current: Direction): Direction {
  let a = angle % (Math.PI * 2);
  if (a < 0) a += Math.PI * 2;
  const HYST = (12 * Math.PI) / 180;
  const centers: Array<{ dir: Direction; center: number }> = [
    { dir: "up", center: 0 },
    { dir: "right", center: Math.PI / 2 },
    { dir: "down", center: Math.PI },
    { dir: "left", center: (3 * Math.PI) / 2 },
  ];
  let best: Direction = current;
  let bestDiff = Infinity;
  for (const c of centers) {
    let diff = Math.abs(a - c.center);
    if (diff > Math.PI) diff = Math.PI * 2 - diff;
    const adjusted = c.dir === current ? diff - HYST : diff;
    if (adjusted < bestDiff) { bestDiff = adjusted; best = c.dir; }
  }
  return best;
}

/** Maps walk-cycle phase to one of 3 sheet columns (contact–pass–contact). Idle holds the passing frame. */
function walkFrameIndex(phase: number, moving: boolean): 0 | 1 | 2 {
  if (!moving) return 1;
  const t = ((phase % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
  if (t < (Math.PI * 2) / 3) return 0;
  if (t < (Math.PI * 4) / 3) return 1;
  return 2;
}

export type EngineEvents = {
  onPickUp: (obj: LevelObject) => void;
  onTalk: (obj: LevelObject) => void;
  onGoal: (obj: LevelObject) => void;
  onDanger: (obj: LevelObject) => void;
  onMove: (pos: Vec2) => void;
  onNearby: (obj: LevelObject | null) => void;
  /** energy delta per second; engine handles drain/recover */
  onEnergyDelta: (delta: number) => void;
  onSprintState?: (sprinting: boolean) => void;
};

export class GameEngine {
  pos: Vec2;
  vel: Vec2 = { x: 0, y: 0 };
  /** target facing angle in radians (sprite faces up = 0) */
  facingAngle = Math.PI; // start facing down
  /** compass direction bucketed from facingAngle; selects the sprite sheet row */
  direction: Direction = "down";
  moving = false;
  sprinting = false;
  /** 0 = idle, 1 = walk, 2 = run */
  gait: 0 | 1 | 2 = 0;
  /** blends 0..1 toward gait, drives anim amplitudes */
  walkBlend = 0;
  runBlend = 0;
  /** 0..1 exhaustion blend (energy under sprint threshold) */
  exhaustBlend = 0;
  walkPhase = 0;
  input = new InputState();
  catImg: HTMLImageElement;
  bgImg: HTMLImageElement;
  level: LevelDef;
  events: EngineEvents;
  rafId = 0;
  lastTs = 0;
  paused = false;
  dangerCooldown = 0;
  collectedThisRun = new Set<string>();
  private lastNearbyId: string | null = null;
  private lastSprinting = false;
  cam: Vec2 = { x: 0, y: 0 };
  private camLead: Vec2 = { x: 0, y: 0 };
  private camInit = false;
  zoom = 1;
  readonly particles = new Particles();
  private dustTimer = 0;
  /** Visible world rect, refreshed each render and reused by the particle system. */
  private view: Rect = { x: 0, y: 0, w: 0, h: 0 };
  /** Decaying screen-shake magnitude in world px. */
  private shake = 0;
  /**
   * The sprite sheet (3 walk-cycle columns × 4 direction rows) is resampled
   * once per direction/frame into small canvases and blitted from there —
   * see the single-sprite bake this replaced for why per-frame resampling
   * is the one thing to avoid.
   */
  private catFrameAtlas: Record<Direction, HTMLCanvasElement[]> | null = null;
  /** Supersample factor: covers max zoom (2.2) x devicePixelRatio (2). */
  private static readonly CAT_CACHE_SS = 4;
  /** mirror of energy from store, set externally */
  energy = 100;
  /** difficulty tunables, set externally */
  difficulty: Difficulty = "medium";

  constructor(level: LevelDef, catImg: HTMLImageElement, bgImg: HTMLImageElement, events: EngineEvents) {
    this.level = level;
    this.catImg = catImg;
    this.bgImg = bgImg;
    this.events = events;
    this.lightDir =
      level.ambient === "night" ? { x: 0.18, y: 0.42 }   // moon, high and slightly right
      : level.ambient === "dim" ? { x: 0.34, y: 0.58 }   // one narrow attic window
      : { x: -0.42, y: 0.55 };                           // afternoon sun from the left
    this.pos = { ...level.spawn };
    // Safety: nudge spawn out of any overlapping obstacle.
    if (this.collidesObstacle(this.pos)) {
      const step = 12;
      outer: for (let r = step; r < 600; r += step) {
        for (let a = 0; a < Math.PI * 2; a += Math.PI / 8) {
          const p = { x: level.spawn.x + Math.cos(a) * r, y: level.spawn.y + Math.sin(a) * r };
          if (!this.collidesObstacle(p)) { this.pos = p; break outer; }
        }
      }
    }
  }

  start(ctx: CanvasRenderingContext2D) {
    this.input.attach();
    const loop = (ts: number) => {
      if (!this.lastTs) this.lastTs = ts;
      const dt = Math.min(0.05, (ts - this.lastTs) / 1000);
      this.lastTs = ts;
      if (!this.paused) this.update(dt);
      this.render(ctx);
      this.rafId = requestAnimationFrame(loop);
    };
    this.rafId = requestAnimationFrame(loop);
  }

  stop() {
    cancelAnimationFrame(this.rafId);
    this.input.detach();
  }

  markCollected(ids: string[]) {
    ids.forEach((id) => this.collectedThisRun.add(id));
  }

  private catRect(): Rect {
    return { x: this.pos.x - CAT_SIZE / 2, y: this.pos.y - CAT_SIZE / 2, w: CAT_SIZE, h: CAT_SIZE };
  }

  private collidesObstacle(next: Vec2): boolean {
    const r: Rect = { x: next.x - CAT_SIZE / 2 + 10, y: next.y - CAT_SIZE / 2 + 20, w: CAT_SIZE - 20, h: CAT_SIZE - 30 };
    for (const o of this.level.objects) {
      if (o.kind === "obstacle" && rectsOverlap(r, o.rect)) return true;
    }
    if (next.x < 20 || next.x > this.level.width - 20) return true;
    if (next.y < 20 || next.y > this.level.height - 20) return true;
    return false;
  }

  private findNearestInteractable(): LevelObject | null {
    let best: LevelObject | null = null;
    let bestD = INTERACT_RADIUS;
    for (const o of this.level.objects) {
      if (o.kind !== "npc" && o.kind !== "goal") continue;
      const center = { x: o.rect.x + o.rect.w / 2, y: o.rect.y + o.rect.h / 2 };
      const d = dist(this.pos, center);
      if (d < bestD) { bestD = d; best = o; }
    }
    return best;
  }

  private update(dt: number) {
    const diff: DifficultyConfig = DIFFICULTIES[this.difficulty];
    const sensitivity = Math.max(0.5, Math.min(1.5, this.input.settings.sensitivity));
    const dir = this.input.getDirection();
    const wantsSprint = this.input.isSprinting() && (dir.x !== 0 || dir.y !== 0);
    const canSprint = this.energy > diff.minSprintEnergy;
    this.sprinting = wantsSprint && canSprint;

    if (this.sprinting !== this.lastSprinting) {
      this.lastSprinting = this.sprinting;
      this.events.onSprintState?.(this.sprinting);
    }

    const maxSpeed = (this.sprinting ? RUN_SPEED : WALK_SPEED) * sensitivity;

    const targetVx = dir.x * maxSpeed;
    const targetVy = dir.y * maxSpeed;

    const ax = dir.x !== 0 ? ACCEL : FRICTION;
    const ay = dir.y !== 0 ? ACCEL : FRICTION;
    this.vel.x += Math.max(-ax * dt, Math.min(ax * dt, targetVx - this.vel.x));
    this.vel.y += Math.max(-ay * dt, Math.min(ay * dt, targetVy - this.vel.y));

    const speed = Math.hypot(this.vel.x, this.vel.y);
    this.moving = speed > 8;

    // --- Facing: target angle from velocity; sprite faces UP at angle 0 ---
    if (speed > 30) {
      // atan2 gives angle from +X axis; sprite "up" is -Y, so add PI/2
      this.facingAngle = Math.atan2(this.vel.y, this.vel.x) + Math.PI / 2;
      this.direction = resolveDirection(this.facingAngle, this.direction);
    }

    // --- Gait classification + smooth blends ---
    const walkThresh = WALK_SPEED * 0.4;
    const runThresh = WALK_SPEED * 1.1;
    let targetGait: 0 | 1 | 2 = 0;
    if (this.sprinting && speed > runThresh) targetGait = 2;
    else if (speed > walkThresh) targetGait = 1;
    else if (speed > 20) targetGait = 1;
    this.gait = targetGait;

    const targetWalk = targetGait >= 1 ? 1 : 0;
    const targetRun = targetGait === 2 ? 1 : 0;
    const blendRate = 6; // per second
    this.walkBlend += Math.max(-blendRate * dt, Math.min(blendRate * dt, targetWalk - this.walkBlend));
    this.runBlend += Math.max(-blendRate * dt, Math.min(blendRate * dt, targetRun - this.runBlend));

    // walk cycle phase: faster as we run, near-zero at idle
    const cycleHz = 0 + this.walkBlend * 9 + this.runBlend * 7; // walk ~9Hz, run ~16Hz
    this.walkPhase += dt * Math.max(2, cycleHz);

    // Exhaustion blend — pod progiem biegu kot dyszy, mocniejszy bob.
    const exhaustTarget = this.energy < diff.minSprintEnergy ? 1 : 0;
    this.exhaustBlend += Math.max(-3 * dt, Math.min(3 * dt, exhaustTarget - this.exhaustBlend));

    // stamina (difficulty-scaled)
    const energyDelta = this.sprinting
      ? -SPRINT_DRAIN * diff.sprintDrainMul * dt
      : REST_RECOVER * diff.restRecoverMul * dt;
    this.events.onEnergyDelta(energyDelta);

    // sliding collisions
    const nx = { x: this.pos.x + this.vel.x * dt, y: this.pos.y };
    if (!this.collidesObstacle(nx)) this.pos.x = nx.x; else this.vel.x = 0;
    const ny = { x: this.pos.x, y: this.pos.y + this.vel.y * dt };
    if (!this.collidesObstacle(ny)) this.pos.y = ny.y; else this.vel.y = 0;
    if (this.moving) this.events.onMove(this.pos);

    // Paw dust while sprinting.
    if (this.sprinting && this.moving) {
      this.dustTimer -= dt;
      if (this.dustTimer <= 0) {
        this.dustTimer = 0.06;
        this.particles.spawnFootDust(this.pos.x, this.pos.y + CAT_SIZE / 2 - 6);
      }
    }
    // Ambient drift is decorative motion; event bursts stay so feedback is not lost.
    const ambientFx = this.input.settings.reducedMotion ? undefined : this.level.ambientFx;
    this.particles.update(dt, ambientFx, this.view);

    // Screen shake decays exponentially back to rest.
    if (this.shake > 0.01) this.shake *= Math.max(0, 1 - 9 * dt);
    else this.shake = 0;

    this.dangerCooldown = Math.max(0, this.dangerCooldown - dt);

    const cr = this.catRect();
    for (const o of this.level.objects) {
      if (o.kind === "item" && o.itemId && !this.collectedThisRun.has(o.id) && rectsOverlap(cr, o.rect)) {
        this.collectedThisRun.add(o.id);
        this.particles.burstPickup(o.rect.x + o.rect.w / 2, o.rect.y + o.rect.h / 2);
        this.events.onPickUp(o);
      }
      if (o.kind === "trigger" && o.danger && rectsOverlap(cr, o.rect) && this.dangerCooldown === 0) {
        this.dangerCooldown = 1.2;
        this.particles.burstSting(this.pos.x, this.pos.y);
        // Camera shake is exactly the kind of motion reduced-motion users opt out of.
        if (!this.input.settings.reducedMotion) this.shake = 9;
        this.events.onDanger(o);
      }
    }

    const nearest = this.findNearestInteractable();
    const nearId = nearest?.id ?? null;
    if (nearId !== this.lastNearbyId) {
      this.lastNearbyId = nearId;
      this.events.onNearby(nearest);
    }

    if (this.input.consumeInteract() && nearest) {
      if (nearest.kind === "npc") this.events.onTalk(nearest);
      else this.events.onGoal(nearest);
    }
  }

  private computeZoom(cw: number, ch: number): number {
    // Base zoom: keep the cat at a comfortable on-screen size across devices.
    // We pick a target view width (in world px) based on the shorter screen edge,
    // then derive zoom = canvas / view. Clamp so the camera never reveals out-of-bounds.
    const shortEdge = Math.min(cw, ch);
    // Smaller screens => smaller view (more zoom). Phones ~520 world px wide view.
    let targetViewW: number;
    if (shortEdge < 380) targetViewW = 480;
    else if (shortEdge < 520) targetViewW = 560;
    else if (shortEdge < 720) targetViewW = 680;
    else if (shortEdge < 1080) targetViewW = 880;
    else targetViewW = 1100;

    let zoom = cw / targetViewW;

    // Safety: do not zoom out beyond level bounds (would reveal black bars / OOB).
    const minZoomW = cw / this.level.width;
    const minZoomH = ch / this.level.height;
    const minZoom = Math.max(minZoomW, minZoomH);

    // Sensible absolute clamps so things never get ridiculous.
    zoom = Math.max(minZoom, Math.min(2.2, zoom));
    return zoom;
  }

  private render(ctx: CanvasRenderingContext2D) {
    const canvas = ctx.canvas;
    const dpr = window.devicePixelRatio || 1;
    const cw = canvas.width / dpr;
    const ch = canvas.height / dpr;

    // --- Responsive, bounds-safe zoom ---
    const targetZoom = this.computeZoom(cw, ch);
    // Smooth zoom changes (e.g. on rotate/resize) to avoid pops.
    this.zoom += (targetZoom - this.zoom) * (this.zoom === 0 ? 1 : 0.12);
    if (!this.camInit) this.zoom = targetZoom;
    const zoom = this.zoom;

    // View size in world units
    const vw = cw / zoom;
    const vh = ch / zoom;

    // --- Camera: velocity look-ahead + dead-zone + smoothed follow ---
    const speed = Math.hypot(this.vel.x, this.vel.y);
    const maxLead = Math.min(vw, vh) * 0.18;
    const leadScale = speed > 0 ? Math.min(1, speed / RUN_SPEED) : 0;
    const leadTx = speed > 1 ? (this.vel.x / speed) * maxLead * leadScale : 0;
    const leadTy = speed > 1 ? (this.vel.y / speed) * maxLead * leadScale : 0;
    // Smooth the lead so it eases in/out of turns.
    this.camLead.x += (leadTx - this.camLead.x) * 0.08;
    this.camLead.y += (leadTy - this.camLead.y) * 0.08;

    let targetCamX = this.pos.x + this.camLead.x - vw / 2;
    let targetCamY = this.pos.y + this.camLead.y - vh / 2;
    // Clamp to level (vw/vh <= level dims is guaranteed by minZoom).
    targetCamX = Math.max(0, Math.min(this.level.width - vw, targetCamX));
    targetCamY = Math.max(0, Math.min(this.level.height - vh, targetCamY));

    if (!this.camInit) {
      this.cam.x = targetCamX; this.cam.y = targetCamY; this.camInit = true;
    } else {
      // Dead-zone: only pull camera when the cat drifts off-center.
      const dzX = vw * 0.06;
      const dzY = vh * 0.06;
      const dx = targetCamX - this.cam.x;
      const dy = targetCamY - this.cam.y;
      const followK = 0.14;
      if (Math.abs(dx) > dzX) this.cam.x += (dx - Math.sign(dx) * dzX) * followK;
      if (Math.abs(dy) > dzY) this.cam.y += (dy - Math.sign(dy) * dzY) * followK;
    }
    // Publish the visible rect so the particle system can seed and cull against it.
    this.view.x = this.cam.x;
    this.view.y = this.cam.y;
    this.view.w = vw;
    this.view.h = vh;

    // Subpixel-stable in world space; rounding in screen space below.
    let camX = this.cam.x;
    let camY = this.cam.y;
    if (this.shake > 0) {
      camX += (Math.random() - 0.5) * this.shake;
      camY += (Math.random() - 0.5) * this.shake;
    }

    // --- Background fill (screen space) ---
    ctx.fillStyle = "#1a1410";
    ctx.fillRect(0, 0, cw, ch);

    // --- World transform: scale by zoom, translate by camera ---
    ctx.save();
    ctx.scale(zoom, zoom);
    ctx.translate(-camX, -camY);

    if (this.bgImg.complete) {
      // "high" here costs a full-resolution resample of a 1920x1080 image every
      // frame; at this scale "low" is visually indistinguishable.
      ctx.imageSmoothingQuality = "low";
      ctx.drawImage(this.bgImg, 0, 0, this.level.width, this.level.height);
    }

    // Ground-contact particles sit beneath every actor.
    this.particles.draw(ctx, "ground");

    // cat — world space
    const eb = this.exhaustBlend;
    // Bob amplitude — bigger when running; when exhausted, extra heave.
    const bobAmp = 1.5 + this.walkBlend * 1.5 + this.runBlend * 2.5 + eb * 1.4;
    const bob = (this.walkBlend + this.runBlend) > 0.05 ? Math.sin(this.walkPhase) * bobAmp : 0;
    // Idle breath — slower when exhausted, deeper amplitude.
    const breathHz = eb > 0.05 ? 320 : 600;
    const breathAmp = 0.6 + eb * 1.0;
    const breath = Math.sin(performance.now() / breathHz) * breathAmp * (1 - this.walkBlend);

    // --- Depth pass: actors sorted by ground line, so the cat passes behind
    // things standing in front of it and in front of things behind it. ---
    this.collectActors();
    for (let i = 0; i < this.actorCount; i++) {
      const a = this.actors[i];
      if (!a.obj) {
        ctx.save();
        ctx.translate(this.pos.x, this.pos.y + bob + breath);
        this.drawShadow(ctx, CAT_SIZE / 2.2, 1 - Math.abs(bob) * 0.015, CAT_SIZE / 2 - 6);
        this.drawCat(ctx);
        // Subtle rim light in the direction opposite to the key light
        const rimLight = this.getLightSprite();
        if (rimLight) {
          const S = CAT_SIZE * 1.8;
          ctx.globalCompositeOperation = "lighter";
          ctx.globalAlpha = 0.08 * (1 + this.runBlend * 0.5);
          ctx.drawImage(rimLight, -S / 2 + this.lightDir.x * 20, -S / 2 + this.lightDir.y * 20, S, S);
          ctx.globalCompositeOperation = "source-over";
        }
        ctx.restore();
      } else {
        this.drawObject(ctx, a.obj, zoom);
      }
    }

    // speed lines (world space, behind cat in screen)
    if (this.sprinting && this.moving) {
      ctx.save();
      ctx.strokeStyle = "rgba(255,255,255,0.35)";
      ctx.lineWidth = 1.5 / zoom;
      const vx = this.vel.x; const vy = this.vel.y;
      const vlen = Math.hypot(vx, vy) || 1;
      const ux = vx / vlen; const uy = vy / vlen;
      for (let i = 0; i < 3; i++) {
        const off = (i - 1) * 10;
        const px = -uy * off;
        const py = ux * off;
        const sx = this.pos.x - ux * 18 + px;
        const sy = this.pos.y - uy * 18 + py;
        const ex = this.pos.x - ux * 36 + px;
        const ey = this.pos.y - uy * 36 + py;
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        ctx.lineTo(ex, ey);
        ctx.stroke();
      }
      ctx.restore();
    }

    // Airborne particles (ambient drift, sparkles) sit above the cat.
    this.particles.draw(ctx, "air");

    ctx.restore(); // end world transform

    // Ambient light pass (screen space). The camera keeps the cat near the centre,
    // so a canvas-centred vignette reads the same as a cat-centred one and can be
    // cached instead of rebuilt every frame.
    const grad = this.getVignette(ctx, cw, ch);
    if (grad) {
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, cw, ch);
    }

    // A soft light travelling with the cat, drawn after the vignette so it lifts
    // the scene back up around the player and gives the flat art some depth.
    const light = this.getLightSprite();
    if (light) {
      const catSX = (this.pos.x - camX) * zoom;
      const catSY = (this.pos.y - camY) * zoom;
      // Breathe gently, and flare while sprinting.
      const pulse = 1 + Math.sin(performance.now() / 900) * 0.03 + this.runBlend * 0.12;
      const r = 300 * zoom * pulse;
      ctx.save();
      ctx.globalCompositeOperation = "soft-light";
      ctx.globalAlpha = this.level.ambient === "day" ? 0.75 : 1;
      ctx.drawImage(light, catSX - r, catSY - r, r * 2, r * 2);
      ctx.restore();
    }

    // Fixed point light sources (e.g. fireplace flicker)
    if (this.level.pointLight) {
      const ptLight = this.getPointLightSprite();
      if (ptLight) {
        const px = (this.level.pointLight.x - camX) * zoom;
        const py = (this.level.pointLight.y - camY) * zoom;
        const baseR = 200 * zoom;
        const flicker = 1 + Math.sin(performance.now() / 200) * 0.25 + Math.random() * 0.1;
        const r = baseR * flicker * this.level.pointLight.intensity;
        ctx.save();
        ctx.globalCompositeOperation = "soft-light";
        ctx.globalAlpha = 0.35 * this.level.pointLight.intensity;
        ctx.drawImage(ptLight, px - r, py - r, r * 2, r * 2);
        ctx.restore();
      }
    }
  }

  /** Reused actor slots — the depth pass runs every frame and must not allocate. */
  private actors: Array<{ y: number; obj: LevelObject | null }> = [];
  private actorCount = 0;

  /**
   * Direction the level's key light comes from; drives shadow offset.
   * Fixed per level, so it is resolved once instead of per shadow per frame.
   */
  private readonly lightDir: Vec2;

  /**
   * Gather everything that should be depth-sorted this frame: visible
   * interactables plus the cat. Sorted by ground line (bottom edge), using an
   * insertion sort because the list is tiny and it sorts a partial array
   * in place without allocating.
   */
  private collectActors() {
    this.actorCount = 0;
    const push = (y: number, obj: LevelObject | null) => {
      const slot = this.actors[this.actorCount] ?? (this.actors[this.actorCount] = { y: 0, obj: null });
      slot.y = y;
      slot.obj = obj;
      this.actorCount++;
    };

    const pad = 120;
    for (const o of this.level.objects) {
      if (o.kind !== "item" && o.kind !== "npc" && o.kind !== "goal") continue;
      if (o.kind === "item" && this.collectedThisRun.has(o.id)) continue;
      // Cull anything well outside the view before it costs any draw calls.
      if (
        o.rect.x + o.rect.w < this.view.x - pad || o.rect.x > this.view.x + this.view.w + pad ||
        o.rect.y + o.rect.h < this.view.y - pad || o.rect.y > this.view.y + this.view.h + pad
      ) continue;
      push(o.rect.y + o.rect.h, o);
    }
    push(this.pos.y + CAT_SIZE / 2, null);

    for (let i = 1; i < this.actorCount; i++) {
      const cur = this.actors[i];
      const y = cur.y;
      const obj = cur.obj;
      let j = i - 1;
      while (j >= 0 && this.actors[j].y > y) {
        this.actors[j + 1].y = this.actors[j].y;
        this.actors[j + 1].obj = this.actors[j].obj;
        j--;
      }
      this.actors[j + 1].y = y;
      this.actors[j + 1].obj = obj;
    }
  }

  /** Soft contact shadow, offset away from the level's key light. */
  private drawShadow(ctx: CanvasRenderingContext2D, radius: number, scale: number, baseY: number) {
    const dir = this.lightDir;
    ctx.save();
    ctx.globalAlpha = 0.34;
    ctx.fillStyle = "#000";
    ctx.beginPath();
    ctx.ellipse(-dir.x * radius * 0.45, baseY + dir.y * 2, radius * scale, 7 * scale, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  private drawObject(ctx: CanvasRenderingContext2D, o: LevelObject, zoom: number) {
    const cx = o.rect.x + o.rect.w / 2;
    const cy = o.rect.y + o.rect.h / 2;
    const span = Math.max(o.rect.w, o.rect.h);
    const now = performance.now();
    const pulse = 0.55 + 0.45 * Math.sin(now / 320);
    // Collectibles hover; fixed things (doors, chests) stay put.
    const hover = o.kind === "item" ? Math.sin(now / 520 + cx) * 3 : 0;
    const tint = o.kind === "item" ? "#ffd76b" : o.kind === "npc" ? "#9be38a" : "#7ec3ff";

    // Soft contact shadow with multiple layers for depth
    ctx.save();
    ctx.translate(cx, cy);
    const dir = this.lightDir;
    ctx.globalAlpha = 0.2;
    for (let i = 0; i < 3; i++) {
      const alpha = 0.34 / (i + 1);
      ctx.globalAlpha = alpha;
      ctx.fillStyle = "#000";
      ctx.beginPath();
      ctx.ellipse(-dir.x * span * 0.45, o.rect.h / 2 + dir.y * 2 + i * 2, span * 0.3 + i * 3, 7 + i * 1, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    // Additive bloom reads as the object emitting light rather than sitting on a disc.
    const light = this.getLightSprite();
    if (light) {
      const r = span * (0.85 + 0.12 * pulse);
      ctx.save();
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = 0.22 * pulse;
      ctx.drawImage(light, cx - r, cy - r + hover, r * 2, r * 2);
      ctx.restore();
    }

    ctx.save();
    ctx.globalAlpha = 0.22 * pulse;
    ctx.fillStyle = tint;
    ctx.beginPath();
    ctx.arc(cx, cy + 4, span * 0.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    const icon = o.icon ?? (o.itemId ? ITEMS[o.itemId]?.emoji : undefined);
    if (icon) {
      ctx.save();
      ctx.font = `${Math.round(span * 0.78)}px "Segoe UI Emoji", "Apple Color Emoji", system-ui, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(icon, cx, cy + hover);
      ctx.restore();
    }

    if (this.lastNearbyId === o.id) {
      ctx.save();
      ctx.globalAlpha = 0.9;
      ctx.strokeStyle = "#ffffff";
      ctx.lineWidth = 2 / zoom;
      ctx.beginPath();
      ctx.arc(cx, cy + 4, span * 0.8, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
  }

  private vignette: CanvasGradient | null = null;
  private vignetteKey = "";
  private lightSprite: HTMLCanvasElement | null = null;
  private pointLightSprite: HTMLCanvasElement | null = null;

  /**
   * Radial falloff baked into a sprite once, so the per-frame cost of the light
   * that follows the cat is a single drawImage instead of building a gradient.
   */
  private getLightSprite(): HTMLCanvasElement | null {
    if (this.lightSprite) return this.lightSprite;
    const S = 256;
    const c = document.createElement("canvas");
    c.width = S;
    c.height = S;
    const cctx = c.getContext("2d");
    if (!cctx) return null;
    const g = cctx.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
    const warm = this.level.ambient === "night" ? "180,205,255" : "255,214,150";
    g.addColorStop(0, `rgba(${warm},0.85)`);
    g.addColorStop(0.45, `rgba(${warm},0.30)`);
    g.addColorStop(1, `rgba(${warm},0)`);
    cctx.fillStyle = g;
    cctx.fillRect(0, 0, S, S);
    this.lightSprite = c;
    return c;
  }

  /** Bake a warm point light for fixed light sources like a fireplace. */
  private getPointLightSprite(): HTMLCanvasElement | null {
    if (this.pointLightSprite) return this.pointLightSprite;
    const S = 256;
    const c = document.createElement("canvas");
    c.width = S;
    c.height = S;
    const cctx = c.getContext("2d");
    if (!cctx) return null;
    const g = cctx.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
    g.addColorStop(0, "rgba(255,140,60,0.9)");
    g.addColorStop(0.4, "rgba(255,100,40,0.4)");
    g.addColorStop(1, "rgba(255,80,30,0)");
    cctx.fillStyle = g;
    cctx.fillRect(0, 0, S, S);
    this.pointLightSprite = c;
    return c;
  }

  private getVignette(ctx: CanvasRenderingContext2D, cw: number, ch: number): CanvasGradient | null {
    const ambient = this.level.ambient ?? "day";
    const key = `${ambient}:${Math.round(cw)}x${Math.round(ch)}`;
    if (this.vignetteKey === key) return this.vignette;

    const cx = cw / 2;
    const cy = ch / 2;
    const inner = Math.min(cw, ch) * 0.22;
    const outer = Math.hypot(cw, ch) * 0.62;
    const g = ctx.createRadialGradient(cx, cy, inner, cx, cy, outer);
    g.addColorStop(0, "rgba(0,0,0,0)");
    if (ambient === "night") {
      g.addColorStop(0.55, "rgba(8,12,32,0.30)");
      g.addColorStop(1, "rgba(4,7,20,0.88)");
    } else if (ambient === "dim") {
      g.addColorStop(0.55, "rgba(10,6,2,0.26)");
      g.addColorStop(1, "rgba(0,0,0,0.80)");
    } else {
      // Daylight still gets a gentle warm falloff so the frame has some shape.
      g.addColorStop(0.6, "rgba(40,20,0,0.05)");
      g.addColorStop(1, "rgba(30,14,0,0.34)");
    }
    this.vignette = g;
    this.vignetteKey = key;
    return g;
  }



  /** Row order the sheet ships in: down/front, left, right, back/up. */
  private static readonly DIRECTION_ROWS: Direction[] = ["down", "left", "right", "up"];
  private static readonly SHEET_COLS = 3;
  private static readonly SHEET_ROWS = 4;

  /** Bake all 12 sheet cells (4 directions × 3 walk-cycle frames) down to on-screen size, once. */
  private getCatFrameAtlas(drawW: number, drawH: number): Record<Direction, HTMLCanvasElement[]> | null {
    if (this.catFrameAtlas) return this.catFrameAtlas;
    const img = this.catImg;
    if (!img.complete || img.naturalWidth === 0) return null;
    const ss = GameEngine.CAT_CACHE_SS;
    const cellW = img.naturalWidth / GameEngine.SHEET_COLS;
    const cellH = img.naturalHeight / GameEngine.SHEET_ROWS;
    const outW = Math.ceil(drawW * ss);
    const outH = Math.ceil(drawH * ss);

    const atlas = {} as Record<Direction, HTMLCanvasElement[]>;
    for (let row = 0; row < GameEngine.SHEET_ROWS; row++) {
      const dir = GameEngine.DIRECTION_ROWS[row];
      const frames: HTMLCanvasElement[] = [];
      for (let col = 0; col < GameEngine.SHEET_COLS; col++) {
        const c = document.createElement("canvas");
        c.width = outW;
        c.height = outH;
        const cctx = c.getContext("2d");
        if (!cctx) return null;
        cctx.imageSmoothingEnabled = true;
        cctx.imageSmoothingQuality = "high";
        cctx.drawImage(img, col * cellW, row * cellH, cellW, cellH, 0, 0, outW, outH);
        frames.push(c);
      }
      atlas[dir] = frames;
    }
    this.catFrameAtlas = atlas;
    return atlas;
  }

  /** Draw the cat sprite: the correct directional walk-cycle frame, with light secondary squash/stretch. */
  private drawCat(ctx: CanvasRenderingContext2D) {
    const img = this.catImg;
    if (!img.complete || img.naturalWidth === 0) return;

    const S = CAT_SIZE;
    const phase = this.walkPhase;
    const wb = this.walkBlend;
    const rb = this.runBlend;

    // Sheet cells are roughly square (standing character), unlike the old
    // tail-trailing top-down painting this replaced.
    const drawW = S * 1.3;
    const drawH = S * 1.5;
    // Anchor the sprite's feet near the shadow's ground point (CAT_SIZE/2 - 6 below pos).
    const bodyOffsetY = CAT_SIZE / 2 - 6 - drawH / 2;

    // Secondary deformation on top of the correct frame — subtle, direction-agnostic.
    const stretchY = 1 + Math.abs(Math.sin(phase)) * rb * 0.06;
    const squashX = 1 - Math.abs(Math.sin(phase)) * (wb * 0.02 + rb * 0.05);

    const atlas = this.getCatFrameAtlas(drawW, drawH);
    if (!atlas) return;
    const frameIdx = walkFrameIndex(phase, this.moving);
    const sprite = atlas[this.direction][frameIdx];

    ctx.save();
    ctx.scale(squashX, stretchY);
    // Cheap blit: the expensive resample already happened when baking the atlas.
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "low";
    ctx.drawImage(sprite, -drawW / 2, -drawH / 2 + bodyOffsetY, drawW, drawH);
    ctx.restore();
  }
}

export { CAT_SIZE };

