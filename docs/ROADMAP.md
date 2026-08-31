# ROADMAP — rozbudowa Edka po zamknięciu migracji

Autor: sesja "lead senior developer", 2026-08-31.
Wejście: `plan31-08.md`, `godot/README.md`, `docs/migration/MIGRATION_MATRIX.md` + audyt
realnego kodu w `godot/` (nie tylko dokumentacji).

Ten dokument **nie** jest logiem migracji (to `plan31-08.md`) ani audytem parity
(to `MIGRATION_MATRIX.md`). To plan tego, co budujemy **dalej**, gdy parity z Phaserem
przestaje być miarą jakości.

---

## Zasady pracy obowiązujące w każdej fazie tego planu

Ustalone przez użytkownika (2026-08-31), obowiązują też podagentów.

1. **Najpierw inspekcja, potem akcja (read-before-write).** Zanim powstanie lub zmieni się
   jakikolwiek skrypt wpięty w scenę — najpierw odczytaj realną strukturę tej sceny
   (MCP `godot` / odczyt `.tscn`) i wypisz, co już w niej jest. Zero zgadywania nazw węzłów,
   ścieżek `$Node` i istniejących komponentów. Ta zasada już raz uratowała projekt przy
   assetach Kenneya (crop-and-view przed zahardkodowaniem `Rect2i`) — teraz obowiązuje
   również dla drzewa węzłów.
2. **Kompozycja ponad dziedziczenie, małe pliki.** Nowa funkcjonalność postaci/NPC/obiektu
   powstaje jako osobny skrypt-komponent (`Node`/`Area2D` jako dziecko), nie jako kolejne
   200 linii w istniejącym pliku. Projekt już to robi dobrze (`PlayerHop.gd`,
   `StatusEffectComponent.gd`, `InteractionDetector.gd`) — **jedyny plik dryfujący w stronę
   "gigantycznego Player.gd" to `PlayerMovement.gd` (262 linie)**, patrz zadanie 0.6.
3. **Błędy naprawiamy przez narzędzia, nie przez zgadywanie.** Błąd z konsoli Godota →
   otwórz powiązany plik przez MCP/CLI, znajdź przyczynę, napraw **zachowując ścisłe
   typowanie** (`var x: Type`, typowane sygnatury, typowane tablice/słowniki). Static typing
   jest w tym projekcie standardem i był już źródłem złapanych bugów (`[] as Array[MissingHint]`).

4. **Systemy oparte na `Resource`.** Przedmioty, umiejętności, propy, tryby, modyfikatory,
   dialogi, fale przeciwników — to **dane**, nie sceny i nie kod. Skrypt dziedziczący po
   `Resource` z samymi polami + pliki `.tres` edytowalne w inspektorze. Nowa zawartość
   powstaje przez dodanie `.tres`, nie przez dopisanie gałęzi `match`.
5. **Wzorzec stanu (FSM) dla wszystkiego, co ma więcej niż dwa zachowania.** Węzeł
   `StateMachine` + jeden malutki plik na stan. Dodanie `PlayerDashState` nie może wymagać
   dotknięcia kodu biegania ani skakania. Dotyczy też NPC i przeciwników, nie tylko gracza.
6. **UI odseparowane od logiki (sygnały, nie `get_node()`).** Warstwa UI **nasłuchuje**;
   nigdy nie sięga po dane do gracza ani do runtime'u. Zamiast `hud.update_energy(v)` —
   `EventBus.energy_changed.emit(v)` i HUD podpięty pod sygnał. Podmiana wyglądu HUD-a albo
   postaci gracza nie może psuć gry.
7. **Spawner / opóźnione wczytywanie.** Obiekty nie instancjonują innych obiektów. Efekty,
   dropy, poziomy i VFX tworzy dedykowany `Spawner`/`LevelManager` po sygnale, z pulą
   obiektów tam, gdzie coś powstaje często. Cykl życia w jednym miejscu = brak wycieków.

Do tego zasady wcześniej potwierdzone i nadal obowiązujące: nie ruszamy `src/game/phaser/`;
pytamy przed pobraniem czegokolwiek z sieci; weryfikujemy assety przed zahardkodowaniem
współrzędnych; GUT przed i po każdym podsystemie; jedna gałąź na podsystem.

### Audyt zgodności z zasadami 4-7 (stan na 2026-08-31)

Zweryfikowane w kodzie. Dwie zasady są spełnione, dwie łamane — i to są konkretne zadania,
nie ogólniki.

| Zasada | Stan | Dowód i co z tym zrobić |
|---|---|---|
| **4. Resources** | ✅ **spełniona, do rozszerzenia** | `ItemData`/`LevelData`/`LevelObjectData`/`QuestStepData` + `data/items/*.tres`, `data/levels/*.tres` — wzorzec działa i jest tu najlepiej zrobioną rzeczą. **Jedyny wyłom:** `LevelData.point_light` i `LevelData.mood` to luźne `Dictionary` (komentarz w pliku przyznaje, że to było świadome, bo nie miały wtedy konsumenta — dziś mają: `AtmosphereFX` + `PostFXOverlay`). Zamienić na `MoodData`/`PointLightData` jako `Resource`. Nowe systemy z tego planu (`PropData`, `GameModeData`, `ModifierData`, `DialogueData`) idą tym samym wzorcem od razu. |
| **5. FSM** | ⚠️ **połowicznie** | `PlayerStateMachine` + `PlayerIdle/Walk/Sprint/HopState` istnieją, ale **tylko klasyfikują stan, nie napędzają fizyki** — to jest dokładnie dług z punktu 1 Fazy 0. Druga luka: **NPC nie mają FSM w ogóle** — `NpcActor.gd` (78 l.) trzyma patrol inline. Przy punkcie 20 (nawigacja) NPC dostaje własny `StateMachine` (Idle/Patrol/Alert/Chase/Flee), inaczej pies i uciekająca wiewiórka wylądują jako `if`-y w tym samym pliku. |
| **6. UI przez sygnały** | ❌ **łamana** | `LevelRuntime.gd` (453 l.) woła metody HUD-a **bezpośrednio** (`update_proximity()` i pozostałe), mimo że `EventBus` istnieje od Części 9 i jest do tego stworzony. HUD jest dziś sprzężony z runtime'em. **Zadanie:** przenieść komunikację runtime → HUD w całości na sygnały `EventBus` (`energy_changed`, `quest_updated`, `item_collected`, `message_shown`, `proximity_updated`). To warunek wstępny punktu 28 (przeprojektowany HUD) — inaczej przepiszesz HUD i sprzężenie zostanie. Przy okazji odchudza `LevelRuntime` (drugi najdłuższy plik w projekcie). |
| **7. Spawner** | ❌ **łamana** | Dwa miejsca: (a) `LevelBuilder.build()` instancjonuje wszystko inline na starcie poziomu, bez asynchronicznego wczytywania; (b) **`PlayerMovement._spawn_ghost()` tworzy `Sprite2D` co 0.045 s podczas sprintu i `queue_free()` po 0.22 s** — czyli ~22 alokacje/s w najgorętszej ścieżce w grze. To jest dokładnie anty-wzorzec z zasady 7. **Zadanie:** `VfxSpawner` z pulą obiektów dla ghost-trail, pyłu i śladów łap + `ResourceLoader.load_threaded_request()` na następny poziom (punkt 9 sekcji 13). |

---

## 0. Diagnoza — gdzie realnie jesteśmy

### Co jest mocne (i nie ruszamy)

Architektura jest lepsza niż w typowym projekcie hobbystycznym i to jest fundament,
na którym da się budować bez przepisywania:

- **Dane jako Resources** (`LevelData`/`LevelObjectData`/`QuestStepData`/`ItemData`) —
  poziom to plik `.tres`, nie kod. Każda rozbudowa świata może iść przez dane.
- **6 autoloadów o rozłącznych odpowiedzialnościach** + `EventBus` — jest gdzie wpiąć
  nowe systemy bez sklejania ich ze sobą.
