import type { LevelObject } from "./types";

/**
 * Calibration of the "tuż obok" (arrived) threshold for reach-quest goals.
 *
 * The threshold is derived from the goal's footprint (half-diagonal) and then
 * tuned per goal archetype: a wide gate should read as "arrived" from further
 * away than a small chest or a piece of ham lying on the floor.
 */
export type GoalArchetype = "gate" | "chest" | "food" | "spot";

export interface ProximityProfile {
  label: string;
  /** multiplier applied to the goal's half-diagonal */
  sizeFactor: number;
  /** flat slack in world px added on top */
  slack: number;
  /** clamp bounds in world px */
  min: number;
  max: number;
  /** multiplier of the threshold that still counts as "blisko" */
  nearFactor: number;
  /** multiplier of the threshold that still counts as "średnio" */
  midFactor: number;
}

/** Tunable game config — one entry per goal archetype. */
export const GOAL_PROXIMITY: Record<GoalArchetype, ProximityProfile> = {
  gate:  { label: "Brama / drzwi", sizeFactor: 1.15, slack: 46, min: 70, max: 240, nearFactor: 2.2, midFactor: 5 },
  chest: { label: "Skrzynia",      sizeFactor: 0.95, slack: 26, min: 48, max: 150, nearFactor: 2.4, midFactor: 5.5 },
  food:  { label: "Szynka / jedzenie", sizeFactor: 0.85, slack: 18, min: 38, max: 120, nearFactor: 2.6, midFactor: 6 },
  spot:  { label: "Miejsce",       sizeFactor: 1.0,  slack: 28, min: 48, max: 180, nearFactor: 2.2, midFactor: 5 },
};

/** Global calibration multiplier bounds (user setting). */
export const PROXIMITY_SCALE_RANGE = { min: 0.6, max: 1.8, step: 0.05 } as const;

const FOOD_ITEMS = new Set(["treat", "bowl", "mouse"]);

const GATE_WORDS = new Set(["gate", "brama", "door", "drzwi", "exit", "hatch", "luk", "roof"]);
const CHEST_WORDS = new Set(["chest", "skrzynia", "skrzyn", "box", "kufer"]);
const FOOD_WORDS = new Set(["ham", "szynka", "szynk", "food", "jedzenie", "jedzen", "bowl", "miska", "treat"]);

/** Split an object id into whole words so "boxing" never reads as "box". */
function idWords(id: string): string[] {
  return id.toLowerCase().split(/[^a-ząćęłńóśźż]+/i).filter(Boolean);
}

/** Classify a level object into a proximity archetype. */
export function goalArchetype(obj: LevelObject): GoalArchetype {
  const words = idWords(obj.id);
  if (words.some((w) => GATE_WORDS.has(w))) return "gate";
  if (words.some((w) => CHEST_WORDS.has(w))) return "chest";
  if (words.some((w) => FOOD_WORDS.has(w))) return "food";
  if (obj.itemId && FOOD_ITEMS.has(obj.itemId)) return "food";
  if (obj.itemId === "chest") return "chest";
  return "spot";
}

export interface GoalProximity {
  archetype: GoalArchetype;
  profile: ProximityProfile;
  /** "tuż obok" radius in world px */
  at: number;
  /** "blisko" radius in world px */
  near: number;
  /** "średnio" radius in world px */
  mid: number;
}

/** Compute calibrated proximity radii for a goal object. */
export function goalProximity(obj: LevelObject, scale = 1): GoalProximity {
  const archetype = goalArchetype(obj);
  const profile = GOAL_PROXIMITY[archetype];
  const halfDiag = Math.hypot(obj.rect.w, obj.rect.h) / 2;
  const raw = halfDiag * profile.sizeFactor + profile.slack;
  const at = Math.min(profile.max, Math.max(profile.min, raw)) * scale;
  return {
    archetype,
    profile,
    at,
    near: at * profile.nearFactor,
    mid: at * profile.midFactor,
  };
}
