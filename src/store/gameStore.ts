import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { ItemId } from "@/game/types";
import { LEVELS } from "@/game/levels";
import { inventoryFromCollected } from "@/game/inventory";

export type LevelProgress = {
  completed: boolean;
  itemsCollected: string[];
};

export type SprintMode = "hold" | "toggle";
export type JoystickSide = "left" | "right";
export type TouchControl = "stick" | "dpad";
export type Difficulty = "easy" | "medium" | "hard" | "explorer";
export type ArrowAnimation = "smooth" | "snap" | "off";

export interface ControlSettings {
  sensitivity: number; // 0.5 .. 1.5 — multiplier on max speed
  sprintMode: SprintMode; // hold Shift vs toggle
  joystickSide: JoystickSide;
  touchControl: TouchControl; // analog stick vs D-pad
  invertY: boolean;
  vibration: boolean;
  showHints: boolean;
  /** Motion-sensitivity: show rotating goal arrows + distance badges for reach quests. */
  goalIndicators: boolean;
  /** Arrow animation: smooth rotation, snap to angle, or hidden. */
  arrowAnimation: ArrowAnimation;
  /** Calibration multiplier for the "tuż obok" proximity thresholds (0.6–1.8). */
  goalProximityScale: number;
  /** Colour-blind mode: encode distance tiers with shapes/patterns/glyphs, not just hue. */
  colorBlindMode: boolean;
  /** Reduced motion: no pulsing glows, no eased transitions on goal indicators. */
  reducedMotion: boolean;
  /** Auto-collapse the HUD distance legend after N seconds (0 = never). */
  legendAutoCollapseSec: number;
  /** Persisted manual state of the HUD distance legend (expanded/collapsed). */
  legendExpanded: boolean;
}

export interface DifficultyConfig {
  label: string;
  startEnergy: number;
  sprintDrainMul: number;
  restRecoverMul: number;
  dangerDamage: number; // energy lost per bee hit
  minSprintEnergy: number;
}

export const DIFFICULTIES: Record<Difficulty, DifficultyConfig> = {
  easy: {
    label: "Łatwy",
    startEnergy: 100,
    sprintDrainMul: 0.55,
    restRecoverMul: 1.5,
    dangerDamage: 5,
    minSprintEnergy: 4,
  },
  medium: {
    label: "Średni",
    startEnergy: 100,
    sprintDrainMul: 1.0,
    restRecoverMul: 1.0,
    dangerDamage: 10,
    minSprintEnergy: 8,
  },
  hard: {
    label: "Trudny",
    startEnergy: 80,
    sprintDrainMul: 1.6,
    restRecoverMul: 0.7,
    dangerDamage: 18,
    minSprintEnergy: 16,
  },
  // Casual/young-player mode: energy never meaningfully drains (0 drain, 0 danger
  // damage) so sprinting and bee stings never gate progress — pure exploration.
  explorer: {
    label: "Eksploracja",
    startEnergy: 100,
    sprintDrainMul: 0,
    restRecoverMul: 1,
    dangerDamage: 0,
    minSprintEnergy: 0,
  },
};

export const DEFAULT_CONTROLS: ControlSettings = {
  sensitivity: 1,
  sprintMode: "hold",
  joystickSide: "left",
  touchControl: "stick",
  invertY: false,
  vibration: true,
  showHints: true,
  goalIndicators: true,
  arrowAnimation: "smooth",
  goalProximityScale: 1,
  colorBlindMode: false,
  reducedMotion: false,
  legendAutoCollapseSec: 6.5,
  legendExpanded: true,
};

/** Upper bound of the energy bar; the HUD renders energy as a percentage of this. */
export const MAX_ENERGY = 100;

const INITIAL_PROGRESS = {
  levelProgress: {} as Record<string, LevelProgress>,
  unlockedLevels: ["1"],
  talkedNpcs: {} as Record<string, string[]>,
  inventory: {} as Partial<Record<ItemId, number>>,
  save: null as SaveSlot | null,
};

