# ARCHITECTURE_MAP.md

Dla każdego systemu: Responsibility / Entry points / Dependencies / Consumers
/ State / Events / Data / Rendering / Persistence / Performance sensitivity /
Migration strategy.

---

## Player Movement & Physics (aktywny: Phaser)

- **Responsibility:** ruch kota, kolizje ze światem, hop, drift, gait/juice.
- **Entry points:** `LevelScene.update()` (`src/game/phaser/LevelScene.ts`).
- **Dependencies:** `Phaser.Physics.Arcade`, `DIFFICULTIES` (gameStore),
  `ITEMS`.
- **Consumers:** `PhaserGameCanvas.tsx` (czyta `scene.pos`/`cam`/`zoom` przez
  gettery), `DebugOverlay.tsx`, `GoalArrows.tsx`.
- **State:** pozycja/prędkość na `Phaser.Physics.Arcade.Body`, lokalny stan
  klasy (`hopping`, `wasSprinting`, `driftUntil`, itd.) — nietrwały.
- **Events:** callbacki `LevelSceneEvents` (nie signals, nie EventBus).
- **Data:** stałe fizyki wpisane na sztywno w pliku (WALK_SPEED=230,
  RUN_SPEED=380, ACCEL=2200, FRICTION=1300, plus stałe hopa/driftu).
- **Rendering:** sprite `cat` (arcade sprite), cień (`Ellipse`), animacje
  (`walk-{dir}` z ręcznie pociętego spritesheetu).
- **Persistence:** pozycja zapisywana do `SaveSlot.pos` co 2s z zewnątrz.
- **Performance sensitivity:** wysoka — `update()` liczy się co klatkę,
  zawiera drift/hop/squash logic; brak alokacji w hot path (dobra praktyka
  już zachowana).
- **Migration strategy:** `CharacterBody2D` + `move_and_slide()`. Stałe
  fizyki → `WeaponData`-style `Resource` (np. `PlayerMovementData`) zamiast
  hardcode. Hop → własny mały state (enter/update/exit) lub `AnimationPlayer`
  sterujący offsetem Y. Drift/lean/squash → osobne komponenty
  (`PlayerJuice.gd`) niezależne od `PlayerMovement.gd`, zgodnie z zasadą
  kompozycji z `godot2.md` §12.

## Input

- **Responsibility:** normalizacja wejścia (klawiatura/dotyk/gamepad) do
  wektora ruchu + flag (sprint, interact).
- **Entry points:** `src/game/input.ts` (`InputState`, używany TYLKO przez
  martwy Canvas2D `GameEngine`), `LevelScene.ts` (własna, zduplikowana
  obsługa klawiatury — **to jest ten faktycznie używany kod wejścia**),
  `src/game/three/useKeyboardVector.ts` (trzeci, niezależny model, tylko 3D).
- **Dependencies:** brak (poza store dla ustawień: `sprintMode`, `invertY`).
- **Consumers:** silnik ruchu odpowiedniej warstwy; `VirtualJoystick.tsx`/
  `DPad.tsx` piszą do `scene.touch`/`scene.sprintToggled` bezpośrednio.
- **State:** brak trwałego stanu; ustawienia w `ControlSettings`
  (gameStore).
- **Events:** brak — odczyt imperatywny co klatkę.
- **Data:** `DEFAULT_CONTROLS` (gameStore.ts).
- **Rendering:** n/d.
- **Persistence:** `controls` w `useGameStore` (persystowane).
- **Performance sensitivity:** średnia — odczyt co klatkę, ale tania logika.
- **Migration strategy:** `Input.get_vector()` + `InputMap` — jedna
  konfiguracja zamiast trzech zduplikowanych implementacji. Priorytet: to
  najlepsza okazja do **konsolidacji długu technicznego** wymienionego w
  audycie (3 równoległe implementacje → 1 `InputMap`).

## World / Levels (dane)

- **Responsibility:** definicja poziomów: geometria, questy, obiekty, mood.
- **Entry points:** `src/game/levels.ts` (`LEVELS`, `getLevel(id)`),
  `src/game/types.ts` (kształty danych).
- **Dependencies:** obrazy teł (`@/assets/*.jpg|jpeg`) importowane przez Vite.
- **Consumers:** wszystkie 3 silniki, `questUtils`, `inventory`, `proximity`,
  `GoalArrows`, `HUD`.
- **State:** statyczne (moduł-level constant), brak mutacji w runtime.
- **Events:** n/d.
- **Data:** `LevelDef[]` — patrz DATA_MODEL.md.
- **Rendering:** n/d (konsumowane przez silniki).
- **Persistence:** n/d (dane statyczne, kompilowane do bundla).
- **Performance sensitivity:** niska — czytane raz per poziom.
- **Migration strategy:** `LevelData` jako Godot `Resource` (`.tres`), jeden
  plik na poziom w `data/levels/`. `objects[]` → `Resource` array lub osobne
  sceny (`Pickup.tscn`, `NPC.tscn`, `Door.tscn`) instancjonowane z danych.
  **Najniższe ryzyko w całej migracji** — czysta struktura danych.

