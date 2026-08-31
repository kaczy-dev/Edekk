# DEPENDENCY_GRAPH.md

## Dane → Silniki → UI (warstwa 2D, aktywna produkcyjnie)

```
types.ts (LevelDef, LevelObject, QuestStep, ItemId)
   │
   ├── items.ts (ITEMS registry)
   │
   └── levels.ts (LEVELS[], getLevel)
         │
         ▼
   LevelScene.ts (Phaser LevelScene) ◄── AtmosphereFX.ts (post-FX/lighting/particles)
         │            ▲
         │            └── DIFFICULTIES (gameStore.ts)
         │
         │ (LevelSceneEvents callbacks: onPickUp/onTalk/onGoal/onDanger/
         │  onEnergyDelta/onSprintState/onHop/onDistance/onNearby)
         ▼
   PhaserGameCanvas.tsx
         │
         ├──> useGameStore (pickUp, markTalked, drainEnergy, restoreEnergy,
         │      completeLevel, setSave, recordHop, addDistance)
         │
         ├──> questUtils.computeQuests() ◄── inventory.ts (NPC_GIFTS, giftObjId)
         │         ▲
         │         └── proximity.ts (goalArchetype, goalProximity)
         │
         ├──> audio.ts (SimpleAudio) — onPickUp/onGoal/onDanger
         │
         └──> React children: HUD.tsx, DialogBox.tsx, PauseMenu.tsx,
              ControlsModal.tsx, GoalArrows.tsx (uses goalTracking.ts),
              Toast.tsx, DPad.tsx/VirtualJoystick.tsx, DebugOverlay.tsx (dev)
```

`GameEngine`/`GameCanvas.tsx` (Canvas2D) is a **structurally identical but
unused parallel path** — same LEVELS/ITEMS dependency, own copy of
input/physics logic, not reachable from any route.

## Warstwa 3D (prototyp, izolowana)

```
levels.ts (getLevel("1") — hardcoded)
   │
   ▼
LevelLoader3D.ts (createLevelMesh, createLevelLighting, getSpawnPosition)
   │
   ▼
World3D.tsx (R3F Canvas)
   ├── EdekPlaceholder.tsx ──> useKeyboardVector.ts (independent input)
   │         │
   │         ▼
   │   usePlayer3DStore.ts (position/rotation/isMoving)
   │         │
   │         └──> gameEventBus.emit("player:moved")
   │
   └── FollowCamera.tsx ──> reads usePlayer3DStore

PhaserHUD.tsx (separate Phaser.Game instance, HUD-only)
   ├──> useGameStore (energy, inventory, talkedNpcs)
   ├──> usePlayer3DStore (position, isMoving)
   └──> questUtils.computeQuests() (duplicated quest text formatting)
```

No shared runtime state between the 2D path and the 3D path other than
`useGameStore` (settings/progress) — position/movement live in entirely
separate stores per engine.

## Zustand store fan-in

```
useGameStore (src/store/gameStore.ts)
   ▲ read/write from:
   ├── PhaserGameCanvas.tsx (primary 2D game loop bridge)
   ├── GameCanvas.tsx (unused parallel path)
   ├── PhaserHUD.tsx (read-only: energy, inventory, talkedNpcs)
   ├── HUD.tsx, PauseMenu.tsx, ControlsModal.tsx, GoalArrows.tsx
   ├── routes: menu.tsx, ustawienia.tsx, koniec.tsx, osiagniecia.tsx
   └── DEFAULT_CONTROLS / DIFFICULTIES consumed by input.ts, engine.ts,
       LevelScene.ts (difficulty tuning)
```

## Build-time dependency chain

```
package.json
  └── vite.config.ts → @lovable.dev/vite-tanstack-config (opaque preset)
        └── TanStack Start + Nitro (Cloudflare target)
              └── src/routeTree.gen.ts (generated, do not hand-edit)
```

This chain has no equivalent in a Godot project and is entirely dropped by
the migration — noted here only so nobody tries to "migrate" the build
tooling itself.