export interface SaveSlot {
  levelId: string;
  pos: { x: number; y: number };
  energy: number;
  difficulty: Difficulty;
  savedAt: number;
}

interface GameState {
  // settings
  volume: number;
  muted: boolean;
  controls: ControlSettings;
  difficulty: Difficulty;
  // progress
  levelProgress: Record<string, LevelProgress>;
  unlockedLevels: string[];
  /** NPCs the player has talked to, keyed by level id */
  talkedNpcs: Record<string, string[]>;
  // session inventory (per level run)
  inventory: Partial<Record<ItemId, number>>;
  energy: number;
  /** auto-saved resume point */
  save: SaveSlot | null;
  /** Tutorial progression (0 = not started, 1-4 = active step, 5 = complete) */
  tutorialStage: number;
  /** Wall-clock ms when the current level attempt started (speedrun timer). Null when not in a level. */
  levelStartedAt: number | null;
  /** Best (lowest) completion time per level, in ms — a simple client-side speedrun record. */
  bestLevelTimes: Record<string, number>;
  /** Lifetime hop count and world-px walked — currently only instrumented by the
   *  Phaser engine (Level 1), since that's the only engine with a hop action and
   *  the only one wired to report movement deltas. Levels on the legacy Canvas2D
   *  engine don't add to these yet. */
  totalHops: number;
  totalDistanceWalked: number;

  // actions
  setVolume: (v: number) => void;
  setMuted: (m: boolean) => void;
  setControls: (patch: Partial<ControlSettings>) => void;
  resetControls: () => void;
  setDifficulty: (d: Difficulty) => void;
  startLevel: (id: string, opts?: { resume?: boolean }) => void;
  pickUp: (itemId: ItemId, objId: string, levelId: string) => void;
  markTalked: (levelId: string, objId: string) => void;
  drainEnergy: (amount: number) => void;
  restoreEnergy: (amount: number) => void;
  completeLevel: (id: string, nextId?: string) => void;
  hasCollected: (levelId: string, objId: string) => boolean;
  setSave: (slot: SaveSlot) => void;
  clearSave: () => void;
  resetProgress: () => void;
  setTutorialStage: (stage: number) => void;
  recordHop: () => void;
  addDistance: (px: number) => void;
}