## Quest System

- **Responsibility:** wyprowadzanie stanu ukończenia questów + hinty.
- **Entry points:** `src/game/questUtils.ts` (`computeQuests`,
  `questCompletion`) — czysta funkcja, ma testy (`questUtils.test.ts`).
- **Dependencies:** `ITEMS`, `LevelDef`/`LevelObject`.
- **Consumers:** `HUD.tsx`, `PhaserHUD.tsx` (duplikuje część formatowania w
  `formatQuest()` — drugi, równoległy renderer tekstu questów).
- **State:** bezstanowe — bierze `Snapshot` (inventory/talked/collected) i
  zwraca `QuestStatus[]`.
- **Events:** brak.
- **Data:** `QuestStep` discriminated union (`collect`/`talk`/`reach`).
- **Rendering:** n/d (czysta logika, renderowana osobno w HUD).
- **Persistence:** n/d bezpośrednio — dane wejściowe pochodzą z
  `levelProgress`/`talkedNpcs` (persystowane).
- **Performance sensitivity:** niska — wołane per render UI, nie per klatka
  gameplay.
- **Migration strategy:** przenieść 1:1 jako `class_name QuestEvaluator` w
  GDScript, niezależne od `SceneTree` (spełnia zasadę testowalności z
  `godot2.md` §36) — to najlepszy kandydat do zachowania identycznego
  kształtu kodu, zmieniając tylko składnię.

## Inventory

- **Responsibility:** przeliczanie zebranych obiektów na liczby przedmiotów;
  rejestr darów NPC.
- **Entry points:** `src/game/inventory.ts`.
- **Dependencies:** `LevelDef`, `ItemId`.
- **Consumers:** `gameStore.startLevel()` (rebuduje `inventory` z
  `itemsCollected`), `PhaserGameCanvas` (`onTalk` handler przyznaje dar).
- **State:** bezstanowe (czysta funkcja `inventoryFromCollected`).
- **Events:** brak.
- **Data:** `NPC_GIFTS: Record<string, ItemId>`, konwencja stringowa
  `"<npcObjId>-gift"`.
- **Rendering:** n/d.
- **Persistence:** pośrednio przez `levelProgress.itemsCollected`.
- **Performance sensitivity:** niska.
- **Migration strategy:** `InventoryService` (autoload lub per-level
  singleton) operujący na `ItemData` Resources; zachować konwencję "dar NPC
  ma syntetyczne id" albo zastąpić jawnym polem `grantsItem` na danych NPC
  (czystsze idiomatycznie dla Godota — do decyzji przy implementacji).

## Save/Load

- **Responsibility:** trwały zapis postępu + jeden slot wznowienia.
- **Entry points:** `useGameStore` (`setSave`, `clearSave`,
  `startLevel(id, {resume})`), zapis co 2s w `PhaserGameCanvas`.
- **Dependencies:** `zustand/persist` → `localStorage`.
- **Consumers:** ekran menu (wybór poziomu, wznowienie), `LevelPage`.
- **State:** `SaveSlot | null`, `levelProgress`, `unlockedLevels`,
  `talkedNpcs`, `bestLevelTimes`, `dailyHistory`, `controls`, `difficulty`.
- **Events:** brak — bezpośrednie odczyty/zapisy store'a.
- **Data:** patrz DATA_MODEL.md.
- **Rendering:** n/d.
- **Persistence:** `localStorage["edek-game-v1"]`, wersjonowane
  (`version: 1`, `migrate()` placeholder, `merge()` scala z defaultami
  kontrolek).
- **Performance sensitivity:** świadomie zminimalizowana — `energy` i
  `inventory` wykluczone z `partialize()`, bo zmieniają się kilka razy/s i
  każdy zapis to synchroniczny `JSON.stringify` + `localStorage.setItem`.
- **Migration strategy:** `SaveGame` Resource z `ResourceSaver`/
  `ResourceLoader` lub JSON do `user://`. Zachować rozdział "co się
  persystuje" (progress/settings) od "co się resetuje przy starcie poziomu"
  (energy/inventory) — to świadoma optymalizacja do zachowania, nie
  przypadek.

## Audio

- **Responsibility:** proceduralne efekty dźwiękowe (pickup/completion/danger).
- **Entry points:** `src/lib/audio.ts` (`SimpleAudio`, `audio` singleton).
- **Dependencies:** Web Audio API (`AudioContext`, `OscillatorNode`).
- **Consumers:** `PhaserGameCanvas.tsx` (onPickUp/onGoal/onDanger handlers).
- **State:** jeden leniwie tworzony `AudioContext`.
- **Events:** brak.
- **Data:** częstotliwości/czasy trwania hardcoded w metodach.
- **Rendering:** n/d.
- **Persistence:** n/d (głośność z `useGameStore.volume`/`muted`, per-call).
- **Performance sensitivity:** niska — wywoływane rzadko (na zdarzenie).
- **Migration strategy:** zdecydować: (a) odtworzyć proceduralnie w Godot
  przez `AudioStreamGenerator`, lub (b) zamienić na przygotowane próbki +
  `AudioStreamPlayer` (prostsze, bardziej idiomatyczne, ale zmienia brzmienie
  — wymaga potwierdzenia z użytkownikiem czy to akceptowalne odejście).
  `howler` w zależnościach wygląda na nieużywane — zweryfikować przed
  założeniem że jest potrzebne w migracji.

