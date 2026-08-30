import Phaser from "phaser";
import type { LevelDef, LevelObject, Vec2 } from "@/game/types";
import { ITEMS } from "@/game/items";
import { DIFFICULTIES, type Difficulty, type RenderQuality } from "@/store/gameStore";

const WALK_SPEED = 230;
const RUN_SPEED = 380;
const CAT_SIZE = 64;
const SHEET_COLS = 3;
const SHEET_ROWS = 4;
/** px/s of velocity gained per second while an input direction is held — kept high for a "feline", agile launch off the mark. */
const ACCEL = 2200;
/** px/s of velocity lost per second once input stops. Deliberately lower than ACCEL so releasing input glides to a soft stop instead of snapping dead — a cat coasting, not a robot braking. */
const FRICTION = 1300;
/** Minimum ms between sprint ghost-trail spawns. */
const GHOST_INTERVAL = 45;
/** Minimum ms between footstep dust puffs while walking (not sprinting). */
const FOOTSTEP_INTERVAL = 230;
/** Idle-breathing: subtle scale pulse while the cat stands still (not hopping, not mid squash-tween). */
const BREATH_SPEED = 1.6; // radians/sec
const BREATH_AMOUNT = 0.018; // fraction of base scale
/** Row order in the sprite sheet, matching the legacy Canvas2D engine. */
const DIRECTION_ROWS = ["down", "left", "right", "up"] as const;

// --- Hop (this game's top-down stand-in for "jump") ------------------------
// There's no gravity/verticality here, so a literal platformer jump doesn't
// apply. Instead Space triggers a quick directional lunge with a visual arc
// — same feel-good building blocks (buffering, grace period, anticipation,
// landing impact) adapted to a flat plane instead of a Y axis.
const HOP_DURATION_MS = 320;
const HOP_ARC_HEIGHT = 22;
const HOP_SPEED = RUN_SPEED * 0.95;
const HOP_COOLDOWN_MS = 260;
/** Jump Buffering: a press this far *before* the hop is ready still fires it the instant it is. */
const HOP_BUFFER_MS = 150;
/** Coyote Time: losing directional input this recently still gets the full-momentum hop instead of a weak on-the-spot one. */
const HOP_COYOTE_MS = 120;

// --- Juicy turning / drift --------------------------------------------------
/** Max lean angle (radians) applied when carving a turn at speed. */
const TURN_LEAN_MAX = 0.16;
/**
 * Sprinting turns beyond this angle (radians) get a brief drift — velocity
 * keeps some of the old heading instead of snapping to the new one.
 * NOTE: this threshold was picked by inspection, not a live playtest — it's
 * the prime candidate to retune by feel once someone can actually play the
 * level (Math.PI/4 for a hair-trigger drift, Math.PI*0.7 for only near-U-turns).
 */
const DRIFT_TURN_ANGLE = Math.PI / 2;
const DRIFT_MS = 140;

export interface LevelSceneEvents {
  onNearby: (obj: LevelObject | null) => void;
  onPickUp: (obj: LevelObject) => void;
  onTalk: (obj: LevelObject) => void;
  onGoal: (obj: LevelObject) => void;
  onDanger: (obj: LevelObject) => void;
  onEnergyDelta: (delta: number) => void;
  onSprintState: (sprinting: boolean) => void;
  /** Fired once per hop — session-stat plumbing for the end screen, not gameplay-affecting. */
  onHop: () => void;
  /** World-px moved this frame (not during a hop's own displacement, to avoid double-counting) — same use. */
  onDistance: (deltaPx: number) => void;
}

export interface LevelSceneInit {
  level: LevelDef;
  catSpriteUrl: string;
  events: LevelSceneEvents;
  collected: string[];
  initialPos?: Vec2;
  initialEnergy: number;
  difficulty: Difficulty;
  renderQuality: RenderQuality;
  /**
   * Phaser's `SceneManager.add(..., autoStart: true)` does not return the
   * booted scene instance synchronously (boot is deferred to the next
   * step), so the caller can't just capture its return value. `create()`
   * hands itself back through this instead.
   */
  onReady: (scene: LevelScene) => void;
}

export interface TouchVec {
  x: number;
  y: number;
}

/**
 * Phaser port of the level gameplay surface (spike: Level 1 only).
 * Mirrors the public surface the legacy `GameEngine` exposed to React
 * (`pos`, `cam`, `zoom`, `paused`, `energy`, `difficulty`, `input.*`) so
 * `PhaserGameCanvas` can drive it the same way `GameCanvas` drives the
 * Canvas2D engine.
 */
export class LevelScene extends Phaser.Scene {
  // --- Level data / lifecycle ------------------------------------------
  private level!: LevelDef;
  private catSpriteUrl!: string;
  private levelEvents!: LevelSceneEvents;
  private collectedIds = new Set<string>();
  private initialPos?: Vec2;
  private onReady!: (scene: LevelScene) => void;

  // --- Public surface PhaserGameCanvas.tsx reads/writes each frame -----
  paused = false;
  energy = 100;
  difficulty: Difficulty = "medium";
  private renderQuality: RenderQuality = "high";
  touch: TouchVec = { x: 0, y: 0 };
  sprintToggled = false;
  touchSprint = false;
  interactPressed = false;
  sprintMode: "hold" | "toggle" = "hold";

