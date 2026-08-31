# Godot 4 — projekt docelowy migracji

Status na 2026-08-31 (koniec bardzo długiej sesji): **7 grywalnych poziomów, pełna warstwa
architektoniczna, formalny framework testowy.** Poziomy 1–6 (Wały Chrobrego → Łucznicza 43)
+ nowy **Poziom 7 "Salon"** (wnętrze domu, prawdziwe assety Kenney — podłoga jako `TileSet`/
`TileMapLayer`, drzwi + meble jako zweryfikowane cropy z `TopDownHouse_*.png`). Gracz ma
pełny zestaw: ruch/sprint/hop (`TESTED` w edytorze), squash/stretch, lean, sprint-drift,
ghost-trail, State Machine (Idle/Walk/Sprint/Hop — warstwa klasyfikująca, **nie** napędza
fizyki, świadoma decyzja), StatusEffectComponent, InteractionDetector ("Wciśnij E").
Sześć autoloadów: `ProgressStore`, `AudioService`, `SettingsStore`, `EventBus`,
`DebugConsole` (`~`, `/god`/`/give_item`/`/load_level`/`/clear_save`), `SceneRouter` (fade
przejść). Kolizje na jawnych warstwach (`COLLISION_MATRIX.md`). i18n: UI chrome
przetłumaczone, **gra formalnie jednojęzyczna PL na stałe** (decyzja użytkownika). Testy:
**GUT** (`godot/addons/gut/`) w `res://tests/integration/` — 37 asercji, uruchamiane z CLI
(`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit`), nie
tylko ręcznie przez MCP. Import assetów: `godot/tools/import_assets.ps1` (batch, headless).

**Pełny, chronologiczny log tej sesji (co, dlaczego, jakie bugi złapane i naprawione) —
`plan31-08.md` w repo-root.** To jest kanoniczne źródło szczegółów, ten plik to tylko
skrót. `docs/migration/MIGRATION_MATRIX.md` — audyt/status per-system z wcześniejszych
sesji, częściowo już nieaktualny względem `plan31-08.md` (nie zaktualizowany wstecznie
wszędzie, sprawdzać oba).

