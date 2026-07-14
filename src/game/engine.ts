import type { LevelDef, LevelObject, Rect, Vec2 } from "./types";
import { InputState } from "./input";
import { DIFFICULTIES, type Difficulty, type DifficultyConfig } from "@/store/gameStore";
import { soundManager } from "./soundManager";

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

type Dust = { x: number; y: number; life: number; max: number; r: number };

export class GameEngine {
  pos: Vec2;
  vel: Vec2 = { x: 0, y: 0 };
  facing: "up" | "down" | "left" | "right" = "down";
  /** target facing angle in radians (sprite faces up = 0) */
  facingAngle = Math.PI; // start facing down
  /** smoothed angle that visually catches up to facingAngle */
  renderAngle = Math.PI;
  moving = false;
  sprinting = false;
  /** 0 = idle, 1 = walk, 2 = run */
  gait: 0 | 1 | 2 = 0;
  /** blends 0..1 toward gait, drives anim amplitudes */
  walkBlend = 0;
  runBlend = 0;
  /** -1..1 lean into current turn, drives banking of the sprite */
  turnLean = 0;
  /** 0..1 exhaustion blend (energy under sprint threshold) */
  exhaustBlend = 0;
  /** idle micro-animation timer (sit/look around) */
  idleTimer = 0;
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
  private cam: Vec2 = { x: 0, y: 0 };
  private camLead: Vec2 = { x: 0, y: 0 };
  private camInit = false;
  private zoom = 1;
  private dust: Dust[] = [];
  private dustTimer = 0;
  private pawPrints: { x: number; y: number; alpha: number; life: number; maxLife: number; isLeft: boolean }[] = [];
  private bees: { id: string; cx: number; cy: number; radius: number; angle: number; speed: number; x: number; y: number }[] = [];
  private particles: {
    x: number;
    y: number;
    vx: number;
    vy: number;
    color: string;
    size: number;
    alpha: number;
    life: number;
    maxLife: number;
    type: "star" | "ember" | "dust" | "star-sky";
  }[] = [];
  /** mirror of energy from store, set externally */
  energy = 100;
  /** difficulty tunables, set externally */
  difficulty: Difficulty = "medium";

  constructor(level: LevelDef, catImg: HTMLImageElement, bgImg: HTMLImageElement, events: EngineEvents) {
    this.level = level;
    this.catImg = catImg;
    this.bgImg = bgImg;
    this.events = events;
    this.pos = { ...level.spawn };

    // Initialize animated bees
    for (const o of level.objects) {
      if (o.kind === "trigger" && o.danger && o.id.includes("bee")) {
        const cx = o.rect.x + o.rect.w / 2;
        const cy = o.rect.y + o.rect.h / 2;
        this.bees.push({
          id: o.id,
          cx,
          cy,
          radius: o.rect.w * 0.45,
          angle: Math.random() * Math.PI * 2,
          speed: 1.8 + Math.random() * 0.6,
          x: cx,
          y: cy
        });
      }
    }

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
    soundManager.playBGM(this.level.id);
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
    soundManager.stopBGM();
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
    // Update bees + calculate closest distance to player
    let minBeeDist = Infinity;
    for (const b of this.bees) {
      b.angle += b.speed * dt;
      b.x = b.cx + Math.cos(b.angle) * b.radius;
      b.y = b.cy + Math.sin(b.angle) * b.radius;

      // Update the LevelObject rect dynamically so Edek collides with the animated bee!
      const o = this.level.objects.find((obj) => obj.id === b.id);
      if (o) {
        o.rect = { x: b.x - 12, y: b.y - 12, w: 24, h: 24 };
      }

      const d = dist(this.pos, b);
      if (d < minBeeDist) minBeeDist = d;
    }

    if (this.bees.length > 0) {
      soundManager.updateBeeWarning(minBeeDist, 280);
    }

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
      if (Math.abs(this.vel.x) > Math.abs(this.vel.y)) {
        this.facing = this.vel.x > 0 ? "right" : "left";
      } else {
        this.facing = this.vel.y > 0 ? "down" : "up";
      }
    }
    // smoothly rotate renderAngle toward facingAngle along shortest arc
    let delta = this.facingAngle - this.renderAngle;
    while (delta > Math.PI) delta -= Math.PI * 2;
    while (delta < -Math.PI) delta += Math.PI * 2;
    // Turn slower at high speed → arc-like natural cornering.
    // Difficulty tweaks agility: łatwy = łagodniej, trudny = ostrzej.
    const speedNorm = Math.min(1, speed / Math.max(1, maxSpeed));
    const turnMul = this.difficulty === "easy" ? 0.85 : this.difficulty === "hard" ? 1.25 : 1;
    const turnSpeed = (14 - speedNorm * 7) * turnMul; // rad/s
    const step = Math.max(-turnSpeed * dt, Math.min(turnSpeed * dt, delta));
    this.renderAngle += step;

