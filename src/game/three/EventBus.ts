/**
 * Central event bus for hybrid Three.js + Phaser + React architecture.
 * Allows loose coupling between systems without direct imports.
 *
 * Events emitted by Three.js world:
 * - player:moved, player:interact, player:attack, player:died, enemy:spawned, etc.
 *
 * Events emitted by Phaser overlay:
 * - ui:inventory-opened, ui:menu-closed, ui:quest-clicked, etc.
 *
 * Events emitted by React:
 * - game:paused, game:resumed, settings:changed, etc.
 */

type ThreeWorldEvents = {
  "player:moved": [{ x: number; z: number; y: number }];
  "player:attacked": [{ targetId: string }];
  "player:interacted": [{ objectId: string }];
  "entity:spawned": [{ id: string; type: string; x: number; z: number }];
  "entity:died": [{ id: string }];
};

type PhaserOverlayEvents = {
  "ui:inventory-opened": [];
  "ui:inventory-closed": [];
  "ui:menu-opened": [];
  "ui:menu-closed": [];
  "ui:quest-clicked": [{ questId: string }];
};

type ReactAppEvents = {
  "game:paused": [];
  "game:resumed": [];
  "settings:changed": [{ key: string; value: unknown }];
  "level:loaded": [{ levelId: string }];
};

export type GameEvent = ThreeWorldEvents & PhaserOverlayEvents & ReactAppEvents;

class GameEventBus {
  private listeners: Map<string, Set<Function>> = new Map();
  private onceListeners: Map<string, Set<Function>> = new Map();

  emit<K extends keyof GameEvent>(event: K, ...args: GameEvent[K]): boolean {
    let fired = false;

    // Run once listeners and remove them
    const onceSet = this.onceListeners.get(event as string);
    if (onceSet) {
      for (const listener of onceSet) {
        (listener as Function)(...args);
        fired = true;
      }
      onceSet.clear();
    }

    // Run regular listeners
    const listenerSet = this.listeners.get(event as string);
    if (listenerSet) {
      for (const listener of listenerSet) {
        (listener as Function)(...args);
        fired = true;
      }
    }

    return fired;
  }

  on<K extends keyof GameEvent>(
    event: K,
    listener: (...args: GameEvent[K]) => void
  ): this {
    const eventKey = event as string;
    if (!this.listeners.has(eventKey)) {
      this.listeners.set(eventKey, new Set());
    }
    this.listeners.get(eventKey)!.add(listener);
    return this;
  }

  once<K extends keyof GameEvent>(
    event: K,
    listener: (...args: GameEvent[K]) => void
  ): this {
    const eventKey = event as string;
    if (!this.onceListeners.has(eventKey)) {
      this.onceListeners.set(eventKey, new Set());
    }
    this.onceListeners.get(eventKey)!.add(listener);
    return this;
  }

  off<K extends keyof GameEvent>(
    event: K,
    listener: (...args: GameEvent[K]) => void
  ): this {
    const eventKey = event as string;
    this.listeners.get(eventKey)?.delete(listener);
    this.onceListeners.get(eventKey)?.delete(listener);
    return this;
  }

  removeAllListeners(): this {
    this.listeners.clear();
    this.onceListeners.clear();
    return this;
  }
}

export const gameEventBus = new GameEventBus();