- **Atomic save + `schema_version`** — można zmieniać kształt zapisu bez utraty postępu.
- **GUT uruchamialny z CLI** (37 asercji) — jest czym pilnować regresji.
- **Jawna matryca kolizji** (5 warstw) — jest do czego dokładać warstwy.
- **Kompozycja w Playerze** — `Hop`, `StatusEffects`, `InteractionArea`, `StateMachine`
  jako osobne węzły-komponenty. Zasada 2 jest już częściowo wdrożona, nie trzeba jej
  wprowadzać od zera.

### Co jest realnym sufitem jakości (i to jest temat tego planu)

Zweryfikowane w kodzie, nie założone:

| # | Problem | Dowód | Konsekwencja |
|---|---|---|---|
| 1 | **Zero Y-sortowania w całym projekcie** | `grep -rn "y_sort" godot/scripts godot/scenes` = 0 trafień | Kot **nigdy** nie chodzi za drzewem/ławką/meblem. Świat czyta się jak wycinanka z kartonu. Największa pojedyncza różnica między "obrazkiem z kotem" a "światem". |
| 2 | **Świat = 1 JPEG + niewidzialne prostokąty** | `LevelBuilder._build_obstacle()` tworzy `RectangleShape2D`, `Polygon2D` ukrywany gdy jest tło | Nic w świecie nie jest obiektem. Nie da się dodać cienia, animacji, kolizji o kształcie innym niż prostokąt ani oświetlenia per-obiekt. Rzeka na L1 to `Rect2(0, 800, 3200, 100)`. |
| 3 | **Itemy/NPC/cele to `Label` z emoji** | `LevelBuilder.DEFAULT_ITEM_ICON = "?"`, `ItemPickup.gd:42` ustawia `font_size` | Wierny port Phasera — ale Phaser robił tak z wygody, nie z decyzji artystycznej. Dziś to jest sufit "realistycznych obiektów". |
| 4 | **Brak `AnimationPlayer`/`AnimationTree`** | `grep` znajduje wyłącznie `Tween` w `PlayerMovement.gd` | Cała animacja to imperatywny kod + ręczny wybór kierunku. Wystarcza na 4 animacje chodzenia; nie skaluje się na idle-warianty, siadanie, uderzenie w ścianę, sen. |
| 5 | **Akcja `pause` istnieje, nikt jej nie konsumuje** | `project.godot` definiuje `pause` (Esc); `grep -rn "get_tree().paused"` = 0 trafień | Nie ma pauzy. Esc nie robi nic. |
| 6 | **Akcja `inventory` (I) też bez konsumenta** | jw. | Zaprojektowany klawisz bez ekranu. |
| 7 | **`run/main_scene = Level1.tscn`** | `project.godot` | Gra startuje w środku poziomu 1. Nie ma menu głównego; `LevelSelect.tscn` odpalasz ręcznie przez F6. |
| 8 | **Zero `Theme`, zero fontów** | `godot/assets/fonts/` = sam `.gitkeep`; 3 skrypty gameplayowe wołają `add_theme_font_size_override` | Domyślny theme silnika w każdym ekranie. Każda zmiana wyglądu = kolejny override rozsypany po kodzie. **Naprawić zanim powstanie więcej UI, nie po.** |
| 9 | **`DailyChallenge.gd` gotowy, niepodłączony** | 50 linii, zero wywołań spoza pliku | Cały tryb gry leży w repo i nic nie robi. |
| 10 | **Zero nawigacji** | `grep -rn "Navigation"` = 0 trafień | NPC to liniowy patrol z odbiciem. Nie da się zrobić psa, który goni. |
| 11 | **Hop jest czysto wizualny** | `PlayerHop.gd` liczy `arc_progress()` (sinus, 22px), nie zmienia maski kolizji | Kot "skacze", ale nie może **przeskoczyć** niczego. Główna mechanika gry nie ma funkcji gameplayowej. |
| 12 | **Warstwa `Danger` + `danger_damage` bez konsumenta** | `COLLISION_MATRIX.md` layer 5, `Difficulty.gd`; `LevelBuilder` loguje warning na `kind == "trigger"` | System energii nie ma stawki — energia nie kosztuje niczego poza sprintem. |
| 13 | **Testy piszą do prawdziwego `user://progress.json`** | notatka w `plan31-08.md`, `ProgressStore.reset_progress()` w testach | Każde lokalne uruchomienie GUT wymaga ręcznego backupu. To dług, nie procedura. |
| 14 | **`PlayerMovement.gd` = 262 linie** | największy plik gameplayowy po `LevelRuntime.gd` (453) | Trzyma ruch, sprint, drift, lean, squash/stretch, ghost-trail i wybór animacji naraz. Zasada 2 mówi: rozbić. |

### Rekomendacja strategiczna #1 — zamknij parity, na piśmie

Wszystko, co zostało na liście "nieprzeniesione", jest albo kosmetyką, albo infrastrukturą
bez konsumenta. **Dalsze mierzenie się do Phasera aktywnie ogranicza jakość** — emoji jako
ikony itemów istnieją wyłącznie dlatego, że Phaser tak robił.

Proponuję formalną decyzję (analogiczną do zamknięcia i18n w rekomendacji "principal lead"
nr 5): **`src/game/phaser/` przestaje być wzorcem do naśladowania i staje się wyłącznie
archiwum referencyjnym.** Zasada 1 z `god/godot.md` (nie kasować, nie psuć) zostaje.
Ale "czy Phaser tak robił" przestaje być argumentem w decyzjach projektowych.

---

## 1. Faza 0 — higiena przed rozbudową (1-2 sesje)

Nic z dalszych faz nie powinno ruszyć przed tym. To są rzeczy, które **potanieją całą
resztę planu**, jeśli zrobisz je pierwsze, i podrożeją, jeśli zrobisz je później.