  // --- Cat sprite + its visual companions (shadow/light/interact icon) -
  private cat!: Phaser.Physics.Arcade.Sprite;
  private catShadow!: Phaser.GameObjects.Ellipse;
  private catLight?: Phaser.GameObjects.Image;
  private hopReadyGlow!: Phaser.GameObjects.Image;
  private baseScaleX = 1;
  private baseScaleY = 1;
  private squashTween?: Phaser.Tweens.Tween;

  // --- World objects / interaction --------------------------------------
  private nearestInteractable: LevelObject | null = null;
  private objSprites = new Map<string, Phaser.GameObjects.Text>();
  private interactIcon!: Phaser.GameObjects.Text;

  // --- Camera ------------------------------------------------------------
  private baseZoom = 1;
  private zoomTween?: Phaser.Tweens.Tween;

  // --- Layers (optional depth-band overrides, see `LevelLayerDef`) -------
  private bgImage!: Phaser.GameObjects.Image;
  private layerDepths: Record<import("@/game/types").LevelLayerKind, number> = {
    background: 0,
    scenery: 5,
    world: 15,
    light: 2,
    foreground: 20_000,
  };

  // --- Particles (footsteps, sprint trail, hop dust) ----------------------
  private dust!: Phaser.GameObjects.Particles.ParticleEmitter;
  private ghostAcc = 0;
  private footstepAcc = 0;

  // --- Movement state ------------------------------------------------------
  private energyAcc = 0;
  private wasSprinting = false;
  private wasMoving = false;
  private wasBlocked = false;

  // --- Hop (Space): buffering + coyote grace, see constants above. -------
  private hopKey!: Phaser.Input.Keyboard.Key;
  private interactKey!: Phaser.Input.Keyboard.Key;
  private hopping = false;
  private hopStart = 0;
  private hopDir = { x: 0, y: 1 };
  private hopCooldownUntil = 0;
  private hopBufferedAt = -Infinity;
  private lastMovingAt = -Infinity;

  // --- Juicy turning / drift -----------------------------------------------
  private lastFacingAngle = Math.PI / 2; // pointing "down"
  private driftUntil = 0;
  private driftVX = 0;
  private driftVY = 0;

  // --- Keyboard bindings ---------------------------------------------------
  private keyUp!: Phaser.Input.Keyboard.Key;
  private keyDown!: Phaser.Input.Keyboard.Key;
  private keyLeft!: Phaser.Input.Keyboard.Key;
  private keyRight!: Phaser.Input.Keyboard.Key;
  private upArrow!: Phaser.Input.Keyboard.Key;
  private downArrow!: Phaser.Input.Keyboard.Key;
  private leftArrow!: Phaser.Input.Keyboard.Key;
  private rightArrow!: Phaser.Input.Keyboard.Key;
  private shiftKey!: Phaser.Input.Keyboard.Key;

  constructor() {
    super("LevelScene");
  }

  init(data: LevelSceneInit) {
    this.level = data.level;
    this.catSpriteUrl = data.catSpriteUrl;
    this.levelEvents = data.events;
    this.collectedIds = new Set(data.collected);
    this.initialPos = data.initialPos;
    this.energy = data.initialEnergy;
    this.difficulty = data.difficulty;
    this.renderQuality = data.renderQuality;
    this.onReady = data.onReady;
  }

  preload() {
    this.load.image("bg", this.level.background);
    this.load.image("cat", this.catSpriteUrl);
  }