**Do zrobienia w kolejnej sesji** (patrz `plan31-08.md`, sekcja "principal lead
rekomendacje" na końcu): (4) opcjonalnie przenieść fizykę HOP z `PlayerMovement.gd` do
`PlayerStateMachine`/`PlayerHopState.physics_update()` — na osobnym branchu, z pełnym
ręcznym retestem, nie w pośpiechu. Reszta rekomendacji (1,2,3,5,6,7) zamknięta.

## Co tu jest

- `project.godot` — Godot 4.7, renderer GL Compatibility, viewport 1280×720, `InputMap`
  (`move_up/down/left/right`, `sprint`, `hop`, `interact`, `inventory`, `pause` — WASD/strzałki
  + Shift/Space/E/I/Esc), `run/main_scene` → `scenes/levels/Level1.tscn` (nie zmieniony mimo
  że `scenes/menu/LevelSelect.tscn` już istnieje — patrz niżej).
  `[autoload] ProgressStore, AudioService, SettingsStore`.
- `scripts/infrastructure/ProgressStore.gd` — autoload singleton (świadomie, per "autoloads
  used sparingly" — to naprawdę globalny, trwały stan). Odpowiednik persystowanej części
  `gameStore.ts` (zustand `persist`): `unlocked_levels`, `level_progress` (completed +
  items_collected), `talked_npcs`, `best_level_times`, zapisywane jako JSON w
  `user://progress.json`, autosave przy każdej zmianie.
- `scripts/infrastructure/AudioService.gd` — drugi autoload. 1:1 port `src/lib/audio.ts`
  (`SimpleAudio`) — czysto proceduralny (WebAudio oscylator + gain envelope w źródle, zero
  plików próbek), więc port używa `AudioStreamGenerator`. Pula 8 głosów na nakładające się
  dźwięki. `play_pickup()`/`play_completion()`/`play_danger()` — chirp/akord/buzz, dokładnie
  te same częstotliwości/czasy/głośności co źródło.
- **Player sprite**: `godot/assets/textures/characters/edek-sprite.png` (896×1200, 3×4
  walk-cycle, zweryfikowane wymiarem pliku, 1:1 z `SHEET_COLS`/`SHEET_ROWS`/`DIRECTION_ROWS`
  w `LevelScene.ts`) + `scenes/player/EdekSpriteFrames.tres` (`SpriteFrames`, 4 animacje
  `walk-{down,left,right,up}`, klatki `[0,1,2,1]` @ 8fps). `Player.tscn`'s `Sprite2D` to teraz
  `AnimatedSprite2D` (przeskalowany do ~64px wyświetlanego rozmiaru — `CAT_SIZE` w źródle).
  `PlayerMovement._update_animation()`: kierunek z dominującej osi prędkości (nie "ostatni
  klawisz"), animacja zamraża się na klatce w bezruchu (1:1 z `anims.stop()`).
- **Tła poziomów**: `godot/assets/textures/environment/*.{jpeg,jpg}` — pre-renderowane
  pełnoklatkowe obrazy sceny (potwierdzone wymiarem pliku, NIE tileset — jedyny prawdziwy
  tileset w repo, `TopDownHouse_*`, jest jawnie nieużywany przez żaden z 6 poziomów, materiał
  na przyszły niezaimplementowany poziom). `scripts/gameplay/world/LevelBackgrounds.gd`
  (statyczny rejestr level-id → texture path, wzorzec `ItemRegistry.gd`).
  `LevelRuntime._setup_background()` skaluje do dokładnych `level.width`/`height`
  (L1-L3 dokładne 1:1, L4/L5 skalowanie 0.833× ten sam aspect ratio, L6 <0.5% rozbieżności
  aspektu — niezauważalne). Gdy tło istnieje, `LevelBuilder.build()`'s nowy
  `hide_obstacle_visual` parametr ukrywa (nie usuwa — kolizja zostaje) szare `Polygon2D`
  przeszkód, bo tło już pokazuje tę geometrię; item/NPC/goal placeholdery zostają widoczne
  (nadal brak dla nich prawdziwej grafiki).
- **Atmosfera**: `scripts/presentation/atmosphere/AtmosphereFX.gd` — punktowe światło + światło
  przy kocie jako addytywny gradient-sprite (nie Godot's `Light2D` — świadomie, ta sama
  logika co Phaser źródła unikające swojego usuniętego `Lights2D`), `CPUParticles2D` per
  `ambientFx` (motes/dust/petals/stars, przybliżenie prędkości nie 1:1), i post-FX color
  grade (`WorldEnvironment`+`Environment.adjustment_*`: brightness/contrast/saturation,
  `mood` z danych poziomu lub day/night fallback). R2 "API niepewne" z audytu formalnie
  nadal otwarte — zaimplementowane, ale nieprzetestowane runtime na GL Compatibility.
  Vignette/hue-rotation/sepia NIE ported (brak wbudowanego odpowiednika bez custom shadera).
- `scripts/gameplay/player/PlayerHop.gd` — komponent `Node` (dziecko `Player`, węzeł `Hop`):
  jump-buffering (150ms), coyote time (120ms), cooldown (260ms), prędkość 361px/s, wizualny
  łuk 22px. `PlayerMovement.gd` woła `hop.update(delta, input_dir)` jawnie na początku
  `_physics_process()`.
- `scripts/presentation/camera/CameraFX.gd` — skrypt na `Camera2D` (dziecko `Player`): shake
  (hop landing 2px/60ms, twarda kolizja >40px/s 3px/70ms) i pulse-zoom (item pickup i NPC
  prezent, 1.03x/160ms). Amplitudy dobrane "na oko" — Phaser's `intensity` (ułamek ekranu)
  nie przenosi się 1:1 na piksele offsetu w Godot, patrz komentarz w pliku.
- `scripts/presentation/ui/HUD.gd` + `scenes/ui/HUD.tscn` — `CanvasLayer` z checklistą questów
  (`[x]/[!]/[ ]` + licznik + tekstowy hint dystansu/tieru: `· blisko (~N kr.)`), chipami
  inventory, i `MessageLabel` (prowizoryczny zamiennik `DialogBox` dla wiadomości NPC/goal).
  Instancjonowany przez `LevelRuntime.gd`. Domyślny theme silnika, brak stylowania/animacji —
  funkcjonalny placeholder.
- `scripts/gameplay/quests/GoalProximity.gd` — statyczny port `proximity.ts` (archetyp
  gate/chest/food/spot + promienie at/near/mid). `LevelRuntime._process()` (throttled 10/s)
  liczy dystans/tier do najbliższego celu każdego nieukończonego questu i karmi HUD.
- `scripts/presentation/menu/LevelSelectMenu.gd` + `scenes/menu/LevelSelect.tscn` — lista
  wszystkich 6 poziomów (tytuł/podtytuł z `menu.tsx`), sequential-unlock gating przez
  `ProgressStore` ("Zablokowane" dla nieodblokowanych, ✓ + czas dla ukończonych), przycisk
  "Graj" → `change_scene_to_file()`. Uruchamiany osobno w edytorze (F6) — `run/main_scene`
  go jeszcze nie używa.
- `scripts/core/{ItemData,LevelObjectData,QuestStepData,LevelData}.gd` — Resource klasy 1:1 z
  `src/game/types.ts`. `data/items/*.tres` (11 itemów) + `ItemRegistry.gd` (loader ze
  ścieżkami wypisanymi jawnie). `data/levels/level_1..6.tres` — dane wszystkich 6 poziomów
  (tylko `level_1` end-to-end przetestowany).
- `scripts/gameplay/inventory/Inventory.gd` — 1:1 port z `inventory.ts`, w tym `NPC_GIFTS`
  (squirrel→yarn, pigeon→feather, kot→key) i `gift_obj_id()` (syntetyczny collected-id z
  sufiksem `-gift`, bo prezenty nie leżą na mapie jako `item`). `scripts/gameplay/quests/QuestUtils.gd` —
  1:1 port z `questUtils.ts`. Oba statyczne, bez zależności od `SceneTree`.
- `scripts/gameplay/world/LevelBuilder.gd` — buduje `LevelData.objects` w scenę:
  `StaticBody2D` (obstacle), `ItemPickup`/`GoalArea`/`NpcActor` (`scenes/interactables/`,
  `Area2D`, overlap-triggered), pomijając już-zebrane itemy (`ProgressStore` przez
  `collected_ids` parametr). `trigger` (danger) jeszcze nieobsłużone — żaden przeniesiony
  poziom go nie używa.
- `scripts/gameplay/world/NpcActor.gd` — `Area2D`, overlap-triggered `talked(obj_id)` (NIE
  znika po rozmowie, w przeciwieństwie do `ItemPickup` — NPC zostaje na scenie). Opcjonalny
  poziomy patrol (`patrol_range`/`patrol_speed`, odbicie na krańcach + mirror `scale.x`,
  1:1 z `updatePatrols()` w `LevelScene.ts`). Używany przez squirrel (L2, patrol),
  pigeon (L5, patrol), kot (L6, statyczny).
- `scripts/gameplay/world/LevelRuntime.gd` — root skryptu poziomu: czyta stan startowy z
  `ProgressStore`, ustawia tło, buduje scenę, łapie `collected`/`reached`/`talked`, liczy
  inventory, sprawdza `requires`, przelicza questy, przyznaje prezent NPC raz, pisze każdą
  zmianę z powrotem do `ProgressStore` (autosave), gra dźwięki przez `AudioService`
  (pickup/completion), wywołuje camera pulse, aktualizuje HUD. Per-obiektowe eventy zostają w
  konsoli (`print()`) jako lekki log deweloperski obok HUD-a.
- `scenes/levels/Level1.tscn` — Poziom 1 grywalny end-to-end (ruch, kolizje, zbieranie
  przedmiotów, cel z wymaganiami, camera FX), w pełni `TESTED`.
  `scenes/levels/Level2..6.tscn` — ten sam trzy-węzłowy wzorzec, po jednym per poziom.
  `scenes/levels/TestLevel.tscn` zostaje jako prostszy smoke-test ruchu/kolizji bez danych.
- **Item/NPC/goal renderują się jako emoji** (`Label`, wyśrodkowany, `font_size = rect.h*0.9`)
  zamiast kolorowych `Polygon2D` — 1:1 z `LevelScene.ts`'s `add.text()`, które też renderuje
  te obiekty jako emoji glify, nie custom sprite'y (`items.ts`: każdy `ItemDef` niesie
  `emoji`). Stary `Polygon2D` zostaje w scenie z `visible=false` jako debug-fallback.
  Obstacle-`Polygon2D` (pełne wypełnienie) ukryte tam, gdzie tło już istnieje (wszystkie
  6 poziomów) — zamiast tego subtelny `Line2D` outline (biały, alpha 0.35, `width=2`), bo
  Phaser też nigdy nie rysował ramki przeszkody (`rect.setVisible(false)` w `LevelScene.ts`)
  i po pierwszym pełnym teście z prawdziwymi tłami brak jakiegokolwiek sygnału wizualnego
  przy krawędzi krzaka/drzewa czytał się jak "niewidzialna ściana" — świadome odejście od
  1:1 parity z Phaserem, decyzja użytkownika po testach.
- **Energy/Difficulty**: `scripts/gameplay/difficulty/Difficulty.gd` — statyczny 1:1 port
  `DIFFICULTIES` z `gameStore.ts`. `LevelRuntime._update_energy()` drenuje energię podczas
  sprintu, odzyskuje w bezruchu (nie podczas zwykłego chodzenia), gasi
  `PlayerMovement.can_sprint` poniżej `min_sprint_energy` — sprint faktycznie przestaje
  działać, nie tylko wizualnie. HUD: `Energia: NN%` + "(Zmęczenie)"/czerwony tekst poniżej
  30%. Trudność czytana z `SettingsStore.difficulty` (patrz niżej).
- **Settings/Controls**: `scripts/infrastructure/SettingsStore.gd` (trzeci autoload,
  `user://settings.json`) — `volume`, `muted`, `difficulty`, `sprint_mode`.
  `SettingsMenu.gd`/`scenes/menu/SettingsMenu.tscn` — dropdown trudności, suwak głośności,
  checkbox wyciszenia, dostępne z `LevelSelectMenu` przez przycisk "Ustawienia".
  `AudioService.play_pickup/play_completion` teraz wołane z `SettingsStore.effective_volume()`.
  **`sprintMode` "toggle" świadomie NIE podłączone do klawiatury** — prześledzone w źródle:
  `sprintToggled` w `LevelScene.ts` jest ustawiane wyłącznie z przycisku dotykowego w HTML
  overlay, klawiatura zawsze działa jako "hold" niezależnie od ustawienia. Godot nie ma
  jeszcze UI dotykowego, więc nie ma czego portować bez wymyślania nieistniejącego
  zachowania — `sprint_mode` zostaje w schemacie na przyszłość.
- Świadomie brakuje: squash/stretch/lean/ghost-trail/drift, "naciśnij E" jako alternatywa
  dla overlapu (dla NPC/goal — potrzebuje systemu najbliższego interaktywnego obiektu w
  promieniu 100px), danger triggery (dane `danger_damage` przeniesione, ale niepodłączone —
  brak obiektów `trigger` w danych), `SaveSlot` (mid-level resume — teraz technicznie
  możliwe skoro Energy/Settings istnieją, ale nadal niezrobione), reszta `ControlSettings`
  (touch/joystick/colorblind/goalIndicators/legend/renderQuality — brak konsumenta),
  dialog-open camera pulse, `reducedMotion`, foreground leaves, vignette/hue/sepia (część
  post-FX bez wbudowanego odpowiednika), animacja skalowana z prędkością ruchu, wizualny
  pasek energii (tylko tekst).
- `scripts/gameplay/daily/DailyChallenge.gd` — 1:1 port `daily.ts` (deterministyczny wybór
  "dnia" po hashu daty). Niepodłączony do niczego — funkcja żyje za ekranami menu, które
  jeszcze nie istnieją w Godot. Przeniesiony teraz bo samodzielny i tani.
- Reszta struktury katalogów (`audio/`, `shaders/`, `tests/`) wciąż pusta, trzymana przez
  `.gitkeep`.

## Czego tu NIE ma (celowo)

- Foreground leaves, vignette/hue/sepia (część post-FX bez wbudowanego odpowiednika w Godot
  bez custom shadera — R2 w audycie), squash/stretch/lean na sprite'cie, animacja skalowana
  z prędkością ruchu.
- Pełnej weryfikacji Poziomu 1 przez sesję AI — WASD, sprint, hop, item pickup/goal i
  camera FX wszystkie potwierdzone przez użytkownika w edytorze (2026-08-31, na starym
  greyboxie — nie jeszcze z nowym tłem/sprite'em kota/emoji-ikonami).
- Pełnej weryfikacji Poziomów 2–6, NPC-systemu, HUD-a, LevelSelect, Save/Load, Audio i
  nowych assetów (sprite kota, tła, emoji-ikony) — dane i kod przeniesione, nieprzetestowane.
  Sprawdź: (1) kot pokazuje prawdziwą grafikę i animuje się w 4 kierunkach, zamraża się w
  bezruchu; (2) każdy poziom pokazuje prawdziwe tło zamiast szarego tła silnika, wyrównane z
  niewidzialnymi strefami kolizji (spacer nie przenika przez narysowane drzewo/budynek ani
  nie zatrzymuje się na pustym miejscu); (3) itemy/NPC/cele pokazują właściwe emoji
  wyśrodkowane, nie puste "tofu" kwadraty (font coverage) ani stare kolorowe kwadraty;
  (4) światło punktowe (L1) i światło przy kocie (poziomy `night`/`dim`) widoczne;
  (5) drobinki ambientFx widoczne, subtelne; (6) czy `level_N.tres` się parsuje, (7) czy
  scena startuje bez błędów z widocznym HUD-em, (8) L3/L4 — grywalne od startu do celu
  (nie mają NPC-ów), (9) L2/L5/L6 — NPC + prezent + patrol (emoji odwraca się z kierunkiem)
  + quest "talk", (10) cel blokowany/ukończony poprawnie, (11) wiadomość NPC/goal w
  `MessageLabel`, (12) zebrany item nie wraca po restarcie, (13) unlock + best-time w
  LevelSelect po restarcie gry, (14) dźwięki pickup/completion bez trzasków, (15)
  **post-FX color grade faktycznie coś zmienia wizualnie** (może się okazać cichym no-op na
  GL Compatibility — R2 z audytu nadal formalnie otwarte — **potwierdzone działające przez
  użytkownika**), (16) subtelna biała ramka wokół przeszkód widoczna, nie za mocna/za słaba
  (**potwierdzone działające przez użytkownika**); (17) **[NOWE, nieprzetestowane]**
  trzymanie Shift podczas ruchu zużywa energię widoczną w HUD, stanie w miejscu ją odzyskuje,
  zwykłe chodzenie nie zmienia jej wcale; (18) sprint faktycznie się wyłącza (nie tylko wolniej
  biegnie) gdy energia spadnie poniżej progu; (19) poniżej 30% energii HUD pokazuje
  "(Zmęczenie)" na czerwono; (20) **[NOWE, nieprzetestowane]** `LevelSelect.tscn` pokazuje
  przycisk "Ustawienia" obok listy poziomów, otwiera `SettingsMenu.tscn` z działającym
  dropdownem trudności/suwakiem głośności/checkboxem wyciszenia; (21) zmiana trudności na
  "hard" i start poziomu daje niższą startową energię i szybszy drenaż; (22) wyciszenie
  faktycznie wycisza dźwięki pickup/completion; (23) ustawienia przetrwają restart gry.

## Kolejne kroki

1. Ręczna weryfikacja wszystkiego powyżej w edytorze — to jest teraz najważniejsze.
2. Vignette/hue/sepia — potrzebuje custom shadera, brak wbudowanego odpowiednika w
   `Environment` dla 2D.
3. Reszta polishki z "Świadomie brakuje" wyżej, gdy dojdzie kolej.

Oryginalny kod źródłowy (`src/game/phaser/`) pozostaje nietknięty do pełnej walidacji migracji —
patrz Zasada 1 w `god/godot.md`.

## Rozważane na przyszłość (NIEwdrożone, tylko notatka)

Użytkownik zaproponował te pluginy/funkcje AssetLib jako możliwe przyszłe usprawnienia —
żaden nie jest częścią projektu, decyzja o wdrożeniu wymaga świadomego wyboru, nie "bo
popularne":

- **Wbudowane TileSet Terrain Sets** (natywne w Godot 4.3+) — gdyby levele przeszły z
  pełnoklatkowych JPEG-ów na prawdziwe kafelki (obecnie nie są — patrz "Aktualizacja: Assety"
  w `MIGRATION_MATRIX.md`).
- **SmartShape2D** — organiczne kształty kolizji (ścieżki, brzegi rzek) zamiast sztywnych
  prostokątów `Rect2` z `LevelData`.
- **Natywny `Light2D` + `LightOccluder2D`** — zastąpiłoby prowizoryczne addytywne
  gradient-sprite'y w `AtmosphereFX.gd` prawdziwym dynamicznym oświetleniem 2D.
- **Shader-based trawa/roślinność z wiatrem** — pasowałoby do parkowych poziomów (Park
  Kasprowicza, Aleja Kasztanowa).
- **Dialogue Manager** (popularny addon) — zastąpiłoby placeholder `MessageLabel` w `HUD.gd`
  prawdziwym systemem dialogowym z gałęziami.
- **Phantom Camera** — bardziej rozbudowana logika kamery niż ręczny `CameraFX.gd`, gdyby
  doszły przejścia między poziomami / cutscenki.