| # | Zadanie | Dlaczego teraz | Skills |
|---|---|---|---|
| 0.1 | **Dokończyć dług HOP** — fizyka z `PlayerMovement.gd`/`PlayerHop.gd` do `PlayerHopState.physics_update()`, branch `migration/player-physics`, pełny ręczny retest | Jedyne otwarte follow-up z poprzedniej sesji. Faza 2 (animacje) i Faza 3 (skok nad przeszkodą) obie dotykają ruchu — robienie ich na niedokończonej refaktoryzacji to podwójna praca | `state-machine`, `player-controller` |
| 0.2 | **Przejść ręcznie 23-punktową checklistę** z `godot/README.md` | Duża część systemów jest `IMPLEMENTED`, nie `TESTED`. Budowanie na niezweryfikowanej bazie to najdroższy możliwy błąd | — |
| 0.3 | **Testowy profil zapisu** — `ProgressStore` czyta ścieżkę z `OS.has_feature("test")` / argumentu `--test-save`, pisze do `user://test_progress.json` | Znosi ręczny backup/restore przy każdym uruchomieniu GUT. Bez tego każda kolejna faza płaci podatek na testy | `godot-testing`, `save-load` |
| 0.4 | **Theme + font** — `ui/theme/edek_theme.tres`, font z **pełnym pokryciem polskich znaków** (ą ć ę ł ń ó ś ź ż), `StyleBoxFlat` dla paneli, type variations dla rozmiarów. Usunąć rozsypane `add_theme_font_size_override` | Każdy ekran zbudowany przed Theme trzeba będzie przerobić. Trzy takie ekrany już są | `godot-ui` |
| 0.5 | **Menu główne + pauza** — `MainMenu.tscn`, `run/main_scene` na menu, `PauseMenu` na akcji `pause` z `process_mode = PROCESS_MODE_WHEN_PAUSED` | Naprawia dwie zwisające akcje inputu (#5, #7). To jest rama, w którą wchodzą wszystkie tryby gry z Fazy 4 | `godot-ui`, `scene-organization` |
| 0.6 | **Rozbić `PlayerMovement.gd`** na komponenty: `PlayerLocomotion` (accel/friction/drift), `PlayerVisuals` (squash/stretch/lean/ghost/animacja), `PlayerEnergyGate`. Zasada 2 | Faza 2 przepisuje warstwę wizualną na `AnimationTree` — łatwiej wymienić jeden komponent niż wyciąć połowę pliku, w którym mieszka też fizyka | `component-system`, `player-controller` |

**Kryterium wyjścia z Fazy 0:** gra startuje w menu, Esc pauzuje, wszystkie ekrany używają
jednego Theme, GUT przechodzi bez dotykania prawdziwego zapisu, HOP jest w state machine
i czuje się tak samo jak przed refaktorem.

---

## 2. Faza 1 — Świat: mapy i realistyczne obiekty

**Faza o największym zwrocie wizualnym w całym planie.** Cel: świat przestaje być obrazkiem
z niewidzialnymi ścianami i staje się sceną złożoną z obiektów.

### 2.1 Y-sortowanie (fundament, robić pierwsze)

Bez tego reszta tej fazy nie ma sensu — realistyczne propy bez Y-sortu wyglądają **gorzej**
niż obecne płaskie tło, bo kot będzie chodził po koronach drzew.

- `y_sort_enabled = true` na węźle świata w `LevelRuntime`.
- Każdy prop dostaje `y_sort_origin` ustawiony na **podstawę/stopę** obiektu, nie na środek
  sprite'a — inaczej wysokie drzewo przestaje zasłaniać kota za wcześnie.
- Gracz i NPC w tym samym Y-sortowanym poddrzewie (dziś Player wisi osobno).
- Tło (`Sprite2D`/`TileMapLayer`) na stałym `z_index` poniżej. PostFX zostaje na `layer=5`,
  HUD na `layer=10` — te warstwy są już poprawnie rozstrzygnięte, nie ruszać.

Skills: `2d-essentials`, `scene-organization`.

### 2.2 Biblioteka propów jako dane (wzorzec, który już działa)

Powtórz dokładnie wzorzec `ItemData` + `ItemRegistry` + `data/items/*.tres`, który się
sprawdził:

    scripts/core/PropData.gd     # Resource: texture, collision_poly, y_sort_origin,
                                 # occluder_poly, sway: bool, footstep_sound
    data/props/*.tres            # drzewo, krzak, ławka, kosz, latarnia, kamień, płot...
    scenes/world/Prop.tscn       # Node2D + Sprite2D + StaticBody2D + LightOccluder2D

Rozszerz `LevelObjectData` o `prop_id: StringName = &""` — **wstecznie kompatybilne**:
puste = dzisiejsze zachowanie (niewidzialny `Rect2`), wypełnione = prawdziwy prop z kolizją
o kształcie sprite'a. Dzięki temu migrujesz poziomy **po jednym**, nie hurtem, i w każdej
chwili możesz się cofnąć.

Kolejność migracji poziomów: **L7 (Salon) → L1 (Wały) → reszta.** L7 bo ma już prawdziwy
`TileSet` i najmniej propów; L1 bo jest najlepiej przetestowany i najczęściej oglądany.

Skills: `resource-pattern`, `2d-essentials`.

### 2.3 Prawdziwe itemy zamiast emoji

`ItemData` dostaje `texture: Texture2D`. `ItemPickup` renderuje `Sprite2D`, gdy tekstura
jest, i `Label` z emoji, gdy jej nie ma — **fallback zostaje**, żeby migracja 11 itemów szła
stopniowo i nic się po drodze nie psuło.

Do tego lekkie bujanie (`Tween` sinusoidalny, ±3 px, ~1.6 s loop) i delikatny glow. Emoji
jest dziś widoczne, bo jest kontrastowe; sprite w tej samej palecie co tło zniknie bez tego.

### 2.4 Geometria świata poza prostokątami

- **Kolizje wielokątne** (`CollisionPolygon2D`) dla brzegów rzeki, ścieżek, skarp — rzeka
  jako `Rect2(0, 800, 3200, 100)` to najgorszy przypadek w obecnych danych.
- **SmartShape2D** (addon z listy "rozważane") dopiero, jeśli okaże się, że ręczne polygony
  są zbyt uciążliwe. Nie instalować na zapas.
- **Terrain Sets w `TileSet`** dla nowych poziomów/wnętrz — autotiling ścian i podłóg.
  L7 udowodnił, że `TileMapLayer` w tym projekcie działa.

Skills: `physics-system`, `2d-essentials`.

### 2.5 Oświetlenie i atmosfera — następny poziom

Baza jest (`PointLight2D` + `LightOccluder2D` + własny post-FX shader). Co dodać:

- **`CanvasModulate` per-poziom** dla globalnego tintu nocy — tańsze i czystsze niż
  addytywne sprite'y; rozważane już w komentarzu `AtmosphereFX.gd`.
- **Occludery na propach** (pole `occluder_poly` w `PropData`) — realne cienie rzucane przez
  drzewa i meble. To moment, w którym oświetlenie zaczyna wyglądać drogo.
- **Miękki cień pod kotem** — `Sprite2D` z gradientem, skalowany odwrotnie do wysokości łuku
  hopa. Jedna z najtańszych rzeczy, które najmocniej osadzają postać w świecie.
- **Migotanie latarni** (`Tween` na `energy`) i **normal mapy** na propach przez
  `CanvasTexture.normal_texture`. GL Compatibility to obsługuje — zweryfikuj na jednym
  propie przed masową produkcją.

Skills: `2d-essentials`, `particles-vfx`.

### 2.6 Shadery świata

- **Wiatr w roślinności** — `canvas_item` vertex shader, offset X ważony `UV.y` (korona się
  buja, podstawa stoi), faza z `TIME + world_position.x`. Pasuje do Parku Kasprowicza
  i Alei Kasztanowej.
- **Woda** — przewijany noise + delikatna refrakcja przez `SCREEN_TEXTURE` na rzece z L1.
  Wzorzec czytania `SCREEN_TEXTURE` już działa w `post_fx_grade.gdshader`.
- **Ślady łap** — zanikające po ~2 s, przez pooling `Sprite2D` albo particles.

Uwaga techniczna: `GPUParticles2D` na GL Compatibility **zweryfikuj na jednym efekcie**,
zanim przepiszesz wszystkie `CPUParticles2D` — obecny kod używa CPU i działa.

Skills: `shader-basics`, `particles-vfx`.

**Kryterium wyjścia z Fazy 1:** na co najmniej jednym poziomie kot chodzi za drzewami, propy
rzucają cienie, itemy mają grafikę, a przeszkody mają kształt inny niż prostokąt.

---

## 3. Faza 2 — Animacja i game feel

Dziś animacja jest imperatywna i mieszka w `PlayerMovement.gd`. To działa, ale każda nowa
animacja to kolejny `if` w tym samym pliku. Czas na warstwę deklaratywną.

### 3.1 `AnimationTree` zamiast ręcznego wyboru klatki

- `AnimationPlayer` + `AnimationTree` z **`BlendSpace2D` sterowanym wektorem prędkości** —
  dokładnie przypadek "8-kierunkowy sprite blendowany po wektorze ruchu". Zastępuje
  `_update_animation()` z jego ręcznym wyborem dominującej osi.
- **Rozdziel dwa automaty**: `AnimationStateMachine` (wewnątrz `AnimationTree`, decyduje jaka
  animacja) od gameplayowego `PlayerStateMachine` (decyduje jaki stan logiczny). To dwie różne
  odpowiedzialności — sklejenie ich jest klasycznym błędem.
- **Zachowaj wystrojone stałe** (`speed_scale = 0.55 + speed_ratio * 0.85`, lean 0.16 rad,
  drift 0.14 s, ghost co 0.045 s). One są 1:1 z oryginału i zostały zaakceptowane — przenosisz
  je, nie wymyślasz na nowo.

Skills: `animation-system`, `state-machine`.

### 3.2 Animacje, które robią z kota postać

Obecnie kot ma 4 animacje chodzenia i zamraża się w bezruchu. Lista w kolejności zwrotu:

1. **Idle-breathing** — subtelne skalowanie 1.0 → 1.02 w 2 s loop. Kot przestaje być martwy
   w bezruchu. Jedna animacja, ogromna różnica.
2. **Idle-warianty po N sekundach bezruchu** — siada, liże łapę, macha ogonem, zasypia po
   ~30 s. Losowany wybór z wagami. To jest sygnatura gry o kocie.
3. **Anticipation + landing na hopie** — przykucnięcie przed skokiem (~80 ms) i ugięcie przy
   lądowaniu. Squash/stretch już jest, ale bez fazy przygotowania.
4. **Uderzenie w ścianę** — krótkie odbicie + potrząśnięcie głową. `CameraFX` już wykrywa
   twarde zderzenie (>40 px/s), więc sygnał jest gotowy do konsumpcji.
5. **Reakcja na item/prezent** — machnięcie ogonem, mrugnięcie.

### 3.3 Reszta świata też się rusza

- **NPC**: wiewiórka i gołąb dostają prawdziwe sprite'y + animacje idle/ruch/obrót.
  Dziś to emoji z odbiciem `scale.x`.
- **Propy**: `AnimationPlayer` na bujających się gałęziach (albo shader z 2.6 — shader jest
  tańszy przy wielu instancjach, `AnimationPlayer` daje większą kontrolę przy pojedynczych).
- **UI**: `Tween` na wejściu paneli, checkmarki questów, liczniki. Patrz Faza 6.
- **Przejścia**: `SceneRouter` już robi fade — dołóż intro-pan kamery na starcie poziomu
  i flourish na ukończeniu questu.

Skills: `animation-system`, `tween-animation`.

**Kryterium wyjścia z Fazy 2:** stojący kot wygląda na żywego, hop ma pełny łuk
anticipation → apex → landing, a dodanie nowej animacji nie wymaga dopisywania `if`
do skryptu ruchu.

---

## 4. Faza 3 — Fizyka

Dziś fizyka to `StaticBody2D` z prostokątami i `Area2D` na overlapy. Zero ciał dynamicznych.
Ta faza daje mechanikom **funkcję**, nie tylko wygląd.

### 4.1 Hop, który faktycznie przeskakuje (najwyższy priorytet w tej fazie)

Główna mechanika gry jest dziś czysto wizualna. Naprawa:

- Nowa warstwa kolizji **6: `LowObstacle`** (płotek, doniczka, niski murek, kałuża).
- W trakcie `PlayerHopState` maska kolizji gracza traci bit `LowObstacle`, wraca przy
  lądowaniu. Wysokie przeszkody (`World`) nadal blokują.
- Lądowanie w środku przeszkody → wypchnięcie do najbliższego wolnego miejsca
  (`move_and_collide` w pętli albo test kształtu przed lądowaniem).
- To otwiera **projektowanie poziomów pod skok**: skróty, sekrety, wymagane przeskoki.

Wymaga wcześniejszego domknięcia zadania 0.1. Skills: `physics-system`, `player-controller`.

### 4.2 Obiekty dynamiczne (`RigidBody2D`)

Gra jest o kocie, a w danych leży item `ball`. Kot, który potrąca piłkę i ta się toczy,
to najtańsza możliwa "wow" mechanika w tym projekcie.

- `RigidBody2D` z tłumieniem liniowym/kątowym: piłka, kłębek wełny, kubek, liście.
- Kot popycha przez `move_and_slide()` + `apply_central_impulse()` na kontaktach
  (`get_slide_collision()`), siła skalowana prędkością.
- Miska/kubek, który da się przewrócić — czysta radość, zero wpływu na progresję.
- Nowa warstwa **7: `Dynamic`**, żeby nie mieszać z `World`.

Skills: `physics-system`, `2d-essentials`.

### 4.3 Zagrożenia — nadanie stawki systemowi energii

Warstwa `Danger` (5) i `Difficulty.danger_damage` istnieją bez ani jednego konsumenta.

- `LevelBuilder` obsługuje wreszcie `kind == "trigger"` (dziś tylko `push_warning`).
- Typy: kałuża (spowalnia), ulica z samochodami (cykliczny `Area2D`), pies (ścigający NPC),
  woda (wypycha na brzeg z karą energii).
- Konsekwencja: energia spada → sprint się wyłącza → trzeba odpocząć. To działa już dziś,
  brakuje tylko źródła obrażeń.
- `AudioService.play_danger()` też czeka niepodłączony — dopnie się przy okazji.

Skills: `physics-system`, `ability-system`.

### 4.4 Nawigacja dla NPC

`NavigationRegion2D` budowany z geometrii poziomu + `NavigationAgent2D` na NPC. Odblokowuje:
patrol po ścieżce zamiast liniowego odbijania, psa, który realnie goni, wiewiórkę uciekającą
przed kotem, gołębie odlatujące przy zbliżeniu.

Skills: `ai-navigation`, `state-machine`.

### 4.5 Higiena fizyki

- `physics_ticks_per_second = 120` było potrzebne przy porcie feelu. Godot 4.4+ ma
  **interpolację fizyki 2D** (`physics/common/physics_interpolation`) — zweryfikuj
  dostępność w 4.7, włącz, i **zmierz**, czy da się wrócić do 60 Hz bez utraty feelu.
  Połowa kosztu CPU fizyki za darmo, jeśli tak.
- **Mierz, nie zgaduj** — profiler Godota przed i po. W tym repo intuicje wydajnościowe
  myliły się już dwa razy (patrz `CLAUDE.md`).

Skills: `godot-optimization`, `physics-system`.

---

## 5. Faza 4 — Tryby gry

Dziś jest jeden tryb: sekwencyjna kampania na 7 poziomów. Dwa kolejne tryby mają już
gotowy kod albo gotowe dane — to najtańsza replayability w całym planie.

| Priorytet | Tryb | Co już jest | Co dopisać |
|---|---|---|---|
| **1** | **Wyzwanie dnia** | `DailyChallenge.gd` w całości (deterministyczny wybór po haszu daty) | Ekran w menu, modyfikator dnia, streak + historia w `ProgressStore`, wynik dnia |
| **2** | **Na czas / speedrun** | `best_level_times` już persystowane, `SceneRouter`, timer w runtime | Przełącznik trybu, splity per quest, **duch najlepszego przejścia** — nagrywasz pozycje co 100 ms i odtwarzasz jako półprzezroczysty sprite; kod ghost-trail ze sprintu jest gotowym budulcem |
| 3 | **Spacer / eksploracja** | wszystkie poziomy, brak blokad | Tryb bez questów i energii, kolekcjonerskie znajdźki, tryb foto (Faza 5) |
| 4 | **Przetrwanie** | `Difficulty`, energia | Eskalujące zagrożenia z 4.3, fale, licznik przetrwanego czasu |
| 5 | **Nowa gra+** | `ProgressStore` | Te same poziomy, więcej zagrożeń, mniej energii, ukryte itemy |

**Wzorzec architektoniczny:** nie rób osobnego `LevelRuntime` na tryb. Zrób
`GameModeData` (Resource) z polami typu `has_energy`, `has_quests`, `time_limit`,
`danger_multiplier`, `item_shuffle`, i wstrzykuj go do `LevelRuntime` przez `SceneRouter`.
Modyfikatory (`data/modifiers/*.tres`) jako osobne Resources składane na sobie — wtedy
Wyzwanie dnia to "poziom + 2 losowe modyfikatory", a nie osobna gałąź kodu.

Skills: `resource-pattern`, `dependency-injection`, `save-load`.

---

## 6. Faza 5 — QoL

Lista uporządkowana od "boli codziennie" do "miło mieć".

### Musi być (naprawia realne dziury)

- **Pauza** (Esc) — wznów / restart / ustawienia / wyjście do menu. Zadanie 0.5.
- **Menu główne** z Kontynuuj / Nowa gra / Poziomy / Wyzwanie dnia / Ustawienia / Wyjdź.
- **Ekran ekwipunku i dziennika questów** na `I` — akcja istnieje bez konsumenta.
- **Zapis w środku poziomu** (`SaveSlot` z listy odłożonych) — pozycja, energia, zebrane.
  Autozapis przy wejściu na poziom i przy każdym quescie.
- **Restart poziomu** hotkeyem (R) z potwierdzeniem.
- **Potwierdzenie przy wyjściu z gry** — dziś zamknięcie okna to natychmiastowe wyjście.

### Ustawienia — rozbudowa istniejącego ekranu

Dziś: trudność, głośność, wyciszenie. Do dołożenia:

- **Pełny ekran / rozdzielczość / VSync / limit FPS.**
- **Szyny audio** — `AudioService` gra dziś na jednym poziomie głośności. Zrób szyny
  `Master / Music / SFX / Ambience` i trzy suwaki. Wymagane, zanim dojdzie muzyka.
- **Zmiana klawiszy (rebinding)** — `InputMap` już ma pełną mapę z gamepadem, brakuje tylko
  UI i zapisu do `settings.json`.
- **`sprint_mode` (hold/toggle)** — pole jest w `SettingsStore` od początku, świadomie bez
  konsumenta, bo Phaser nie miał czego portować. Teraz **jest** własna decyzja projektowa:
  podłącz je do klawiatury.
- **Ikony padów** — podmiana glifów wg podłączonego kontrolera.

### Dostępność

- **`reducedMotion`** — wyłącza shake, ghost-trail, pulse-zoom, cząsteczki. Odłożone
  w migracji, teraz ma gdzie zamieszkać.
- **Suwak siły trzęsienia kamery** (0-100 %) zamiast binarnego przełącznika.
- **Skala fontu UI** (100/125/150 %) — trywialne, gdy jest `Theme` (0.4).
- **Tryb dla daltonistów** dla tierów bliskości — dziś tier to sam kolor
  (`tierStyle.ts` nie został sportowany); dołóż kształt/ikonę, nie tylko barwę.
- **Napisy/logi dialogów** z możliwością odtworzenia ostatniej wiadomości.

### Wygoda

- **Strzałka/kompas do celu** — `GoalProximity` liczy już dystans i kierunek; dziś to tylko
  tekst w HUD. Strzałka na krawędzi ekranu to konsumpcja istniejących danych.
- **Minimapa** poziomu z odkrytymi itemami.
- **Tryb foto** — ukryj HUD, swobodna kamera, zoom, zapis PNG. Naturalny dla gry o kocie
  i darmowy marketing.
- **Statystyki** — przejścia, skoki (`totalHops` nie sportowane), dystans, najlepsze czasy.
- **Podpowiedzi startowe na L1** — dziś nie ma żadnego tutorialu.
- **Legenda sterowania** pod F1 / w pauzie.

Skills: `godot-ui`, `save-load`, `input-handling`, `audio-system`, `hud-system`.

---

## 7. Faza 6 — UI/UX i menu (odpowiedź na "ładne menu")

### 7.1 Kierunek artystyczny — ustalić przed pierwszym pikselem

To gra o kocie w **realnym Szczecinie** — Wały Chrobrego, Park Kasprowicza, Aleja
Kasztanowa, Łucznicza 43. To jest gotowy, mocny kierunek i szkoda go zmarnować na
generyczny ciemny motyw z neonem.

Propozycja: **ciepła ilustracja / książka obrazkowa**. Paleta z teł poziomów (ochra,
przygaszona zieleń, ciepły brąz, kremowy papier), zaokrąglone panele z lekkim cieniem,
faktura papieru w tle menu, font humanistyczny szeryfowy lub miękki bezszeryfowy —
**warunek konieczny: pełne pokrycie polskich diakrytyków.**

### 7.2 `Theme` to fundament, nie ozdoba

Jeden `edek_theme.tres`: `StyleBoxFlat`/`StyleBoxTexture` dla `Panel`/`Button`/`PanelContainer`,
kolory stanów (`normal`/`hover`/`pressed`/`focus`/`disabled`), `Font` + rozmiary jako type
variations (`HeaderLarge`, `Body`, `Caption`). **Żadnych `add_theme_*_override` w kodzie
gameplayowym** — dziś są trzy, wszystkie do usunięcia.

### 7.3 Ekrany

| Ekran | Uwagi |
|---|---|
| **Splash / tytuł** | Logo, kot w idle-animacji na pierwszym planie, ambient tła |
| **Menu główne** | Kontynuuj / Nowa gra / Poziomy / Wyzwanie dnia / Ustawienia / Wyjdź. Wejście panelu na `Tween` ze staggerem |
| **Wybór poziomu** | **Duży pomysł: mapa Szczecina z pinezkami zamiast listy.** Poziomy to realne miejsca — lista `VBoxContainer` marnuje ten atut. Pinezka = miniatura + tytuł + ✓ + najlepszy czas; zablokowane wyszarzone. Fallback do listy, jeśli mapa okaże się za droga |
| **Ustawienia** | Sekcje w `FoldableContainer` (Godot 4.5+): Gra / Obraz / Dźwięk / Sterowanie / Dostępność |
| **Pauza** | Półprzezroczysta nakładka + blur (`BackBufferCopy` lub shader), te same style co menu |
| **Podsumowanie poziomu** | Czas, zebrane, questy, rekord (z animacją, gdy pobity), Dalej / Powtórz / Menu |

### 7.4 HUD — przeprojektowanie

- **Pasek energii jako prawdziwy `ProgressBar`** ze `StyleBox` (dziś to `Label` z tekstem
  `Energia: NN%` — komentarz w `HUD.gd` wprost mówi, że brak Theme był powodem).
- **Checklist questów** z animowanym ptaszkiem i miękkim przejściem koloru zamiast `[x]/[ ]`.
- **Chipy ekwipunku** z prawdziwymi ikonami itemów (po Fazie 1.3).
- **Toasty** zamiast jednego `MessageLabel` — kolejkowane, znikające, nie nadpisujące się.
- **Strzałka do celu** na krawędzi ekranu (dane są, patrz Faza 5).
- **HUD chowa się** przy bezczynności / w trybie foto.

### 7.5 Dialogi

Zastąp `MessageLabel` prawdziwym okienkiem: portret NPC, efekt maszyny do pisania,
przewijanie, `interact` do przewinięcia/pominięcia. **Rekomendacja: zbuduj mały własny**
(masz `EventBus` i wzorzec Resource) zamiast instalować Dialogue Manager — addon opłaci się
dopiero, gdy pojawią się rozgałęzione wybory. Nie instaluj na zapas.

### 7.6 Nawigacja i responsywność

- **Pełna obsługa klawiatury i pada w menu** — dziś zero: brak `focus_neighbor_*`, brak
  `grab_focus()` na wejściu, brak stylu focusu. `InputMap` ma gamepada, UI go nie widzi.
- Dźwięk na zmianę focusu i na potwierdzenie.
- **Responsywność**: `stretch/mode = canvas_items` jest ustawione, ale bez `aspect` —
  ustaw `expand` i przetestuj 16:9, 16:10, **1280×800 (Steam Deck)** i ultrawide.
  Kotwice i kontenery zamiast sztywnych `offset_*`, których w `HUD.tscn` jest dziś sporo.
- Respektuj `reducedMotion` we wszystkich animacjach UI.

Skills: `godot-ui`, `responsive-ui`, `hud-system`, `dialogue-system`, `tween-animation`.

---

## 8. Rekomendowana kolejność — pięć rzeczy o najwyższym zwrocie

Jeśli miałbym wybrać tylko pięć pozycji z całego dokumentu, w tej kolejności:

1. **Faza 0 w całości** (menu + pauza + Theme + dług HOP). Gra przestaje być prototypem.
2. **Y-sort + prawdziwe propy na jednym poziomie** (2.1-2.2). Największa różnica wizualna
   w całym planie, a zrobiona na jednym poziomie jest odwracalna.
3. **`AnimationTree` + idle-warianty** (3.1-3.2). Kot staje się postacią, nie sprite'em.
4. **Wyzwanie dnia + tryb na czas** (Faza 4, poz. 1-2). Kod i dane już są — to głównie UI.
5. **Hop przeskakujący przeszkody + piłka na `RigidBody2D`** (4.1-4.2). Mechanika
   sygnaturowa dostaje wreszcie funkcję.

---

## 9. Decyzje

### ROZSTRZYGNIĘTE (użytkownik, 2026-08-31)

1. **Kierunek graficzny świata = hybryda.** Siedem istniejących poziomów **zostaje na
   pre-renderowanych tłach JPEG**, propy kładziemy na wierzchu (Y-sort + `PropData`, punkty
   7-11). **Nowe poziomy powstają na prawdziwych `TileSet`ach z Terrain Sets** (L7 jest
   precedensem — `TileMapLayer` już tam działa). Konsekwencje wiążące:
   - Nie przebudowujemy L1-L6 na tilesety. Zero ryzyka regresji na przetestowanej zawartości.
   - `LevelObjectData.prop_id` **musi** być wstecznie kompatybilne (puste = dzisiejszy
     niewidzialny `Rect2`), bo oba światy będą współistnieć na stałe, nie przejściowo.
   - `LevelRuntime._setup_background()` obsługuje dwie ścieżki (tło-sprite i `TileMapLayer`)
     jako równorzędne, nie jako "stara i nowa" — obecna gałąź `if level.id == "7"` musi
     zostać uogólniona do pola w `LevelData` (np. `background_mode`), zanim powstanie
     poziom 8.

2. **Punkt startowy = Faza 0 (fundament).** Kolejność w następnej sesji: punkt 1 (dług HOP
   → `PlayerHopState`, branch `migration/player-physics`) → punkt 2 (rozbicie
   `PlayerMovement.gd` na komponenty) → punkt 3 (testowy profil zapisu) → punkty 4-6
   (`Theme` + font PL, menu główne, pauza). Świat i animacje ruszają dopiero po tym.

### OTWARTE

3. **Źródło grafiki propów i itemów** — masz częściowo wykorzystane paczki Kenneya
   (`FurnitureState2.png`, `SmallItems.png` nietknięte). Wystarczą na wnętrza, ale nie na
   park. Trzeba zdecydować: dokupić/dobrać paczkę, rysować samemu, czy zostać przy emoji
   dla części obiektów. **Nic nie pobieram bez Twojej wyraźnej zgody** (zasada z poprzedniej
   sesji obowiązuje).
3. **Docelowa skala projektu** — gra rodzinna/osobista czy realny plan wydania (Steam/itch)?
   To determinuje głębokość ustawień, achievementów, statystyk i eksportu. Dziś plan zakłada
   "porządna gra osobista z opcją wydania" — powiedz, jeśli celujesz wyżej lub niżej.

---

## 10. Zasady niezmienne w trakcie całej rozbudowy

- `src/game/phaser/` **nietknięty** (Zasada 1 z `god/godot.md`), ale przestaje być wzorcem.
- **Jeden podsystem = jedna gałąź** (`feature/world-props`, `feature/animation-tree`, ...),
  walidacja (kompiluje się, uruchamia, GUT przechodzi, przetestowane ręcznie) przed przejściem
  dalej.
- **GUT przed i po** każdym podsystemie; nowe systemy dostają własne testy w `tests/`.
- **Inspekcja przed akcją** — struktura sceny odczytana przez MCP/plik, nie zgadnięta.
- **Kompozycja, małe pliki** — nowa funkcja to nowy komponent, nie kolejne 200 linii.
- **Ścisłe typowanie** we wszystkim, co nowe.
- **Weryfikacja assetów przed zahardkodowaniem** współrzędnych (crop-and-view).
- **Nic nie pobieramy bez pytania** — nazwa pliku, źródło, rozmiar, potem zgoda.
- **Profiler przed optymalizacją** — intuicje w tym repo myliły się już dwukrotnie.
- **Wygląd potwierdza użytkownik.** Przechodzące asercje i czysty boot nie są dowodem, że coś
  wygląda dobrze.

---

## 11. Plan rozbudowy — 30 konkretnych punktów

Kolejność jest zależnościowa: każdy punkt zakłada, że wcześniejsze z jego grupy są zrobione.
`S` = pół sesji, `M` = 1-2 sesje, `L` = 3+ sesji.

### Fundament (1-6) — bez tego reszta drożeje

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 1 | **Dług HOP do state machine** — ✅ **kod gotowy (2026-08-31), commit `0c78ddd` na `migration/player-physics`**, GUT 37/37 PASS przed i po. ⚠️ **Brakuje ręcznego retestu feelu w edytorze — nie mergować przed tym.** `PlayerHop.gd` nietknięty (nadal jedyne źródło bufora/coyote/cooldown), tylko wykorzystanie jego wyniku przeniesione do `PlayerHopState.physics_update()`. Walk/Sprint/Idle świadomie NIE ruszone w tym kroku | M | `state-machine`, `player-controller` |
| 2 | **Rozbić `PlayerMovement.gd` (262 l.) na komponenty** — `PlayerLocomotion` / `PlayerVisuals` / `PlayerEnergyGate`. Zasada 2 | M | `component-system` |
| 3 | **Testowy profil zapisu** — GUT przestaje pisać do prawdziwego `progress.json` | S | `godot-testing`, `save-load` |
| 4 | **`Theme` + font z pełnymi polskimi diakrytykami**, usunięcie `add_theme_*_override` z kodu gameplayowego | M | `godot-ui` |
| 5 | **Menu główne** + `run/main_scene` na menu zamiast `Level1.tscn` | M | `godot-ui` |
| 6 | **Pauza (Esc)** + potwierdzenie wyjścia + restart poziomu (R) | S | `godot-ui` |

### Świat (7-12) — największy zwrot wizualny

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 7 | **Y-sortowanie** — `y_sort_enabled` na świecie, `y_sort_origin` w podstawie każdego obiektu, gracz i NPC w tym samym poddrzewie | S | `2d-essentials` |
| 8 | **`PropData` + `Prop.tscn` + `data/props/*.tres`** — biblioteka propów wzorowana na `ItemData`/`ItemRegistry`; `LevelObjectData.prop_id` wstecznie kompatybilne | M | `resource-pattern` |
| 9 | **Migracja L7, potem L1 na prawdziwe propy** — po jednym poziomie, odwracalnie | L | `2d-essentials` |
| 10 | **Tekstury itemów zamiast emoji** (`ItemData.texture`, fallback do emoji zostaje) + bujanie i glow | M | `resource-pattern` |
| 11 | **Kolizje wielokątne + occludery na propach + miękki cień pod kotem** — koniec z `Rect2(0, 800, 3200, 100)` jako rzeką | M | `physics-system`, `2d-essentials` |
| 12 | **Shadery świata** — wiatr w roślinności, woda, zanikające ślady łap | M | `shader-basics`, `particles-vfx` |

### Animacja (13-16) — kot staje się postacią

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 13 | **`AnimationTree` + `BlendSpace2D`** sterowany wektorem prędkości; automat animacji rozdzielony od gameplayowego | M | `animation-system` |
| 14 | **Idle-breathing + idle-warianty** (siada, liże łapę, macha ogonem, zasypia po ~30 s) | M | `animation-system` |
| 15 | **Anticipation / landing / uderzenie w ścianę** — pełny łuk hopa, reakcja na twarde zderzenie (sygnał już istnieje w `CameraFX`) | S | `animation-system`, `tween-animation` |
| 16 | **Animacje NPC, propów i przejść UI** — sprite'y wiewiórki/gołębia zamiast emoji, intro-pan kamery, flourish questu | M | `animation-system` |

### Fizyka (17-20) — mechaniki dostają funkcję

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 17 | **Hop, który faktycznie przeskakuje** — warstwa `LowObstacle` (6), maska zdejmowana na czas skoku, wypchnięcie przy lądowaniu w przeszkodzie | M | `physics-system` |
| 18 | **`RigidBody2D`: piłka, kłębek, przewracalna miska** — kot popycha impulsem z `get_slide_collision()`, warstwa `Dynamic` (7) | M | `physics-system` |
| 19 | **Zagrożenia** — `LevelBuilder` obsługuje `kind == "trigger"`; kałuża, ulica, woda, pies. Energia wreszcie ma stawkę, `play_danger()` przestaje wisieć | M | `physics-system` |
| 20 | **`NavigationRegion2D` + `NavigationAgent2D`** — patrol po ścieżce, pies goniący, wiewiórka uciekająca, gołębie odlatujące | M | `ai-navigation` |

### Sterowanie (21-24) — szczegóły w sekcji 12

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 21 | **UI zmiany klawiszy** — `InputMap` już ma pełną mapę z padem, brakuje ekranu i zapisu do `settings.json` | M | `input-handling` |
| 22 | **Pakiet responsywności inputu** — sprint hold/toggle, buforowanie `interact`, "lepki" cel interakcji, auto-zwrot w stronę obiektu | M | `input-handling` |
| 23 | **Gamepad na serio** — wibracje przy lądowaniu/zderzeniu, radialna martwa strefa, automatyczne przełączanie glifów klawiatura/pad | S | `input-handling` |
| 24 | **Nawigacja fokusem w całym UI** (`focus_neighbor_*`, `grab_focus()`, styl focusu, dźwięk) + opcjonalnie `VirtualJoystick` pod ewentualne mobile | M | `godot-ui`, `responsive-ui` |

### Tryby gry (25-27) — szczegóły w sekcji 14

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 25 | **`GameModeData` + modyfikatory jako Resources** — jeden `LevelRuntime`, tryby jako dane, nie gałęzie kodu | M | `resource-pattern`, `dependency-injection` |
| 26 | **Wyzwanie dnia** — podłączenie gotowego `DailyChallenge.gd` do menu, streak, historia, modyfikator dnia | M | `save-load`, `godot-ui` |
| 27 | **Na czas + duch + Zbieractwo** — timer, splity, nagrywanie i odtwarzanie ducha, tryb zbierania na punkty z combo | L | `save-load`, `hud-system` |

### UI, QoL, dostępność (28-30)

| # | Zadanie | Rozm. | Skills |
|---|---|---|---|
| 28 | **Przeprojektowany HUD** — energia jako `ProgressBar` ze `StyleBox`, toasty zamiast jednego `MessageLabel`, strzałka do celu na krawędzi ekranu, animowane ptaszki questów | M | `hud-system` |
| 29 | **Dialogi + dziennik + ekwipunek na `I`** — okno dialogowe z portretem i maszyną do pisania, album zebranych rzeczy, dziennik questów | L | `dialogue-system`, `inventory-system` |
| 30 | **Pakiet "ukryta moc" + dostępność** — cała sekcja 13 plus `reducedMotion`, skala fontu, suwak trzęsienia, tryb dla daltonistów | M | `godot-ui`, `player-controller` |

---

### Gdzie w tych 30 punktach siedzi audyt zasad 4-7

Cztery znaleziska z audytu architektonicznego nie są osobnymi punktami — są **warunkami
wstępnymi** punktów, które i tak są w planie. Robione w tej kolejności nic nie kosztują
dodatkowo; robione po fakcie oznaczają przepisywanie tego samego dwa razy.

| Znalezisko | Wchodzi do | Dlaczego tam |
|---|---|---|
| `mood`/`point_light` jako `Dictionary` → `Resource` | **przed punktem 12** (shadery świata) | Shadery i pogoda z pomysłu 7 będą czytać te dane; typowany `MoodData` teraz = brak refaktoru przy trzech wariantach pory dnia |
| NPC bez FSM | **wewnątrz punktu 20** (nawigacja) | Pies, uciekająca wiewiórka i odlatujące gołębie to 3 nowe zachowania. Bez `StateMachine` wylądują jako `if`-y w `NpcActor.gd` |
| HUD wołany bezpośrednio zamiast przez `EventBus` | **przed punktem 28** (redesign HUD) | Przepisanie wyglądu HUD-a bez wcześniejszego rozprzęgnięcia = sprzężenie zostaje w nowym kodzie |
| Brak spawnera, ghost-trail alokuje ~22 obiekty/s | **wewnątrz punktu 2** (rozbicie `PlayerMovement.gd`) | `PlayerVisuals` i tak przejmuje ghost-trail — to jest właściwy moment, żeby wyszedł z niego do `VfxSpawner` z pulą, a nie do kolejnego pliku alokującego per klatkę |

---

## 12. Sterowanie — co konkretnie ulepszyć

Baza jest dobra (`InputMap` z gamepadem, `Input.get_vector()`, coyote time, jump buffering).
Braki są w warstwie **komfortu**, nie w warstwie technicznej.

**Responsywność**

- **Buforowanie `interact`** — naciśnięcie E ~150 ms przed wejściem w zasięg nadal działa.
  Ten sam wzorzec, który już masz w `PlayerHop` dla skoku, tylko dla interakcji.
- **"Lepki" cel interakcji** — `InteractionDetector` wybiera dziś najbliższy obiekt; gdy dwa
  są prawie równo blisko, cel migocze. Dodaj histerezę: obecny cel wygrywa, dopóki inny nie
  jest bliżej o co najmniej ~15 %.
- **Auto-zwrot w stronę celu** przy interakcji — kot patrzy na to, z czym rozmawia.
- **Korekta narożników** — przy ruchu po skosie w róg przeszkody delikatnie zsuń gracza
  wzdłuż ściany zamiast zatrzymywać. Najbardziej niedoceniana rzecz w grach top-down.

**Konfiguracja**

- **Zmiana klawiszy** z UI, zapis do `settings.json`, przycisk "przywróć domyślne", detekcja
  konfliktów.
- **`sprint_mode` hold/toggle** — pole czeka w `SettingsStore` od początku migracji.
- **Radialna martwa strefa** dla gałki zamiast per-osiowej (dziś `deadzone: 0.2` na oś, przez
  co ruch po skosie ma inny próg niż w pionie).
- **Opcjonalne przyciąganie do 8 kierunków** dla graczy preferujących precyzję nad swobodą.

**Pad i platformy**

- **Wibracje** (`Input.start_joy_vibration`) przy lądowaniu z hopa, twardym zderzeniu,
  zebraniu itemu — te trzy zdarzenia już emitują sygnały do `CameraFX`, wystarczy je podpiąć.
- **Automatyczne przełączanie glifów** klawiatura ↔ pad przy pierwszym zdarzeniu z drugiego
  urządzenia.
- **`VirtualJoystick`** (Godot 4.7) — tylko jeśli mobile w ogóle wchodzi w grę. Do tego czasu
  nie budować.

**Dostępność sterowania**

- Układ jednoręczny, "lepki sprint" (nie trzeba trzymać), pełne przemapowanie na pada,
  regulacja czasu przytrzymania.

---

## 13. Ukryta moc QoL — rzeczy, których gracz nigdy nie zauważy, a poczuje

To jest kategoria, w której gry "czują się dobre" bez jednej widocznej funkcji na liście.
Część tego już masz (coyote time 120 ms, jump buffering 150 ms, cooldown 260 ms) — to dowód,
że ten sposób myślenia jest w projekcie obecny. Reszta do dorobienia:

1. **Magnetyczne zbieranie** — item w promieniu ~24 px dryfuje do kota. Znika frustracja
   "byłem pół piksela obok".
2. **Asymetryczne hitboxy** — hitbox do zbierania **większy** niż sprite, hitbox do obrażeń
   **mniejszy**. Gracz czuje się zręczny, nie oszukany.
3. **Łaska na energii** — gdy energia spadnie do zera w trakcie sprintu, daj ~0.4 s wybiegu
   zamiast twardego odcięcia w połowie kroku.
4. **Opóźniony drenaż** — energia nie zaczyna spadać przez pierwsze ~0.2 s sprintu, więc
   krótkie zrywy są darmowe i nie karzą za mikro-korekty.
5. **Wyprzedzanie kamery** — kamera przesuwa się lekko w stronę ruchu (~40 px przy sprincie).
   Widzisz więcej tam, gdzie biegniesz.
6. **Martwa strefa kamery** — kamera nie reaguje na drobne ruchy w środku ekranu. Koniec
   z mikro-drganiem obrazu przy stojącym kocie.
7. **Wariacja wysokości dźwięku** ±5 % przy powtarzanych SFX — piąty item z rzędu przestaje
   brzmieć jak robot. `AudioService` ma pulę 8 głosów, więc miejsce jest.
8. **Auto-pauza przy utracie focusu okna** (`NOTIFICATION_APPLICATION_FOCUS_OUT`) —
   alt-tab nie kosztuje postępu.
9. **Wczytywanie w tle** — `ResourceLoader.load_threaded_request()` na następny poziom
   podczas ekranu podsumowania. `SceneRouter` już robi fade, więc jest gdzie to schować.
10. **Pamięć wyborów** — menu wraca na ostatnio wybrany poziom, ustawienia otwierają się na
    ostatnio używanej sekcji.
11. **Automatyczne pomijanie widzianych dialogów** przy powtórnym przejściu poziomu.
12. **Audyt niezależności od klatek** — masz już jeden złapany przypadek (lerp lean przy
    120 Hz). Przejrzyj wszystkie pozostałe współczynniki per-klatka pod tym kątem, raz.
13. **Zapis przy wyjściu i przy każdym quescie**, nie tylko na eventach zbierania.
    Atomic save już jest, brakuje momentów wyzwalania.
14. **Ciche pochłanianie podwójnych zdarzeń** — item zebrany dwa razy w tej samej klatce,
     dialog otwarty dwukrotnie. Tanie zabezpieczenia, drogie bugi.
15. **Priorytet wejścia** — gdy otwarty jest dialog/pauza, gameplay nie konsumuje inputu
    (`set_input_as_handled()`), zamiast reagować "przez" UI.

---

## 14. Nowe tryby gry — szczegóły

Wszystkie oparte o jeden `GameModeData` (punkt 25), nie o osobne gałęzie `LevelRuntime`.

**A. Na czas (Time Attack)** — dane już są (`best_level_times`).
Timer w HUD, splity per quest, medale brąz/srebro/złoto per poziom, osobny ranking dla
pełnego przejścia kampanii (speedrun). Restart jednym klawiszem bez powrotu do menu.

**B. Wyścig z duchem** — najlepsze przejście nagrywane jako pozycje co 100 ms, odtwarzane
jako półprzezroczysty kot. **Kod ghost-trail ze sprintu jest gotowym budulcem wizualnym** —
tint `0x8fd0ff`, alpha 0.32, kopiowanie klatki i rotacji już zaimplementowane. Ściganie się
z własnym rekordem to najtańsza możliwa rywalizacja: zero serwerów, zero kont.

**C. Kocie skarby (zbieractwo)** — N przedmiotów rozrzuconych losowo (z ziarnem, żeby dało się
powtórzyć i podzielić kodem), zbierz jak najwięcej w X sekund. **Combo:** każdy item w ciągu
3 s od poprzedniego podbija mnożnik, przerwa go zeruje. To zamienia znajomy poziom w zupełnie
inną grę bez rysowania ani jednego nowego piksela.

**D. Ucieczka** — pies (punkt 20) goni, kot ucieka do bezpiecznego miejsca; energia staje się
zasobem krytycznym, a hop przez płotek (punkt 17) staje się umiejętnością przetrwania.

**E. Dostawca** — dopchnij `RigidBody2D` (piłkę, kłębek) do celu bez zgubienia. Wymaga tylko
punktu 18 i jednej strefy celu.

**F. Wyzwanie dnia** — gotowy kod, brakuje ekranu. Poziom dnia + 2 losowe modyfikatory
(np. "podwójna prędkość", "bez sprintu", "noc", "wszystko waży więcej"), jedna próba,
streak, historia 7 dni.

**G. Spacer** — bez questów, bez energii, bez timera. Znajdźki, tryb foto, ambient. Tryb dla
kogoś, kto chce po prostu pooglądać Szczecin.

**H. Nowa gra+** — te same poziomy, więcej zagrożeń, mniej energii, itemy w innych miejscach.

---

## 15. Moje pomysły — rzeczy, o które nie pytałeś

Uporządkowane od "zrobiłbym to jutro" do "duży pomysł na później".

1. **Kot ma nastrój.** Ukryta wartość 0-1 rosnąca od zebranych rzeczy, rozmów i odpoczynku,
   spadająca od zderzeń, zagrożeń i zmęczenia. Nie pokazuj jej nigdzie w HUD — steruj nią
   tylko doborem idle-animacji, tempem ogona i barwą miauknięć. Gracz zauważy, że "kot jest
   dziś zadowolony", nie wiedząc dlaczego. Kosztuje jedną zmienną i wagi w losowaniu z punktu 14.

2. **Węch zamiast strzałki.** Zamiast klasycznego wskaźnika celu: przytrzymaj `Q`, kot
   podnosi nos, z ekranu rozchodzi się impuls i najbliższy szukany przedmiot błyska. Kosztuje
   trochę energii i ma cooldown. Masz już policzone dystanse i kierunki w `GoalProximity` —
   to jest ta sama dana, tylko podana jak mechanika kota, a nie jak GPS.

3. **Miauknięcie jako czasownik.** Jeden klawisz, jedno miauknięcie: gołębie odlatują,
   wiewiórka zamiera, NPC się odwraca, śpiący kot się budzi. Jedna akcja, wiele reakcji
   zależnych od kontekstu — najtańszy sposób, żeby świat wydawał się reaktywny.

4. **Ślady i brud.** Kot, który przejdzie przez kałużę, przez chwilę zostawia mokre łapki na
   tle. Wizualnie kosztuje tyle co punkt 12, a jest jedną z tych rzeczy, które ludzie
   pokazują znajomym.

5. **Album kota zamiast ekwipunku.** Zebrane przedmioty nie jako siatka ikon, ale jako karty
   w albumie z jednozdaniowym opisem po polsku ("Piłeczka z Wałów. Pachnie Odrą."). To ta sama
   dana co dziś, opowiedziana jak książka dla dzieci. Pasuje do kierunku artystycznego z 7.1.

6. **Pocztówki ze Szczecina.** Ukończenie poziomu odblokowuje pocztówkę z prawdziwego miejsca
   (Wały, Park Kasprowicza, Aleja Kasztanowa). Ściana pocztówek jako ekran kolekcji. Gra
   dostaje tożsamość, której nie ma żadna inna gra o kocie: **jest o konkretnym mieście.**

7. **Pora dnia i pogoda jako modyfikatory poziomu.** Masz już system `mood` z brightness/
   contrast/saturation/hue/sepia per poziom — to jest gotowa infrastruktura na "ten sam park
   o świcie, w południe i po zmierzchu". Deszcz spowalnia kota (nie lubi wody), noc zmienia
   które NPC są obecne. Trzy warianty każdego poziomu za cenę danych, nie kodu.

8. **Mapa Szczecina jako ekran wyboru poziomu.** Powtarzam z 7.3, bo uważam to za
   najmocniejszy pojedynczy pomysł na UI w tym projekcie: pinezki na stylizowanej mapie
   zamiast `VBoxContainer` z siedmioma przyciskami. Poziomy to realne miejsca — lista to marnuje.

9. **Wysokość jako trzecia warstwa.** Kot wchodzi hopem na ławkę, murek, parapet — osobna
   warstwa kolizji dla "na podwyższeniu", z której widać dalej i gdzie nie sięgają psy.
   Duży kawałek pracy, ale to naturalne rozwinięcie punktu 17 i jedyna rzecz na tej liście,
   która realnie zmienia projektowanie poziomów.

10. **Drugi kot lokalnie (co-op).** Ten sam ekran, drugi pad, druga postać. Godot obsługuje
    wielu graczy na jednym urządzeniu bez żadnej warstwy sieciowej, a `InputMap` z `device`
    jest do tego przygotowany. Gra rodzinna o kocie ze Szczecina, w którą gra się we dwoje,
    jest lepszym produktem niż ta sama gra dla jednego. To decyzja na poziomie wizji, nie
    zadanie — dlatego jest ostatnia.