  create() {
    const { width, height } = this.level;
    this.physics.world.setBounds(0, 0, width, height);
    this.cameras.main.setBounds(0, 0, width, height);

    this.setupLayers();

    this.bgImage = this.add.image(0, 0, "bg").setOrigin(0, 0).setDisplaySize(width, height);
    this.bgImage.setDepth(this.layerDepths.background);

    this.sliceCatFrames();

    const spawn = this.initialPos ?? this.level.spawn;
    this.cat = this.physics.add.sprite(spawn.x, spawn.y, "cat", "down-0");
    // The source sheet's cells are ~300x300px; without this the cat renders
    // at native frame size instead of the game's CAT_SIZE footprint.
    this.cat.setDisplaySize(CAT_SIZE, CAT_SIZE);
    this.cat.setCollideWorldBounds(true);
    // Arcade body size/offset are in the sprite's native (pre-`setDisplaySize`)
    // frame units, so these must stay proportions of `this.cat.width/height`
    // (~300px), not absolute `CAT_SIZE` pixels — that mismatch previously gave
    // the collider a near-invisible hitbox once the display size was scaled down.
    const bodyW = this.cat.width * 0.55;
    const bodyH = this.cat.height * 0.4;
    this.cat.setSize(bodyW, bodyH);
    this.cat.setOffset((this.cat.width - bodyW) / 2, this.cat.height - bodyH);
    this.cat.setDepth(10);
    this.baseScaleX = this.cat.scaleX;
    this.baseScaleY = this.cat.scaleY;

    // A soft contact shadow grounds the cat in the world instead of it
    // looking like a sticker pasted on the background. It's a plain
    // Ellipse rather than a texture so its alpha/scale can cheaply track
    // the hop arc (shrinks and fades as the cat lifts off the ground).
    this.catShadow = this.add.ellipse(
      spawn.x,
      spawn.y,
      CAT_SIZE * 0.7,
      CAT_SIZE * 0.28,
      0x000000,
      0.32,
    );
    this.catShadow.setDepth(1);

    const obstacles = this.physics.add.staticGroup();
    const interactZones: Phaser.GameObjects.Zone[] = [];

    for (const obj of this.level.objects) {
      if (obj.kind === "obstacle") {
        const rect = this.add.rectangle(
          obj.rect.x + obj.rect.w / 2,
          obj.rect.y + obj.rect.h / 2,
          obj.rect.w,
          obj.rect.h,
        );
        rect.setVisible(false);
        obstacles.add(rect);
        continue;
      }

      if (obj.kind === "item" && (obj.collected || this.collectedIds.has(obj.id))) continue;

      const label = obj.icon ?? (obj.itemId ? ITEMS[obj.itemId]?.emoji : "❓") ?? "❓";
      const text = this.add.text(obj.rect.x + obj.rect.w / 2, obj.rect.y + obj.rect.h / 2, label, {
        fontSize: `${Math.round(obj.rect.h * 0.9)}px`,
      });
      text.setOrigin(0.5);
      // Y-sort: static objects get a fixed depth from their ground position
      // so the cat's own per-frame y-depth (set in update()) correctly
      // slots in front of/behind them as it walks past.
      text.setDepth(obj.rect.y + obj.rect.h);
      this.objSprites.set(obj.id, text);

      const zone = this.add.zone(
        obj.rect.x + obj.rect.w / 2,
        obj.rect.y + obj.rect.h / 2,
        obj.rect.w,
        obj.rect.h,
      );
      this.physics.add.existing(zone, true);
      zone.setData("obj", obj);
      interactZones.push(zone);
    }

    this.physics.add.collider(this.cat, obstacles);

    for (const zone of interactZones) {
      this.physics.add.overlap(this.cat, zone, (_cat, z) => {
        const obj = (z as Phaser.GameObjects.Zone).getData("obj") as LevelObject;
        if (obj.kind === "item") {
          this.collectItem(obj);
        } else if (obj.kind === "trigger") {
          this.levelEvents.onDanger(obj);
        }
      });
    }

    const keyboard = this.input.keyboard;
    if (!keyboard) throw new Error("Keyboard plugin missing");
    const { KeyCodes } = Phaser.Input.Keyboard;
    this.keyUp = keyboard.addKey(KeyCodes.W);
    this.keyDown = keyboard.addKey(KeyCodes.S);
    this.keyLeft = keyboard.addKey(KeyCodes.A);
    this.keyRight = keyboard.addKey(KeyCodes.D);
    this.shiftKey = keyboard.addKey(KeyCodes.SHIFT);
    this.upArrow = keyboard.addKey(KeyCodes.UP);
    this.downArrow = keyboard.addKey(KeyCodes.DOWN);
    this.leftArrow = keyboard.addKey(KeyCodes.LEFT);
    this.rightArrow = keyboard.addKey(KeyCodes.RIGHT);
    this.hopKey = keyboard.addKey(KeyCodes.SPACE);
    this.interactKey = keyboard.addKey(KeyCodes.E);

    // A single soft dot texture, generated once, doubles as footstep dust
    // and hop-landing puffs — tinted/scaled/rotated differently per use.
    const dustGfx = this.add.graphics();
    dustGfx.fillStyle(0xffffff, 1);
    dustGfx.fillCircle(4, 4, 4);
    dustGfx.generateTexture("dust", 8, 8);
    dustGfx.destroy();
    this.dust = this.add.particles(0, 0, "dust", {
      lifespan: 380,
      speed: { min: 10, max: 45 },
      scale: { start: 0.9, end: 0 },
      alpha: { start: 0.45, end: 0 },
      tint: 0xcbb892,
      emitting: false,
    });
    this.dust.setDepth(4);

    const zoom = Phaser.Math.Clamp(Math.min(this.scale.width, this.scale.height) / 620, 0.75, 1.3);
    this.baseZoom = zoom;
    this.cameras.main.setZoom(zoom);
    this.cameras.main.startFollow(this.cat, true, 0.12, 0.12);

    // Subtle in-world "you can interact here" cue above the cat's head,
    // alongside (not instead of) the HTML HUD prompt — a small nudge in the
    // game world itself rather than only in the UI chrome layered over it.
    this.interactIcon = this.add
      .text(0, 0, "💬", { fontSize: "22px" })
      .setOrigin(0.5)
      .setDepth(10_000)
      .setVisible(false);

    // Render quality gates the expensive-but-optional layers, cheapest to
    // priciest: post-FX camera filters and the foreground leaf layer go
    // first (medium+), full lighting/ambient particles need high+. "low"
    // is background + cat + gameplay only — no atmosphere layers at all.
    const q = this.renderQuality;
    if (q !== "low") this.setupPostFX();
    if (q === "high" || q === "ultra") {
      this.setupWorldLighting();
      this.setupAmbientParticles();
      this.setupForegroundLeaves();
    }

    // Hop-ready cue: a faint glow at the cat's feet that fades in once the
    // cooldown clears, so "can I hop again?" is answerable by looking at the
    // cat instead of guessing off a fixed rhythm.
    this.hopReadyGlow = this.add.image(spawn.x, spawn.y, "glow");
    this.hopReadyGlow.setBlendMode(Phaser.BlendModes.ADD);
    this.hopReadyGlow.setTint(0xfff2c8);
    this.hopReadyGlow.setScale(0.35);
    this.hopReadyGlow.setAlpha(0);
    this.hopReadyGlow.setDepth(2);

    this.onReady(this);
  }