    // Body lean into corners: normalised angular velocity, weighted by speed.
    const angularVel = step / Math.max(dt, 1 / 120);
    const leanTarget = Math.max(-1, Math.min(1, (angularVel / turnSpeed) * (0.3 + 0.7 * speedNorm)));
    const leanRate = 8;
    this.turnLean += Math.max(-leanRate * dt, Math.min(leanRate * dt, leanTarget - this.turnLean));

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
    const prevStep = Math.floor(this.walkPhase / Math.PI);
    this.walkPhase += dt * Math.max(2, cycleHz);
    const nextStep = Math.floor(this.walkPhase / Math.PI);

    // Spawn paw prints when Edek takes steps
    if (this.moving && nextStep !== prevStep) {
      const isLeft = nextStep % 2 === 0;
      const moveAngle = this.facingAngle - Math.PI / 2; // actual motion direction
      const perpAngle = moveAngle + (isLeft ? -Math.PI / 2 : Math.PI / 2);
      const sideOffset = 13;
      const backOffset = 10;
      const px = this.pos.x - Math.cos(moveAngle) * backOffset + Math.cos(perpAngle) * sideOffset;
      const py = this.pos.y - Math.sin(moveAngle) * backOffset + Math.sin(perpAngle) * sideOffset;

      this.pawPrints.push({
        x: px,
        y: py,
        alpha: this.level.ambient === "night" ? 0.28
             : this.level.ambient === "dim" ? 0.35
             : 0.22,
        life: 0,
        maxLife: 2.2, // seconds
        isLeft,
      });
    }

    // idle timer for micro-animations (tail flick, head turn)
    if (targetGait === 0) this.idleTimer += dt; else this.idleTimer = 0;

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

    // dust particles when sprinting
    if (this.sprinting && this.moving) {
      this.dustTimer -= dt;
      if (this.dustTimer <= 0) {
        this.dustTimer = 0.06;
        this.dust.push({
          x: this.pos.x + (Math.random() - 0.5) * 14,
          y: this.pos.y + CAT_SIZE / 2 - 6,
          life: 0,
          max: 0.45,
          r: 4 + Math.random() * 4,
        });
      }
    }
    for (const p of this.dust) p.life += dt;
    this.dust = this.dust.filter((p) => p.life < p.max);

    // Update paw prints
    for (const p of this.pawPrints) p.life += dt;
    this.pawPrints = this.pawPrints.filter((p) => p.life < p.maxLife);

    this.dangerCooldown = Math.max(0, this.dangerCooldown - dt);

    const cr = this.catRect();
    for (const o of this.level.objects) {
      if (o.kind === "item" && o.itemId && !this.collectedThisRun.has(o.id) && rectsOverlap(cr, o.rect)) {
        this.collectedThisRun.add(o.id);
        this.spawnPickupParticles(o.rect.x + o.rect.w / 2, o.rect.y + o.rect.h / 2);
        this.events.onPickUp(o);
      }
      if (o.kind === "trigger" && o.danger && rectsOverlap(cr, o.rect) && this.dangerCooldown === 0) {
        this.dangerCooldown = 1.2;
        this.spawnStingParticles(this.pos.x, this.pos.y);
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

    // Update particles
    for (const p of this.particles) {
      p.life += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.type === "ember") {
        p.vx += Math.sin(p.life * 5) * 6 * dt; // sway rising embers
      }
    }
    this.particles = this.particles.filter((p) => p.life < p.maxLife);

    // Spawn ambient level particles
    if (this.level.id === "1" && Math.random() < 0.15) {
      // Salon: Fireplace embers
      this.particles.push({
        x: 770 + Math.random() * 60,
        y: 150 + Math.random() * 20,
        vx: (Math.random() - 0.5) * 15,
        vy: -35 - Math.random() * 30,
        color: `hsl(${15 + Math.random() * 25}, 100%, ${50 + Math.random() * 20}%)`,
        size: 1.5 + Math.random() * 2,
        alpha: 0.95,
        life: 0,
        maxLife: 0.8 + Math.random() * 0.8,
        type: "ember",
      });
    }
    else if (this.level.id === "3" && this.particles.filter(p => p.type === "dust").length < 60 && Math.random() < 0.3) {
      // Strych: Drifting dust motes
      this.particles.push({
        x: Math.random() * this.level.width,
        y: Math.random() * this.level.height,
        vx: (Math.random() - 0.5) * 6,
        vy: (Math.random() - 0.2) * 5,
        color: "rgba(235, 235, 235, 0.4)",
        size: 1.0 + Math.random() * 1.8,
        alpha: 0.2 + Math.random() * 0.4,
        life: 0,
        maxLife: 4 + Math.random() * 6,
        type: "dust",
      });
    }
    else if (this.level.id === "4" && Math.random() < 0.003) {
      // Dach: Falling shooting star
      const startX = 200 + Math.random() * (this.level.width - 200);
      this.particles.push({
        x: startX,
        y: 50,
        vx: -180 - Math.random() * 120,
        vy: 90 + Math.random() * 60,
        color: "rgba(255, 245, 220, 0.95)",
        size: 2.0 + Math.random() * 1.5,
        alpha: 1,
        life: 0,
        maxLife: 1.2 + Math.random() * 0.8,
        type: "star-sky",
      });
    }
  }

