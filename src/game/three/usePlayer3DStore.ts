import { create } from "zustand";

/**
 * Session-only store for 3D player state.
 * Synchronized with EdekPlaceholder every frame, not persisted.
 * Separate from gameStore (which handles meta-game state and settings).
 */

interface Player3DState {
  position: { x: number; y: number; z: number };
  rotation: number; // Y-axis rotation in radians
  isMoving: boolean;

  // Actions
  setPosition: (x: number, y: number, z: number) => void;
  setRotation: (rot: number) => void;
  setIsMoving: (moving: boolean) => void;
}

export const usePlayer3DStore = create<Player3DState>((set) => ({
  position: { x: 0, y: 0.5, z: 0 },
  rotation: 0,
  isMoving: false,

  setPosition: (x, y, z) => set({ position: { x, y, z } }),
  setRotation: (rot) => set({ rotation: rot }),
  setIsMoving: (moving) => set({ isMoving: moving }),
}));