  /**
   * Applies `level.layers` (if the level defines it) on top of the default
   * depth bands. Purely a lookup-table override for the *fixed-position*
   * render layers (background image, ambient light glows, particle
   * emitters, foreground leaves) — the y-sorted cat/NPC/scenery-icon depth
   * logic elsewhere in this file is untouched, so a level that omits
   * `layers` renders with exactly the same depths as before this method
   * existed.
   */
  private setupLayers() {
    if (!this.level.layers) return;
    for (const layer of this.level.layers) {
      this.layerDepths[layer.id] = layer.depth;
    }
  }

  /**
   * Renders `level.pointLight` (already present in level data, previously
   * only read by the legacy Canvas2D engine) as a soft additive glow, plus a
   * smaller warm light that follows the cat — the same two-light idea the
   * old engine used (a fixed scene light + a moving one around the player),
   * done here with a generated radial-gradient texture instead of a
   * per-frame gradient fill.
   */
  private setupWorldLighting() {
    const glowGfx = this.add.graphics();
    const r = 128;
    for (let i = r; i > 0; i -= 2) {
      const alpha = Math.pow(1 - i / r, 2);
      glowGfx.fillStyle(0xffffff, alpha);
      glowGfx.fillCircle(r, r, i);
    }
    glowGfx.generateTexture("glow", r * 2, r * 2);
    glowGfx.destroy();

    if (this.level.pointLight) {
      const pl = this.level.pointLight;
      const color = Phaser.Display.Color.ValueToColor(cssColorToHex(pl.color));
      const fixedGlow = this.add.image(pl.x, pl.y, "glow");
      fixedGlow.setBlendMode(Phaser.BlendModes.ADD);
      fixedGlow.setTint(color.color);
      fixedGlow.setAlpha(pl.intensity);
      fixedGlow.setScale(2.4);
      fixedGlow.setDepth(this.layerDepths.light);
      // Gentle flicker so the fixed light doesn't read as a static decal.
      this.tweens.add({
        targets: fixedGlow,
        alpha: { from: pl.intensity * 0.75, to: pl.intensity },
        scale: { from: 2.3, to: 2.5 },
        duration: 1800,
        yoyo: true,
        repeat: -1,
        ease: "Sine.easeInOut",
      });
    }

    if (this.level.ambient === "night" || this.level.ambient === "dim") {
      this.catLight = this.add.image(this.cat.x, this.cat.y, "glow");
      this.catLight.setBlendMode(Phaser.BlendModes.ADD);
      this.catLight.setTint(0xffdca8);
      this.catLight.setAlpha(0.28);
      this.catLight.setScale(1.1);
      this.catLight.setDepth(this.layerDepths.light);
    }
  }

  /** `level.ambientFx` drives a light drifting-particle layer instead of a flat, static scene. */
  private setupAmbientParticles() {
    const fx = this.level.ambientFx;
    if (!fx) return;
    const { width, height } = this.level;
    const configByFx: Record<string, Phaser.Types.GameObjects.Particles.ParticleEmitterConfig> = {
      motes: {
        tint: 0xffdca8,
        alpha: { start: 0.25, end: 0 },
        scale: { start: 0.5, end: 0.2 },
        speedY: { min: -8, max: -2 },
        speedX: { min: -4, max: 4 },
      },
      dust: {
        tint: 0xd8cba8,
        alpha: { start: 0.18, end: 0 },
        scale: { start: 0.6, end: 0.2 },
        speedY: { min: -4, max: 4 },
        speedX: { min: -6, max: 6 },
      },
      petals: {
        tint: 0xffb6c1,
        alpha: { start: 0.5, end: 0 },
        scale: { start: 0.7, end: 0.3 },
        speedY: { min: 12, max: 30 },
        speedX: { min: -12, max: 12 },
      },
      stars: {
        tint: 0xffffff,
        alpha: { start: 0.7, end: 0 },
        scale: { start: 0.35, end: 0.1 },
        speedY: { min: -2, max: 2 },
        speedX: { min: -2, max: 2 },
      },
    };
    const cfg = configByFx[fx];
    if (!cfg) return;
    const emitter = this.add.particles(0, 0, "dust", {
      ...cfg,
      x: { min: 0, max: width },
      y: { min: 0, max: height },
      lifespan: 6000,
      frequency: 220,
      emitting: true,
    });
    emitter.setDepth(3);
    emitter.setScrollFactor(0.85); // subtle parallax vs. the world/camera
  }