## UI / HUD (React)

- **Responsibility:** cała otoczka poza gameplay canvas — pasek energii,
  dialogi, pauza, ustawienia, strzałki celu, tutorial.
- **Entry points:** `src/components/game/*.tsx`.
- **Dependencies:** `useGameStore`, `useGoalTracks`, `computeQuests`.
- **Consumers:** trasy (`poziom.$id.tsx` renderuje `PhaserGameCanvas`, który
  renderuje te komponenty jako dzieci).
- **State:** lokalny stan komponentów (dialog, toasts, paused) + odczyty
  store'a.
- **Events:** callbacki propsowe z `PhaserGameCanvas`.
- **Data:** n/d (odczyt z `levels.ts`/`items.ts`/store).
- **Rendering:** DOM/CSS (Tailwind), nie canvas.
- **Persistence:** n/d bezpośrednio.
- **Performance sensitivity:** niska/średnia (React re-rendery, nie hot
  gameplay loop — poza `GoalArrows` która używa RAF).
- **Migration strategy:** `Control`-based UI w Godot (`Panel`/`Label`/
  `ProgressBar`), zasilana przez sygnały z `QuestEvaluator`/`InventoryService`
  zamiast propsów Reacta. To największa zmiana idiomu (deklaratywny React →
  imperatywne/sygnałowe Control nodes) — wymaga przeprojektowania, nie portu.

## EventBus (Three.js/Phaser/React — warstwa 3D)

- **Responsibility:** luźne sprzężenie między Three.js, Phaser-HUD i React
  w prototypie 3D.
- **Entry points:** `src/game/three/EventBus.ts` (`gameEventBus`).
- **Dependencies:** brak.
- **Consumers:** `EdekPlaceholder.tsx` (emit `player:moved`), `PhaserHUD.tsx`
  (nasłuchuje `player:moved`, ale handler jest pusty — martwy kod).
- **State:** wewnętrzne `Map<string, Set<Function>>` (listeners/onceListeners).
- **Events:** typowany zestaw (`ThreeWorldEvents`/`PhaserOverlayEvents`/
  `ReactAppEvents`), większość niewyemitowana nigdzie w kodzie (np.
  `player:attacked`, `entity:spawned` — zaprojektowane pod przyszłość, jeszcze
  nieużywane).
- **Data:** n/d.
- **Rendering:** n/d.
- **Persistence:** n/d.
- **Performance sensitivity:** niska obecnie (mało eventów), ale zaprojektowany
  pod częste użycie — do obserwacji przy migracji żeby nie odtworzyć
  "globalnego eventbusa dla wszystkiego", którego `godot2.md` §32 explicite
  odradza.
- **Migration strategy:** NIE odtwarzać jako jeden globalny Autoload-signal-hub.
  Zamiast tego: lokalne sygnały Godot per system (`health_changed`,
  `player_moved` z konkretnego `CharacterBody2D`), zgodnie z zasadą z planu.
  Ograniczyć zakres tej migracji do rzeczywiście używanych eventów
  (`player:moved` jest jedynym faktycznie emitowanym).

## Three.js World (LevelLoader3D / World3D / EdekPlaceholder / FollowCamera)

- **Responsibility:** prototypowy render 3D geometrii poziomu + placeholder
  ruchu gracza + kamera trzecioosobowa.
- **Entry points:** `src/routes/poziom3d.tsx` → `World3D.tsx`.
- **Dependencies:** `three`, `@react-three/fiber`, `LevelDef` (konwertowane
  2D→3D w `LevelLoader3D.ts`).
- **Consumers:** `PhaserHUD.tsx` (czyta `usePlayer3DStore` dla debug UI).
- **State:** `usePlayer3DStore` (Zustand, sesyjny, nie persystowany).
- **Events:** `gameEventBus.emit("player:moved", ...)`.
- **Data:** przeliczenia geometrii z `LevelObject.rect` na `THREE.BoxGeometry`
  itp. — proste bryły placeholder, nie prawdziwe modele.
- **Rendering:** WebGL przez R3F `<Canvas>`.
- **Persistence:** brak.
- **Performance sensitivity:** nieznana — brak pomiarów (prototyp).
- **Migration strategy:** jeśli 3D wchodzi w zakres migracji — zastąpić
  całą warstwę natywnymi węzłami Godot 3D (`Node3D`, `CharacterBody3D`,
  `Camera3D`) budowanymi z tych samych danych `LevelDef`. Nie przenosić
  Three.js-owego kodu 1:1 — to jawnie sprzeczne z zasadą nadrzędną planu
  migracji ("nie przepisujemy kodu, przenosimy grę"). Wymaga wcześniejszego
  potwierdzenia z użytkownikiem czy 3D jest w zakresie (patrz
  PHASER_AUDIT.md §13).
