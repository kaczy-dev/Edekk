import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { ItemId } from "@/game/types";
import { LEVELS } from "@/game/levels";

export type LevelProgress = {
  completed: boolean;
  itemsCollected: string[];
};

export type SprintMode = "hold" | "toggle";
export type JoystickSide = "left" | "right";
export type TouchControl = "stick" | "dpad";
export type Difficulty = "easy" | "medium" | "hard";

export interface ControlSettings {
  sensitivity: number;       // 0.5 .. 1.5 — multiplier on max speed
  sprintMode: SprintMode;    // hold Shift vs toggle
  joystickSide: JoystickSide;
  touchControl: TouchControl; // analog stick vs D-pad
  invertY: boolean;
  vibration: boolean;
  showHints: boolean;
}

export interface DifficultyConfig {
  label: string;
  startEnergy: number;
  sprintDrainMul: number;
  restRecoverMul: number;
  dangerDamage: number;      // energy lost per bee hit
  minSprintEnergy: number;
}

export const DIFFICULTIES: Record<Difficulty, DifficultyConfig> = {
  easy:   { label: "Łatwy",  startEnergy: 100, sprintDrainMul: 0.55, restRecoverMul: 1.5, dangerDamage: 5,  minSprintEnergy: 4 },
  medium: { label: "Średni", startEnergy: 100, sprintDrainMul: 1.0,  restRecoverMul: 1.0, dangerDamage: 10, minSprintEnergy: 8 },
  hard:   { label: "Trudny", startEnergy: 80,  sprintDrainMul: 1.6,  restRecoverMul: 0.7, dangerDamage: 18, minSprintEnergy: 16 },
};

const DEFAULT_CONTROLS: ControlSettings = {
  sensitivity: 1,
  sprintMode: "hold",
  joystickSide: "left",
  touchControl: "stick",
  invertY: false,
  vibration: true,
  showHints: true,
};

export interface SaveSlot {
  levelId: string;
  pos: { x: number; y: number };
  energy: number;
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
}


export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      volume: 0.6,
      muted: false,
      controls: { ...DEFAULT_CONTROLS },
      difficulty: "medium",
      levelProgress: {},
      unlockedLevels: ["1"],
      talkedNpcs: {},
      inventory: {},
      energy: 100,
      save: null,

      setVolume: (v) => set({ volume: Math.max(0, Math.min(1, v)) }),
      setMuted: (m) => set({ muted: m }),
      setControls: (patch) => set({ controls: { ...get().controls, ...patch } }),
      resetControls: () => set({ controls: { ...DEFAULT_CONTROLS } }),
      setDifficulty: (d) => set({ difficulty: d, energy: DIFFICULTIES[d].startEnergy, save: null }),

      startLevel: (id, opts) => {
        const state = get();
        const existing = state.levelProgress[id] ?? { completed: false, itemsCollected: [] };
        const level = LEVELS.find((l) => l.id === id);
        const inventory: Partial<Record<ItemId, number>> = {};
        if (level) {
          for (const objId of existing.itemsCollected) {
            if (objId.endsWith("-gift")) {
              inventory.yarn = (inventory.yarn ?? 0) + 1;
              continue;
            }
            const obj = level.objects.find((o) => o.id === objId);
            if (obj?.kind === "item" && obj.itemId) {
              inventory[obj.itemId] = (inventory[obj.itemId] ?? 0) + 1;
            }
          }
        }
        const prevTalked = state.talkedNpcs[id] ?? [];
        const startEnergy = DIFFICULTIES[state.difficulty].startEnergy;
        const resumeEnergy = opts?.resume && state.save?.levelId === id ? state.save.energy : startEnergy;

        set({
          inventory,
          energy: resumeEnergy,
          talkedNpcs: { ...state.talkedNpcs, [id]: prevTalked },
          levelProgress: { ...state.levelProgress, [id]: existing },
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
      restoreEnergy: (amount) => set({ energy: Math.min(100, get().energy + amount) }),

      completeLevel: (id, nextId) => {
        const state = get();
        const lp = state.levelProgress[id] ?? { completed: false, itemsCollected: [] };
        set({
          levelProgress: { ...state.levelProgress, [id]: { ...lp, completed: true } },
          unlockedLevels: nextId && !state.unlockedLevels.includes(nextId)
            ? [...state.unlockedLevels, nextId]
            : state.unlockedLevels,
        });
      },

      hasCollected: (levelId, objId) => {
        return get().levelProgress[levelId]?.itemsCollected.includes(objId) ?? false;
      },

      setSave: (slot) => set({ save: slot }),
      clearSave: () => set({ save: null }),

      resetProgress: () => set({
        levelProgress: {},
        unlockedLevels: ["1"],
        talkedNpcs: {},
        inventory: {},
        energy: 100,
        save: null,
      }),
    }),
    {
      name: "edek-game-v1",
      merge: (persisted, current) => {
        const p = (persisted ?? {}) as Partial<GameState>;
        return {
          ...current,
          ...p,
          controls: { ...DEFAULT_CONTROLS, ...(p.controls ?? {}) },
        };
      },
    }
  )
);