  /**
   * A slow, sparse layer of drifting autumn leaves rendered in front of
   * everything else (world objects, cat, cat-light) — this is the
   * "foreground" layer from the rendering brief, adapted to a
   * single-background (no tilemap) level: independent tinted/rotated
   * particles rather than actual leaf sprites, since none exist as assets.
   * Kept deliberately sparse (low frequency) so it reads as ambience, not
   * as clutter blocking the player's view of the cat.
   */
  private setupForegroundLeaves() {
    const leafGfx = this.add.graphics();
    leafGfx.fillStyle(0xffffff, 1);
    // Small elongated leaf silhouette rather than a plain dot, so the random
    // per-particle `rotate` below reads as tumbling leaves instead of dust.
    leafGfx.fillEllipse(5, 3, 10, 6);
    leafGfx.generateTexture("leaf", 10, 6);
    leafGfx.destroy();

    const { width, height } = this.level;
    const leafTints = [0xd9822b, 0xc1531f, 0xe0a545, 0x8a3b1f];
    const leaves = this.add.particles(0, 0, "leaf", {
      x: { min: 0, max: width },
      y: { min: -40, max: height },
      lifespan: 9000,
      frequency: 950, // sparse — ambience, not a blizzard of leaves
      speedY: { min: 8, max: 18 },
      speedX: { min: -14, max: 14 },
      rotate: { min: 0, max: 360 },
      scale: { start: 0.9, end: 0.7 },
      alpha: { start: 0.85, end: 0 },
      tint: leafTints,
      emitting: true,
    });
    // Above the cat/world/cat-light but below the HTML HUD (which lives
    // outside the canvas entirely) — this is what makes it read as "in
    // front of the camera" rather than just another world layer.
    leaves.setDepth(this.layerDepths.foreground);
    leaves.setScrollFactor(1.08); // very slight foreground parallax
  }

  /**
   * Cheap, asset-free "consistent style" grade: a soft vignette plus a
   * color tilt (cool/blue at night, warm/neutral by day) via Phaser's
   * built-in camera post-pipeline — no extra textures needed.
   *
   * `level.ambient` ("day" | "dim" | "night") drives a continuous blend
   * between the day and night grades rather than a hard day/night switch,
   * so "dim" levels get a real in-between look instead of silently falling
   * into the day branch (the previous binary if/else had no dim case at all).
   */
  private setupPostFX() {
    const cam = this.cameras.main;
    const mood = this.level.mood;
    // Vignette in screen space (external); color grade in camera-local
    // space before the transform (internal) — matches the v4 filter split.
    cam.filters.external.addVignette(0.5, 0.5, 0.82, mood?.vignetteStrength ?? 0.35);
    const grade = cam.filters.internal.addColorMatrix();

    if (mood) {
      // Per-level hand-authored mood (see `LevelMood`) takes over entirely
      // instead of blending with the generic day/night grade below — each
      // level's authored numbers already account for its own `ambient`.
      if (mood.sepia) grade.colorMatrix.sepia();
      if (mood.brightness !== undefined) grade.colorMatrix.brightness(mood.brightness);
      if (mood.contrast !== undefined) grade.colorMatrix.contrast(mood.contrast);
      if (mood.saturate !== undefined) grade.colorMatrix.saturate(mood.saturate);
      if (mood.hue !== undefined) grade.colorMatrix.hue(mood.hue);
      return;
    }

    const night = this.level.ambient === "night" ? 1 : this.level.ambient === "dim" ? 0.5 : 0;
    const lerp = (day: number, nightVal: number) => Phaser.Math.Linear(day, nightVal, night);
    grade.colorMatrix.brightness(lerp(1.02, 0.92));
    grade.colorMatrix.contrast(lerp(1.04, 1.08));
    grade.colorMatrix.saturate(lerp(0.06, -0.1));
    grade.colorMatrix.hue(lerp(0, 6));
  }

  private sliceCatFrames() {
    const source = this.textures.get("cat").getSourceImage();
    const cellW = source.width / SHEET_COLS;
    const cellH = source.height / SHEET_ROWS;
    for (let row = 0; row < SHEET_ROWS; row++) {
      const dir = DIRECTION_ROWS[row];
      for (let col = 0; col < SHEET_COLS; col++) {
        this.textures.get("cat").add(`${dir}-${col}`, 0, col * cellW, row * cellH, cellW, cellH);
      }
      this.anims.create({
        key: `walk-${dir}`,
        frames: [0, 1, 2, 1].map((col) => ({ key: "cat", frame: `${dir}-${col}` })),
        frameRate: 8,
        repeat: -1,
      });
    }
  }

  /**
   * Brief camera zoom-in/out pulse — the reusable hook for "atmosphere"
   * moments (dialogue opening, puzzle focus) rather than a hard cut.
   * `factor` is relative to the level's own base zoom, not absolute, so it
   * composes correctly across levels/viewports with different base zooms.
   */
  pulseZoom(factor: number, durationMs: number) {
    this.zoomTween?.stop();
    this.zoomTween = this.tweens.add({
      targets: this.cameras.main,
      zoom: this.baseZoom * factor,
      duration: durationMs,
      ease: "Sine.easeOut",
      yoyo: true,
      hold: durationMs * 0.6,
    });
  }

  /**
   * Tweens the cat from an exaggerated (sx, sy) pose back to its resting
   * scale — the classic squash & stretch "anticipation then settle" used for
   * starts, stops, and impacts. `sx`/`sy` are multipliers on the sprite's
   * base display scale, not absolute values, so it composes with the
   * continuous speed-based lean applied in `update()`.
   */
  private squash(sx: number, sy: number, durationMs: number) {
    this.squashTween?.stop();
    this.cat.setScale(this.baseScaleX * sx, this.baseScaleY * sy);
    this.squashTween = this.tweens.add({
      targets: this.cat,
      scaleX: this.baseScaleX,
      scaleY: this.baseScaleY,
      duration: durationMs,
      ease: "Back.easeOut",
    });
  }

