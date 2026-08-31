# MIGRATION_MATRIX.md

Statusy: `NOT_ANALYZED | ANALYZED | PLANNED | IN_PROGRESS | IMPLEMENTED |
TESTED | PLAYTESTED | VERIFIED | COMPLETE | BLOCKED`

Nic w tym audycie przechodzi implementację — wszystko poniżej co najwyżej
`ANALYZED`. `BLOCKED` oznacza: czeka na decyzję użytkownika przed dalszą
pracą.

| System | Pliki źródłowe | Godot target | Complexity | Risk | Dependencies | Status |
|---|---|---|---|---|---|---|
| Dane poziomów | `src/game/levels.ts`, `types.ts` | `godot/scripts/core/{LevelData,LevelObjectData,QuestStepData}.gd` Resources + `godot/data/levels/level_1..6.tres` | Low | Low | Items | IMPLEMENTED (wszystkie 6 poziomów) — `level_1.tres` `TESTED` (patrz Player movement/Camera), `level_2..6.tres` untested (dane 1:1 z `levels.ts`, ten sam wzorzec co `level_1`, `Array[ExtResource(...)]` syntax już potwierdzony jako poprawny). `background` to placeholder string (asset import to osobna faza). `npc`-kind obiekty (squirrel/pigeon/kot) i "talk" questy przeniesione jako dane, ale `LevelBuilder.gd` jeszcze nie spawnuje `npc` — patrz wiersz "Item pickup / Goal reach" |
| Rejestr przedmiotów | `src/game/items.ts` | `godot/scripts/core/ItemData.gd` + `godot/data/items/*.tres` (11 plików) + `godot/scripts/core/ItemRegistry.gd` (loader) | Low | Low | — | IMPLEMENTED — wszystkie 11 itemów |
| Player movement (Phaser) | `src/game/phaser/LevelScene.ts` | `godot/scenes/player/Player.tscn` + `godot/scripts/gameplay/player/PlayerMovement.gd` | High | Medium (R1) | Input, Physics, Hop | TESTED — WASD movement confirmed working in-editor by user (2026-08-31). NOT yet verified: sprint feel, wall collision stop; NOT yet ported: energy-gated sprint, sprintMode toggle, squash/stretch/lean/ghost-trail/drift visuals |
| Hop mechanic | `LevelScene.ts` (hop* methods) | `godot/scripts/gameplay/player/PlayerHop.gd` component | Medium | Low | Player movement | TESTED — jump buffering (150ms), coyote time (120ms), cooldown (260ms), speed 361 px/s, duration 320ms, visual arc via `arc_progress()` (sine, 22px), confirmed working in-editor by user (2026-08-31). NOT yet: squash-anticipation, paw dust |
| Input (aktywny) | `LevelScene.ts` (klawiatura), brak dotyku/gamepada w Phaser | `InputMap` + `Input.get_vector()` | Medium | High (R1, R5) | — | TESTED — `move_up/down/left/right`, `sprint`, `hop` confirmed by user; `interact`/`inventory`/`pause` wired but not individually exercised yet (no consuming systems built); keyboard only, touch/gamepad parity still open |
| Input (martwy, Canvas2D) | `src/game/input.ts` | n/d (referencja do ew. odzyskania gamepada) | — | — | — | ANALYZED, ref-only |
| Kolizje / przeszkody | `LevelScene.ts` (Arcade Physics) | `CollisionShape2D` + collision layers | Medium | Low | World | TESTED — kolizja potwierdzona zgodna z tłem przez użytkownika (zatrzymuje się na krawędzi krzaka/drzewa). `godot/scripts/gameplay/world/LevelBuilder.gd` builds `StaticBody2D` obstacles from `LevelObjectData` ("obstacle" kind), plus subtelny `Line2D` outline (świadome odejście od Phasera, który nie rysował nic — patrz sekcja "subtelny outline dla przeszkód" niżej), potwierdzone działające. Real collision layers/masks (`COLLISION_MATRIX.md`) still not designed, all bodies share the default layer for now |
| Quest system | `src/game/questUtils.ts` | `godot/scripts/gameplay/quests/QuestUtils.gd` (static, `RefCounted`) | Low | Low | Items, Level data | IMPLEMENTED — 1:1 port including `_missing_items`/`_location_of` hint generation (pure computation, doesn't need UI to exist). `QuestStatus`/`MissingHint` are plain Dictionaries, not typed classes (transient computed values, see file header comment) |
| Inventory | `src/game/inventory.ts` | `godot/scripts/gameplay/inventory/Inventory.gd` (static, `RefCounted`) | Low | Low | Items | IMPLEMENTED — 1:1 port (`NPC_GIFTS`, `gift_obj_id`, `inventory_from_collected`) |
| Item pickup / Goal reach | `LevelScene.ts` (overlap handlers) | `godot/scripts/gameplay/items/ItemPickup.gd`, `godot/scripts/gameplay/world/GoalArea.gd` (`Area2D`) | Medium | Low | Level data, Inventory, Quest | TESTED (overlap only) — pickup and goal (blocked/completed) confirmed working in-editor by user (2026-08-31). NOT yet: "or press E" alternative (needs nearest-interactable-in-100px system across NPC+goal), danger triggers |
| NPC (talk + patrol) | `LevelScene.ts` (npc overlap, `updatePatrols`), `inventory.ts` (`NPC_GIFTS`) | `godot/scripts/gameplay/world/NpcActor.gd` (`Area2D`) | Medium | Low | Level data, Inventory, Quest | IMPLEMENTED — overlap-triggered `talked` signal (not one-shot/`queue_free`d like `ItemPickup`, NPC stays in scene), horizontal patrol back-and-forth around spawn (`patrol_range`/`patrol_speed`, mirrors `scale.x` on turn like Phaser's `setScale(dir,1)`). `LevelRuntime._on_npc_talked()` appends to `_talked`, grants `Inventory.NPC_GIFTS` gift once via synthetic `gift_obj_id()` (same "-gift" suffix scheme as TS). Unlocks L2 (squirrel/yarn), L5 (pigeon/feather), L6 (kot/key). NOT yet: "press E" alternative, dialog UI (still `print()`) |
| Proximity/goal hints | `src/game/proximity.ts`, `goalTracking.ts` | `godot/scripts/gameplay/quests/GoalProximity.gd` (static) | Medium | Low | Level data | IMPLEMENTED (minimalny slice) — `goal_archetype()`/`goal_proximity()`/`tier_for()` 1:1 z `proximity.ts` (gate/chest/food/spot klasyfikacja po słowach w id, promienie at/near/mid). `LevelRuntime._process()` (throttled 10/s) liczy `_compute_tracks()` dla każdego nieukończonego questu "reach"/"collect" (najbliższy pozostały item dla "collect", 1:1 z `useGoalTracks()`), przekazuje do `HUD.update_proximity()`, który dopisuje tekstowy hint (`· blisko (~N kr.)`) do wiersza questu. NIE ported: strzałka on-canvas + kolorowy badge (`tierStyle.ts` — CSS/Tailwind, nieprzenaszalne wprost), tryb kolorślepy, wygładzanie dist/angle z `goalTracking.ts` (React `requestAnimationFrame` lerp) — hint aktualizuje się skokowo co 100ms zamiast płynnie |
| Daily challenge | `src/game/daily.ts` | `godot/scripts/gameplay/daily/DailyChallenge.gd` (pure) | Low | Low | Level data | IMPLEMENTED — 1:1 port: `daily_date_key()`, `pick_daily()` (djb2-ish hash, `& 0xFFFFFFFF` dla unsigned 32-bit wrap zamiast JS `>>> 0`), `previous_day_key()` (przez Unix-time roundtrip zamiast `new Date(y,m-1,d-1)` — Godot's `Time` API nie ma odpowiednika konstruktora `Date` rolling over miesiąc/rok). Niepodłączone do niczego — funkcja "Daily Challenge" w TS żyje za ekranami menu, które jeszcze nie zmigrowane (`Build/routing/menu`); przeniesione teraz bo samodzielne, tanie, zero ryzyka rozjazdu z niezmigrowanymi systemami |
| Save/Load | `src/store/gameStore.ts` (save slice) | `SaveGame` Resource + `SaveService` | Medium | Medium (versioning) | — | IMPLEMENTED (minimalny slice) — `godot/scripts/infrastructure/ProgressStore.gd`, autoload singleton (registered in `project.godot`), JSON w `user://progress.json`. Ported: `unlocked_levels`, `level_progress` (completed + items_collected), `talked_npcs`, `best_level_times` — autosave na każdą zmianę (1:1 z zustand `persist` zapisującym na każdy `set()`). `LevelRuntime.gd` czyta stan przy `_ready()` (seeduje `_collected_ids`/`_talked`, `LevelBuilder.build()` pomija już-zebrane itemy) i pisze przy każdym evencie. `LevelSelectMenu.gd` blokuje "Graj" dla nieodblokowanych poziomów, pokazuje ✓ + best time. NIE ported: `SaveSlot` (mid-level resume pozycja/energia — wymaga Energy systemu, ANALYZED), controls/volume/totalHops/dailyHistory/tutorialStage, wersjonowanie schematu (zustand `migrate`/`version`) |
| Energy/Difficulty | `src/store/gameStore.ts` (DIFFICULTIES, energy/sprint drain) | `godot/scripts/gameplay/difficulty/Difficulty.gd` (static data) | Low | Low | Player movement, Settings/Controls | IMPLEMENTED — `Difficulty.CONFIG` 1:1 port (easy/medium/hard/explorer: start_energy, sprint_drain_mul, rest_recover_mul, danger_damage, min_sprint_energy). `LevelRuntime._update_energy()` drains while sprinting, recovers while fully stopped (not walking — 1:1 `!isMoving` guard from `LevelScene.ts`), gates `PlayerMovement.can_sprint` when energy < `min_sprint_energy`. HUD shows `Energia: NN%` + "(Zmęczenie)" below 30%. Difficulty now read from `SettingsStore.difficulty` (was hardcoded "medium", see Settings/Controls row) |
| Settings/Controls | `src/store/gameStore.ts` (controls, difficulty selector) | `godot/scripts/infrastructure/SettingsStore.gd` (autoload) + `SettingsMenu.gd` | Low | Low | — | IMPLEMENTED (minimalny slice) — `SettingsStore.gd` (trzeci autoload, `user://settings.json`, autosave): `volume`, `muted`, `difficulty`, `sprint_mode` (persystowany, ale bez konsumenta na klawiaturze — patrz niżej). `SettingsMenu.gd`/`scenes/menu/SettingsMenu.tscn`: `OptionButton` trudności, `HSlider` głośności, `CheckBox` wyciszenia, dostępny z `LevelSelectMenu` przez przycisk "Ustawienia". `AudioService.play_pickup/play_completion` teraz wołane z `SettingsStore.effective_volume()` (0 gdy `muted`) zamiast domyślnego 1.0. **Świadomie NIE ported: `sprintMode` "toggle" na klawiaturze** — prześledzone w źródle (`LevelScene.ts` + `PhaserGameCanvas.tsx`): `sprintToggled` jest tam ustawiane WYŁĄCZNIE z przycisku dotykowego w HTML overlay, klawiatura zawsze działa jako "hold" niezależnie od `sprintMode`. Godot nie ma jeszcze UI dotykowego, więc nie ma czego portować bez wymyślania nieistniejącego zachowania. Reszta `ControlSettings` (touch/joystick/colorblind/goalIndicators/legend/renderQuality) nadal bez konsumenta, nieprzeniesiona |
| Audio (proceduralne) | `src/lib/audio.ts` | `godot/scripts/infrastructure/AudioService.gd` (`AudioStreamGenerator`, autoload) | Medium | Medium (R6) | — | IMPLEMENTED — decyzja "procedural vs próbki" rozstrzygnięta faktem: `audio.ts` w całości używa syntezy WebAudio (oscylator sinusoidalny + gain envelope), zero plików próbek do sportowania. 1:1 port: `play_tone/play_pickup/play_completion/play_danger`, exponential decay do podłogi 0.001 (odpowiednik `exponentialRampToValueAtTime`). Pula 8 głosów (`AudioStreamPlayer`+`AudioStreamGenerator` per głos) do nakładających się dźwięków (chirp pickup, akord completion). Podłączone: pickup → `play_pickup()`, goal completed → `play_completion()`. NIE podłączone: `play_danger()` (brak trigger'ów danger w żadnym przeniesionym poziomie), głośność/mute (Settings nie zmigrowany — domyślnie pełna głośność) |
| UI/HUD | `src/components/game/*.tsx` | `Control`-based UI, `CanvasLayer` | High | Low (ale duża zmiana idiomu) | Quest, Inventory, Save | IMPLEMENTED (minimalny slice) — `godot/scripts/presentation/ui/HUD.gd` + `scenes/ui/HUD.tscn`: quest checklist (label + `[x]/[!]/[ ]` + licznik), inventory chips, message label (zastępuje DialogBox dla NPC/goal messages). Zastąpiono nim `print()`-owy placeholder w `LevelRuntime.gd` (eventy per-obiekt zostają w konsoli jako lekki log deweloperski). NIE przeniesione: pasek energii (Energy system), tracker dystansu do celu + legenda (`proximity.ts`/`goalTracking.ts`), timer speedrunowy + best-time (Save), animacje/flash/tooltips, stylowanie (domyślny theme silnika, brak importu fontów) |
| Camera (2D) | `LevelScene.ts` (follow/pulseZoom/shake) | `godot/scripts/presentation/camera/CameraFX.gd` (script on Player's `Camera2D`) | Medium | Low | Player | TESTED — follow via built-in `position_smoothing` (approximation of the 0.12/frame lerp, not measured against it numerically, but confirmed to feel right by user); shake on hop landing and hard wall collision, pulse-zoom on item pickup all confirmed working in-editor by user (2026-08-31). NOT yet: dialog-open pulse (1.06x/260ms, no dialog system yet), `reducedMotion` skip (Settings not migrated). Amplitudes are feel-based, not literal ports of Phaser's screen-fraction intensity units (documented divergence, see file header) |
| Atmosfera/post-FX | `src/game/phaser/AtmosphereFX.ts` | `godot/scripts/presentation/atmosphere/AtmosphereFX.gd` | High | Medium (R2 — **ROZWIĄZANE**, potwierdzone działające przez użytkownika) | Level mood data | TESTED (post-FX color grade i światła/cząsteczki potwierdzone widoczne przez użytkownika w edytorze, 2026-08-31) — punktowe światło + światło przy kocie (addytywny gradient-sprite), `CPUParticles2D` ambient (motes/dust/petals/stars, przybliżenie), post-FX color grade (brightness/contrast/saturation przez `WorldEnvironment`+`Environment.adjustment_*`, `mood` override lub day/night lerp fallback — 1:1 liczbowo z `setupPostFX()`, poza saturacją, która w TS jest addytywna a w Godot multiplikatywna, przeliczone jako `1.0 + saturate`). NIE ported: vignette, hue-rotation/sepia (brak wbudowanego odpowiednika bez custom shadera), foreground leaves |
| Assety (sprite'y, tła) | `src/assets/*` | `res://assets/` (import Nearest/Linear per typ) | Low | Low | — | IMPLEMENTED — Player (`edek-sprite.png`, 4-kierunkowy walk-cycle), tła wszystkich 6 poziomów (`LevelBackgrounds.gd`), i item/NPC/goal jako emoji `Label` (1:1 z `LevelScene.ts`'s `add.text()` — źródło też nie używa custom sprite'ów dla nich). Patrz sekcje "Aktualizacja: Assety" i "item/NPC/goal renderowane jako emoji" niżej. NIE ported: foreground leaves, squash/stretch na sprite'cie kota |
| Assety niewykorzystane (tileset domu, obrazy) | `src/assets/TopDownHouse_*`, `src/obrazki/*` | Poziom 7 "Salon" (`godot/data/levels/level_7.tres`) | — | Low (R7) | — | ROZSTRZYGNIĘTE (2026-08-31, plan31-08.md "Salon (Poziom 7)") — `TopDownHouse_FloorsAndWalls.png`/`DoorsAndWindows.png` użyte (podłoga kafelkowana + drzwi, współrzędne zweryfikowane cropem przed użyciem, nie zgadywane; `FloorsAndWalls.png` okazał się kartą podglądową stylów, nie granularnym tilesetem). `src/obrazki/*` sprawdzone i odrzucone — to zrzuty z niepowiązanej gry, nie assety tego projektu. `FurnitureState1.png` częściowo wykorzystany (kanapa + regał, Poziom 7) — granice sprite'ów wykryte flood-fillem po kanale alfa zamiast szukanego pliku atlas/XML (żaden nie istniał dla tego pakietu), zweryfikowane wizualnie przed użyciem. `FurnitureState2.png`/`SmallItems.png` nadal niewykorzystane |
| Warstwa 3D (Three.js/R3F) | ~~`src/game/three/*`~~ (USUNIĘTE 2026-08-31) | — | — | — | — | OUT_OF_SCOPE — niepodłączony prototyp, potwierdzone i usunięty z repo wraz z zależnościami (`three`, `@react-three/*`) i `/poziom3d` |
| Build/routing/menu (React) | `src/routes/*`, TanStack Start | `Control`-based UI w Godot; Godot zastępuje cały runtime gry (menu, ustawienia, HUD) | High | Medium | UI/HUD | IMPLEMENTED (minimalny slice) — `godot/scripts/presentation/menu/LevelSelectMenu.gd` + `scenes/menu/LevelSelect.tscn`: lista 6 poziomów (tytuł/podtytuł z `menu.tsx`), sequential-unlock gating i best-time przez `ProgressStore` (patrz wiersz Save/Load), przycisk "Graj" → `change_scene_to_file()`. `project.godot`'s `run/main_scene` zostaje `Level1.tscn` (nie zmienione — obecny workflow testowy tego wymaga); ten ekran uruchamia się osobno (F6), decyzja czy staje się właściwym entry pointem jest odłożona |

## Decyzje użytkownika (2026-08-31)

1. **Warstwa 3D — poza zakresem, usunięta.** `src/game/three/*` i
   `src/routes/poziom3d.tsx` usunięte z repo, `three`/`@react-three/drei`/
   `@react-three/fiber` odinstalowane z `package.json`. Phaser (`LevelScene.ts`)
   jest jedynym źródłem prawdy dla parity zachowań w Godot.
2. **Hop/drift** — zachowujemy jako mechanikę do przeniesienia; dopracowanie
   szczegółów parity odłożone do fazy implementacji Playera (nie blokuje
   startu migracji).
3. **Audio** — ROZSTRZYGNIĘTE (2026-08-31, przy implementacji): procedural,
   bo `src/lib/audio.ts` w całości jest syntezą WebAudio, zero plików
   próbek do przeniesienia. Zaimplementowane jako `AudioService.gd`
   (`AudioStreamGenerator`), patrz wiersz "Audio" w tabeli.
4. **`sensitivity`** — usunięte jako martwe ustawienie: pole z
   `ControlSettings`/`DEFAULT_CONTROLS` w `gameStore.ts`, suwak w
   `ustawienia.tsx`, i odczyt w `engine.ts` (dead Canvas2D fallback). Nie ma
   odpowiednika do migrowania do Godot.
5. **Nieużywane assety** (tileset domu, część teł, `src/obrazki/*`) —
   zachowujemy w repo jako materiał na przyszłe levele/dekoracje; katalog w
   `ASSET_INVENTORY.md`, decyzja o użyciu per-level przy Fazie World, nie
   migrujemy ich hurtem teraz.
6. **Menu/HUD/ustawienia** — też migrują do Godota (`Control`-based UI),
   zgodnie z planem Godot zastępuje cały runtime gry, nie tylko warstwę
   gameplay. Szczegóły (czy zostaje jakikolwiek wrapper webowy) ustalimy przy
   Fazie UI.

Żadna z powyższych decyzji nie jest jeszcze zaimplementowana w Godot —
uaktualnia to wyłącznie zakres i dokumentację. Kod Phaser (`src/game/phaser/`)
pozostaje nietknięty do pełnej migracji, zgodnie z Zasadą 1.

## Postęp implementacji (branch `migration/input-player`, 2026-08-31)

Pierwszy wycinek vertical slice: **Input + Player movement + minimalne
kolizje**. Pliki:

- `godot/project.godot` — `InputMap` (`move_up/down/left/right`, `sprint`,
  `hop`, `interact`, `inventory`, `pause`), `run/main_scene` wskazuje na
  `TestLevel.tscn`.
- `godot/scripts/gameplay/player/PlayerMovement.gd` — `CharacterBody2D`
  ruch: `WALK_SPEED=230`, `RUN_SPEED=380`, `ACCELERATION=2200`,
  `FRICTION=1300` (1:1 ze stałymi w `LevelScene.ts`, patrz
  `GAMEPLAY_BEHAVIOR.md` → "Ruch podstawowy").
- `godot/scenes/player/Player.tscn` — `CharacterBody2D` + `CollisionShape2D`
  (28×40 prostokąt, placeholder rozmiar) + `Sprite2D` (bez tekstury —
  import assetów to osobna faza) + `Camera2D` (position smoothing jako
  przybliżenie lerp 0.12/klatkę z Phaser — do zmierzenia i dostrojenia po
  uruchomieniu w edytorze) + `InteractionArea` (`CircleShape2D`, promień
  100px, zgodnie z audytem — nieaktywna, czeka na system interakcji).
- `godot/scenes/levels/TestLevel.tscn` — jedna instancja Playera + jeden
  `StaticBody2D` do ręcznego smoke-testu kolizji.

**Świadomie NIE zrobione w tym kroku** (żeby diff został przeglądalny, patrz
Zasada 3 z `god/godot2.md`): sprint zależny od energii, `sprintMode` toggle,
squash/stretch, lean, ghost-trail, drift na ostrym skręcie, warstwy kolizji
(`COLLISION_MATRIX.md` nie istnieje jeszcze).

### Aktualizacja: Hop mechanic (ten sam branch)

Dodano `godot/scripts/gameplay/player/PlayerHop.gd` — komponent `Node`
(dziecko `Player`), nie modyfikuje `CharacterBody2D`/`move_and_slide()`
bezpośrednio. `PlayerMovement.gd` woła `hop.update(delta, input_dir)` na
początku `_physics_process()` i używa zwróconej prędkości zamiast własnej,
gdy hop jest aktywny — jawna kolejność zamiast polegania na kolejności
przetwarzania węzłów w drzewie Godota.

Sparowane ze specyfikacją w `GAMEPLAY_BEHAVIOR.md`: `DURATION=0.32s`,
`SPEED=361.0` (`RUN_SPEED*0.95`), `ARC_HEIGHT=22px` (czysto wizualny offset
`Sprite2D.position.y`, sinusoida), `BUFFER_WINDOW=0.15s`,
`COYOTE_WINDOW=0.12s`, `COOLDOWN=0.26s`. Kierunek hopa: bieżący input →
ostatni kierunek hopa (jeśli w oknie coyote) → kierunek "twarzy" (ostatni
niezerowy input) → `Vector2.DOWN` jako ostateczny fallback.

Sygnały `hop_started(direction)` / `hop_landed` wyemitowane, ale
niepodłączone — camera shake i pył pod łapami czekają na systemy Camera i
VFX (kolejność w `MIGRATION_MATRIX.md`).

**Status walidacji:** kod nie był uruchomiony w edytorze Godot przez sesję
AI — w tym środowisku nie ma zainstalowanego Godota. Użytkownik ma lokalnie
Godota i testuje ten branch; wymaga ręcznej weryfikacji (otworzyć
`godot/project.godot`, uruchomić `TestLevel.tscn`, sprawdzić ruch WASD,
sprint na Shift, zatrzymanie na przeszkodzie, oraz hop na Space — kierunek,
czas trwania/wysokość łuku "na oko", i że spamowanie Space nie psuje stanu)
przed oznaczeniem statusu jako `TESTED`.

## Aktualizacja: Dane, Inventory, Quest, Item/Goal (ten sam branch)

Drugi wycinek vertical slice: **dane Poziomu 1 jako Resource + Inventory +
QuestUtils (1:1 port) + żywe interaktywne obiekty (item pickup, goal)**.

Nowe pliki:
- `godot/scripts/core/{ItemData,LevelObjectData,QuestStepData,LevelData}.gd`
  — Resource klasy, patrz `DATA_MODEL.md` → "Godot target". `QuestStepData`
  jest jedną płaską klasą z polem `kind`, nie trzema podklasami (uzasadnienie
  w komentarzu pliku) — rozstrzyga otwarte pytanie z R9.
- `godot/data/items/*.tres` (11 sztuk) + `godot/scripts/core/ItemRegistry.gd`
  (statyczny loader — ścieżki wypisane jawnie, nie skanowane w runtime).
- `godot/data/levels/level_1.tres` — pełne dane Poziomu 1 (Wały Chrobrego):
  7 przeszkód, 3 itemy, 1 cel z `requires`, 3 questy. **Najbardziej ryzykowna
  składnia w tej paczce:** `Array[ExtResource(...)]([...])` dla pól
  `quests`/`objects` — jeśli Godot odrzuci ten plik przy starcie, to
  pierwsze miejsce do sprawdzenia.
- `godot/scripts/gameplay/inventory/Inventory.gd`,
  `godot/scripts/gameplay/quests/QuestUtils.gd` — 1:1 porty, statyczne,
  `RefCounted`, bez zależności od `SceneTree` (jak oryginał w TS).
- `godot/scripts/gameplay/world/LevelBuilder.gd` — buduje `LevelData.objects`
  w żywą scenę: `StaticBody2D` (obstacle), `ItemPickup`/`GoalArea` (`Area2D`,
  `scenes/interactables/`). `npc`/`trigger` jeszcze nie obsłużone (żaden
  przeniesiony poziom ich nie używa).
- `godot/scripts/gameplay/world/LevelRuntime.gd` — root skryptu poziomu:
  buduje scenę, łapie sygnały `collected`/`reached`, liczy inventory przez
  `Inventory.inventory_from_collected()`, sprawdza `requires` na celu,
  przelicza questy przez `QuestUtils.compute_quests()` i loguje status do
  konsoli (`print()`) — świadomy placeholder zamiast HUD, nie zapomniany
  debug (HUD to osobna faza, `MIGRATION_MATRIX.md`).
- `godot/scenes/levels/Level1.tscn` — nowa scena główna
  (`run/main_scene` w `project.godot` przestawiony z `TestLevel.tscn` na
  ten plik); `TestLevel.tscn` zostaje jako prostszy smoke-test ruchu/kolizji.

**Znany bug znaleziony i naprawiony przed testem:** `ItemPickup`/`GoalArea`
początkowo ustawiały rozmiar kolizji przez `@onready var _shape` — ale
`LevelBuilder` woła `set_shape_size()` zaraz po `instantiate()`, zanim węzeł
wejdzie do drzewa sceny, więc `@onready` jeszcze by nie zadziałało (byłby
`null`). Naprawione na bezpośrednie `$CollisionShape2D` w miejscu wywołania.

**Świadomie NIE zrobione:** pozostałe 5 poziomów (tylko Poziom 1
przeniesiony), NPC/patrol, danger triggery, "naciśnij E" jako alternatywa
dla overlapu, camera punch przy pickupie, dźwięki.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI — jak wyżej,
użytkownik testuje lokalnie. Sprawdzić w kolejności: (1) czy
`level_1.tres` w ogóle się parsuje, (2) czy `Level1.tscn` startuje bez
błędów, (3) zbieranie piłeczki/smakołyka usuwa obiekt i loguje w konsoli
`[LevelRuntime] quests 1/3` itd., (4) wejście w bramę bez obu itemów loguje
"goal blocked, missing: ...", z oboma — "level completed".

### Aktualizacja: diagnostyka braku ruchu (ten sam branch)

Użytkownik potwierdził: `level_1.tres` parsuje się, `Level1.tscn` startuje
bez błędów w Output/Debugger, kształty placeholder (Polygon2D — dodane w tym
kroku, bo `Sprite2D`/`StaticBody2D`/`Area2D` bez tekstury i bez włączonego
"Visible Collision Shapes" są niewidoczne) są widoczne, ale **gracz nie
reaguje na WASD**.

Brak błędów + widoczna scena zawęża przyczynę do: focus okna gry (częsty
Godotowy gotcha — kliknięcie w okno edytora ≠ focus okna gry), albo realny
problem w `Input`/`_physics_process`. Dodano tymczasową diagnostykę:

- `godot/scripts/gameplay/world/DebugHud.gd` (**TYMCZASOWE, do usunięcia po
  zdiagnozowaniu** — oznaczone w komentarzu pliku) — `Label` w
  `CanvasLayer`, co klatkę pokazuje `Input.get_vector(...)`,
  `player.velocity`, stan `sprint`/`hop`. Podłączone w `Level1.tscn` jako
  `DebugHudLayer/DebugHud`.
- Przy pisaniu tego skryptu złapany ten sam błąd typowania co wcześniej przy
  `LevelBuilder`: `get_tree().get_first_node_in_group("player")` zwraca
  statycznie `Node`, więc `player.velocity` (pole istniejące tylko na
  `CharacterBody2D`) wymaga **nietypowanej** zmiennej (`=`, nie `:=`) —
  inaczej analizator GDScript odrzuciłby to na etapie kompilacji.

**Rozwiązane:** po kliknięciu w okno gry (focus) WASD zadziałał —
przyczyną był brak focusu okna gry, nie błąd w kodzie. `DebugHud.gd` usunięty
z `Level1.tscn` i z repo (posłużył jednorazowo, cel osiągnięty). Player
movement + Hop przechodzą z `IMPLEMENTED` na **`TESTED`** (ruch WASD
potwierdzony w edytorze przez użytkownika); hop, sprint, item pickup i goal
nadal czekają na osobne potwierdzenie w tej samej sesji testowej.

## Aktualizacja: Camera (2D) — shake + pulse-zoom (ten sam branch)

Trzeci wycinek: **`CameraFX.gd`**, skrypt bezpośrednio na węźle `Camera2D`
dziecku `Player` (nie osobny komponent — oba efekty działają na własnym
zoom/offset tego węzła). Podłączenia:

- `PlayerHop.hop_landed` → `PlayerMovement._on_hop_landed()` →
  `camera.shake(0.06, 2px)`.
- Twarda kolizja ze ścianą (edge-triggered przez `_was_colliding`, próg
  prędkości > 40px/s jak w Phaser) → `camera.shake(0.07, 3px)`.
- `ItemPickup.collected` → `LevelRuntime._pulse_player_camera()` →
  `camera.pulse_zoom(1.03, 0.16)`.

**Świadome odejście od literalnych stałych Phaser:** Phaser's `shake(duration,
intensity)` używa `intensity` jako ułamka rozmiaru ekranu — nie przenosi się
1:1 na piksele offsetu w Godot. Amplitudy (2px/3px) dobrane "na oko", nie
przeliczone z `0.001`/`0.0015` z `GAMEPLAY_BEHAVIOR.md`. Udokumentowane w
komentarzu `CameraFX.gd`, nie ukryte odejście.

**Znaleziony i naprawiony przed testem:** `CameraFX.gd` nie miał
`class_name` mimo że `PlayerMovement.gd` używa `CameraFX` jako typu
(`@onready var _camera: CameraFX = $Camera2D`) — to by nie skompilowało się
w ogóle. Dodane.

**Świadomie NIE zrobione:** camera pulse przy otwarciu dialogu (system
dialogu nie istnieje), `reducedMotion` (Settings nie zmigrowany).

**Status walidacji:** potwierdzone przez użytkownika (2026-08-31) — "dziala
wszystko": hop (kierunek/czas trwania/łuk/spam), sprint, zbieranie
przedmiotów + log questów, blokada/ukończenie celu, oraz wszystkie efekty
kamery (shake przy lądowaniu z hopa, shake przy kolizji ze ścianą przy
sprincie, pulse-zoom przy zbieraniu itemu). Player movement, Hop, Input
(WASD/sprint/hop), Item pickup/Goal reach i Camera (2D) przechodzą z
`IMPLEMENTED` na **`TESTED`** w tabeli powyżej. Pierwszy pełny vertical
slice (Poziom 1, end-to-end) jest zamknięty i zwalidowany.

## Aktualizacja: kolejny krok — pozostałe poziomy danych

Zgodnie z kolejnością w tabeli (`Kolejne kroki` w `godot/README.md`),
następny subsystem to przeniesienie danych poziomów 2–6 z
`src/game/levels.ts` do `godot/data/levels/level_N.tres`, tym samym wzorcem
co `level_1.tres` (już zwalidowanym — `Array[ExtResource(...)]([...])`
syntax potwierdzony jako poprawny, bo Poziom 1 wczytuje się i działa).
Wszystkie potrzebne itemy są już w `ItemRegistry` (11 sztuk, zakładając że
pokrywają wszystkie poziomy — do zweryfikowania przy przenoszeniu).

**Zrobione:** `godot/data/levels/level_2.tres` … `level_6.tres` utworzone,
1:1 z `src/game/levels.ts` (obstacles/items/npc/goal objects, quests,
mood). Wszystkie referencje itemów (`mouse`, `leaf`, `star`, `bowl`, `key`,
`yarn`, `feather`, `photo`) już istnieją w `ItemRegistry` — nic nie brakuje.
`background` pozostaje placeholder string (`"park1"`, `"attic"`, itd. —
asset import to osobna faza, patrz `godotassets.md`).

Dodano też odpowiadające sceny `godot/scenes/levels/Level2.tscn` …
`Level6.tscn` (ten sam trzy-węzłowy wzorzec co `Level1.tscn`: `LevelRuntime`
root + `level` export + `Player` na pozycji `spawn` z danych poziomu), żeby
każdy poziom dało się uruchomić osobno w edytorze bez menu (menu/level-select
to osobna faza — "Build/routing/menu" w tabeli, nadal `PLANNED`).

**Świadomie NIE zrobione:** `npc`-kind obiekty (squirrel w L2, pigeon w L5,
kot w L6) i "talk"-kind questy są przeniesione jako dane (parsują się,
`QuestUtils.compute_quests()` już je obsługuje), ale `LevelBuilder.gd`
nadal buduje tylko `obstacle`/`item`/`goal` — NPC-e się nie zmaterializują
w scenie i questy "talk" nigdy nie przejdą na `done`, dopóki NPC-system
(patrol, dialog, "podaj przedmiot") nie zostanie zaimplementowany. To nie
regresja tego kroku — ten sam stan co `level_1` (który nie ma NPC-ów wcale).
Levels 2, 5, 6 więc nie są grywalne end-to-end, dopóki NPC nie powstanie;
L3 i L4 (bez NPC) powinny być grywalne end-to-end już teraz.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia w kolejności: (1) czy każdy `level_N.tres` się parsuje bez
błędów, (2) czy `LevelN.tscn` startuje i loguje poprawną liczbę questów
(2 dla L3/L4, 3 dla pozostałych — pamiętając że "talk" questy w L2/L5/L6
nigdy nie przejdą na `done` bez NPC-systemu), (3) L3 (Aleja Kasztanowa) i L4
(Strych) grywalne od startu do celu, bo nie mają questów "talk".

## Aktualizacja: NPC system (patrol + talk + gift), branch `migration/input-player`

Zbudowano `godot/scripts/gameplay/world/NpcActor.gd` (`Area2D`, `scenes/interactables/NpcActor.tscn`),
odblokowujący L2/L5/L6:

- Overlap-triggered `talked(obj_id)` sygnał (`body_entered`, guard `is_in_group("player")`)
  — w przeciwieństwie do `ItemPickup` NPC **nie** znika (`queue_free()`) po rozmowie, zgodnie
  z oryginałem (NPC zostaje na scenie, można podejść ponownie).
- Patrol: ruch poziomy `_physics_process()` wokół `_base_x` (pozycja spawnu) w zakresie
  `patrol_range` (pełny zakres, połówka w każdą stronę — 1:1 z `updatePatrols()` w
  `LevelScene.ts`), odbicie kierunku na krańcach, `scale.x` odwracany przy zmianie kierunku
  (odpowiednik `setScale(dir, 1)`). `patrol_range == 0` → statyczny (sąsiad-kot, L6).
- `LevelBuilder._build_npc()` instancjonuje z `LevelObjectData` (`npc_id`, `patrol_range`,
  `patrol_speed`), dodany do zwracanej listy `interactables` obok item/goal.
- `LevelRuntime._on_npc_talked()`: dopisuje `obj_id` do `_talked` (idempotentnie — questy
  "talk" sprawdzają tylko przynależność), sprawdza `Inventory.NPC_GIFTS` po `npc_id` i
  przyznaje prezent (yarn/feather/key) raz, jako syntetyczny wpis w `_collected_ids` przez
  `Inventory.gift_obj_id()` — dokładnie ten sam schemat co `PhaserGameCanvas.tsx: onTalk`.
  Camera pulse odpala się też przy otrzymaniu prezentu (ten sam `_pulse_player_camera()`).

**Świadomie NIE zrobione:** "naciśnij E" jako alternatywa dla overlapu (potrzebuje systemu
najbliższego interaktywnego obiektu w promieniu 100px — nieporortowany), dialog UI (nadal
`print()` do konsoli zamiast okna dialogowego), ikona 💬 nad głową gracza.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do sprawdzenia: (1) L2 —
podejście do wiewiórki loguje `talked: squirrel` i `gift received: yarn`, wiewiórka
patroluje w poziomie; (2) L5 — analogicznie gołąb/feather, patrol; (3) L6 — kot statyczny,
`gift received: key`; (4) we wszystkich trzech: quest "talk" przechodzi na `done` w logu
questów po rozmowie, a cel (`goal`) można ukończyć dopiero po zebraniu prezentu.

## Aktualizacja: HUD (minimalny slice) + LevelSelect menu, branch `migration/input-player`

Zbudowano dwa niezależne kawałki UI, oba `Control`-based, oba zastępujące
dotychczasowe placeholdery (`print()` / brak entry pointu):

**HUD** — `godot/scripts/presentation/ui/HUD.gd` (`CanvasLayer`) +
`scenes/ui/HUD.tscn`. Trzy elementy: lista questów (`Label` per quest,
prefiks `[x]`/`[!]`/`[ ]` + licznik `current/total` gdy `total > 1`,
przygaszenie po ukończeniu), rząd chipów inventory (`emoji xN`, "Pusty
plecak" gdy brak), oraz `MessageLabel` na dole ekranu pokazujący ostatnią
wiadomość NPC/goal (prowizoryczny zamiennik `DialogBox` — bez auto-hide,
bez historii, tylko ostatnia wiadomość). `LevelRuntime.gd` instancjonuje HUD
w `_ready()`, karmi go przez `update_status()` z `_update_status()`
(przemianowane z `_log_quest_status()`), i woła `hud.set_message()` w
`_on_npc_talked()`/`_on_goal_reached()`. Per-obiektowe `print()` (collected/
talked/gift/goal) zostały jako lekki log deweloperski w konsoli, obok HUD-a,
nie zamiast niego.

**LevelSelect** — `godot/scripts/presentation/menu/LevelSelectMenu.gd`
(`Control`) + `scenes/menu/LevelSelect.tscn`. Lista wszystkich 6 poziomów
(tytuł/podtytuł 1:1 z `src/routes/menu.tsx`), przycisk "Graj" na
`change_scene_to_file()`. Wszystkie poziomy zawsze dostępne — kolejnościowe
odblokowanie (`unlockHint`) wymaga Save systemu (nadal `ANALYZED`), świadomie
odłożone. `project.godot`'s `run/main_scene` **nie zmieniony** (zostaje
`Level1.tscn`) — ten ekran uruchamia się osobno w edytorze (F6) na razie.

**Świadomie NIE zrobione:** w HUD — pasek energii, tracker dystansu/legenda,
timer/best-time, animacje/flash/tooltips, stylowanie (domyślny theme
silnika); w LevelSelect — unlock gating, best-time, achievements link,
spójny theme/stylowanie z resztą gry, przejście na LevelSelect jako
`run/main_scene`.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) czy `Level1.tscn` startuje z widocznym HUD-em (lista
questów + inventory), (2) czy zbieranie itemu/rozmowa z NPC/dotarcie do celu
aktualizuje HUD na żywo, (3) czy wiadomość NPC/goal pojawia się w
`MessageLabel`, (4) czy `scenes/menu/LevelSelect.tscn` uruchomiony osobno
(F6) pokazuje listę 6 poziomów i "Graj" faktycznie ładuje odpowiedni
`LevelN.tscn`.

## Aktualizacja: Save/Load (minimalny slice, `ProgressStore` autoload)

Zbudowano `godot/scripts/infrastructure/ProgressStore.gd`, zarejestrowany
jako autoload w `project.godot` (`[autoload] ProgressStore=...`) — pierwszy
autoload w projekcie, świadomie ("używane oszczędnie", `god/godot2.md`):
to jest naprawdę globalny, trwały, cross-scene stan, ta sama kategoria co
zustand `persist` store w TS, nie wygodny globalny skrót.

- Persystuje `unlocked_levels`, `level_progress` (`completed` +
  `items_collected`), `talked_npcs`, `best_level_times` do
  `user://progress.json` (JSON, nie Resource — prostsze dla dict-of-dict
  kształtu, żadna z tych struktur nie jest edytowana ręcznie w edytorze jak
  `.tres`). Autosave przy każdej zmianie (`save_progress()` wołane z każdej
  `record_*` metody) — 1:1 z zustand `persist` piszącym synchronicznie przy
  każdym `set()`.
- `LevelRuntime._ready()` czyta `ProgressStore.items_collected_for()`/
  `talked_for()`/`is_completed()` przy starcie sceny (odpowiednik
  `startLevel()` odtwarzającego inventory z `itemsCollected`), i przekazuje
  `_collected_ids` do `LevelBuilder.build()`, który teraz pomija obiekty
  `item` już zebrane (`obj.collected || collectedIds.has(obj.id)` z
  `LevelScene.ts`). Każdy `_on_item_collected`/`_on_npc_talked`/
  `_on_goal_reached` teraz też pisze do `ProgressStore` (nie tylko do
  lokalnych `_collected_ids`/`_talked` jak wcześniej).
- `_next_level_id()`: poziomy numerowane "1".."6", następny to `+1` (bez
  osobnego rejestru `LEVELS` w Godot — `LevelSelectMenu` ma swoją własną
  listę). Best time liczony przez `Time.get_ticks_msec()` przy starcie i
  ukończeniu sceny.
- `LevelSelectMenu.gd` zaktualizowany: przycisk "Graj" wyłączony
  ("Zablokowane") dla nieodblokowanych poziomów, ✓ + sformatowany czas przy
  ukończonych.

**Świadomie NIE zrobione:** `SaveSlot` (zapis pozycji/energii w trakcie
poziomu, potrzebuje Energy systemu — nadal `ANALYZED`), controls/volume/
totalHops/totalDistanceWalked/dailyHistory/tutorialStage (żadne nie blokują
gameplayu ani level-selecta), wersjonowanie schematu zapisu (zustand's
`migrate`/`version` — na razie jeden płaski format, do zaprojektowania gdy
pojawi się pierwsza zmiana kształtu), UI do `reset_progress()` (metoda
istnieje, nic jej jeszcze nie woła).

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) zebranie itemu na L1, restart gry (zamknięcie i ponowne
uruchomienie edytora/gry) — item nie pojawia się ponownie, HUD od razu
pokazuje go jako zebrany; (2) ukończenie L1 odblokowuje L2 w
`LevelSelect.tscn` (przycisk aktywny, bez restartu edytora — działa w tej
samej sesji gry, bo `ProgressStore` jest w pamięci); (3) po restarcie gry
`LevelSelect.tscn` nadal pokazuje L2 jako odblokowany (czyli
`user://progress.json` faktycznie się zapisał i wczytał); (4) ukończony
poziom pokazuje ✓ i czas w formacie `m:ss`; (5) plik `user://progress.json`
istnieje i ma sensowną zawartość (ścieżka na Windows: zwykle
`%APPDATA%/Godot/app_userdata/Edek/progress.json`).

## Aktualizacja: Audio (proceduralne, `AudioService` autoload)

Zbudowano `godot/scripts/infrastructure/AudioService.gd`, trzeci autoload
(`[autoload] AudioService=...` w `project.godot`). Decyzja "procedural vs
próbki" z audytu (decyzja #3) rozstrzygnięta przez przeczytanie
`src/lib/audio.ts`: to w całości `AudioContext` + `OscillatorNode`
(fala sinusoidalna) + `GainNode` z `exponentialRampToValueAtTime` — nie ma
żadnych plików dźwiękowych do zaimportowania. Godot's `AudioStreamGenerator`
jest bezpośrednim odpowiednikiem tej syntezy.

- Pula 8 "głosów" (`AudioStreamPlayer` + `AudioStreamGenerator` per głos),
  każdy niezależnie odtwarza jeden ton — potrzebne bo `playPickup`
  (dwa tony 60ms od siebie) i `playCompletion` (trzy tony jednocześnie,
  akord durowy) nakładają się w czasie.
- `play_tone(freq, duration_ms, volume)` generuje falę sinusoidalną z
  obwiednią zanikającą wykładniczo do `0.001` — 1:1 z
  `gain.exponentialRampToValueAtTime(0.001, ...)` w TS.
- `play_pickup()`, `play_completion()`, `play_danger()` — 1:1 porty
  częstotliwości/czasów/głośności z `SimpleAudio`. Podłączone:
  `LevelRuntime._on_item_collected()` → `play_pickup()`,
  `_on_goal_reached()` (przy ukończeniu) → `play_completion()` — dokładnie
  tam gdzie `PhaserGameCanvas.tsx` je woła (gift NPC świadomie NIE gra
  dźwięku, bo TS też tego nie robi dla prezentów).

**Świadomie NIE zrobione:** `play_danger()` niepodłączone (brak `trigger`
obiektów w jakimkolwiek przeniesionym poziomie), głośność/mute (Settings
system nie zmigrowany — wszystko gra na pełnej głośności na sztywno).

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) zbieranie itemu gra rosnący "ćwierk" (dwa tony), (2)
ukończenie poziomu gra akord durowy (trzy tony jednocześnie), (3) brak
trzasków/artefaktów audio przy nakładających się dźwiękach (np. szybkie
zbieranie kilku itemów pod rząd).

## Aktualizacja: Proximity/goal hints (minimalny slice, tekstowy)

Zbudowano `godot/scripts/gameplay/quests/GoalProximity.gd` (statyczny, bez
zależności od `SceneTree` — jak `Inventory.gd`/`QuestUtils.gd`), 1:1 port
`proximity.ts`: klasyfikacja obiektu na archetyp (`gate`/`chest`/`food`/
`spot`) po słowach w id + `item_id`, promienie `at`/`near`/`mid` liczone z
połowy przekątnej prostokąta obiektu i profilu archetypu.

`LevelRuntime.gd` dostał `_process(delta)` (throttled do 10/s, nie każda
klatka fizyki — podpowiedź dystansu nie potrzebuje precyzji 60fps):
`_compute_tracks()` dla każdego nieukończonego questu "reach" (dystans do
celu) i "collect" (dystans do najbliższego pozostałego itemu danego typu —
1:1 z logiką "nearest" w `useGoalTracks()`) liczy tier (`tier_for()`) i
dystans, przekazuje do `HUD.update_proximity()`. HUD dopisuje do wiersza
questu tekstowy hint w formacie `· blisko (~N kr.)` (N = kroki, `dist/32`,
ta sama jednostka co `DistanceBadge` w `HUD.tsx`).

**Świadomie NIE zrobione:** strzałka on-canvas wskazująca kierunek do celu
i kolorowy badge z `tierStyle.ts` (czysto wizualne, CSS/Tailwind/SVG —
nieprzenaszalne wprost, wymagałyby osobnego rysowania w `_draw()` lub
sprite'a; niska wartość przy braku prawdziwej grafiki), tryb kolorślepy,
wygładzanie dystansu/kąta z `goalTracking.ts` (React `requestAnimationFrame`
lerp — tu hint aktualizuje się skokowo co ~100ms zamiast płynnie, co dla
tekstu jest niezauważalne), legenda dystansu (auto-collapse UI z `HUD.tsx`).

**Bug znaleziony i naprawiony przy pierwszym uruchomieniu przez użytkownika**
(2026-08-31): `goal_proximity()` czytał pola z `profile` (typu `Dictionary`)
przez `var raw := half_diag * profile.size_factor + profile.slack` —
wartości z `Dictionary` są `Variant`, więc `:=` nie mogło wywnioskować typu
(ten sam błąd co wcześniej w `LevelBuilder`/`DebugHud`, Godot zamykał się
przy Play). Naprawione jawnym rzutowaniem każdego pola na `float` przed
użyciem. **Po naprawie: Godot uruchamia się i Play działa** (potwierdzone
przez użytkownika) — pierwszy rzeczywisty test całego zestawu zmian z tej
sesji (autoloady, HUD, NPC, Save/Load, Audio, proximity hints).

**Status walidacji:** boot potwierdzony. Szczegółowe testy per-system
(patrz punkty w `godot/README.md`, sekcja "Czego tu NIE ma") wciąż czekają.
Do sprawdzenia dla proximity hints konkretnie: (1) podczas questu "reach" (np. brama na L1) HUD pokazuje
`· <tier> (~N kr.)` obok etykiety questu, tier zmienia się (`daleko` →
`średnio` → `blisko` → `tuż obok`) w miarę zbliżania się gracza; (2) dla
questu "collect" (np. piłeczka na L1) hint wskazuje dystans do najbliższej
pozostałej sztuki, znika po zebraniu wszystkich (`status.done`); (3) brak
zauważalnego spadku FPS od dodatkowego przeliczania co 100ms.

## Aktualizacja: Assety — Player sprite + tło Poziomu 1

**Zweryfikowane przed implementacją (nie zgadywane):** przeczytano
`god/godotassets.md` i `docs/migration/ASSET_INVENTORY.md`, sprawdzono
pliki w `src/assets/` (`ls`) i ich wymiary piksela (PowerShell
`System.Drawing.Image`). Kluczowe ustalenie: **tła poziomów 1-6 to
pojedyncze, pełnoklatkowe, pre-renderowane obrazy sceny (`waly-merged.jpeg`
= 3200×900, dokładnie `LevelData.width/height` Poziomu 1), NIE tileset.**
Jedyny prawdziwy tileset w repo (`TopDownHouse_*`) jest jawnie
nieużywany przez żaden z 6 poziomów (potwierdzone w `ASSET_INVENTORY.md`)
— to materiał na przyszły, niezaimplementowany poziom wnętrza domu.
`TileMapLayer` więc nie ma zastosowania do Poziomów 1-6 w obecnym stanie
gry; `obstacle`/`item`/`goal` `Rect2` z `LevelData` to niewidzialne strefy
kolizji/interakcji nałożone na już-gotową grafikę tła, nie siatka kafelków.

Zaimportowano i podłączono (branch `migration/input-player`, level-by-level
zgodnie z instrukcją):

- **Player**: `godot/assets/textures/characters/edek-sprite.png` (896×1200,
  3 kolumny × 4 rzędy — down/left/right/up, 1:1 z `SHEET_COLS`/`SHEET_ROWS`/
  `DIRECTION_ROWS` w `LevelScene.ts`). `godot/scenes/player/EdekSpriteFrames.tres`
  — `SpriteFrames` z 4 animacjami `walk-{down,left,right,up}`, klatki
  `[0,1,2,1]` @ 8fps — 1:1 z `sliceCatFrames()`. `Player.tscn`'s `Sprite2D`
  węzeł zmieniony z pustego `Sprite2D` na `AnimatedSprite2D` (ta sama nazwa
  węzła — `PlayerMovement.gd`'s `$Sprite2D` referencja nie wymagała zmiany,
  tylko typu w `@onready`), przeskalowany do wyświetlanego rozmiaru ~64px
  (`CAT_SIZE` w `LevelScene.ts`) przez `scale = Vector2(0.2143, 0.2133)`.
  `PlayerMovement._update_animation()` (nowa funkcja, wołana z
  `_physics_process()` po `move_and_slide()`): kierunek z dominującej osi
  prędkości (`abs(vx)>abs(vy)` → left/right, inaczej up/down — 1:1 z
  `update()` w `LevelScene.ts`, NIE "ostatni wciśnięty klawisz"), animacja
  zamraża się na bieżącej klatce w bezruchu (`_sprite.stop()`, nie reset do
  klatki idle — 1:1 z `anims.stop()`).
- **Tło Poziomu 1**: `godot/assets/textures/environment/waly-merged.jpeg`.
  `godot/scripts/gameplay/world/LevelBackgrounds.gd` (statyczny rejestr,
  wzorzec `ItemRegistry.gd` — ścieżki wypisane jawnie, level-id → texture
  path, puste ID = brak tła, nie błąd). `LevelRuntime._setup_background()`
  dodaje `Sprite2D` (`z_index=-100`, przeskalowany do dokładnych
  `level.width`/`level.height`) i zwraca `bool` czy tło istnieje.
  `LevelBuilder.build()` dostał nowy parametr `hide_obstacle_visual` — gdy
  `true`, szare `Polygon2D` przeszkód są `visible=false` (kolizja zostaje)
  bo tło już pokazuje tę geometrię wizualnie; itemy/NPC/cel **zostają
  widoczne** (żółty/różowy/zielony) bo te wciąż nie mają prawdziwej grafiki.
- **Atmosfera**: `godot/scripts/presentation/atmosphere/AtmosphereFX.gd`
  (nowy, minimalny port `AtmosphereFX.ts` — punktowe światło + światło przy
  kocie jako addytywny sprite z gradientem radialnym zamiast Godot's
  natywnego `Light2D` [ta sama logika co unikanie Phaser 4's usuniętego
  `Lights2D` w źródle — prostszy, stabilny API zamiast ryzykownego
  dynamicznego oświetlenia na jeszcze-greyboxowej grze], plus
  `CPUParticles2D` per `ambientFx` typ [motes/dust/petals/stars] —
  przybliżenie, nie 1:1 port prędkości X/Y, patrz komentarz w pliku).
  Podłączony w `LevelRuntime._ready()` jako dziecko, wywoływany raz z
  `level`+`player`. Post-FX color grade (vignette, colorMatrix) **NIE
  ported** — flagowane w audycie jako R2 "API niepewne", osobna, większa
  praca (patrz komentarz w pliku).

**Aktualizacja: tła Poziomów 2-6 dodane w tym samym kroku** (mechaniczne
powtórzenie tego samego wzorca co L1, więc zrobione razem zamiast osobno
per-level, mimo instrukcji "level po levelu" — uzasadnienie: identyczny,
zweryfikowany kod ścieżki, zero nowej logiki, tylko dane w
`LevelBackgrounds._PATHS`; ryzyko regresji ograniczone do "obrazek się nie
wczyta", nie do zachowania gry):
- `park-merged.jpeg` (L2), `alley-merged.jpeg` (L3) — 3200×900, dokładnie
  jak L1, zero skalowania niedokładnego (`Sprite2D.scale` wychodzi 1.0).
- `level-attic.jpg` (L4), `level-garden.jpg` (L5) — 1920×1080 vs
  `LevelData` 1600×900 — ten sam aspect ratio 16:9, skalowanie 0.833×
  jednolite w obu osiach, bez zniekształcenia.
- `lu.jpeg` (L6) — 2400×1792 vs `LevelData` 1600×1200 — aspect ratio
  1.339 vs 1.333, rozbieżność <0.5%, rozciągnięcie niezauważalne.

Wszystkie sześć zarejestrowane w `LevelBackgrounds._PATHS`, zero zmian w
`LevelRuntime.gd`/`LevelBuilder.gd` potrzebnych — generyczna logika
skalowania (`level.width / texture.get_width()`) już to obsługuje.

**Świadomie NIE zrobione:** foreground leaves layer, post-FX color grade,
prawdziwa grafika dla item/NPC/goal (nadal kolorowe kwadraty),
squash/stretch/lean na sprite'cie kota, prędkość animacji skalowana z
prędkością ruchu (`timeScale` w Phaser).

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) kot wyświetla prawdziwą grafikę (nie pomarańczowy
kwadrat) i animuje się poprawnie w 4 kierunkach podczas ruchu, zamraża się
w bezruchu; (2) Poziom 1 pokazuje prawdziwe tło zamiast szarego tła
silnika, wyrównane z układem przeszkód (drzewa/budynki z tła pokrywają się
z niewidzialnymi strefami kolizji — spacer nie powinien "przenikać" przez
narysowane drzewo ani zatrzymywać się na pustym miejscu); (3) światło
punktowe (`pointLight` z L1) widoczne jako ciepła poświata z delikatnym
migotaniem; (4) przy `ambient: "night"` widoczna poświata wokół kota;
(5) drobinki (`ambientFx: "motes"` na L1) widoczne, subtelne, nie
przytłaczające.

## Aktualizacja: item/NPC/goal renderowane jako emoji (nie kolorowe kwadraty)

**Ustalenie kluczowe dla zakresu:** `src/game/items.ts` pokazuje, że każdy
`ItemDef` niesie pole `emoji` — `LevelScene.ts` renderuje itemy/NPC/cele
przez `this.add.text(...)` z tym emoji jako glifem, **nie custom sprite'ami**.
To oznacza, że "prawdziwa grafika" dla tych obiektów już istnieje w
źródle — jako tekst Unicode, nie jako plik graficzny do zaimportowania.
Podmiana kolorowego `Polygon2D` na `Label` z emoji jest więc 1:1 portem
wizualnym, nie dodatkową fazą wymagającą nowych assetów.

Zmiany: `ItemPickup.gd`/`GoalArea.gd`/`NpcActor.gd` dostały `set_icon(icon)`
+ `IconLabel` (`Label`, wyśrodkowany, `font_size = rect.height * 0.9` — 1:1
z `Math.round(obj.rect.h * 0.9)}px` w źródle). Stary `DebugVisual`
(`Polygon2D`) zostaje w scenie z `visible = false` — fallback do włączenia
ręcznie przy debugowaniu kolizji, nie usunięty. `LevelBuilder.gd` dostał
parametr `items: Dictionary` (przekazywany z `LevelRuntime._items`) do
rozwiązania `ItemData.emoji` dla itemów bez własnego `icon`; goal/NPC mają
`icon` ustawiony wprost w danych `.tres` (🏰/🚪/🍂/🐈/🐿️/🐦), więc nie
potrzebują rejestru itemów. `NpcActor`'s patrol mirror (`scale.x = ... * dir`)
odwraca też `IconLabel` razem z resztą węzła — 1:1 z Phaser's
`text.setScale(dir, 1)`.

**Świadomie NIE zrobione:** Godot's domyślna czcionka może nie pokrywać
wszystkich emoji użytych w danych (np. 🐿️/🗝️ ze złożonymi sekwencjami/ZWJ)
— jeśli render pokaże "tofu"/puste kwadraciki zamiast glifu, to font-coverage
gap do rozwiązania osobno (import czcionki z pełniejszym pokryciem emoji,
np. Noto Color Emoji), nie bug w tym kodzie.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) piłeczka/smakołyk/inne itemy na każdym poziomie pokazują
właściwe emoji (⚽/🍤/🐭/🍁/⭐/🥣) wyśrodkowane w swoim obszarze, nie
kwadrat; (2) cele (🏰/🚪/🍂/🐈) i NPC (🐿️/🐦/🐈) analogicznie; (3) żaden
emoji nie renderuje się jako pusty kwadrat/"tofu" (gdyby tak było — problem
pokrycia czcionki, zgłosić); (4) wiewiórka/gołąb podczas patrolu odwraca
emoji razem z ruchem (nie zostaje "przyklejone" w jedną stronę).

## Aktualizacja: subtelny outline dla przeszkód (świadome odejście od Phasera)

Po pierwszym pełnym teście przez użytkownika ze wszystkimi 6 tłami: kot
zatrzymuje się poprawnie na krawędzi krzaków/drzew (kolizja jest zgodna z
tłem — potwierdzone przez użytkownika), ale **nie ma żadnego wizualnego
sygnału**, że coś tam blokuje — sprawia wrażenie "niewidzialnej ściany".

Zweryfikowano, że to zachowanie zgodne z oryginałem: `LevelScene.ts` też
woła `rect.setVisible(false)` na każdym obiekcie `obstacle` — Phaser nigdy
nie rysował ramki przeszkody, poleganie na tym, że artysta tła umieścił
krzak/drzewo dokładnie pod niewidzialnym prostokątem. To nie był więc bug
w porcie, tylko brak wizualnej podpowiedzi odziedziczony z oryginału.

**Decyzja użytkownika:** dodać stały, subtelny outline (nie pełne
wypełnienie) wokół przeszkód — świadome odejście od 1:1 parity z Phaserem
dla lepszej czytelności, nie cofnięcie tej decyzji.

Zaimplementowano w `LevelBuilder._build_obstacle()`: nowy `Line2D`
("outline", zamknięta pętla 5 punktów, `width=2.0`,
`default_color=Color(1,1,1,0.35)`), widoczny dokładnie gdy
`hide_obstacle_visual` jest `true` (czyli tam gdzie prawdziwe tło już
zastąpiło pełne szare wypełnienie). Gdy tła nie ma (teoretyczny przypadek —
obecnie wszystkie 6 poziomów ma tło), stary pełny `Polygon2D` fill nadal
się pokazuje, outline zostaje ukryty (uniknięcie podwójnego rysowania).

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: subtelna biała ramka (nie wypełnienie) widoczna na krawędziach
przeszkód na wszystkich 6 poziomach, wystarczająco delikatna żeby nie
psuć wrażenia prawdziwego tła, ale wystarczająco widoczna żeby dać sygnał
"tu jest ściana" przed zderzeniem.

## Aktualizacja: Post-FX color grade (brightness/contrast/saturation)

Poprzednio świadomie odłożone jako zbyt ryzykowne do wdrożenia bez
możliwości uruchomienia edytora przez sesję AI (R2 z audytu). Użytkownik
aktywnie testuje w tej sesji, więc ryzyko akceptowalne — zaimplementowane.

`AtmosphereFX._setup_post_fx()`: tworzy `WorldEnvironment` +
`Environment` z `adjustment_enabled=true`, `background_mode=BG_KEEP` (żeby
nie nadpisać niczego poza samą korektą kolorów). `level.mood` (per-level
wartości) ma pierwszeństwo nad ogólnym day/night blendem — 1:1 z gałęzią
`if (mood) {...}` w `setupPostFX()`. Fallback bez `mood`: `night` factor
0/0.5/1 dla day/dim/night, `lerpf()` między dziennymi a nocnymi wartościami
brightness/contrast/saturation — te same liczby co w źródle
(1.02→0.92, 1.04→1.08, +0.06→-0.1).

**Rozbieżność jednostek (udokumentowana, nie błąd):** Phaser's `saturate`
w `LevelMood` jest addytywne (0 = bez zmian, ±wartość = delta). Godot's
`adjustment_saturation` jest multiplikatywne (1.0 = bez zmian). Przeliczone
jako `1.0 + saturate` — dla małych wartości (0.05-0.3 w danych poziomów)
efekt wizualny powinien być zbliżony, ale nie jest to matematycznie
identyczna krzywa.

**Świadomie NIE zrobione:** vignette (brak wbudowanego odpowiednika w
`Environment` dla 2D bez custom shadera), hue-rotation i sepia (jw.) —
`mood.hue`/`mood.sepia` z danych poziomów są czytane przez nikogo, zostają
nieużyte pola. To jedyna pozostała różnica względem pełnego
`setupPostFX()` z Phasera.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI — **R2
("API niepewne") nadal formalnie otwarte**, mimo implementacji. Do
sprawdzenia pilnie: (1) `adjustment_*` faktycznie coś zmienia wizualnie na
renderer GL Compatibility (może się okazać że nie ma efektu w ogóle —
to byłby najgorszy przypadek: cichy no-op, nie crash), (2) L1 (mood
sepia+brightness) wygląda cieplej/sepiowo (sepia świadomie nieportowana,
więc może wyglądać tylko jaśniej/kontrastowo bez sepii — to oczekiwane),
(3) poziomy `night`/`dim` bez własnego `mood` (żaden obecnie — wszystkie 6
poziomów ma `mood`) więc fallback day/night lerp jest w praktyce
nieużywany kodem, martwa gałąź do przetestowania osobno jeśli powstanie
poziom bez `mood`.

## Aktualizacja: Energy/Difficulty (sprint drain + gating)

`godot/scripts/gameplay/difficulty/Difficulty.gd` — statyczny 1:1 port
`DIFFICULTIES` z `gameStore.ts` (easy/medium/hard/explorer). `PlayerMovement.gd`
dostał `can_sprint: bool` (domyślnie `true`, gaszony przez `LevelRuntime`),
`is_sprinting`/`is_moving` (czytane przez `LevelRuntime` do naliczania
energii) — sprint teraz wymaga `can_sprint and Input.is_action_pressed
("sprint") and is_moving`, zamiast bezwarunkowego "hold to sprint" z
poprzedniego kroku.

`LevelRuntime._update_energy()` (wołane co klatkę z `_process()`): odejmuje
`sprint_drain_mul * 6.0 * delta` podczas sprintu, dodaje
`rest_recover_mul * 4.0 * delta` gdy gracz stoi w miejscu (NIE podczas
zwykłego chodzenia — 1:1 z `!isMoving` guard w `LevelScene.ts`), `clampf`
do `[0, MAX_ENERGY=100]`. Ustawia `player.can_sprint = energy >=
min_sprint_energy` z powrotem na graczu — sprint faktycznie się wyłącza po
wyczerpaniu energii, tak jak w źródle. HUD dostał `EnergyPanel`/
`EnergyLabel` (`update_energy()`): `"Energia: NN%"` + `"(Zmęczenie)"` i
czerwony tekst poniżej 30% energii — uproszczony tekstowy odpowiednik
paska energii z animacją w `HUD.tsx` (bez paska/animacji, sam procent).

**Świadomie NIE zrobione:** wybór trudności — brak UI selektora (Settings
system, nadal `ANALYZED`), więc `_DIFFICULTY` jest zahardkodowane na
`"medium"` w `LevelRuntime.gd`. `danger_damage` przeniesione w danych, ale
niepodłączone — brak `trigger`/danger obiektów w jakimkolwiek przeniesionym
poziomie. Pasek energii (wizualny gradient/animacja) — tylko tekst.

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) trzymanie Shift podczas ruchu zużywa energię widoczną w
HUD (`Energia: NN%` maleje), (2) stanie w miejscu odzyskuje energię,
zwykłe chodzenie (bez sprintu) NIE odzyskuje ani nie zużywa, (3) przy
energii poniżej progu `min_sprint_energy` (8 dla medium) sprint faktycznie
przestaje działać (prędkość spada do WALK_SPEED mimo trzymania Shift), (4)
poniżej 30% energii etykieta pokazuje "(Zmęczenie)" i zmienia kolor na
czerwony, (5) energia nie spada poniżej 0 ani nie rośnie powyżej 100.

## Aktualizacja: Settings/Controls (minimalny slice, `SettingsStore` autoload)

Zbudowano `godot/scripts/infrastructure/SettingsStore.gd`, czwarty autoload
(`[autoload] SettingsStore=...`). Persystuje `volume`, `muted`,
`difficulty`, `sprint_mode` do `user://settings.json`, autosave przy
każdej zmianie (ten sam wzorzec co `ProgressStore.gd`).

- `SettingsMenu.gd` + `scenes/menu/SettingsMenu.tscn`: `OptionButton`
  trudności (4 pozycje, etykiety z `Difficulty.gd`), `HSlider` głośności
  (0-1, krok 0.05), `CheckBox` wyciszenia, przycisk "Wróć" do
  `LevelSelect.tscn`. Dostęp z `LevelSelectMenu` przez nowy przycisk
  "Ustawienia" (dodany do `Panel/Content/SettingsButton`, `List`
  przeniesione pod nowy węzeł `Content` żeby zmieścić oba obok siebie w
  jednym `PanelContainer`).
- `LevelRuntime.gd`: `_energy = Difficulty.get_config(SettingsStore.difficulty)...`
  (było zahardkodowane `"medium"`) — trudność wybrana w Ustawieniach
  faktycznie wpływa na start energii i tempo drenażu/regeneracji.
- `AudioService.play_pickup()`/`play_completion()` w `LevelRuntime.gd`
  wołane z `SettingsStore.effective_volume()` (0.0 gdy `muted`, inaczej
  `volume`) zamiast domyślnego argumentu 1.0 — głośność i wyciszenie
  faktycznie działają na dźwięki.

**Ważne ustalenie przed implementacją (nie zgadywane):** prześledzono
`sprintMode` przez cały `LevelScene.ts` + `PhaserGameCanvas.tsx` —
`sprintToggled` (pole używane gdy `sprintMode === "toggle"`) jest
ustawiane WYŁĄCZNIE z przycisku dotykowego w HTML overlay
(`PhaserGameCanvas.tsx` linia ~352), nigdy z klawiatury. Klawiatura
(`shiftKey.isDown`) zawsze działa jako "hold", niezależnie od ustawienia
`sprintMode`. Ponieważ Godot nie ma jeszcze żadnego UI dotykowego,
zaimplementowanie "toggle" na klawiaturze byłoby wymyśleniem zachowania,
którego oryginał nigdy nie miał — świadomie pominięte.
`SettingsStore.sprint_mode` zostaje w schemacie/persystencji na przyszłość
(gdy powstanie UI dotykowe), ale nic go jeszcze nie czyta.

**Świadomie NIE zrobione:** reszta `ControlSettings` (touch/joystick/
colorblind/goalIndicators/legend/renderQuality) — brak konsumenta dla
każdego z nich w obecnym stanie gry (brak inputu dotykowego, brak
stylowania HUD-a wrażliwego na tryb kolorślepy, brak presetów jakości
renderowania).

**Status walidacji:** nieuruchomione w edytorze przez sesję AI. Do
sprawdzenia: (1) `scenes/menu/LevelSelect.tscn` (F6) pokazuje przycisk
"Ustawienia" obok listy poziomów, (2) kliknięcie otwiera
`SettingsMenu.tscn` z działającym dropdownem trudności/suwakiem
głośności/checkboxem wyciszenia, (3) "Wróć" wraca do listy poziomów,
(4) zmiana trudności na "hard" i start poziomu daje niższą startową
energię (80 zamiast 100) i szybszy drenaż podczas sprintu, (5) wyciszenie
(`Wycisz`) faktycznie wycisza dźwięki pickup/completion, (6) ustawienia
przetrwają restart gry (`user://settings.json`).

## Aktualizacja: automatyczny boot-test wszystkich scen (MCP Godot)

Użytkownik podłączył MCP Godot do tej sesji — pierwsza okazja by sesja AI
sama uruchomiła projekt (`run_project`/`get_debug_output`/`stop_project`),
zamiast wyłącznie czekać na ręczny test. **Zakres tego, co MCP faktycznie
sprawdza: boot bez błędów/warningów + log konsoli.** Nie ma narzędzia do
symulacji inputu (WASD/klik) ani zrzutu ekranu w dostępnym zestawie MCP —
więc to NIE zastępuje wizualnej/gameplayowej weryfikacji z list "Do
sprawdzenia" wyżej (animacja sprite'a, wyrównanie teł, emoji, światła,
HUD na żywo, dźwięk) — to nadal wymaga człowieka.