  private spawnPickupParticles(x: number, y: number) {
    for (let i = 0; i < 15; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 40 + Math.random() * 80;
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: `hsl(${40 + Math.random() * 15}, 100%, ${65 + Math.random() * 20}%)`, // golden chime
        size: 2 + Math.random() * 3,
        alpha: 1,
        life: 0,
        maxLife: 0.6 + Math.random() * 0.5,
        type: "star",
      });
    }
  }

  private spawnStingParticles(x: number, y: number) {
    for (let i = 0; i < 15; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 30 + Math.random() * 60;
      this.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: "#ff3b30", // red impact
        size: 2.5 + Math.random() * 3.5,
        alpha: 1,
        life: 0,
        maxLife: 0.5 + Math.random() * 0.4,
        type: "star",
      });
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
    // Subpixel-stable in world space; rounding in screen space below.
    const camX = this.cam.x;
    const camY = this.cam.y;

    // --- Background fill (screen space) ---
    ctx.fillStyle = "#1a1410";
    ctx.fillRect(0, 0, cw, ch);

    // --- World transform: scale by zoom, translate by camera ---
    ctx.save();
    ctx.scale(zoom, zoom);
    ctx.translate(-camX, -camY);

    if (this.bgImg.complete) {
      ctx.drawImage(this.bgImg, 0, 0, this.level.width, this.level.height);
    }

    // --- Paw prints (behind everything else) ---
    for (const p of this.pawPrints) {
      ctx.save();
      const ageRatio = p.life / p.maxLife;
      ctx.globalAlpha = p.alpha * (1 - ageRatio);
      ctx.fillStyle = this.level.ambient === "night" ? "rgba(255, 255, 255, 0.16)"
                    : this.level.ambient === "dim" ? "rgba(0, 0, 0, 0.22)"
                    : "rgba(0, 0, 0, 0.16)";

      ctx.translate(p.x, p.y);
      // Main pad
      ctx.beginPath();
      ctx.ellipse(0, 0, 3.2, 2.7, 0, 0, Math.PI * 2);
      ctx.fill();
      // 4 tiny toes
      const toes = [
        { x: -2.4, y: -2.7 },
        { x: -0.8, y: -3.8 },
        { x: 0.8, y: -3.8 },
        { x: 2.4, y: -2.7 },
      ];
      for (const t of toes) {
        ctx.beginPath();
        ctx.arc(t.x, t.y, 1.1, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    // interactable highlights (world space now)
    for (const o of this.level.objects) {
      if (o.kind === "item" && this.collectedThisRun.has(o.id)) continue;
      if (o.kind === "item" || o.kind === "npc" || o.kind === "goal") {
        const cx = o.rect.x + o.rect.w / 2;
        const cy = o.rect.y + o.rect.h / 2;
        const pulse = 0.55 + 0.45 * Math.sin(performance.now() / 320);
        ctx.save();
        ctx.globalAlpha = 0.32 * pulse;
        ctx.fillStyle = o.kind === "item" ? "#ffd76b" : o.kind === "npc" ? "#9be38a" : "#7ec3ff";
        ctx.beginPath();
        ctx.arc(cx, cy + 4, Math.max(o.rect.w, o.rect.h) * 0.7, 0, Math.PI * 2);
        ctx.fill();
        if (this.lastNearbyId === o.id) {
          ctx.globalAlpha = 0.9;
          ctx.strokeStyle = "#ffffff";
          ctx.lineWidth = 2 / zoom;
          ctx.beginPath();
          ctx.arc(cx, cy + 4, Math.max(o.rect.w, o.rect.h) * 0.85, 0, Math.PI * 2);
          ctx.stroke();
        }
        ctx.restore();
      }
    }

    // dust particles (under cat)
    for (const p of this.dust) {
      const t = p.life / p.max;
      ctx.save();
      ctx.globalAlpha = (1 - t) * 0.55;
      ctx.fillStyle = "#d6c9b8";
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r * (1 + t * 0.8), 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // cat — world space
    const eb = this.exhaustBlend;
    // Bob amplitude — bigger when running; when exhausted, extra heave.
    const bobAmp = 1.5 + this.walkBlend * 1.5 + this.runBlend * 2.5 + eb * 1.4;
    const bob = (this.walkBlend + this.runBlend) > 0.05 ? Math.sin(this.walkPhase) * bobAmp : 0;
    // Idle breath — slower when exhausted, deeper amplitude.
    const breathHz = eb > 0.05 ? 320 : 600;
    const breathAmp = 0.6 + eb * 1.0;
    const breath = Math.sin(performance.now() / breathHz) * breathAmp * (1 - this.walkBlend);

    ctx.save();
    ctx.translate(this.pos.x, this.pos.y + bob + breath);

    // soft ground shadow (does not rotate; scales subtly with bob for grounding)
    const shadowScale = 1 - Math.abs(bob) * 0.015;
    ctx.fillStyle = "rgba(0,0,0,0.38)";
    ctx.beginPath();
    ctx.ellipse(0, CAT_SIZE * 0.36, (CAT_SIZE * 0.65) * shadowScale, 9 * shadowScale, 0, 0, Math.PI * 2);
    ctx.fill();

    this.drawCat(ctx);
    ctx.restore();

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

    // --- Render animated bees (world space) ---
    for (const b of this.bees) {
      ctx.save();
      ctx.translate(b.x, b.y);

      // Face flight direction
      const flightAngle = b.angle + Math.PI / 2;
      ctx.rotate(flightAngle);

      // Shadow under bee
      ctx.fillStyle = "rgba(0,0,0,0.25)";
      ctx.beginPath();
      ctx.ellipse(0, 16, 8, 4, 0, 0, Math.PI * 2);
      ctx.fill();

      // Bee body
      ctx.fillStyle = "#ffcc00";
      ctx.beginPath();
      ctx.ellipse(0, 0, 10, 8, 0, 0, Math.PI * 2);
      ctx.fill();

      // Stripes
      ctx.strokeStyle = "#1a1a1a";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-3, -7); ctx.lineTo(-3, 7);
      ctx.moveTo(3, -7); ctx.lineTo(3, 7);
      ctx.stroke();

      // Head
      ctx.fillStyle = "#1a1a1a";
      ctx.beginPath();
      ctx.arc(8, 0, 4.5, 0, Math.PI * 2);
      ctx.fill();

      // Eyes
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.arc(9, -2, 1, 0, Math.PI * 2);
      ctx.arc(9, 2, 1, 0, Math.PI * 2);
      ctx.fill();

      // Wing vibe
      const wingVibe = Math.sin(performance.now() * 0.15) * 0.15;
      ctx.fillStyle = "rgba(230, 245, 255, 0.65)";
      ctx.strokeStyle = "rgba(255, 255, 255, 0.85)";
      ctx.lineWidth = 0.8;

      ctx.save();
      ctx.translate(-2, -5);
      ctx.rotate(-Math.PI / 3 + wingVibe);
      ctx.beginPath();
      ctx.ellipse(0, 0, 8, 4, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.restore();

      ctx.save();
      ctx.translate(-2, 5);
      ctx.rotate(Math.PI / 3 - wingVibe);
      ctx.beginPath();
      ctx.ellipse(0, 0, 8, 4, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.restore();

      ctx.restore();
    }

    // --- Render particles (world space) ---
    for (const p of this.particles) {
      const ageRatio = p.life / p.maxLife;
      const alpha = p.alpha * (1 - ageRatio);
      ctx.save();
      ctx.globalAlpha = alpha;

      if (p.type === "star") {
        ctx.fillStyle = p.color;
        ctx.shadowColor = p.color;
        ctx.shadowBlur = 8;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      } 
      else if (p.type === "ember") {
        ctx.fillStyle = p.color;
        ctx.shadowColor = p.color;
        ctx.shadowBlur = 4;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      } 
      else if (p.type === "dust") {
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      } 
      else if (p.type === "star-sky") {
        ctx.strokeStyle = p.color;
        ctx.lineWidth = p.size;
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x - p.vx * 0.08, p.y - p.vy * 0.08);
        ctx.stroke();
      }
      ctx.restore();
    }

    ctx.restore(); // end world transform

    // Vignette (screen space) centered on cat's screen position
    if (this.level.ambient === "dim" || this.level.ambient === "night") {
      const catScreenX = (this.pos.x - camX) * zoom;
      const catScreenY = (this.pos.y - camY) * zoom;
      const grad = ctx.createRadialGradient(catScreenX, catScreenY, 60 * zoom, catScreenX, catScreenY, 360 * zoom);
      grad.addColorStop(0, "rgba(0,0,0,0)");
      grad.addColorStop(1, this.level.ambient === "night" ? "rgba(5,8,20,0.85)" : "rgba(0,0,0,0.78)");
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, cw, ch);
    }
  }



  /** Draw the cat sprite using the 12-directional spritesheet. */
  private drawCat(ctx: CanvasRenderingContext2D) {
    const img = this.catImg;
    if (!img.complete || img.naturalWidth === 0) return;

    const S = CAT_SIZE;
    const phase = this.walkPhase;
    const wb = this.walkBlend;
    const rb = this.runBlend;

    const cellW = img.naturalWidth / 3;
    const cellH = img.naturalHeight / 4;

    // Preserve aspect ratio
    const drawW = S * 1.45;
    const drawH = drawW * (cellH / cellW);

    // Map renderAngle (0 is UP, PI/2 is RIGHT, PI is DOWN, 3*PI/2 is LEFT) to 12 sectors
    let deg = (this.renderAngle * 180 / Math.PI) % 360;
    if (deg < 0) deg += 360;

    const sector = Math.floor((deg + 15) / 30) % 12;

    const SECTOR_TO_SPRITE = [
      { row: 3, col: 1 }, // 0: Up-Center (0°)
      { row: 3, col: 2 }, // 1: Up-Right (30°)
      { row: 2, col: 0 }, // 2: Right-Up (60°)
      { row: 2, col: 1 }, // 3: Right-Center (90°)
      { row: 2, col: 2 }, // 4: Right-Down (120°)
      { row: 0, col: 2 }, // 5: Down-Right (150°)
      { row: 0, col: 1 }, // 6: Down-Center (180°)
      { row: 0, col: 0 }, // 7: Down-Left (210°)
      { row: 1, col: 0 }, // 8: Left-Down (240°)
      { row: 1, col: 1 }, // 9: Left-Center (270°)
      { row: 1, col: 2 }, // 10: Left-Up (300°)
      { row: 3, col: 0 }, // 11: Up-Left (330°)
    ];

    const sprite = SECTOR_TO_SPRITE[sector] ?? SECTOR_TO_SPRITE[0];
    const sx = sprite.col * cellW;
    const sy = sprite.row * cellH;

    // Procedural shoulder/hip walk sway (wobble) + corner lean
    const gaitSway = Math.sin(phase) * (wb * 0.05 + rb * 0.08);
    const banking = this.turnLean * 0.12;
    const sway = gaitSway + banking;

    // Running stretches the body slightly along its motion axis (procedural squash & stretch)
    const stretchY = 1 + Math.abs(Math.sin(phase)) * rb * 0.045;
    const squashX = 1 - Math.abs(Math.sin(phase)) * (wb * 0.015 + rb * 0.035);

    ctx.save();
    ctx.rotate(sway);
    ctx.scale(squashX, stretchY);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";

    // Premium outer glow and drop-shadow to make the cat pop
    if (this.level.ambient === "night") {
      ctx.shadowColor = "rgba(255, 218, 122, 0.45)"; // Amber starlight glow
      ctx.shadowBlur = 14;
    } else if (this.level.ambient === "dim") {
      ctx.shadowColor = "rgba(255, 255, 255, 0.22)"; // Silver moonlight glow
      ctx.shadowBlur = 9;
    } else {
      ctx.shadowColor = "rgba(0, 0, 0, 0.2)"; // Soft daylight depth shadow
      ctx.shadowBlur = 5;
    }

    ctx.drawImage(
      img,
      sx, sy, cellW, cellH, // source rect
      -drawW / 2, -drawH / 2, drawW, drawH // dest rect
    );
    ctx.restore();
  }
}

export { CAT_SIZE };