  private spawnGhost() {
    const ghost = this.add.image(this.cat.x, this.cat.y, "cat", this.cat.frame.name);
    ghost.setScale(this.cat.scaleX, this.cat.scaleY);
    ghost.setDepth(9);
    ghost.setAlpha(0.32);
    ghost.setTint(0x8fd0ff);
    this.tweens.add({
      targets: ghost,
      alpha: 0,
      scaleX: ghost.scaleX * 0.85,
      scaleY: ghost.scaleY * 0.85,
      duration: 220,
      onComplete: () => ghost.destroy(),
    });
  }

  private spawnDust(x: number, y: number, count: number) {
    // Halve particle counts below "high" — dust is frequent (every footstep)
    // so its cost adds up fastest of all the optional layers.
    const n = this.renderQuality === "low" ? 0 : this.renderQuality === "medium" ? Math.ceil(count / 2) : count;
    if (n > 0) this.dust.explode(n, x, y);
  }

  private collectItem(obj: LevelObject) {
    if (this.collectedIds.has(obj.id)) return;
    this.collectedIds.add(obj.id);
    this.objSprites.get(obj.id)?.destroy();
    this.objSprites.delete(obj.id);
    this.levelEvents.onPickUp(obj);
  }

  markCollected(ids: string[]) {
    for (const id of ids) {
      this.collectedIds.add(id);
      this.objSprites.get(id)?.destroy();
      this.objSprites.delete(id);
    }
  }

  get pos(): Vec2 {
    return this.cat ? { x: this.cat.x, y: this.cat.y } : this.level.spawn;
  }

  set pos(v: Vec2) {
    if (this.cat) this.cat.setPosition(v.x, v.y);
  }

  get cam(): Vec2 {
    return { x: this.cameras.main.scrollX, y: this.cameras.main.scrollY };
  }

  get zoom(): number {
    return this.cameras.main.zoom;
  }