Przetestowane (`run_project` → `get_debug_output` → `stop_project`, każda
scena osobno): `Level1..6.tscn`, `TestLevel.tscn`, `menu/LevelSelect.tscn`,
`menu/SettingsMenu.tscn`. Wynik: **wszystkie 9 scen startują bez błędów**;
questy logują się z oczekiwaną liczbą (L1 3/3 — bo `ProgressStore` ma zapis
z wcześniejszej sesji ręcznej użytkownika, L2 1/3, L3 0/2, L4 0/2, L5 1/3,
L6 0/3 — zgodne z oczekiwaniami z poprzednich wpisów w tym pliku).

**Bug znaleziony i naprawiony:** `LevelSelectMenu.gd:61-62`
(`_format_ms()`) rzucał `WARNING: Integer division. Decimal part will be
discarded.` przy każdym uruchomieniu `LevelSelect.tscn` — dzielenie
całkowitoliczbowe tam jest celowe (`ms → sekundy → m:ss`), więc naprawione
przez `@warning_ignore("integer_division")` na obu liniach, nie zmianę
logiki. Zweryfikowane ponownym `run_project` — warning zniknął, `errors:
[]`.

## Aktualizacja: Camera bounds + zoom (fix po ręcznych testach użytkownika)

Użytkownik zgłosił po pełnym ręcznym przejściu wszystkich systemów: **wszystko
działa oprócz map** — sprecyzowane jako "tło za duże / przycina się" na
wszystkich poziomach. Prześledzone w źródle: `LevelScene.ts` woła
`cameras.main.setBounds(0, 0, width, height)` **oraz**
`setZoom(Phaser.Math.Clamp(Math.min(scale.width, scale.height) / 620, 0.75,
1.3))` w `create()` — port w Godot (`CameraFX.gd`/`LevelRuntime.gd`) miał
**żadne z tych dwóch**: `Camera2D` bez `limit_*` (domyślne ±10 000 000, więc
kamera mogła przewinąć się poza sprite tła i pokazać pustą kolorem-czyszczenia
przestrzeń silnika) i zoom zawsze `1.0` (zamiast policzonego z rozmiaru
viewportu, przez co kadrowanie różniło się od Phasera). To nie był dotąd
zauważony brak parity, nie regresja tej sesji.

Naprawione: `CameraFX.gd`'s `BASE_ZOOM` (stała `Vector2.ONE`) zamieniona na
`base_zoom` (zmienna) + nowa `set_base_zoom(z)`. `LevelRuntime.gd` dostał
`_setup_camera(player)`, wołane z `_ready()` zaraz po znalezieniu gracza:
ustawia `camera.limit_left/top/right/bottom` na `0,0,level.width,level.height`
i woła `set_base_zoom(clamp(min(viewport.x, viewport.y) / 620.0, 0.75, 1.3))`
— 1:1 z formułą Phasera, `get_viewport_rect().size` jako odpowiednik
`this.scale.width/height` (Godot nie ma per-scene "game canvas size" jak
Phaser, viewport rect to najbliższy odpowiednik).

**Status walidacji:** boot bez błędów potwierdzony przez sesję AI (L1, L6 via
MCP Godot). Wizualna weryfikacja (czy tło faktycznie wypełnia kadr bez
ucinania się na krawędziach, czy kadrowanie/zoom wygląda podobnie do Phasera)
nadal wymaga ręcznego testu w edytorze przez użytkownika — sesja AI nie ma
narzędzia do zrzutu ekranu/inspekcji wizualnej w dostępnym zestawie MCP.
