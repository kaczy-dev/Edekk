export type Vec2 = { x: number; y: number };
export type Rect = { x: number; y: number; w: number; h: number };

export type ItemId =
  | "bowl"
  | "ball"
  | "mouse"
  | "treat"
  | "key"
  | "chest"
  | "yarn"
  | "star"
  | "feather"
  | "leaf"
  | "photo";

export type ItemDef = {
  id: ItemId;
  name: string;
  emoji: string;
  description: string;
};

export type LevelObjectKind = "obstacle" | "item" | "npc" | "goal" | "trigger";

export interface LevelObject {
  id: string;
  kind: LevelObjectKind;
  rect: Rect;
  itemId?: ItemId;
  npcId?: string;
  message?: string;
  /** Glyph drawn in-world. Items fall back to their ITEMS emoji. */
  icon?: string;
  /** how many of which items must be collected to complete this goal */
  requires?: Partial<Record<ItemId, number>>;
  collected?: boolean;
  /** for danger triggers in garden */
  danger?: boolean;
}

export type QuestStep =
  | { id: string; kind: "collect"; itemId: ItemId; count: number; label: string }
  | { id: string; kind: "talk"; objId: string; label: string }
  | { id: string; kind: "reach"; objId: string; label: string };

/**
 * Named depth band a rendering layer belongs to, loosely following the
 * "background / scenery / dynamic world / light / foreground" model.
 * `depth` is the Phaser depth value assigned to that band's fixed-position
 * objects (background image, ambient lighting glows, particle emitters,
 * foreground leaves). Dynamic, y-sorted actors (cat, NPCs, world-object
 * icons) are NOT reassigned by this — they keep the existing "depth = ground
 * y" sort so they correctly tuck in front of/behind scenery as they move.
 * This is purely an optional override table consumed by `setupLayers()`;
 * a level without `layers` renders exactly as before.
 */
export type LevelLayerKind = "background" | "scenery" | "world" | "light" | "foreground";

export interface LevelLayerDef {
  id: LevelLayerKind;
  /** Phaser depth assigned to this band's fixed-position render objects. */
  depth: number;
}

/**
 * Per-level color grading / mood, applied via Phaser's camera ColorMatrix
 * post-FX (see `setupPostFX` in LevelScene). Optional — levels without a
 * `mood` fall back to the generic day/dim/night blend derived from `ambient`.
 */
export interface LevelMood {
  /** Apply Phaser's built-in sepia preset before the adjustments below. */
  sepia?: boolean;
  brightness?: number;
  contrast?: number;
  /** Additive saturation delta, e.g. 0.3 = richer colors, -0.2 = muted. */
  saturate?: number;
  /** Hue rotation in degrees. */
  hue?: number;
  /** Vignette strength override (radius stays fixed); omit to keep the default. */
  vignetteStrength?: number;
}

export interface LevelDef {
  id: string;
  slug: string;
  title: string;
  subtitle: string;
  background: string;
  /** virtual world size in px */
  width: number;
  height: number;
  spawn: Vec2;
  ambient?: "day" | "dim" | "night";
  /** Ambient particle style drifting through this level. */
  ambientFx?: "motes" | "petals" | "dust" | "stars";
  /** dialog spoken by Edek's narrator at start */
  intro: string;
  /** final objective text */
  objective: string;
  /** short reason why this level was locked (shown in menu) */
  unlockHint: string;
  /** structured checklist of tasks shown in HUD and journal */
  quests: QuestStep[];
  objects: LevelObject[];
  /** Optional point light source in world space: { position, color, intensity } */
  pointLight?: { x: number; y: number; color: string; intensity: number };
  /**
   * Optional depth-band overrides for fixed-position render layers. Backward
   * compatible: omitting this keeps the previous hardcoded depths exactly.
   */
  layers?: LevelLayerDef[];
  /** Optional per-level color grading. See `LevelMood`. */
  mood?: LevelMood;
}
