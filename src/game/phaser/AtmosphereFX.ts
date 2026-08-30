import Phaser from "phaser";
import type { LevelDef, LevelLayerKind } from "@/game/types";

/**
 * Fixed-position atmosphere layers for a level: point/cat lighting, ambient
 * drifting particles, foreground leaves, and the camera post-FX color grade.
 * Extracted out of `LevelScene` (which was pushing 1000+ lines) — this class
 * owns nothing that `update()` needs every frame except the cat-following
 * light, exposed via `updateCatLight`.
 */
export class AtmosphereFX {
  private catLight?: Phaser.GameObjects.Image;

  constructor(
    private scene: Phaser.Scene,
    private level: LevelDef,
    private layerDepths: Record<LevelLayerKind, number>,
    private reducedMotion: boolean,
  ) {}

  /**
   * Renders `level.pointLight` as a soft additive glow, plus a smaller warm
   * light that follows the cat at night/dim — the same two-light idea the
   * legacy Canvas2D engine used (a fixed scene light + a moving one around
   * the player), done here with a generated radial-gradient texture instead
   * of a per-frame gradient fill.
   *
   * NOTE: an earlier version of this method branched into a real Phaser
   * Lights2D pipeline (`scene.lights`, `setPipeline("Light2D")`) on WebGL.
   * That pipeline was written for Phaser 3's renderer; this project runs
   * Phaser 4.2.1, whose WebGL renderer was rewritten (RenderNodes) and no
   * longer has a "Light2D" pipeline key at all — `setPipeline("Light2D")`
   * threw at runtime, which aborted `create()` mid-way and broke input
   * entirely (WASD did nothing). This glow-sprite approach is
   * renderer-agnostic and known to work — don't reintroduce Lights2D
   * without first confirming the Phaser 4 replacement API.
   */
  setupWorldLighting(catX: number, catY: number) {
    const glowGfx = this.scene.add.graphics();
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
      const fixedGlow = this.scene.add.image(pl.x, pl.y, "glow");
      fixedGlow.setBlendMode(Phaser.BlendModes.ADD);
      fixedGlow.setTint(color.color);
      fixedGlow.setAlpha(pl.intensity);
      fixedGlow.setScale(2.4);
      fixedGlow.setDepth(this.layerDepths.light);
      // Gentle flicker so the fixed light doesn't read as a static decal —
      // skipped under reducedMotion, where it stays at its steady-state glow.
      if (!this.reducedMotion) {
        this.scene.tweens.add({
          targets: fixedGlow,
          alpha: { from: pl.intensity * 0.75, to: pl.intensity },
          scale: { from: 2.3, to: 2.5 },
          duration: 1800,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
    }

    if (this.level.ambient === "night" || this.level.ambient === "dim") {
      this.catLight = this.scene.add.image(catX, catY, "glow");
      this.catLight.setBlendMode(Phaser.BlendModes.ADD);
      this.catLight.setTint(0xffdca8);
      this.catLight.setAlpha(0.28);
      this.catLight.setScale(1.1);
      this.catLight.setDepth(this.layerDepths.light);
    }
  }

  /** Called every frame from `LevelScene.update()` to keep the cat-following light in place. */
  updateCatLight(x: number, y: number) {
    this.catLight?.setPosition(x, y);
  }

  /** `level.ambientFx` drives a light drifting-particle layer instead of a flat, static scene. */
  setupAmbientParticles() {
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
    const emitter = this.scene.add.particles(0, 0, "dust", {
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
  setupForegroundLeaves() {
    const leafGfx = this.scene.add.graphics();
    leafGfx.fillStyle(0xffffff, 1);
    // Small elongated leaf silhouette rather than a plain dot, so the random
    // per-particle `rotate` below reads as tumbling leaves instead of dust.
    leafGfx.fillEllipse(5, 3, 10, 6);
    leafGfx.generateTexture("leaf", 10, 6);
    leafGfx.destroy();

    const { width, height } = this.level;
    const leafTints = [0xd9822b, 0xc1531f, 0xe0a545, 0x8a3b1f];
    const leaves = this.scene.add.particles(0, 0, "leaf", {
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
  setupPostFX() {
    const cam = this.scene.cameras.main;
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
}

/** `level.pointLight.color` is an `rgba(r,g,b,a)` CSS string (the legacy Canvas2D engine's format) — reduce it to the 0xRRGGBB Phaser's tint API expects. */
function cssColorToHex(css: string): number {
  const m = css.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
  if (!m) return 0xffffff;
  const [, r, g, b] = m;
  return (Number(r) << 16) | (Number(g) << 8) | Number(b);
}