  update(time: number, deltaMs: number) {
    if (this.paused || !this.cat) return;
    const dt = Math.min(deltaMs / 1000, 0.05);
    // Physical E and the mobile E button both funnel into the same
    // `interactPressed` flag consumed at the bottom of this method.
    if (Phaser.Input.Keyboard.JustDown(this.interactKey)) this.interactPressed = true;
    const body = this.cat.body as Phaser.Physics.Arcade.Body;
    const groundY = this.cat.y; // y after this frame's physics sync, before any hop-arc offset below

    const kx =
      (this.keyLeft.isDown || this.leftArrow.isDown ? -1 : 0) +
      (this.keyRight.isDown || this.rightArrow.isDown ? 1 : 0);
    const ky =
      (this.keyUp.isDown || this.upArrow.isDown ? -1 : 0) +
      (this.keyDown.isDown || this.downArrow.isDown ? 1 : 0);
    let dx = kx + this.touch.x;
    let dy = ky + this.touch.y;
    // Free 360° vector, not snapped to 4/8-way — diagonals and analog touch
    // input already move at any angle since dx/dy are only ever normalized.
    const len = Math.hypot(dx, dy);
    if (len > 1) {
      dx /= len;
      dy /= len;
    }
    const isMoving = len > 0.05;
    if (isMoving) this.lastMovingAt = time;

    const wantsSprint =
      this.sprintMode === "toggle" ? this.sprintToggled : this.shiftKey.isDown || this.touchSprint;
    const canSprint = this.energy > DIFFICULTIES[this.difficulty].minSprintEnergy;
    const sprinting = wantsSprint && canSprint && isMoving;
    if (sprinting !== this.wasSprinting) {
      this.wasSprinting = sprinting;
      this.levelEvents.onSprintState(sprinting);
    }

    // --- Hop: buffer + coyote grace, resolved before movement below -------
    if (Phaser.Input.Keyboard.JustDown(this.hopKey)) this.hopBufferedAt = time;
    const bufferValid = time - this.hopBufferedAt <= HOP_BUFFER_MS;
    const cooldownReady = time >= this.hopCooldownUntil;
    if (!this.hopping && bufferValid && cooldownReady) {
      this.hopBufferedAt = -Infinity;
      // Coyote Time: input let go moments ago still counts as "was moving"
      // for the purpose of getting the full running hop instead of a weak
      // on-the-spot one.
      const hadRecentMomentum = time - this.lastMovingAt <= HOP_COYOTE_MS;
      const dir = isMoving
        ? { x: dx, y: dy }
        : hadRecentMomentum
          ? this.hopDir
          : this.facingVector();
      this.startHop(dir, time);
    }

    if (this.hopping) {
      const t = Phaser.Math.Clamp((time - this.hopStart) / HOP_DURATION_MS, 0, 1);
      this.cat.setVelocity(this.hopDir.x * HOP_SPEED, this.hopDir.y * HOP_SPEED);
      this.levelEvents.onDistance(HOP_SPEED * dt);
      const arc = Math.sin(t * Math.PI) * HOP_ARC_HEIGHT;
      this.cat.y = groundY - arc;
      // Shadow stays pinned to actual ground level (not the lifted sprite)
      // and shrinks/fades at the arc's peak — the usual "how high off the
      // ground" readability trick.
      this.catShadow.setPosition(this.cat.x, groundY);
      const liftT = arc / HOP_ARC_HEIGHT;
      this.catShadow.setScale(1 - liftT * 0.35);
      this.catShadow.setAlpha(0.32 * (1 - liftT * 0.5));
      if (t >= 1) this.endHop();
    } else {
      const speed = sprinting ? RUN_SPEED : WALK_SPEED;
      let targetVX = dx * speed;
      let targetVY = dy * speed;

      // Drift: carving a sharp turn at speed keeps some of the previous
      // heading for a beat instead of snapping the new direction on
      // instantly — a slide through the corner rather than a pivot.
      if (time < this.driftUntil) {
        const driftT = Phaser.Math.Clamp((this.driftUntil - time) / DRIFT_MS, 0, 1);
        targetVX = Phaser.Math.Linear(targetVX, this.driftVX, driftT * 0.6);
        targetVY = Phaser.Math.Linear(targetVY, this.driftVY, driftT * 0.6);
      }
      if (isMoving && sprinting) {
        const newAngle = Math.atan2(dy, dx);
        const turnDelta = Phaser.Math.Angle.Wrap(newAngle - this.lastFacingAngle);
        if (
          Math.abs(turnDelta) > DRIFT_TURN_ANGLE &&
          Math.hypot(body.velocity.x, body.velocity.y) > WALK_SPEED
        ) {
          this.driftUntil = time + DRIFT_MS;
          this.driftVX = body.velocity.x;
          this.driftVY = body.velocity.y;
        }
      }

      // Accel/friction-limited step per axis instead of snapping to target,
      // so starts/stops/turns feel weighted rather than instant. Friction
      // (no input) decelerates faster than accel builds speed.
      const rate = isMoving ? ACCEL : FRICTION;
      const maxStep = rate * dt;
      const vx = Phaser.Math.Linear(
        body.velocity.x,
        targetVX,
        Math.min(1, maxStep / Math.max(1, Math.abs(targetVX - body.velocity.x))),
      );
      const vy = Phaser.Math.Linear(
        body.velocity.y,
        targetVY,
        Math.min(1, maxStep / Math.max(1, Math.abs(targetVY - body.velocity.y))),
      );
      this.cat.setVelocity(vx, vy);
      this.levelEvents.onDistance(Math.hypot(vx, vy) * dt);

      // Obstacle-hit feedback: a rising edge on `blocked` (was free, now
      // stopped by a collider) gets a small camera shake + squash pulse,
      // throttled to the edge so it doesn't fire every overlapping frame.
      const isBlocked =
        body.blocked.up || body.blocked.down || body.blocked.left || body.blocked.right;
      if (
        isBlocked &&
        !this.wasBlocked &&
        Math.abs(body.velocity.x) + Math.abs(body.velocity.y) > 40
      ) {
        this.cameras.main.shake(70, 0.0015);
        this.squash(1.2, 0.75, 90);
      }
      this.wasBlocked = isBlocked;

      // Squash & stretch: a quick anticipation pulse when starting or fully
      // stopping, on top of the continuous per-frame lean below.
      if (isMoving !== this.wasMoving) {
        this.wasMoving = isMoving;
        if (isMoving) this.squash(1.18, 0.85, 100);
        else this.squash(0.88, 1.15, 90);
      }
      const speedRatio = Math.min(1, Math.hypot(vx, vy) / RUN_SPEED);
      if (!this.squashTween?.isPlaying()) {
        if (isMoving) {
          this.cat.setScale(
            this.baseScaleX * (1 + speedRatio * 0.08),
            this.baseScaleY * (1 - speedRatio * 0.06),
          );
        } else {
          // Idle-breathing: a very small continuous scale pulse so a
          // standing cat still reads as alive instead of a frozen sticker.
          const breath = Math.sin(time * 0.001 * BREATH_SPEED) * BREATH_AMOUNT;
          this.cat.setScale(this.baseScaleX * (1 + breath), this.baseScaleY * (1 - breath));
        }
      }

      // Juicy turning: bank slightly into the direction change, proportional
      // to how sharp the turn is, eased back out as the turn completes.
      if (isMoving && speedRatio > 0.15) {
        const angle = Math.atan2(vy, vx);
        const turnDelta = Phaser.Math.Angle.Wrap(angle - this.lastFacingAngle);
        this.lastFacingAngle = angle;
        const lean = Phaser.Math.Clamp(turnDelta * 2.2, -TURN_LEAN_MAX, TURN_LEAN_MAX) * speedRatio;
        this.cat.rotation = Phaser.Math.Linear(this.cat.rotation, lean, 0.35);
      } else {
        this.cat.rotation = Phaser.Math.Linear(this.cat.rotation, 0, 0.2);
      }

      // Footstep dust while walking; sprinting instead gets the ghost trail
      // below (the two would otherwise visually compete at the same spot).
      if (isMoving && !sprinting) {
        this.footstepAcc += deltaMs;
        if (this.footstepAcc >= FOOTSTEP_INTERVAL) {
          this.footstepAcc = 0;
          this.spawnDust(this.cat.x, groundY + this.cat.displayHeight * 0.32, 2);
        }
      } else {
        this.footstepAcc = 0;
      }

      // Sprint ghost trail: cheap "motion blur" via short-lived faded copies
      // of the current frame, spawned at a fixed cadence rather than every
      // frame (frame-rate independent, and avoids flooding the scene).
      if (sprinting && this.renderQuality !== "low") {
        this.ghostAcc += deltaMs;
        if (this.ghostAcc >= GHOST_INTERVAL) {
          this.ghostAcc = 0;
          this.spawnGhost();
        }
      } else {
        this.ghostAcc = 0;
      }

      if (sprinting) {
        this.energyAcc -= DIFFICULTIES[this.difficulty].sprintDrainMul * 6 * dt;
      } else if (!isMoving) {
        this.energyAcc += DIFFICULTIES[this.difficulty].restRecoverMul * 4 * dt;
      }
      if (Math.abs(this.energyAcc) >= 1) {
        const whole = Math.trunc(this.energyAcc);
        this.energyAcc -= whole;
        this.levelEvents.onEnergyDelta(whole);
      }

      if (isMoving) {
        const dir =
          Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "right" : "left") : dy > 0 ? "down" : "up";
        this.cat.anims.play(`walk-${dir}`, true);
        // Animation speed tied to character speed: idle-ish shuffle at low
        // speed, full-tempo cycle at a sprint, instead of one fixed rate.
        this.cat.anims.timeScale = 0.55 + speedRatio * 0.85;
      } else {
        this.cat.anims.stop();
      }

      this.catShadow.setPosition(this.cat.x, this.cat.y);
      this.catShadow.setScale(1);
      this.catShadow.setAlpha(0.32);
    }

