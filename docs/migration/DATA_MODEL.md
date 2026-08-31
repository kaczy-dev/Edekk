# DATA_MODEL.md

## Poziom (`LevelDef`, `src/game/types.ts`)

```ts
interface LevelDef {
  id: string;            // "1".."6" — string, not number
  slug: string;           // URL-friendly, currently unused in routing (id is used)
  title: string;          // Polish display title
  subtitle: string;
  background: string;     // imported image URL
  width: number; height: number;   // world size in px
  spawn: Vec2;
  ambient?: "day" | "dim" | "night";
  ambientFx?: "motes" | "petals" | "dust" | "stars";
  intro: string;           // narrator dialog shown once per un-completed level
  objective: string;
  unlockHint: string;
  quests: QuestStep[];
  objects: LevelObject[];
  pointLight?: { x; y; color: string; intensity: number };
  layers?: LevelLayerDef[];   // optional depth-band override
  mood?: LevelMood;           // color grading (sepia/brightness/contrast/saturate/hue/vignette)
}
```

`LevelObject`:
```ts
interface LevelObject {
  id: string;                 // stable identifier, string-matched elsewhere (see gotcha #6 in AGENTS.md)
  kind: "obstacle" | "item" | "npc" | "goal" | "trigger";
  rect: Rect;                  // { x, y, w, h } in world px
  itemId?: ItemId;
  npcId?: string;
  message?: string;            // dialog text on interaction
  icon?: string;                // emoji override; falls back to ITEMS[itemId].emoji
  requires?: Partial<Record<ItemId, number>>;   // for goal objects
  collected?: boolean;
  danger?: boolean;             // for trigger kind
  patrol?: { range: number; speed?: number };
}
```

`QuestStep` (discriminated union):
```ts
type QuestStep =
  | { id; kind: "collect"; itemId: ItemId; count: number; label: string }
  | { id; kind: "talk"; objId: string; label: string }
  | { id; kind: "reach"; objId: string; label: string };
```

**Cross-file string couplings (nie sprawdzane przez kompilator — patrz
AGENTS.md gotcha #6):**
- `quest.objId` musi odpowiadać `object.id` w tym samym poziomie.
- `proximity.ts` klasyfikuje archetyp celu po całych słowach w `object.id`.
- Dary NPC zapisywane jako `"<npcObjectId>-gift"` (`inventory.ts`).

## Item (`ItemDef`, `src/game/items.ts`)

```ts
interface ItemDef { id: ItemId; name: string; emoji: string; description: string; }
```
`ITEMS: Record<ItemId, ItemDef>` — wyczerpujący rekord (11 wpisów: bowl,
ball, mouse, treat, key, chest, yarn, star, feather, leaf, photo). Brak
wpisu dla nowego `ItemId` to błąd kompilacji TypeScript — właściwość warta
odtworzenia w Godot (np. przez test/CI sprawdzający kompletność zasobów
`ItemData` względem enuma).

## Zustand `gameStore` (`src/store/gameStore.ts`)

Persystowane (`partialize`) pod kluczem `localStorage["edek-game-v1"]`,
`version: 1`:
```ts
{
  volume: number; muted: boolean;
  controls: ControlSettings;
  difficulty: Difficulty;
  levelProgress: Record<string, { completed: boolean; itemsCollected: string[] }>;
  unlockedLevels: string[];       // domyślnie ["1"]
  talkedNpcs: Record<string, string[]>;   // levelId -> npc object ids
  save: SaveSlot | null;
  bestLevelTimes: Record<string, number>;   // ms
  totalHops: number; totalDistanceWalked: number;
  dailyHistory: Record<string, string>;     // "YYYY-MM-DD" -> levelId
}
```

NIE persystowane (świadomie — patrz AGENTS.md gotcha #5, wysoka
częstotliwość zmian):
```ts
{
  inventory: Partial<Record<ItemId, number>>;   // rebuilt from itemsCollected on startLevel()
  energy: number;                                // reset to difficulty's startEnergy or save.energy
}
```

`ControlSettings`:
```ts
{
  sensitivity: number;            // 0.5..1.5 (NOTE: ignored by active Phaser engine, see GAMEPLAY_BEHAVIOR.md)
  sprintMode: "hold" | "toggle";
  joystickSide: "left" | "right";
  touchControl: "stick" | "dpad";
  invertY: boolean; vibration: boolean; showHints: boolean;
  goalIndicators: boolean; arrowAnimation: "smooth" | "snap" | "off";
  goalProximityScale: number;      // 0.6..1.8
  colorBlindMode: boolean; reducedMotion: boolean;
  legendAutoCollapseSec: number; legendExpanded: boolean;
  renderQuality: "low" | "medium" | "high" | "ultra";
}
```

`DIFFICULTIES: Record<Difficulty, DifficultyConfig>` — patrz
GAMEPLAY_BEHAVIOR.md tabela.

`SaveSlot`:
```ts
{ levelId: string; pos: { x; y }; energy: number; difficulty: Difficulty; savedAt: number }
```

## `usePlayer3DStore` (warstwa 3D, sesyjna, nietrwała)

```ts
{ position: {x,y,z}; rotation: number; isMoving: boolean; setPosition/setRotation/setIsMoving }
```
Reset przy każdym załadowaniu świata 3D — nigdy nie trafia do
`localStorage`.

## GameEventBus payloads (`src/game/three/EventBus.ts`)

```ts
type ThreeWorldEvents = {
  "player:moved": [{x,z,y}]; "player:attacked": [{targetId}];
  "player:interacted": [{objectId}]; "entity:spawned": [{id,type,x,z}];
  "entity:died": [{id}];
};
type PhaserOverlayEvents = {
  "ui:inventory-opened": []; "ui:inventory-closed": [];
  "ui:menu-opened": []; "ui:menu-closed": []; "ui:quest-clicked": [{questId}];
};
type ReactAppEvents = {
  "game:paused": []; "game:resumed": [];
  "settings:changed": [{key,value}]; "level:loaded": [{levelId}];
};
```
Tylko `player:moved` jest faktycznie emitowany gdziekolwiek w
przeanalizowanym kodzie — reszta to zaprojektowany, niewdrożony kontrakt.

## Godot target — szkic mapowania

| Źródło TS | Godot Resource |
|---|---|
| `LevelDef` | `LevelData extends Resource` (`.tres` per poziom) |
| `LevelObject` | `LevelObjectData extends Resource` (array w `LevelData` lub osobne sceny instancjonowane z danych) |
| `ItemDef` | `ItemData extends Resource` (`.tres` per item, `data/items/`) |
| `QuestStep` | `QuestStepData extends Resource` z polem `kind: String` lub osobne klasy `CollectQuestData`/`TalkQuestData`/`ReachQuestData` |
| `ControlSettings`/`DIFFICULTIES` | `SettingsData`/`DifficultyData extends Resource`, `SettingsService` autoload |
| `SaveSlot` + progress | `SaveGame extends Resource`, zapisywany przez `ResourceSaver` do `user://` |

Uwaga projektowa: TS-owe discriminated unions (`QuestStep`) nie mają
bezpośredniego odpowiednika w Resource — GDScript nie ma unii typów.
Zalecane: albo jedna klasa z opcjonalnymi polami + `kind: StringName`, albo
dziedziczenie (`QuestStepData` bazowa, trzy podklasy) — do rozstrzygnięcia
w fazie architektury implementacji, nie w audycie.