export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      volume: 0.6,
      muted: false,
      controls: { ...DEFAULT_CONTROLS },
      difficulty: "medium",
      ...INITIAL_PROGRESS,
      energy: DIFFICULTIES.medium.startEnergy,
      tutorialStage: 0,
      levelStartedAt: null,
      bestLevelTimes: {},
      totalHops: 0,
      totalDistanceWalked: 0,

      recordHop: () => set({ totalHops: get().totalHops + 1 }),
      addDistance: (px) => set({ totalDistanceWalked: get().totalDistanceWalked + px }),

      setVolume: (v) => set({ volume: Math.max(0, Math.min(1, v)) }),
      setMuted: (m) => set({ muted: m }),
      setControls: (patch) => set({ controls: { ...get().controls, ...patch } }),
      resetControls: () => set({ controls: { ...DEFAULT_CONTROLS } }),
      setDifficulty: (d) => set({ difficulty: d, energy: DIFFICULTIES[d].startEnergy, save: null }),

      startLevel: (id, opts) => {
        const state = get();
        const existing = state.levelProgress[id] ?? { completed: false, itemsCollected: [] };
        const level = LEVELS.find((l) => l.id === id);
        const inventory = level ? inventoryFromCollected(level, existing.itemsCollected) : {};
        const prevTalked = state.talkedNpcs[id] ?? [];
        const startEnergy = DIFFICULTIES[state.difficulty].startEnergy;
        const resumeEnergy =
          opts?.resume && state.save?.levelId === id ? state.save.energy : startEnergy;

        set({
          inventory,
          energy: resumeEnergy,
          talkedNpcs: { ...state.talkedNpcs, [id]: prevTalked },
          levelProgress: { ...state.levelProgress, [id]: existing },
          // A resumed run keeps its original start time (the timer already
          // running counts real elapsed time); a fresh attempt resets it.
          levelStartedAt: opts?.resume && state.levelStartedAt ? state.levelStartedAt : Date.now(),
        });
      },

      pickUp: (itemId, objId, levelId) => {
        const state = get();
        const lp = state.levelProgress[levelId] ?? { completed: false, itemsCollected: [] };
        if (lp.itemsCollected.includes(objId)) return;
        set({
          inventory: { ...state.inventory, [itemId]: (state.inventory[itemId] ?? 0) + 1 },
          levelProgress: {
            ...state.levelProgress,
            [levelId]: { ...lp, itemsCollected: [...lp.itemsCollected, objId] },
          },
        });
      },

      markTalked: (levelId, objId) => {
        const state = get();
        const current = state.talkedNpcs[levelId] ?? [];
        if (current.includes(objId)) return;
        set({ talkedNpcs: { ...state.talkedNpcs, [levelId]: [...current, objId] } });
      },

      drainEnergy: (amount) => set({ energy: Math.max(0, get().energy - amount) }),
      restoreEnergy: (amount) => set({ energy: Math.min(MAX_ENERGY, get().energy + amount) }),

      completeLevel: (id, nextId) => {
        const state = get();
        const lp = state.levelProgress[id] ?? { completed: false, itemsCollected: [] };
        const elapsed = state.levelStartedAt ? Date.now() - state.levelStartedAt : null;
        const prevBest = state.bestLevelTimes[id];
        const bestLevelTimes =
          elapsed !== null && (prevBest === undefined || elapsed < prevBest)
            ? { ...state.bestLevelTimes, [id]: elapsed }
            : state.bestLevelTimes;
        set({
          levelProgress: { ...state.levelProgress, [id]: { ...lp, completed: true } },
          unlockedLevels:
            nextId && !state.unlockedLevels.includes(nextId)
              ? [...state.unlockedLevels, nextId]
              : state.unlockedLevels,
          bestLevelTimes,
          levelStartedAt: null,
        });
      },

      hasCollected: (levelId, objId) => {
        return get().levelProgress[levelId]?.itemsCollected.includes(objId) ?? false;
      },

      setSave: (slot) => set({ save: slot }),
      clearSave: () => set({ save: null }),
      setTutorialStage: (stage) => set({ tutorialStage: stage }),

      resetProgress: () =>
        set({
          ...INITIAL_PROGRESS,
          energy: DIFFICULTIES[get().difficulty].startEnergy,
          tutorialStage: 0,
          levelStartedAt: null,
          bestLevelTimes: {},
        }),
    }),
    {
      name: "edek-game-v1",
      // `energy` changes several times a second during play, and every persisted
      // write is a synchronous JSON.stringify + localStorage.setItem of the whole
      // store. Neither field needs to survive a reload: startLevel() rebuilds the
      // inventory from itemsCollected, and energy comes from the save slot or the
      // difficulty's startEnergy.
      partialize: (s) => ({
        volume: s.volume,
        muted: s.muted,
        controls: s.controls,
        difficulty: s.difficulty,
        levelProgress: s.levelProgress,
        unlockedLevels: s.unlockedLevels,
        talkedNpcs: s.talkedNpcs,
        save: s.save,
        bestLevelTimes: s.bestLevelTimes,
        totalHops: s.totalHops,
        totalDistanceWalked: s.totalDistanceWalked,
      }),
      merge: (persisted, current) => {
        const p = (persisted ?? {}) as Partial<GameState>;
        return {
          ...current,
          ...p,
          controls: { ...DEFAULT_CONTROLS, ...(p.controls ?? {}) },
        };
      },
    },
  ),
);