    // Y-sorting: depth = ground y, so the cat tucks behind objects whose
    // anchor is further down the screen and in front of ones further up,
    // instead of a fixed z-order regardless of position.
    this.cat.setDepth(this.cat.y);
    this.catShadow.setDepth(this.cat.y - 1);
    this.catLight?.setPosition(this.cat.x, this.cat.y);

    // Hop-ready cue: fade the paw-glow in while the cooldown is clear (and
    // not mid-hop), fade it out the instant a hop is buffered/fired, so its
    // visibility always answers "can I hop right now?" directly.
    this.hopReadyGlow.setPosition(this.cat.x, this.cat.y + this.cat.displayHeight * 0.3);
    this.hopReadyGlow.setDepth(this.cat.y - 1);
    const hopReady = !this.hopping && time >= this.hopCooldownUntil;
    const targetGlowAlpha = hopReady ? 0.22 + Math.sin(time * 0.004) * 0.08 : 0;
    this.hopReadyGlow.setAlpha(Phaser.Math.Linear(this.hopReadyGlow.alpha, targetGlowAlpha, 0.15));

    this.updateNearest();
    if (this.interactPressed) {
      this.interactPressed = false;
      if (this.nearestInteractable) {
        const obj = this.nearestInteractable;
        if (obj.kind === "npc") this.levelEvents.onTalk(obj);
        else if (obj.kind === "goal") this.levelEvents.onGoal(obj);
      }
    }
  }

  /** Direction the cat is currently posed to face, from its last animation key. */
  private facingVector(): Vec2 {
    const key = this.cat.anims.currentAnim?.key ?? "walk-down";
    const dir = key.replace("walk-", "");
    if (dir === "left") return { x: -1, y: 0 };
    if (dir === "right") return { x: 1, y: 0 };
    if (dir === "up") return { x: 0, y: -1 };
    return { x: 0, y: 1 };
  }

  private startHop(dir: Vec2, time: number) {
    const len = Math.hypot(dir.x, dir.y) || 1;
    this.hopDir = { x: dir.x / len, y: dir.y / len };
    this.hopping = true;
    this.hopStart = time;
    this.hopCooldownUntil = time + HOP_DURATION_MS + HOP_COOLDOWN_MS;
    this.levelEvents.onHop();
    // Anticipation: a brief crouch-and-stretch takeoff pose before the arc.
    this.squash(1.3, 0.68, HOP_DURATION_MS * 0.6);
    this.spawnDust(this.cat.x, this.cat.y + this.cat.displayHeight * 0.32, 4);
  }

  private endHop() {
    this.hopping = false;
    this.squash(0.8, 1.25, 110);
    this.cameras.main.shake(60, 0.001);
    this.spawnDust(this.cat.x, this.cat.y + this.cat.displayHeight * 0.32, 8);
  }

  private updateNearest() {
    const INTERACT_RADIUS = 100;
    let best: LevelObject | null = null;
    let bestDist = Infinity;
    for (const obj of this.level.objects) {
      if (obj.kind !== "npc" && obj.kind !== "goal") continue;
      const cx = obj.rect.x + obj.rect.w / 2;
      const cy = obj.rect.y + obj.rect.h / 2;
      const d = Phaser.Math.Distance.Between(this.cat.x, this.cat.y, cx, cy);
      if (d < INTERACT_RADIUS && d < bestDist) {
        bestDist = d;
        best = obj;
      }
    }
    if (best !== this.nearestInteractable) {
      this.nearestInteractable = best;
      this.levelEvents.onNearby(best);
      this.interactIcon.setVisible(!!best);
      if (best) this.interactIcon.setText(best.kind === "npc" ? "💬" : "🚪");
    }
    if (best) {
      this.interactIcon.setPosition(this.cat.x, this.cat.y - this.cat.displayHeight * 0.75);
    }
  }
}

/** `level.pointLight.color` is an `rgba(r,g,b,a)` CSS string (the legacy Canvas2D engine's format) — reduce it to the 0xRRGGBB Phaser's tint API expects. */
function cssColorToHex(css: string): number {
  const m = css.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
  if (!m) return 0xffffff;
  const [, r, g, b] = m;
  return (Number(r) << 16) | (Number(g) << 8) | Number(b);
}
