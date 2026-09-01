# RPG — plan refaktoryzacji z eksploracji top-down na 2D action-RPG z walką

Autor: sesja "principal/senior lead game developer", 2026-08-31, branch `feature/rpg-stats`
(od `migration/input-player`). Wejście: audyt realnych assetów w `godot/assets/assety/`,
`godot/README.md`, `docs/migration/MIGRATION_MATRIX.md`, `docs/migration/COLLISION_MATRIX.md`,
`docs/ROADMAP.md`, `plan31-08.md`, oraz realny kod w `godot/scripts/`.

Ten dokument **nie** dubluje `docs/ROADMAP.md` (to plan rozbudowy QoL/świata/animacji dla gry
eksploracyjnej o kocie) ani `plan31-08.md` (log migracji Phaser→Godot). To jest plan
**nowego pionu funkcjonalnego — walki** — i tego, jak wchodzi w istniejącą architekturę
bez jej dublowania ani łamania.

---

## 0. Zasady obowiązujące (bez zmian względem reszty projektu)

Te same, co w `docs/ROADMAP.md` sekcja "Zasady pracy" — powtórzone tu dla kompletności,
bo ten dokument prowadzi osobny strumień pracy:

1. **Inspekcja przed akcją** — struktura sceny/asset odczytana (MCP/plik/wymiary PNG),
   nie zgadnięta. Ten plan powstał *po* pełnym audycie assetów (sekcja 2), nie przed.
2. **Kompozycja, małe pliki** — nowy system to nowy komponent (`Node`/`Area2D` jako
   dziecko), nie kolejne 200 linii w istniejącym skrypcie.
3. **Błędy naprawiamy przez narzędzia** — MCP Godot / czytanie źródła, ścisłe typowanie
   wszędzie w nowym kodzie.
4. **Dane jako `Resource`** — statystyki, wrogowie, bronie, obrażenia to dane, nie kod.
5. **FSM dla wszystkiego z >2 zachowaniami** — gracz już ma wzorzec
   (`PlayerState`/`PlayerStateMachine`), wrogowie dostają analogiczny.
6. **UI przez `EventBus`**, nigdy `get_node()` z HUD-a do gracza/wroga.
7. **Spawner / pула obiektów** dla wszystkiego, co powstaje często (pociski, VFX trafień).
8. **`src/game/phaser/` nietknięty** — referencyjny, nie do naśladowania w tym pionie
   (Phaser nigdy nie miał walki — to jest czysto nowa zawartość, nie port).
9. **Jeden podsystem = jedna gałąź**, GUT przed i po, walidacja w edytorze przed mergem.
10. **Nic nie pobieramy bez pytania** — audyt (sekcja 2) używa wyłącznie tego, co już
    leży w `godot/assets/assety/`.

---

## 1. Decyzje rozstrzygnięte (użytkownik, 2026-08-31)

| # | Decyzja | Konsekwencja |
|---|---|---|
| 1 | **Gracz zostaje kotem.** Assety ludzkie/RPG (Cute Fantasy, Tiny RPG, Tiny Swords, Mana Seed) idą wyłącznie na **wrogów i UI walki**, nie zastępują gracza. | Zero ryzyka regresji na przetestowanym ruchu/hopie/animacjach kota. Walka to nowa warstwa dołożona do istniejącego gracza, nie przepisanie go. |
| 2 | **Pierwszy wróg: `Demon_A`** (Tiny RPG Character Asset Pack 02). | Jedyna paczka z kompletnym, gotowym zestawem `Idle/Walk/Attack01/Attack02/Hurt/Death` bez cięcia na piechotę — najniższy koszt integracji, najszybsza ścieżka do grywalnego prototypu walki. `Blood Monster_A` (ta sama paczka, ten sam layout) — drugi typ wroga za darmo, tym samym pipeline'em. |
| 3 | **UI walki: Tiny Swords teraz, re-skin później.** Paski HP (`Bars/BigBar_Base+Fill`), ikony (`Icons/Icon_01..12`), przyciski — użyte funkcjonalnie od razu (jako `TextureProgressBar`/`TextureRect`), wymiana na styl "ciepła ilustracja" (`docs/ROADMAP.md` 7.1) to osobna, późniejsza faza wizualna, nie blokuje funkcji. | HUD walki (`HealthBar`, `EnemyHealthBar`) korzysta z realnej grafiki od pierwszego GUT-a, nie z placeholderowych `ColorRect`. |
| 4 | **`godot/assets/assety/walk/`** (domniemane dawne "pielarty") **zostaje poza zakresem.** Nieregularna siatka klatek, niepewne pochodzenie. | Nie blokuje żadnego z powyższych — jeśli okaże się potrzebny w przyszłości (dodatkowy NPC?), wraca jako osobny, świadomy krok z re-eksportem z `.aseprite`, nie zgadywaniem `Rect2i`. |

---

## 2. Audyt assetów — skrót (pełna wersja w historii konwersacji tej sesji)

Zweryfikowane realnie: wymiary PNG (`System.Drawing.Image` przez PowerShell, nie zgadywane),
zawartość wizualna (`Read` na obrazkach), obecność `.tres`/`SpriteFrames` (brak — wszystko
surowe PNG, nic gotowego do wciągnięcia bez przejścia przez importer).

### Gracz — potwierdzenie decyzji #1, nie wykorzystywane teraz
- Cute Fantasy Free `Player/Player.png` (192×320, 32×32) + `Player_Actions.png` (96×576,
  atak mieczem w 4 kier. + łuk) — najlepszy kandydat, gdyby kiedyś padła decyzja o zmianie
  gracza. Dziś nieużywany.
- Mana Seed Character Base — paperdoll (baza + warstwy ubrań/broni), osobny, droższy system
  integracji. Nieużywany teraz.

### Wrogowie — do wykorzystania (decyzja #2)
| Paczka | Siatka | Animacje potwierdzone | Status |
|---|---|---|---|
| **Tiny RPG `Demon_A`** | 100×100/klatkę, osobne pliki per-animacja | `Idle`(6) `Walk`(8) `Attack01`(8) `Attack02`(7) `Hurt`(4) `Death`(4) | **Wybrany pierwszy wróg** |
| **Tiny RPG `Blood Monster_A`** | jw. | jw. (te same nazwy plików, drugi skin) | Drugi wróg, ten sam pipeline |
| Cute Fantasy `Enemies/Skeleton.png` | 32×32, 192×320 | walk 4-kier. + warianty (atak niepotwierdzony) | Rezerwa na później |
| Tiny Swords Units (Warrior/Archer/Lancer/Pawn/Monk) | wysokość rzędu 192-320px | Idle/Run/Attack1/Attack2/Guard | Nadwyżka — jednostki RTS, nie na pierwszy sprint |

### UI walki — potwierdzone gotowe (decyzja #3)
`Tiny Swords/UI Elements/UI Elements/`: `Bars/{Big,Small}Bar_{Base,Fill}.png`,
`Icons/Icon_01..12.png` (64×64), `Buttons/*`, `Human Avatars/Avatars_01..25.png` (256×256).

### VFX trafień
`Super Pixel Effects Gigapack`: `PNG/Impacts/`, `PNG/Splatters/`, `PNG/Explosions/` —
**klatki jako osobne pliki w podfolderach**, nie jeden spritesheet (do zaimportowania jako
`SpriteFrames` z sekwencji plików). `Tiny Swords/Particle FX/`: arkusze pojedyncze
(`Fire_01-03`, `Dust_01-02`) — prostsze w użyciu.

### Braki potwierdzone
- **Zero dźwięków combat** w `assety/` — `AudioService.gd` generuje SFX proceduralnie
  (`AudioStreamGenerator`); iść tą samą drogą dla whoosh/impact, nie pobierać próbek bez pytania.
- Brak danych balansu (HP/obrażenia/prędkość) — to i tak nowe `Resource`, zgodnie z zasadą 4.

### Nierozstrzygnięte, świadomie odłożone
- `godot/assets/assety/walk/` — patrz decyzja #4.

---

## 3. Architektura — jak walka wchodzi w istniejący system

### 3.1 Warstwy kolizji — rozszerzenie `COLLISION_MATRIX.md`, nie zastąpienie

Dziś zajęte: 1 World, 2 Player, 3 Items, 4 NPCs, 5 Danger (zarezerwowana, bez konsumenta).
Nowe warstwy potrzebne dla walki:

| # | Nazwa | Kto | Mask |
|---|---|---|---|
| 6 | `Enemies` | `EnemyActor` (`CharacterBody2D`) | 1 (World) — fizycznie koliduje z geometrią poziomu jak gracz |
| 7 | `PlayerHitbox` | `Area2D` dziecko gracza, aktywne tylko w oknie ataku | mask 6 (Enemies) |
| 8 | `EnemyHitbox` | `Area2D` dziecko wroga, aktywne w oknie ataku wroga | mask 2 (Player) |

Rozróżnienie hitbox/hurtbox jako osobne `Area2D` (nie reużycie `CollisionShape2D` ciała) —
pozwala hitboxowi istnieć tylko przez czas trwania ataku (dodawany/`monitoring=true` na
klatki ataku z `AnimationPlayer`/`Timer`), bez ryzyka przypadkowej kolizji ciał.

### 3.2 Dane jako `Resource` — ten sam wzorzec co `ItemData`/`LevelObjectData`

    scripts/core/combat/StatsData.gd     # Resource: max_hp, attack, defense, move_speed,
                                          # attack_cooldown, i18n display_name
    scripts/core/combat/EnemyData.gd     # Resource: stats: StatsData, sprite_frames_path,
                                          # frame_size: Vector2i, detect_radius, attack_range
    data/enemies/demon_a.tres
    data/enemies/blood_monster_a.tres

`EnemyActor.gd` czyta `EnemyData` przez `@export`, identycznie jak `ItemPickup` czyta
`ItemData` dziś — zero nowego wzorca wstrzykiwania danych.

### 3.3 `HealthComponent` — komponent, nie pole na graczu/wrogu

    scripts/gameplay/combat/HealthComponent.gd   # Node, current_hp/max_hp,
                                                  # take_damage(amount) -> void,
                                                  # signal health_changed(current, max),
                                                  # signal died

Dziecko zarówno `Player.tscn`, jak i `EnemyActor.tscn` — ten sam komponent, dwa razy
użyty, bez dziedziczenia klas gracz/wróg po wspólnej bazie (zgodne z zasadą 2: kompozycja,
nie hierarchia). Analogicznie do `StatusEffectComponent.gd`, który już żyje jako dziecko
`Player.tscn`.

### 3.4 FSM — rozszerzenie istniejącego wzorca, nie nowy system

**Gracz**: `PlayerStateMachine` dostaje `PlayerAttackState`, `PlayerHurtState`,
`PlayerDeathState` obok istniejących Idle/Walk/Sprint/Hop — te same `PlayerState`
podstawy, ten sam `_states: Dictionary[StateName, PlayerState]`.

**Wróg**: nowy, analogiczny (nie ten sam) `EnemyState`/`EnemyStateMachine` —
Idle → Chase → Attack → Hurt → Death. Osobny od gracza, bo `EnemyActor` nie jest
`Player` — ale kopiuje *wzorzec*, nie kod 1:1 (zasada "zrozum odpowiedzialność, nie
tłumacz dosłownie" z `god/godot2.md`, egzekwowana już wcześniej przy Hopie).

### 3.5 `EventBus` — dopisanie sygnałów, nie nowa magistrala

`EventBus.gd` już istnieje i już dokumentuje *dlaczego* `player_damaged`/`level_completed`
nie zostały dodane w Części 9 ("nic jeszcze tego nie potrzebuje"). Ten pion jest właśnie
tym potrzebującym konsumentem:

    signal player_damaged(current_hp: int, max_hp: int)
    signal enemy_damaged(obj_id: String, current_hp: int, max_hp: int)
    signal enemy_died(obj_id: String)

HUD nasłuchuje `player_damaged` dla paska HP gracza; `LevelRuntime`/spawner nasłuchuje
`enemy_died` dla drop-loot/liczników. Zero `get_node()` z HUD-a do gracza.

### 3.6 Spawner dla pocisków/VFX trafień (zasada 7)

`VfxSpawner`/pула obiektów dla efektów trafień (`Super Pixel Effects` klatki) —
**nie** `queue_free()` per-efekt jak dzisiejszy ghost-trail sprintu (ROADMAP już flaguje
to jako anty-wzorzec do naprawienia, punkt 2/0.6 w `docs/ROADMAP.md`). Nowy kod combat
nie powtarza tego błędu od zera.

---

## 4. Plan wdrożenia — jeden podsystem na gałąź, GUT przed/po każdym

| # | Gałąź | Zakres | Kryterium wyjścia |
|---|---|---|---|
| 1 | `feature/rpg-stats` | `StatsData`, `HealthComponent`, warstwy kolizji 6-8 w `project.godot`, sygnały `EventBus` (bez emiterów jeszcze) | ✅ **ZROBIONE (2026-08-31)** — GUT: `HealthComponent.take_damage()` zmniejsza HP, emituje `health_changed`, `died` przy 0 (7/7 nowych testów, pełny pakiet 11/11 PASS). Boot bez błędów potwierdzony przez MCP na L1. |
| 2 | `feature/rpg-enemy` | `EnemyData`+`.tres` dla Demon_A/Blood Monster_A, import `Demon_A` jako `SpriteFrames` (slice 100×100 z realnych wymiarów plików, nie zgadywane), `EnemyActor.tscn`+`EnemyStateMachine` (Idle/Chase/Attack — bez Hurt/Death, bo `HealthComponent` z #1 jeszcze niepodłączony do reakcji) | ✅ **ZROBIONE (2026-08-31)** — GUT: 7/7 nowych testów (klasyfikacja Idle/Chase/Attack po dystansie, ruch w CHASE, bezruch w ATTACK). Pełny pakiet 18/18 PASS. Boot L1 bez błędów. **Wizualne "wróg chodzi/goni w edytorze" NIE potwierdzone ręcznie** — brak narzędzia symulacji inputu/zrzutu ekranu po stronie sesji AI (ta sama, udokumentowana wcześniej granica co przy Hop/Squash-Stretch w `plan31-08.md`); `EnemyActor` nie jest jeszcze umieszczony na żadnym poziomie (to celowo poza zakresem — patrz notatka niżej). |
| 3 | `feature/rpg-combat` | Hitbox/hurtbox (`Area2D` warstwy 7/8), `PlayerAttackState`, podłączenie `HealthComponent.take_damage()` po trafieniu, `EnemyHurtState`/`EnemyDeathState`, emisje `EventBus.player_damaged`/`enemy_damaged`/`enemy_died` | ✅ **ZROBIONE (2026-08-31)** — GUT: 5/5 nowych testów (atak gracza trafia/nie trafia poza zasięgiem, atak wroga trafia gracza, HURT na obrażenia, DEAD+auto-`queue_free` po śmierci). Pełny pakiet 24/24 PASS. Boot L1 czysty. Wizualne "gracz zabija wroga w edytorze" nieprzetestowane ręcznie — patrz notatka niżej. |
| 4 | `feature/rpg-hud` | `HealthBar`/`EnemyHealthBar` jako `TextureProgressBar`, nasłuch `EventBus.player_damaged`/`enemy_damaged` | ✅ **ZROBIONE (2026-08-31)** — GUT: 4/4 nowych testów. Pełny pakiet 28/28 PASS. Boot L1 (z paskiem HP w HUD) czysty. Wizualne potwierdzenie w edytorze wciąż nierobione ręcznie — patrz notatka niżej. |
| 5 | `feature/rpg-vfx` | `VfxSpawner` z pулą dla klatek trafień, podpięty pod trafienie | ✅ **ZROBIONE (2026-08-31)** — GUT: 3/3 nowych testów (pula nie rośnie po wielu trafieniach, sprite chowa się po animacji). Pełny pakiet **31/31 PASS**. Boot L1 czysty, zero warningów. |

Kolejność jest zależnościowa: #2 wymaga #1 (wróg potrzebuje `HealthComponent`), #3 wymaga
obu, #4-5 są kosmetyczne i mogą iść równolegle po #3.

---

## 5. Poza zakresem tej rundy (świadomie odłożone)

- Ekwipunek broni / paperdoll gracza (Mana Seed) — osobna, większa decyzja architektoniczna.
- Balans (liczby HP/obrażeń) — pierwsza iteracja idzie na wartościach roboczych,
  strojenie po pierwszym ręcznym playteście.
- Dźwięki combat — proceduralne SFX w `AudioService.gd`, dogrywane przy `feature/rpg-combat`,
  nie osobna faza.
- `godot/assets/assety/walk/` — patrz decyzja #4.
- Drugi i kolejni wrogowie poza Demon_A/Blood Monster_A (Skeleton, jednostki Tiny Swords) —
  ten sam pipeline z #2, ale nowa zawartość, nie w pierwszym cięciu.

---

## 5a. Punkt 1 — ZROBIONE (2026-08-31, branch `feature/rpg-stats`)

- **`scripts/core/combat/StatsData.gd`** (nowy, `Resource`) — `max_hp/attack/defense/
  move_speed/attack_cooldown`, generyczny (bez pól enemy-only/player-only), gotowy pod
  przyszłe `.tres` w `data/enemies/` (punkt 2) i ewentualny `PlayerStats.tres`.
- **`scripts/gameplay/combat/HealthComponent.gd`** (nowy, `Node`) — `current_hp/max_hp`,
  `take_damage(amount)`, sygnały `health_changed(current, max)`/`died`. Świadomie bez
  matematyki obrażenia-vs-pancerz — to zadanie wywołującego (`feature/rpg-combat`), bo tylko
  on zna `StatsData` obu stron starcia. Zero-guard: `take_damage(0)`/ujemne/po śmierci to
  no-op (przetestowane).
- **`project.godot`** `[layer_names]` — warstwy 6 `Enemies`, 7 `PlayerHitbox`,
  8 `EnemyHitbox` dopisane obok istniejących 1-5. `docs/migration/COLLISION_MATRIX.md`
  zaktualizowany o te trzy wiersze + notatkę, że są zarezerwowane przed swoim pierwszym
  konsumentem (inaczej niż `Danger`, które zostało nieużywane od migracji).
- **`scripts/infrastructure/EventBus.gd`** — dopisane `player_damaged(current_hp, max_hp)`,
  `enemy_damaged(obj_id, current_hp, max_hp)`, `enemy_died(obj_id)`, z `@warning_ignore
  ("unused_signal")` jak istniejące trzy sygnały (żaden emiter jeszcze nie istnieje —
  to zamierzone, `feature/rpg-combat` je podłączy).
- **`tests/combat/test_health_component.gd`** (nowy) — 7 testów: start na `max_hp`,
  redukcja HP + `health_changed`, clamp do 0 (nie ujemne), `died` dokładnie przy 0,
  brak `died` gdy HP > 0, no-op po śmierci, no-op dla obrażeń ≤ 0.
- **Gotcha napotkany (znany z `plan31-08.md`)**: nowy `class_name HealthComponent` nie był
  widoczny dla CLI GUT (`Parse Error: Could not find type "HealthComponent"`), dopóki
  edytor nie przeskanował projektu raz (`launch_editor` przez MCP, ~10s, potem
  `Stop-Process` i normalny CLI run) — `.godot/global_script_class_cache.cfg` aktualizuje
  się tylko przy skanie edytora, nie przy uruchomieniu z CLI.
- **Status walidacji**: `tests/combat` 7/7 PASS, cały pakiet `tests/` (`-ginclude_subdirs`,
  bo domyślny `-gdir` nie schodzi rekurencyjnie) 11/11 PASS (49 asercji), boot L1 bez
  błędów/warningów przez MCP. Brak jeszcze żadnego node'a w scenie korzystającego z
  `HealthComponent` (to `feature/rpg-enemy`/`feature/rpg-combat`) — punkt 1 to czysto
  fundament danych/komponentu/warstw, zgodnie z zakresem w tabeli wyżej.

## 5b. Punkt 2 — ZROBIONE (2026-08-31, branch `feature/rpg-enemy`)

- **`tools/build_enemy_sprite_frames.gd`** (nowy, headless tool jak `build_theme.gd`) —
  tnie `Demon_A`/`Blood Monster_A` (Tiny RPG pack, bez wariantu "with shadows") na
  `SpriteFrames` (`idle/walk/attack1/attack2/hurt/death`). Frame count liczony
  **dynamicznie** z `texture.get_width() / 100`, nie ze stałej tabeli — pierwsza wersja
  hardkodowała 8/7 klatek z jednego enemy'ego i wywaliła się na drugim (`Demon_A_Attack01.png`
  to faktycznie 700×100/7 klatek, nie 800×100/8 jak `Blood Monster_A`, mimo tej samej
  paczki). Output: `godot/assets/sprite_frames/{demon_a,blood_monster_a}.tres`.
- **Gotcha odkryty i naprawiony**: `DirAccess.make_dir_recursive_absolute()` na zupełnie
  nowym, nigdy nieprzeskanowanym przez edytor folderze pod `res://` **cicho zapisał**
  `ResourceSaver.save()`'y do niepowiązanego, istniejącego folderu (`assets/assety/`)
  zamiast do świeżo utworzonego `assets/sprite_frames/` — bez żadnego błędu z obu wywołań.
  Naprawa: założenie folderu prawdziwym `mkdir` z poziomu OS przed uruchomieniem toola.
  Udokumentowane w komentarzu w `build_enemy_sprite_frames.gd`, żeby nie powtórzyć.
- **`scripts/core/combat/EnemyData.gd`** (nowy, `Resource`) — `id/display_name/stats/
  sprite_frames/detect_radius/attack_range`. `data/enemies/demon_a.tres` (HP 12, atk 2,
  detect 160px, attack_range 28px) i `blood_monster_a.tres` (HP 16, atk 3, def 1) —
  wartości robocze do strojenia po pierwszym playteście (zgodnie z rozdziałem 5).
- **`scripts/gameplay/enemies/state_machine/`** — `EnemyState`(baza)/`EnemyIdleState`/
  `EnemyChaseState`/`EnemyAttackState`/`EnemyStateMachine`. Osobna hierarchia od
  `PlayerState` (nie wspólna baza gracz/wróg — zasada 2, "zrozum odpowiedzialność, nie
  dziedzicz na siłę"). Klasyfikacja czysto po dystansie do węzła w grupie `"player"`;
  `Chase` idzie po prostej (bez `NavigationAgent2D` — to `docs/ROADMAP.md` punkt 20, poza
  zakresem tej gałęzi). `Attack` **nie zadaje obrażeń** — czeka na hitboxy z
  `feature/rpg-combat`.
- **`scripts/gameplay/enemies/EnemyActor.gd`** + **`scenes/enemies/EnemyActor.tscn`** —
  `CharacterBody2D` w grupie `"enemy"`, `collision_layer=32` (warstwa 6 Enemies),
  `mask=1` (World). Dzieci: `Sprite2D` (`AnimatedSprite2D`), `HealthComponent`,
  `StateMachine`. `@export var enemy_data: EnemyData` — ten sam wzorzec wstrzykiwania co
  `ItemPickup`/`ItemData`.
- **`Player.tscn`** dostał `HealthComponent` (dziecko, `max_hp=20`, wartość robocza) —
  zgodnie z sekcją 3.3 planu ("komponent, dwa razy użyty"), zero konsumentów jeszcze
  (identyczna sytuacja jak `StatusEffectComponent` przy swoim wprowadzeniu).
- **`tests/enemies/test_enemy_state_machine.gd`** (nowy) — 7 testów: `_ready()` faktycznie
  wgrywa `sprite_frames`/`max_hp` z `EnemyData`, klasyfikacja IDLE (brak gracza / gracz
  daleko) / CHASE (w zasięgu `detect_radius`) / ATTACK (w `attack_range`), realny ruch w
  stronę gracza podczas CHASE, bezruch podczas ATTACK.
- **Status walidacji**: `tests/enemies` 7/7 PASS, pełny pakiet `tests/` 18/18 PASS
  (58 asercji), boot L1 bez błędów/warningów przez MCP. **Nieprzetestowane wizualnie**:
  `EnemyActor` nie został jeszcze umieszczony na żadnym poziomie ani ręcznie odpalony w
  edytorze z realnym graczem — GUT symuluje odległość programowo, nie zastępuje
  patrzenia, czy demon faktycznie wygląda i porusza się dobrze. Zgodnie z ustaloną w tym
  repo granicą (`plan31-08.md`), sesja AI nie ma narzędzia do zrzutu ekranu/symulacji
  wzrokowej — to wymaga Twojego ręcznego retestu, najlepiej razem z `feature/rpg-combat`
  (żeby test od razu obejmował realną walkę, nie samo chodzenie).

## 5c. Punkt 3 — ZROBIONE (2026-08-31, branch `feature/rpg-combat`)

- **Odkrycie na starcie**: `EdekSpriteFrames.tres` (kot) ma tylko `walk-{up,down,left,right}`
  — zero animacji ataku, zgodnie z decyzją #1 (kot zostaje graczem). Rozwiązanie: atak
  gracza nie zmienia animacji sprite'a, tylko odgrywa krótki squash-tween "pounce"
  (`PlayerVisuals.on_attack_started()`, ten sam mechanizm co Hop, mniejsza amplituda) —
  udokumentowane w `PlayerAttackState.gd`, nie ukryte jako przeoczenie.
- **`project.godot`** — nowa akcja `attack` (J + pad B/1).
- **`scripts/gameplay/player/PlayerAttack.gd`** (nowy, wzorzec `PlayerHop.gd`) —
  timing ataku (`DURATION=0.35`, `HIT_WINDOW_AT=0.15`, `COOLDOWN=0.25`), sygnały
  `attack_started`/`attack_hit_window_started`/`attack_ended`. Bez bufora/coyote —
  atak to prostszy input niż Hop, nie potrzebuje tego wybaczania.
- **`scripts/gameplay/player/PlayerHitbox.gd`** + **`scripts/gameplay/enemies/
  EnemyHitbox.gd`** — `Area2D` z `monitoring` **stale włączonym** (tanie: widzi tylko
  właściwą warstwę), obrażenia aplikowane jawnym wywołaniem `apply_hits()`/`apply_hit()`
  dokładnie w oknie trafienia, zamiast przełączać `monitoring` on/off (co ma edge case:
  ciało już nakładające się w momencie włączenia `monitoring` NIE odpala
  `body_entered`). Funkcjonalnie równoważne "aktywne tylko w oknie ataku" z planu 3.1,
  bez tego problemu.
- **`PlayerAttackState.gd`** (nowy stan FSM gracza) + `PlayerStateMachine` rozszerzony
  o `StateName.ATTACK` — ma priorytet nad HOP w klasyfikacji (świadoma decyzja,
  udokumentowana w kodzie: combat poprawność ważniejsza niż hop feel w rzadkim
  zbiegu obu inputów).
- **`EnemyAttackState.gd`** przepisany — cykl windup/cooldown wycięty z
  `data.stats.attack_cooldown` (40%/60%), powtarza swing w kółko, dopóki gracz zostaje
  w zasięgu (zamiast trafiać raz i zamierać).
- **`EnemyHurtState.gd`**/**`EnemyDeathState.gd`** (nowe) + `EnemyStateMachine` rozszerzony
  o `HURT`/`DEAD` jako **wymuszone** przejścia (`force_hurt()`/`force_death()`), nie przez
  normalny `_classify()` po dystansie — HP nie ma dystansu do zmierzenia.
  `EnemyDeathState` wyłącza kolizję/hitbox, odgrywa `death` raz, `queue_free()` po
  zakończeniu animacji.
- **`Player.tscn`**/**`EnemyActor.tscn`** — dodane węzły `Attack`/`Hitbox` (gracz) i
  `Hitbox` (wróg), warstwy 7/8 z `COLLISION_MATRIX.md` teraz mają realne noda, nie tylko
  rezerwację.
- **Bug znaleziony i naprawiony**: `HealthComponent._ready()` (dziecko) wykonuje się
  **przed** `EnemyActor._ready()` (rodzic) w Godocie — `EnemyActor.gd` ustawiał
  `_health.max_hp = enemy_data.stats.max_hp` PO tym, jak `HealthComponent._ready()`
  już ustawił `current_hp` z domyślnego (eksportowanego) `max_hp=10`. Efekt: wrogowie
  startowali z 10 HP zamiast właściwych 12/16, niezależnie od danych w `.tres` — złapane
  przez test asercji na `current_hp`, nie zgadnięte. Naprawa: nowa metoda
  `HealthComponent.configure(new_max_hp)`, która ustawia oba pola naraz; `EnemyActor.gd`
  używa jej zamiast bezpośredniego przypisania do `.max_hp`.
- **`tests/combat/test_combat.gd`** (nowy, integracyjny — prawdziwe `Player.tscn` +
  `EnemyActor.tscn`, `Input.parse_input_event()` jak `test_gameplay.gd`) — 5 testów:
  atak w zasięgu hitboxa trafia i emituje `EventBus.enemy_damaged`, atak poza zasięgiem
  nic nie robi, atak wroga w jego `attack_range` trafia gracza i emituje
  `EventBus.player_damaged`, obrażenia nieśmiertelne wchodzą w `HURT`, obrażenia
  śmiertelne wchodzą w `DEAD` i węzeł faktycznie się usuwa po animacji śmierci.
  `test_health_component.gd` dostał dodatkowy test na `configure()`.
- **Status walidacji**: `tests/combat` (9 testów łącznie z Punktu 1) + `tests/enemies`
  wszystkie PASS, pełny pakiet `tests/` **24/24 PASS** (68 asercji), boot L1 czysty przez
  MCP. **Nieprzetestowane wizualnie**: realna walka gracz-wróg w edytorze z ręcznym
  inputem — ta sama, powtarzana granica (brak narzędzia zrzutu ekranu/symulacji
  wzrokowej po stronie sesji AI). Szczególnie warte ręcznego sprawdzenia: czy squash-tween
  "pounce" faktycznie czytelnie sygnalizuje atak bez animacji, czy `EnemyAttackState`'s
  powtarzający się swing nie wygląda na zacinający się, i czy 40px promień
  `PlayerHitbox` (bez uwzględnienia kierunku, na sztywno wyśrodkowany na graczu) czuje
  się sensownie w praktyce.

## 5d. Pivot kierunku artystycznego (2026-08-31, po punkcie 3, na branchu `feature/rpg-combat`)

Użytkownik dograł nową falę assetów o wyraźnie **współczesnym/miejskim** charakterze
(LimeZu "Modern Interiors", Kenney City/Urban/Tiny Town) i **zmienił decyzję #1/#2 z
sekcji 1**: kierunek gry przechodzi z fantasy na współczesny (miasto, wnętrza,
współcześni NPC). Konsekwencje sprawdzone i wykonane:

- **Architektura combat (Punkty 1-3) zostaje bez zmian** — `EnemyData`/`HealthComponent`/
  FSM/hitboxy są danymi/komponentami, nie zakodowanym Demonem. Zero przepisywania.
- **Wróg zmieniony z `Demon_A` na `thug`** (dane: `data/enemies/thug.tres`), sprite:
  `Tiny Swords` Warrior (Red Units) zamiast Tiny RPG Demon_A — człowiek zamiast fantasy
  potwora, zgodnie z decyzją użytkownika "agresywni ludzie/NPC".
- **Luka w assecie znaleziona i udokumentowana, nie obejściowo zamaskowana**: żaden
  wariant kolorystyczny Tiny Swords Units (sprawdzone wszystkie 5: Black/Blue/Purple/
  Red/Yellow) nie ma animacji `Hurt`/`Death` — tylko `Idle/Run/Attack1/Attack2/Guard`.
  Rozwiązanie: `hurt` zmapowany z `Guard` (wiarygodna wizualnie reakcja obronna),
  `death` **świadomie pominięty** w danych — `EnemyDeathState.gd` sprawdza
  `sprite_frames.has_animation(&"death")` i dla enemy'ów bez tej animacji robi
  tween fade-out (`modulate:a` → 0, 0.4s) + `queue_free()` zamiast zmyślać klatki
  śmierci z klatek, które nigdy nie miały nią być.
- **`EnemyData.sprite_scale`** (nowe pole) — Demon_A ma natywne klatki 100px, Warrior
  192px; zamiast jednej sztywnej skali w `EnemyActor.tscn` (poprawnej tylko dla jednego
  archetypu), skala jest teraz danymi per-enemy, ustawianymi w `EnemyActor._ready()`.
- **`tools/build_thug_sprite_frames.gd`** (nowy, osobny plik od `build_enemy_sprite_frames.gd`
  — inny układ źródła, inny frame size, nie warto sklejać w jeden generyczny tool na
  tym etapie: dwa enemy "rodzinny" pipeline'y, nie jeden z rozgałęzieniami).
- **`demon_a.tres`/`blood_monster_a.tres` NIE usunięte** — zostają jako zweryfikowany,
  działający przykład wzorca (i materiał testowy), ale `EnemyActor.tscn`'s domyślny
  `enemy_data` wskazuje teraz na `thug.tres`.
- **Wartości `StatsData` dla `thug` są identyczne jak dla `demon_a`** (12 HP, atak 2,
  itd.) — celowo, żeby nie przepisywać testów przy samej podmianie tematycznej; to i tak
  były wartości robocze do strojenia (sekcja 5, "poza zakresem tej rundy").
- **Walidacja po podmianie**: pełny pakiet GUT nadal **24/24 PASS** bez modyfikacji
  ani jednego testu — potwierdza, że architektura faktycznie jest asset-agnostyczna.
  Boot L1 czysty przez MCP.

**ROZSTRZYGNIĘTE (użytkownik, 2026-08-31, na stałe)**: pytanie powyżej przestało być
otwarte. Współczesne miasto z chuliganami **jest teraz oficjalnym kierunkiem całej gry**,
nie tylko warstwy combat. Konsekwencje wiążące na przyszłość:
- `docs/ROADMAP.md` sekcja 7.1 ("ciepła ilustracja / książka obrazkowa", storybook-kot-w-
  -Szczecinie) jest **nieaktualna** w części dot. kierunku artystycznego UI/świata —
  wymaga aktualizacji przy najbliższej pracy nad Fazą 1/6 tamtego planu (nie zrobione w
  tej sesji, bo poza zakresem bieżącego pionu combat, ale zaznaczone, żeby nikt nie
  wznowił starego kierunku przez przeoczenie).
- Nowe poziomy/lokacje idą na assetach miejskich (LimeZu Modern Interiors, Kenney City/
  Urban/Tiny Town) — L1-L7 (kot w realnych miejscach Szczecina) **zostają nietknięte**
  zgodnie z zasadą "nie przebudowujemy przetestowanej zawartości" (ta sama zasada co
  `src/game/phaser/` i decyzja hybrydowa z `docs/ROADMAP.md` sekcji 9), ale są teraz
  traktowane jako zamknięty, historyczny rozdział, nie wzorzec dla nowej zawartości.
- **Dokumentacja zsynchronizowana (2026-08-31)**: `docs/ROADMAP.md` sekcja 7.1 dostała
  notatkę o nieaktualności starego kierunku dla nowej pracy (L1-L7 zostają w starym
  stylu, reszta dokumentu — nietknięta). `.claude/agents/godotagent.md` (profil
  "kot3_godot") miał wpisany na sztywno kierunek "premium cozy hand-painted autumn" —
  zaktualizowany na "contemporary urban" (paleta, dzień/noc przez `TimeManager`/
  `DayNightOverlay`, cząsteczki miejskie zamiast liści jesiennych), z jawną notatką o
  dacie i powodzie zmiany, żeby przyszłe odpalenie tego agenta nie dostało sprzecznych
  instrukcji.
- `thug` (Tiny Swords Warrior) jako wróg #1 nie jest już tymczasowym kompromisem
  stylistycznym — jest docelowym kierunkiem.

## 5e. Punkt 4 — ZROBIONE (2026-08-31, branch `feature/rpg-combat`)

- **Refaktor emisji `EventBus` (warunek wstępny)**: `PlayerHitbox`/`EnemyHitbox` przestały
  same wołać `EventBus.player_damaged`/`enemy_damaged`/`enemy_died` po `take_damage()`.
  Zamiast tego jedno źródło prawdy per encja: `PlayerMovement.gd`/`EnemyActor.gd` łączą
  się z **własnym** `HealthComponent.health_changed`/`died` i relayują do `EventBus`.
  Korzyść: pasek HP dostaje realną wartość **od razu przy spawnie** (pełne HP), nie
  dopiero po pierwszym trafieniu — `HealthComponent.configure()` teraz też emituje
  `health_changed`, tak jak `take_damage()`.
- **Drugi raz ten sam gotcha z kolejnością `_ready()`**: `EnemyHealthBar` (dziecko
  `EnemyActor.tscn`) odpala swój `_ready()` **przed** `EnemyActor._ready()`, więc
  `enemy_id` nie był jeszcze ustawiony, gdy `HealthBar` decydowałby, do którego sygnału
  się podłączyć. Naprawa: `HealthBar` łączy się z **wszystkimi trzema** sygnałami
  bezwarunkowo w `_ready()`, filtrowanie po `enemy_id` przeniesione do handlerów
  (wywoływanych później, gdy `enemy_id` jest już poprawny) — udokumentowane wprost w
  kodzie jako druga instancja tego samego wzorca błędu co w Punkcie 3.
- **`scripts/gameplay/ui/HealthBar.gd`** (nowy, `TextureProgressBar`) — jedna klasa, dwie
  role przez `enemy_id` (pusty = gracz via `player_damaged`, niepusty = konkretny wróg
  via `enemy_damaged`/`enemy_died`). Zero `get_node()` w gameplay — czysto `EventBus`,
  zgodnie z zasadą 6.
- **`scenes/ui/HealthBar.tscn`** (gracz, zielony pasek) + **`EnemyHealthBar.tscn`** (wróg,
  czerwony, mniejszy, pływający nad głową) — obie z `kenney_ui-pack-rpg-expansion`
  (`barBack_horizontalMid`/`barGreen_horizontalMid`/`barRed_horizontalMid`). **Świadome
  uproszczenie**: użyty tylko środkowy kafelek (Mid), bez zaokrąglonych końcówek
  (Left/Right) — złożenie 3-częściowego paska w jedną teksturę wymagałoby dodatkowego
  toola do wypalania obrazu + kolejnej rundy importu; prostokątny pasek czyta się
  poprawnie na start, zaokrąglenie to polish, nie funkcja.
- **`EnemyActor.tscn`** dostał dziecko `EnemyHealthBar` (pozycja nad sprite'em);
  `EnemyActor.gd` ustawia `enemy_id = name` w `_ready()`. **`HUD.tscn`** dostał
  `PlayerHealthBar` (róg, pod `EnergyPanel`).
- **`tests/ui/test_health_bar.gd`** (nowy) — 4 testy: pasek gracza reaguje na
  `player_damaged`, pasek wroga filtruje po `enemy_id` (ignoruje inne id), chowa się na
  `enemy_died` dla właściwego id, i **test integracyjny na prawdziwym `EnemyActor.tscn`**
  potwierdzający, że dziecko dostaje poprawny `enemy_id` i pełne HP od razu przy spawnie
  (bezpośrednia weryfikacja, że naprawa kolejności `_ready()` faktycznie działa, nie tylko
  w teorii).
- **Status walidacji**: `tests/ui` 4/4 PASS, pełny pakiet **28/28 PASS** (79 asercji),
  boot L1 (z paskiem HP w HUD) czysty przez MCP. Edytor Godota zostawiony uruchomiony w
  tle (na życzenie użytkownika) pod dalsze testy przez MCP. **Nieprzetestowane
  wizualnie**: czy pasek faktycznie wygląda dobrze na ekranie, czy pozycja paska wroga
  nad głową nie koliduje z niczym innym w HUD-zie na realnym poziomie z walką — wymaga
  Twojego ręcznego potwierdzenia.

## 5f. Punkt 5 — ZROBIONE (2026-08-31, branch `feature/rpg-combat`)

- **`EventBus.hit_landed(position: Vector2)`** (nowy sygnał) — świadomie **osobny** od
  `enemy_damaged`/`player_damaged`, nie rozszerzenie ich sygnatury: te dwa już mają
  ustalone parametry, na których opierają się asercje w `test_health_bar.gd`/
  `test_combat.gd` i nasłuch `HealthBar.gd` — dopisanie `position` byłoby zmianą łamiącą
  dla jednego nowego konsumenta. `PlayerHitbox.gd`/`EnemyHitbox.gd` emitują go dokładnie
  tam, gdzie już wywołują `take_damage()` (mają `body.global_position` pod ręką).
- **`scripts/infrastructure/VfxSpawner.gd`** (nowy, **siódmy autoload**, obok
  `ProgressStore`/`AudioService`/`SettingsStore`/`EventBus`/`DebugConsole`/`SceneRouter`)
  — pula 8 `AnimatedSprite2D` tworzona raz w `_ready()`, cyklowana round-robin (nie
  "znajdź wolny slot" — przy realnym tempie walki w tej grze kolizja terminów jest
  praktycznie niemożliwa, udokumentowane wyliczeniem w kodzie). To jest **realna
  naprawa** anty-wzorca, który `docs/ROADMAP.md`'s audyt zasady 7 opisał dla
  `PlayerVisuals._spawn_ghost()` (~22 alokacje/s) — tamten kod zostaje nietknięty (poza
  zakresem tej gałęzi), ale nowy kod combat **nie powtarza** tego błędu od zera.
- **Efekt**: `Tiny Swords/Particle FX/Explosion_01.png` (8 klatek, 192×192/klatkę,
  policzone z `texture.get_width()/192`, nie zgadywane) — uniwersalny "poof" trafienia,
  używany zarówno dla ciosów gracza jak i wroga (jeden generyczny efekt na start, nie
  osobne dla każdej strony).
- **`tests/vfx/test_vfx_spawner.gd`** (nowy, testuje prawdziwy autoload singleton, nie
  świeżą instancję — autoloadów nie da się instancjonować osobno) — 3 testy: trafienie
  aktywuje pulowany sprite we właściwej pozycji, **pula nie rośnie nawet po 20 trafieniach
  pod rząd** (główna teza tego punktu — bezpośrednio testuje brak alokacji per-hit),
  sprite chowa się sam po zakończeniu animacji (nie zamraża się na ostatniej klatce).
- **Dwa warningi znalezione i wyczyszczone przy boot-checku** (nie zignorowane): integer
  division przy liczeniu `frame_count` (celowe, uciszone `@warning_ignore
  ("integer_division")` z komentarzem *dlaczego* jest bezpieczne) i shadowing parametru
  `position` z wbudowaną właściwością `Node2D.position` (zmienione na `hit_position`).
- **Status walidacji**: `tests/vfx` 3/3 PASS, pełny pakiet **31/31 PASS** (82 asercje),
  boot L1 czysty **bez żadnych warningów** przez MCP (zgodnie z `CLAUDE.md`'s "clean up
  diagnostics" — nie zostawione na później). **Nieprzetestowane wizualnie**: czy efekt
  faktycznie wygląda dobrze w skali `DISPLAY_SCALE=0.35` i czy 24fps/8 klatek czyta się
  jako satysfakcjonujący "impact", nie migotanie — wymaga Twojego ręcznego potwierdzenia.

**Cała tabela z sekcji 4 (Punkty 1-5) zamknięta.** Pełny pion combat: `StatsData`/
`HealthComponent` → `EnemyData`/`EnemyActor`/FSM → hitboxy/HURT/DEAD → paski HP → VFX
trafień, wszystko na jednej gałęzi historii commitów od `feature/rpg-stats` przez kolejne
branch-checkouty do `feature/rpg-combat`, 31/31 GUT PASS na każdym kroku pośrednim.

## 5g. Sekcja 6 pkt 2-3 — ZROBIONE (2026-08-31): drugi wróg + osadzenie na poziomie

- **Drugi wróg: `bandit`** (`data/enemies/bandit.tres`) — Tiny Swords Purple Units Warrior,
  ten sam pipeline co `thug` (`build_thug_sprite_frames.gd` rozszerzony o `VARIANTS`
  dict zamiast pojedynczej ścieżki, żeby nie duplikować pliku dla samej zmiany koloru).
  Mocniejszy od `thug`: 18 HP, atak 3, `move_speed` 65, `attack_cooldown` 0.9 — czytelna
  progresja trudności, nie kolejny identyczny przeciwnik.
- **`LevelObjectData.enemy_id`** (nowe pole) + **`kind == "enemy"`** w `LevelBuilder.build()`
  — dokładnie ten sam wzorzec co `item_id`/`ItemRegistry`. **`EnemyRegistry.gd`** (nowy,
  wzorzec `ItemRegistry.gd`) rozwiązuje `enemy_id` → `EnemyData`.
- **`LevelRuntime.gd`** ładuje `EnemyRegistry.load_all()` i przekazuje do
  `LevelBuilder.build()` (nowy, opcjonalny parametr `enemies: Dictionary = {}` —
  wstecznie kompatybilne, każde wcześniejsze wywołanie z mniejszą liczbą argumentów
  nadal działa).
- **Realne osadzenie**: `data/levels/level_2.tres` (Park Kasprowicza) dostał obiekt
  `thug1` (`kind="enemy"`, `enemy_id=&"thug"`) — **Level 2 wybrany, nie Level 1**,
  zgodnie z zasadą hybrydową z `docs/ROADMAP.md` (nie przebudowujemy najbardziej
  przetestowanego poziomu; L2 to dodanie treści na istniejących danych, nie przebudowa
  tła/tilesetu).
- **`tests/enemies/test_level_builder_enemy.gd`** (nowy) — 3 testy: `LevelBuilder`
  buduje `EnemyActor` z poprawnym `enemy_data` dla `kind="enemy"`, nieznany `enemy_id`
  nie tworzy zepsutego węzła (tylko warning), i **Level2 rzeczywiście spawnuje**
  `Enemy_thug1` po uruchomieniu prawdziwej sceny (nie tylko dane, realny efekt).
- **Status walidacji**: pełny pakiet **34/34 PASS** (89 asercji), boot L1 i sceny
  testowej (`scenes/dev/TestCombat.tscn`, patrz niżej) czysty przez MCP.

## 5h. Scena testowa + poprawki po pierwszym ręcznym playteście (2026-08-31)

Użytkownik potwierdził: **combat działa**. Zgłoszone i naprawione od razu dwa problemy
wizualne z ręcznego testu:

- **`scenes/dev/TestCombat.tscn`** (nowa) — gotowa scena do ręcznego testowania: kot +
  2× `EnemyActor` (`thug`) + `HUD` na jednym ekranie, bez potrzeby budowania całego
  poziomu. Uruchamiana przez F6 w edytorze (Run Current Scene), nie F5 (main scene).
- **Bug: pasek HP "widać tylko puste obramowanie"** — `TextureProgressBar` bez
  `nine_patch_stretch=true` renderuje `texture_under`/`texture_progress` w ich
  **natywnym rozmiarze** (18×18px z Kenneya), nie rozciąga do rozmiaru kontrolki
  (120×20 / 40×6px) — widoczny efekt to malutki fragment tekstury w rogu, czytany jako
  "puste". Naprawa: `nine_patch_stretch = true` + małe `stretch_margin_*` (4px gracz,
  2px wróg — obie tekstury to płaskie kolory, nie potrzebują dużych marginesów na
  detal) w obu `HealthBar.tscn`/`EnemyHealthBar.tscn`.
- **Bug/feedback: "animacja ataku jest straszna"** — sam squash-tween bez niczego
  towarzyszącego czytał się jako statyczne "drgnięcie", nie atak. Rozbudowane w
  `PlayerVisuals.on_attack_started()` o dwa dodatkowe elementy:
  1. **Lunge** — sprite (nie `CharacterBody2D`, kolizja się nie rusza) wysuwa się
     14px w kierunku patrzenia i wraca, tylko na osi X. **Świadomie tylko X**: linia
     `_sprite.position.y = -_hop.arc_progress() * ARC_HEIGHT` w `PlayerMovement.gd`
     nadpisuje Y **co klatkę fizyki bezwarunkowo** (offset łuku hopa) — tween na pełnym
     `Vector2` zostałby przez to skasowany w jednej klatce. Znalezione przez
     prześledzenie kodu, nie przez zaobserwowanie błędu na oko.
  2. **Prawdziwy VFX cięcia** — `brackeys_vfx_bundle/particles/alpha/slash_01_a.png`
     (sierp/półksiężyc, kanał alfa, 512×512), obrócony pod kierunek ataku, z fade+scale
     tweenem, `queue_free()` po zakończeniu. **Nie pулowany przez `VfxSpawner`** —
     świadomie: atak ma cooldown 0.25s (rząd wielkości rzadszy niż ghost-trail sprintu
     45ms, który `docs/ROADMAP.md` faktycznie flaguje jako problem) — to jest ten sam,
     już zaakceptowany w projekcie poziom tolerancji co `_spawn_ghost()`, nie nowy
     anty-wzorzec.
- **Status walidacji**: pełny pakiet **34/34 PASS** (bez zmian w liczbie testów — to
  poprawki wizualne, nie nowa logika do testowania), boot `TestCombat.tscn` czysty przez
  MCP. **Wymaga ponownego ręcznego potwierdzenia** przez użytkownika, że teraz wygląda
  dobrze — to konkretnie ta rzecza, której nie można ocenić samą asercją.

## 6. Backlog — mechaniki "współczesne miasto"

Użytkownik przekazał dwie duże listy pomysłów (2026-08-31). **Aktualizacja**: pierwsza
runda zrobiona bez telefonu (sekcja 10a) — status per punkt poniżej.

### System smartfona — CAŁY PION **WYŁĄCZONY** z zakresu (decyzja użytkownika: "ale bez systemu smartfona")
- ~~Telefon zamiast menu pauzy~~, ~~aplikacja Kontakty/SMS jako Quest Log~~, ~~aplikacja
  Bank~~, ~~komputery/hakowanie~~ — nie robimy, dopóki użytkownik nie zmieni zdania.
- **Automaty/sklepy** — ✅ **ZROBIONE** jako `VendingMachine.gd` (sekcja 10a), bez
  otoczki telefonu — zwykły interaktywny obiekt w świecie, dokładnie jak zaproponowano
  w prompt-cie, tylko bez warstwy UI telefonu.
- **System śledztwa/notatnika** (`ClueResource.gd`) — **nie zrobione**, poza zakresem tej
  rundy (patrz sekcja 10, uzasadnienie: brak realnych śledztw/zagadek w grze do
  podpięcia pod dowody — budowa tego teraz byłaby infrastrukturą bez konsumenta).
- **Ruch uliczny / ambient AI** (samochody na `Path2D`, przechodnie FSM) — **nie
  zrobione**, treść-ciężka robota (wymaga faktycznych ścieżek na poziomie), zostaje
  w backlogu.

### Cykl dobowy, ekonomia miasta, reputacja
- **`TimeManager.gd`** — ✅ **ZROBIONE** (sekcja 10a), z `DayNightOverlay` zamiast
  `CanvasModulate` (świadoma zmiana z uzasadnieniem w kodzie).
- **Ekonomia (automat + portfel)** — ✅ **ZROBIONE** (sekcja 10a).
- **Metro/szybka podróż** — ✅ **ZROBIONE (2026-08-31)**. `TransitDestination.gd`
  (`Resource`, ten sam wzorzec co `ItemData`/`EnemyData`) + `TransitStation.gd`/`.tscn`
  (`interact()`-kompatybilny, jak `VendingMachine`) + `TransitMenu.gd`/`.tscn` — zwykły
  animowany panel (pop-in/out jak `ToastManager`), **bez telefonu**. Wybór celu:
  `ProgressStore.spend_money()` + `TimeManager.advance_minutes()` +
  `SceneRouter.change_scene_to_file()`. **Pierwsze pauzowanie `SceneTree` w projekcie**
  (`get_tree().paused = true` na czas otwartego menu, `process_mode = PROCESS_MODE_ALWAYS`
  na samym menu) — `PauseMenu` z audytu `docs/ROADMAP.md` wciąż nie istnieje, to jest
  pierwszy konsument tego mechanizmu w kodzie.
  **Refaktor pod testowalność**: `_on_destination_selected()` rozbite na
  `_try_purchase()` (czysta logika pieniądze+zegar, zero `get_tree()`) i
  nawigację — bo wywołanie pełnej ścieżki przez `SceneRouter.change_scene_to_file()`
  w headless GUT zostawiało osierocone węzły i błędy silnika (`current_scene` nie
  istnieje tak samo jak w prawdziwej grze) — **artefakt środowiska testowego, nie bug
  produkcyjny**, ale wystarczający powód, żeby rozdzielić te dwie odpowiedzialności.
  `tests/economy/test_transit_station.gd` (3 testy) testuje `_try_purchase()`
  bezpośrednio, nie pełny łańcuch z nawigacją.
  Umieszczony w `TestCombat.tscn` (przystanek → `Level2.tscn`, koszt 4 zł, 30 min).
  Status: pełny pakiet **70/70 PASS** (154 asercje), boot `TestCombat.tscn` czysty.
- **Stamina/zmęczenie + Social Links** — **świadomie NIE zrobione**, patrz sekcja 10:
  brak realnych aktywności (praca/śledztwo/nauka) do podpięcia, i już istnieje osobny
  system "Energy" (sprint) w `LevelRuntime`/`Difficulty.gd` — dodanie drugiego,
  prawie identycznego licznika bez realnego konsumenta byłoby duplikacją, nie funkcją.
- **Reputacja w dzielnicach** — ✅ **ZROBIONE (2026-08-31)**, patrz sekcja 10b. Zamiast
  geograficznych granic dzielnic (za mało zdefiniowane, żeby zgadywać kształt mapy):
  `zone_id` to dowolny string (poziom, nazwana dzielnica) — warstwa danych jest gotowa
  i realna, granice geograficzne to osobna, późniejsza decyzja projektowa.
- **Ruch uliczny / ambient AI** — ✅ **ZROBIONE (2026-08-31)**, patrz sekcja 10b.

**Uwaga architektoniczna** (zaktualizowana): `TimeManager`/`VfxSpawner` to autoloady
8 i 7 — projekt ma ich teraz **osiem** (`ProgressStore`/`AudioService`/`SettingsStore`/
`EventBus`/`DebugConsole`/`SceneRouter`/`VfxSpawner`/`TimeManager`). Zasada "autoloady
oszczędnie" z `god/godot2.md` coraz bardziej warta pilnowania — Metro/Reputacja, jeśli
wrócą, **nie powinny** automatycznie dostawać własnych autoloadów bez realnej potrzeby
globalnego stanu (Reputacja mogłaby np. żyć w `ProgressStore` zamiast być dziewiątym
singletonem).

## 10b. Reputacja + Ambient AI — ZROBIONE (2026-08-31)

- **Reputacja** — `ProgressStore.reputation: Dictionary` (`zone_id: String -> int`),
  `get_reputation()`/`add_reputation()` (bez podłogi/sufitu — strefa może zejść poniżej
  0), `EventBus.reputation_changed` (bez konsumenta jeszcze, jak `player_damaged` przy
  swoim wprowadzeniu). **Świadomie w `ProgressStore`, nie jako dziewiąty autoload** —
  zgodnie z własną notatką architektoniczną z sekcji 6 ("Reputacja mogłaby żyć w
  ProgressStore"). `zone_id` to dowolny string, nie geograficzna granica — odkłada
  decyzję o faktycznych granicach dzielnic na później, bez blokowania warstwy danych.
- **Ambient AI** — `AmbientPedestrian.gd` (`CharacterBody2D`, FSM Idle↔Walk, losowy
  punkt w promieniu, **rozkład jednolity w kole** — pierwsza wersja losowała punkt w
  kwadracie, złapane przez test asercji `distance <= wander_radius` failujący na
  ~104 vs 100, naprawione przez `sqrt(randf())` zamiast liniowego `randf_range` na
  promieniu, nie przez rozluźnienie testu) i `AmbientVehicle.gd` (`PathFollow2D`,
  `progress` zawijany przez `fmod` względem długości krzywej, nie `Curve2D.closed`
  samo w sobie — działa nawet na otwartej krzywej). Osobna klasa od `NpcActor.gd`
  (patrol liniowy, questowo istotny) — to jest bezcelowe błądzenie w tle, zero
  `interact()`.
- **`tests/economy/test_progress_store_reputation.gd`** (7 testów) +
  **`tests/unit/test_ambient_pedestrian.gd`** (5) + **`test_ambient_vehicle.gd`** (3).
- Umieszczone w `TestCombat.tscn` (2 przechodnie + 1 pętla z autem).
- **Status walidacji**: pełny pakiet **85/85 PASS** (173 asercje), boot `TestCombat.tscn`
  czysty przez MCP.

**Sekcja 6 zamknięta w całości** — wszystkie pozycje z obu list backlogu "współczesne
miasto" (poza wyłączonym na żądanie użytkownika systemem smartfona) są teraz zrobione:
`TimeManager`, ekonomia+`VendingMachine`, `Toast`, Metro, Reputacja, Ambient AI.

## 11. Backlog — druga fala pomysłów (2026-08-31, NIE zaimplementowane)

Użytkownik przekazał kolejną, dużą listę pomysłów rozbudowy po zamknięciu sekcji 6.
Zapisane tu jako plan na przyszłość — **nic z poniższego nie jest zrobione w tej
sesji**. Grupowanie zachowane z oryginalnej wiadomości.

### Nowe tryby gry
- **Tryb nocny/patrol** — cel: przetrwać/dotrzeć gdzieś tylko nocą (niebezpieczniej).
  Fundament już istnieje: `TimeManager.is_night()`, wrogowie już zróżnicowani
  (`thug`/`bandit`).
- **Tryb "dostawa"** — proste zadania kurierskie między punktami miasta. Pasuje pod
  istniejący system questów (`QuestStepData`) + ekonomię (`ProgressStore.money`).

### QoL (priorytet — typowe braki bolące gracza najszybciej)
- Mapa/wskaźnik celu questa (strzałka/kompas) — `GoalProximity.gd` już liczy
  dystans/kierunek, dziś tylko tekst w HUD (patrz też `docs/ROADMAP.md` Faza 5).
- Szybki zapis/wczytaj (`SaveSlot`, mid-level resume) — `docs/ROADMAP.md` już to
  odnotowuje jako brakujące.
- Log/dziennik questów (aktywne + historia ukończonych).
- Panel trudności jako osobne ustawienie (obrażenia/ceny/agresywność wrogów), nie na
  sztywno w `StatsData`/`Difficulty.gd`.
- Toast przy niskiej energii/pieniądzach — `ToastManager`/`EventBus.toast_requested`
  już istnieją, to tylko nowy emiter.
- Rebindowanie klawiszy + skalowalny interfejs (dostępność).
- Podsumowanie dnia (zarobek/wydatki/starcia) — tanie, `ProgressStore`+`TimeManager`
  już śledzą surowe dane.

### Drobne "życie miasta"
- Losowe wydarzenia uliczne (drobne zadania poboczne bez pełnego systemu questów).
- Sklepy z rotującym asortymentem dziennym (`TimeManager.current_day` już istnieje).
- "Ulubione miejsca" gracza — szybki powrót do zapamiętanego automatu/NPC.

### Systemy społeczne/miejskie
- Policja/reakcja na agresję wobec NPC — naturalne rozwinięcie `ProgressStore.reputation`,
  bez potrzeby granic dzielnic.
- Gazeta/plotki miejskie reagujące na czyny gracza — wykorzystuje istniejący
  `ToastManager`/UI.
- Sąsiedzi/stali bywalcy przy konkretnych automatach/miejscach — prostszy substytut
  "social links" bez pełnego systemu (ten pełny został świadomie odrzucony, sekcja 10a).

### Rozbudowa combat/eksploracji
- Losowe potyczki uliczne (zależne od pory dnia/reputacji), nie tylko zaplanowane na
  poziomie.
- Bronie/przedmioty jednorazowe ze świata (tymczasowy bonus do ataku) — lekki system
  bez pełnego ekwipunku (pełny ekwipunek/paperdoll wciąż odłożony, sekcja 10).
- Kryjówki/skróty odblokowywane po pokonaniu wroga lub zapłacie.

### Progresja gracza bez pełnego RPG-levelowania
- Osiągnięcia/statystyki życiowe (wrogowie pokonani, zarobek, dni przeżyte) — tanie na
  danych już zbieranych w `ProgressStore`.
- "Umiejętności" jako pasywne bonusy za pieniądze/reputację (tańsze zakupy, szybsza
  regeneracja energii) zamiast pełnego drzewka.

### QoL specyficzne dla tej gry
- Historia transakcji (co/kiedy/za ile) — ekonomia i czas już śledzone.
- Tryb "szybkiego dnia" — przyspieszenie czasu w bezpiecznym miejscu zamiast biernego
  czekania.

**Uwaga**: żadna z tych pozycji nie ma jeszcze przypisanego priorytetu ani gałęzi —
do ustalenia z użytkownikiem przy starcie każdej, tą samą metodą co sekcja 6
(jedna rzecz na raz, GUT przed/po, boot-check).

## 10c. Pierwsza REALNA wizualna weryfikacja (2026-08-31) — znaleziony i naprawiony rendering bug

**Przełom metodologiczny**: sesja AI zdobyła zdolność robienia zrzutów ekranu prawdziwego
okna gry — `mcp__godot__run_project` otwiera realne okno na ekranie użytkownika,
PowerShell (`GetWindowRect`/`SetForegroundWindow`/`Graphics.CopyFromScreen`) łapie jego
zawartość do PNG, `Read` odczytuje obraz. To **nie jest** oficjalne narzędzie MCP — obejście
na poziomie systemu — ale działa i pozwala pierwszy raz w tej sesji faktycznie **zobaczyć**
efekt pracy zamiast polegać wyłącznie na asercjach. Udokumentowane tu, żeby przyszła sesja
wiedziała, że ta metoda istnieje i działa.

Zrzuty ekranu `TestCombat.tscn` ujawniły **realny bug renderowania**, niewidoczny w żadnym
teście: **`TextureProgressBar` + `nine_patch_stretch=true` renderował się źle** — tło
(`texture_under`) praktycznie niewidoczne, wypełnienie (`texture_progress`) w złej
proporcji względem realnej wartości HP. To nie był kosmetyczny drobiazg — pasek HP był
faktycznie nieczytelny.

**Naprawa**: `HealthBar.gd` przepisany z `TextureProgressBar` na zwykły `Control` z dwoma
`ColorRect`-ami (`Background` + `Fill`, `Fill.anchor_right` ustawiane na `value/max_value`)
— klasyczna, tekstura-niezależna technika paska postępu, odporna na cokolwiek psuło
nine-patch. `value`/`max_value` zachowane jako właściwości (nie `Range`-owe wbudowane, bo
`Control` ich nie ma) — testy z sekcji 5e działają bez zmian poza jednym literałem
(patrz niżej).

**Dwa dodatkowe bugi znalezione tym samym zrzutem, oba naprawione**:
1. **Wróg za mały względem kota** — `sprite_scale` dla `thug`/`bandit` (0.17) dawał
   sylwetkę ~4x mniejszą od kota, wizualnie odwrotną proporcję niż realistyczna
   (człowiek < kot). Podniesione do 0.5.
2. **`PlayerHealthBar` całkowicie zasłonięty przez `EnergyPanel`** — `EnergyPanel` w
   `HUD.tscn` jest wyższy niż zakładałem (auto-rozmiar `PanelContainer` z marginesami
   Theme), a rysowany PÓŹNIEJ w drzewie (czyli NA WIERZCHU) — `PlayerHealthBar` był
   fizycznie pod spodem, niewidoczny mimo poprawnej logiki. Przesunięty niżej
   (`offset_top` 56→110).
3. **Fałszywy "flash obrażeń" przy starcie** — domyślne `value=100.0` w `.tscn` (zapisane
   przy naprawie Punktu 4) nie pasowało do realnego `max_hp` (20/12/18), więc pierwszy
   prawdziwy sygnał `health_changed` wyglądał jak spadek HP i odpalał flash bez żadnego
   trafienia. Zmienione na `value=1.0` (spójne z domyślnym `max_value=1.0`) —
   `ratio=1.0` od razu, zero fałszywego alarmu.

**Ważna lekcja metodologiczna**: pierwszy odczyt zrzutu (brak wroga, brak paska HP)
wyglądał jak katastrofa — ale debug print w `EnemyActor._ready()` pokazał, że dane
(pozycja/widoczność/skala) były w 100% poprawne, więc "zniknięcie" wroga było artefaktem
złego momentu zrzutu (scena jeszcze się ładowała), nie prawdziwym bugiem. Podobnie "brak
zielonego wypełnienia" na pasku gracza okazał się realnym, ale OCZEKIWANYM stanem — wróg
faktycznie atakował gracza przez kilka sekund przed zrzutem, HP spadło do wąskiego
zielonego paska na ciemnym tle, łatwego do przeoczenia przy pobieżnym spojrzeniu.
**Wniosek: debug print + druga, kontrolna próba przed uznaniem czegoś za bug** — dokładnie
ta sama dyscyplina co reszta sesji ("błędy naprawiamy przez narzędzia, nie zgadywanie").

**Status walidacji**: pełny pakiet **85/85 PASS** (173 asercje, 1 literał testowy
zaktualizowany pod nowy domyślny `value`), boot L1 i `TestCombat.tscn` czyste, **wizualnie
potwierdzone zrzutem ekranu** (pierwszy raz w tej sesji) — pasek HP wroga pełny czerwony
prostokąt, wróg poprawnej wielkości, pasek gracza widoczny i oddzielony od `EnergyPanel`.

## 11a. Backlog — redesign menu głównego (2026-08-31, priorytet: WYŻEJ niż reszta sekcji 11)

Użytkownik poprosił o dodanie z priorytetem wyższym niż ogólny backlog sekcji 11.
**Nie zaimplementowane w tej sesji** — plan na następną turę.

### Layout (spójny z tym, co już zbudowane)
- Tło: pełnoekranowa scena z zasobów miejskich (LimeZu Modern Interiors / Kenney
  City-Urban/Tiny Town) zamiast jednolitego koloru.
- **Ożywienie tła reużywa `AmbientPedestrian.gd`/`AmbientVehicle.gd`** (sekcja 10b) —
  te same skrypty co w grze, tylko instancje w scenie menu.
- `DayNightOverlay` (sekcja 10a) zsynchronizowany z realną porą dnia z `TimeManager` —
  menu inaczej wygląda rano niż wieczorem, tanio (już zbudowany mechanizm).

### UI — reużyć to, co zweryfikowane wizualnie (sekcja 10c)
- Przyciski: `kenney_ui-pack` (`button_round_gloss`/`button_round_depth_gloss` — te same,
  które już są w `MobileControls`/`TouchButton.gd`).
- Panel: ten sam wzorzec `PanelContainer`+Theme+pop-in (`TRANS_BACK`) co
  `ToastManager`/`TransitMenu` — spójny język wizualny.
- **Nowy wariant kolorystyczny motywu** — `edek_theme.tres` (Baloo2/Nunito) to wciąż
  kierunek "storybook", uznany za nieaktualny przy pivocie (sekcja 5d/`ROADMAP.md` 7.1).
  Użytkownik chce **chłodniejszą paletę, motyw cyberpunkowy** dla ekranu startowego —
  osobny wariant/drugi Theme, nie podmiana istniejącego `edek_theme.tres` używanego
  gdzie indziej.

### Funkcjonalność
- Przycisk "Kontynuuj" widoczny warunkowo, jeśli `ProgressStore` ma zapisany stan —
  pierwszy realny konsument danych zapisu na starcie gry.
- Podsumowanie ostatniej sesji na przycisku ("Dzień 3, 45 zł") — tanie,
  `TimeManager.current_day`/`ProgressStore.money` już śledzone.
- Subtelne cząsteczki otoczenia (`brackeys_vfx_bundle` — kurz/mgła) jako akcent
  atmosferyczny.

**Uwaga**: "motyw cyberpunkowy" dla menu głównego jest w pewnym napięciu z decyzją #5d
("współczesne miasto", nie sci-fi/neon — `godotagent.md` explicite mówi "not
neon-cyberpunk... this is grounded contemporary, not sci-fi"). Do wyjaśnienia z
użytkownikiem przy starcie tego zadania, czy chodzi o chłodniejszą, stonowaną paletę
miejską, czy faktycznie neonowy cyberpunk — to dwie różne decyzje artystyczne.

## 11b. Backlog — trzecia fala pomysłów (2026-08-31, NIE zaimplementowane)

Dopisane do sekcji 11 (ten sam status: plan, zero implementacji).

### Interakcje społeczne/dialogowe
- System plotek — NPC przekazują sobie informacje o czynach gracza (z opóźnieniem
  między dzielnicami).
- Znajomi z pracy/ulicy — stali NPC z cyklem "dzień dobry/pogawędka/prośba o przysługę".
- Anonimowe wiadomości/gryps — kartka w świecie z drobnym zadaniem pobocznym.

### Ekonomia i przedmioty
- Znajdźki kolekcjonerskie bez wpływu na progresję (wzorzec `ItemData` już gotowy).
- Odzyskiwanie skradzionych/zgubionych rzeczy — prosty quest-generator.
- Sezonowe/dzienne promocje w automatach (`TimeManager.current_day` jako seed).

### Świat i atmosfera
- Pogoda (deszcz/mgła) niezależna od cyklu dobowego — punkt zaczepienia:
  `DayNightOverlay` (sekcja 10a).
- Dźwięki otoczenia zależne od pory dnia — `AudioService` już istnieje.
- Graffiti/ślady gracza w miejscach walk/automatów — kosmetyczne, buduje "to moje miasto".

### Wyzwania/tryby dodatkowe
- Tryb "bez walki" z osobnym osiągnięciem/walutą.
- Codzienne wyzwanie miejskie — seed z `TimeManager.current_day`.

### QoL
- Filtr/sortowanie w dzienniku transakcji (jeśli historia transakcji powstanie, sekcja 11).
- Skróty klawiszowe do najczęściej używanych automatów/lokacji.

## 11c. Redesign menu głównego — ZROBIONE (2026-08-31)

Doprecyzowanie kierunku (użytkownik): **"stonowana miejska z dodatkiem cyberpunk
nowoczesnej technologii"** — ciemna, przygaszona paleta miejska + JEDEN akcent koloru
(cyjan/tech), nie pełny neon. Rozwiązuje napięcie zaznaczone w 11a.

- **`ui/theme/menu_theme.tres`** (nowy, przez `tools/build_menu_theme.gd` — ten sam
  wzorzec co `build_theme.gd`) — osobny Theme od `edek_theme.tres` (który zostaje
  nietknięty, dalej używany gdzie indziej w grze, zgodnie z decyzją 5d, że L1-L7 i
  istniejące UI to zamknięty rozdział). Paleta: ciemny grafitowo-granatowy tło/panel,
  cyjanowy akcent (`Color(0.196, 0.749, 0.847)`) na przyciskach — jedyny kolorowy
  element na ekranie, reszta stonowana. Te same fonty Baloo2/Nunito (zmiana palety,
  nie typografii).
- **`MainMenu.gd`/`.tscn`** (nowy) — **pierwszy raz w tej sesji `run/main_scene`
  wskazuje na menu, nie na `Level1.tscn`** (zamyka przy okazji punkt audytu #7 z
  `docs/ROADMAP.md`: "gra startuje w środku poziomu 1"). Tło ożywione **tymi samymi
  skryptami `AmbientPedestrian.gd`/`AmbientVehicle.gd`** co w grze (sekcja 10b) —
  zero nowej logiki, tylko nowe instancje. `DayNightOverlay` (sekcja 10a) zsynchronizowany
  z realnym `TimeManager`. Subtelne cząsteczki dymu/kurzu z `brackeys_vfx_bundle`
  (`smoke_01_a.png`, bardzo niska alfa 0.12) jako akcent atmosferyczny.
- **Przycisk "Kontynuuj"** — pierwszy realny konsument `ProgressStore` **na starcie
  sesji** (dotąd dane były czytane tylko wewnątrz poziomu). Widoczny warunkowo po
  istnieniu **pliku** zapisu (`FileAccess.file_exists`), nie po wartościach pól — 0 zł
  to legalny, zapisany stan, nie "brak zapisu". Podsumowanie na przycisku
  ("Dzień N · M zł") z `TimeManager`/`ProgressStore`, bez dodatkowej infrastruktury.
- **Przyciski `kenney_ui-pack`** reużyte pośrednio przez wspólny `menu_theme.tres`
  (StyleBoxFlat, nie bezpośrednio tekstury Kenneya) — zachowuje spójność stylu
  przycisków z resztą gry (ten sam wzorzec co `edek_theme.tres`), zamiast osobnego
  zestawu tekstur tylko dla menu.
- **Pop-in panelu** — ten sam wzorzec `TRANS_BACK` scale+fade co `ToastManager`/
  `TransitMenu` (spójny język ruchu w całej sesji).
- **Bug znaleziony i naprawiony od razu**: `.tscn` **nie jest GDScriptem** —
  komentarz `##` wstawiony między definicjami węzłów **skorumpował parser sceny**
  (`Parent path './AmbientLayer' for node 'Pedestrian2' has vanished when
  instantiating` — pierwsze dziecko po komentarzu ładowało się poprawnie, kolejne
  rodzeństwo już nie). Naprawa: usunięcie komentarza z `.tscn`, wyjaśnienie zostaje
  wyłącznie w nagłówku `MainMenu.gd`. **Nowa, zapamiętana zasada na przyszłość: żadnych
  `##`/`#` komentarzy wewnątrz plików `.tscn`.**
- **`tests/unit/test_main_menu.gd`** (nowy, 4 testy) — widoczność/treść przycisku
  "Kontynuuj" zależna od pliku zapisu, "Nowa gra" faktycznie resetuje portfel, wybór
  celu "Kontynuuj" to ostatni odblokowany poziom. Logika testowana bezpośrednio
  (`_on_new_game_pressed()`, obliczenie `level_id`), nie przez pełny łańcuch z
  `SceneRouter` — ta sama, już ustalona granica co w testach Metra (sekcja 10a).
- **Wizualnie potwierdzone zrzutem ekranu** (metoda z sekcji 10c) — ciemne, stonowane
  tło z dryfującą mgłą, dwóch przechodniów, panel z cyjanowymi przyciskami, przycisk
  "Kontynuuj" z realnym podsumowaniem. Drobna korekta po zrzucie: auto na pętli
  częściowo wychodziło poza dolną krawędź okna (720px) — przesunięte wyżej.
- **Status walidacji**: pełny pakiet **89/89 PASS** (178 asercji), boot bez sceny
  (nowy domyślny `MainMenu.tscn`) czysty przez MCP, wizualnie potwierdzone.

**Otwarte na przyszłość** (świadomie poza zakresem tej rundy): pełne tło z
LimeZu/Kenney city zamiast jednolitego koloru+mgły — udokumentowane w kodzie jako
zaakceptowane uproszczenie, nie przeoczenie.

## 12. Następny krok

**Stan na koniec tej sesji**: pion combat (sekcje 1-5) + cały backlog "współczesne
miasto" sekcji 6 (bez telefonu) + mobilne/zaawansowane sterowanie (sekcja 8) + pierwsza
realna wizualna weryfikacja przez zrzuty ekranu, 3 realne bugi znalezione i naprawione
(sekcja 10c) + dokumentacja zsynchronizowana — wszystko zrobione, **85/85 GUT PASS**.

**Redesign menu głównego zrobiony** (sekcja 11c) — nowy `MainMenu.tscn` jest teraz
`run/main_scene`, **89/89 GUT PASS**, wizualnie potwierdzony zrzutem ekranu.

## 11d. Druga i trzecia fala backlogu — pierwsza podgrupa ZROBIONA (2026-08-31)

Z próśb "druga i trzecia fale backlogu, działaj" wybrana konkretna podgrupa QoL (reszta
obu list w sekcjach 11/11b zostaje w backlogu, świadomie nie próbowano zrobić wszystkiego
naraz):

1. **Toasty przy niskiej energii/pieniądzach** — `LevelRuntime._check_low_energy_toast()`
   (próg `LOW_ENERGY_THRESHOLD = 20.0`, tylko przy przekroczeniu progu w dół, nie co
   klatkę), wywoływane z `_update_energy()` i `restore_energy()`. `ProgressStore.
   spend_money()` emituje toast przy `money < LOW_MONEY_THRESHOLD (5)`.
2. **Podsumowanie dnia** — `ProgressStore` śledzi `day_earned`/`day_spent`/
   `day_fights_won` (nietrwałe, resetowane na `TimeManager.day_changed`, patrz komentarz
   w kodzie czemu to NIE jest częścią zapisu), `_on_day_changed()` emituje jeden toast
   podsumowujący ("Podsumowanie dnia: +X zł, -Y zł, Z starć"), pomijany gdy dzień był
   całkiem bez aktywności. Nowy sygnał `EventBus.money_changed(new_amount)`.
3. **Kompas questa** — `ProximityTrack.gd` dostał pole `direction: Vector2` (liczone w
   `LevelRuntime._compute_tracks()` obok już istniejącego `tier`/`dist`, praktycznie za
   darmo z tych samych dwóch pozycji). `HUD.gd` dostał `$CompassArrow` (Label z glifem
   "➤", `pivot_offset` na środku), `_update_compass()` co klatkę wybiera najbliższy
   aktywny track i ustawia `rotation = direction.angle()`; ukryty gdy brak questów lub
   najbliższy jest już w tierze "at".

**GUT: 103/103 PASS** (nowe pliki: `tests/economy/test_progress_store_day_summary.gd`,
`tests/integration/test_low_energy_toast.gd`, `tests/ui/test_hud_compass.gd`). Po drodze
złapany i naprawiony realny bug testowy (nie produkcyjny): `day_earned`/`day_spent`/
`day_fights_won` celowo nie są częścią `reset_progress()` (nie są zapisywane), więc
pierwszy test w nowym pliku widział wyciek stanu z gier symulowanych we wcześniejszych
plikach testowych w tym samym przebiegu GUT — poprawka: `before_each()` zeruje je
explicité tylko w tym pliku testowym, produkcyjny kod bez zmian.

Nie zrobione z tej rundy (świadomie odłożone, wracać wg priorytetu z sekcji 11/11b):
reszta QoL (mapa miasta, fast-travel UI polish), życie miasta/ambient content, ekonomia/
przedmioty poza tym co już jest, atmosfera (graffiti/ślady), tryby wyzwań, social/dialog.

**Próba wizualnego playtestu (2026-08-31) — NIEUDANA, ograniczenie potwierdzone**: próbowano
rozszerzyć metodę z sekcji 10c (zrzut ekranu prawdziwego okna) o symulację inputu przez
PowerShell `System.Windows.Forms.SendKeys` na okno `Edek (DEBUG)` (`SetForegroundWindow` +
`SendWait`) — cel: otworzyć `DebugConsole` (backtick) i użyć nowej komendy `/advance_day`
oraz `/give_money`, żeby wywołać toast podsumowania dnia i niskiego stanu konta na żywo, plus
podejść do questa i zobaczyć kompas. **`SendKeys` nie dotarł do gry** — ani ruch (strzałki),
ani konsola (backtick) nie dały żadnego efektu na kolejnych zrzutach ekranu, mimo że okno
było poprawnie foreground'owane. Gra sama w sobie bootuje się czysto (0 błędów,
`TestCombat.tscn` renderuje się poprawnie — potwierdzone zrzutem). Wniosek: zrzut ekranu
działa, symulacja inputu do realnego okna Godota — NIE. Za zgodą użytkownika ("2" =
zostajemy przy testach logiki) kompas/toasty/podsumowanie dnia z sekcji 11d pozostają
zweryfikowane WYŁĄCZNIE przez GUT (103/103), bez wizualnego potwierdzenia. Jeśli przyszła
sesja będzie chciała jednak zobaczyć je na żywo, jedyna dotąd działająca metoda to
użytkownik ręcznie gra, a AI tylko robi zrzuty między krokami (opcja odrzucona w tej
rundzie, nie testowana).

Debug-console dostał przy okazji nową komendę **`/advance_day`** (`DebugConsole.gd`) —
skacze czas do końca bieżącego dnia (`TimeManager.advance_minutes`), żeby nie czekać 24
realnych minut na naturalną zmianę dnia przy teście podsumowania. Nieużyta w tej rundzie
(input nie dotarł), ale zostaje jako trwałe narzędzie QA na przyszłość.

## 11e. Sekcja 11 — druga podgrupa ZROBIONA (2026-08-31): statystyki życiowe + historia transakcji

Po decyzji użytkownika "zostajemy przy testach logiki" kontynuacja sekcji 11/11b, znowu
jedna konkretna, tania podgrupa (dane-only, bez nowego UI — zgodnie z ustaleniem, że
wizualna weryfikacja nie działa w tej sesji):

1. **Osiągnięcia/statystyki życiowe** — `ProgressStore.total_enemies_defeated`/
   `total_money_earned`/`total_days_survived`. W odróżnieniu od `day_earned`/`day_spent`/
   `day_fights_won` (sekcja 11d) te NIGDY się nie resetują i SĄ trwałe (część
   `save_progress()`/`load_progress()`/`reset_progress()`). Inkrementowane w
   `add_money()`, `_on_enemy_died()`, `_on_day_changed()`.
2. **Historia transakcji** — `ProgressStore.transaction_history: Array[Dictionary]`,
   każdy wpis `{type: "earn"|"spend", amount, day, hour, minute}` z `TimeManager`,
   dopisywany w `add_money()`/`spend_money()` (tylko przy udanej transakcji — nieudana
   próba zakupu nic nie zapisuje). Ucięty do `MAX_TRANSACTION_HISTORY = 100` najnowszych
   wpisów — świadomie ograniczone, żeby zapis nie rósł bez końca przez wiele sesji gry.
   Trwały (zapisywany/wczytywany), fundament pod "Filtr/sortowanie w dzienniku
   transakcji" z sekcji 11b, gdy powstanie faktyczny UI dziennika.

**GUT: 116/116 PASS** (nowe pliki: `tests/economy/test_progress_store_lifetime_stats.gd`,
`tests/economy/test_progress_store_transaction_history.gd`). Boot-check L1 czysty (0
błędów). Świadomie bez UI w tej rundzie — oba punkty to czysto warstwa danych, gotowa pod
przyszły ekran statystyk/dziennika, ale sam ekran nie istnieje jeszcze (podobny wzorzec do
`reputation`: dane + sygnał, konsument UI dodany dopiero gdy realnie potrzebny).

## 11f. Sekcja 11 — trzecia podgrupa ZROBIONA (2026-08-31): trudność skaluje obrażenia/ceny

**Panel trudności jako osobne ustawienie** (sekcja 11) był już częściowo zrobiony —
`SettingsMenu.tscn`/`SettingsStore.difficulty` (selektor easy/medium/hard/explorer) już
istniały z wcześniejszej sesji. Brakująca część z opisu backlogu — "obrażenia/ceny/
agresywność wrogów, nie na sztywno w StatsData/Difficulty.gd" — teraz zrobiona:

- `Difficulty.CONFIG` dostał `enemy_damage_mul`/`shop_price_mul` na każdym poziomie
  trudności (easy 0.7/0.85, medium 1.0/1.0, hard 1.4/1.15, explorer 0.0/1.0 — "brak
  niebezpieczeństwa" nie oznacza też "darmowe zakupy").
- Nowe statyczne helpery `Difficulty.scaled_damage(base, difficulty)` i
  `Difficulty.scaled_price(base, difficulty)` — mnożą i zaokrąglają w jednym miejscu
  zamiast duplikować `get_config(...).xxx_mul` w każdym wywołaniu, `maxi(0, ...)` chroni
  przed ujemnym wynikiem.
- Zastosowane w punkcie zadawania obrażeń/sprzedaży, NIE zapisane na sztywno w danych:
  `EnemyHitbox.apply_hit()` (`Difficulty.scaled_damage(attack_damage, SettingsStore.
  difficulty)`), `VendingMachine.interact()` i `TransitMenu.open()`/`_try_purchase()`
  (`Difficulty.scaled_price(cost, SettingsStore.difficulty)`) — jeden placed `cost`/
  `attack_damage` na węźle automatycznie odzwierciedla wszystkie poziomy trudności, bez
  osobnej kopii `EnemyData`/`VendingMachine` na trudność.

**GUT: 123/123 PASS** (nowy plik `tests/unit/test_difficulty_scaling.gd` + jeden nowy test
w `tests/economy/test_vending_machine.gd`). Domyślna trudność to "medium" (mnożnik 1.0),
więc wszystkie istniejące testy combat/vending/transit działają bez zmian — nowe testy
świadomie przełączają `SettingsStore.difficulty` tymczasowo i przywracają ją na końcu.
Boot-check `TestCombat.tscn` czysty. Bez wizualnej weryfikacji (ograniczenie z sekcji 11d
wciąż aktywne) — balans liczb (0.7/1.4/0.85/1.15) to pierwsze rozsądne wartości, nie
przetestowane w praktyce grania; do ewentualnej korekty przy przyszłym prawdziwym
playteście.

## 11g. PRZEŁOM: samosterujący harness zrzutów UI — działa tam, gdzie SendKeys zawiódł (2026-08-31)

Sekcja 11d odnotowała, że symulacja inputu (`SendKeys`) do prawdziwego okna gry nie działa.
Rozwiązanie: **nie trzeba symulować inputu wcale** — zamiast klikać/naciskać klawisze z
zewnątrz, nowa scena `scenes/dev/UIVerify.tscn` + `scripts/dev/UIVerify.gd` steruje stanem
HUD-a bezpośrednio z GDScript (dokładnie te same wywołania co `LevelRuntime`/`EventBus` —
`hud.update_proximity(...)`, `hud.update_energy(...)`, `EventBus.toast_requested.emit(...)`),
czeka kilka klatek na tweeny, łapie `get_viewport().get_texture().get_image()` i zapisuje
PNG do `user://` (`ProjectSettings.globalize_path()` daje ścieżkę na dysku), po czym sama
się zamyka (`get_tree().quit()`). Uruchamiane przez `mcp__godot__run_project` na tę scenę —
proces kończy się sam, `Read` czyta zapisany plik bezpośrednio. Zero zależności od
Win32/PowerShell/okna na pierwszym planie. Ta metoda powinna być domyślną drogą
weryfikacji UI na przyszłość — działa wszędzie, w tym w trybie headless/CI, w
przeciwieństwie do zrzutu prawdziwego okna z sekcji 10c/11d (który nadal jest jedyną opcją
dla rzeczy zależnych od realnego rendera pełnej sceny/gry, nie samego UI-CanvasLayer).

**Zweryfikowano wizualnie i potwierdzono poprawne**: kompas (`HUD._update_compass()`) w
4 kierunkach (prawo/dół/lewo/góra) — strzałka `➤` obraca się dokładnie zgodnie z
`direction.angle()`, żaden z testów nie skłamał. Etykieta energii przy niskim stanie
pokazuje poprawnie czerwony sufiks "(Zmęczenie)". Pasek HP gracza widoczny, zielony, pełny
(zgodne z naprawą z sekcji 10c).

**Znaleziony i naprawiony realny bug wizualny, niewykryty przez żaden test**: gdy toast
(`ToastContainer`) i aktywny kompas (`CompassArrow`) są widoczne jednocześnie, grot strzałki
dotykał/nachodził na dolną krawędź dymka toastu — `CompassArrow.offset_top` w `HUD.tscn`
był ustawiony na 60 (świeżo dodane w sekcji 11d), za blisko `ToastContainer` (`offset_top`
16, wysokość jednowierszowego toastu ~54px). Przesunięte na `offset_top=110`/
`offset_bottom=142` (ten sam wzorzec co przesunięcie `PlayerHealthBar` w sekcji 10c —
"dopiero realny render pokazuje kolizje layoutu, których asercja o `rotation`/`visible`
nigdy nie złapie"). **GUT: 123/123 PASS niezmienione** po przesunięciu (offsety nie są
częścią logiki testowanej przez `test_hud_compass.gd`).

## 11h. Sekcja 11 — czwarta podgrupa ZROBIONA (2026-08-31): dziennik ukończonych questów (backend + toast)

**Log/dziennik questów (aktywne + historia ukończonych)** — część "aktywne" już istniała
(HUD pokazuje bieżące questy). Dodana brakująca część "historia ukończonych":

- `ProgressStore.quest_completion_history: Array[Dictionary]` — trwały, NIE ucięty
  (w odróżnieniu od `transaction_history`) — pełna historia questów w całej grze to mały,
  ograniczony zbiór (jeden wpis na `QuestStepData` kiedykolwiek autorowany), nie
  nieograniczony strumień jak zakupy. `record_quest_completed(level_id, quest_id)` +
  `has_completed_quest(...)` — idempotentne per (level_id, quest_id).
- `LevelRuntime._update_status()` wykrywa przejście questa w stan `done` (porównanie z
  `_known_done_quest_ids`, per-sesja-poziomu) i wtedy: zapisuje do `ProgressStore`
  + emituje toast "Ukończono: {label questa}" — realny, natychmiastowy feedback dla
  gracza, nie tylko cichy zapis danych.

**Zweryfikowane realnym przepływem** (nie tylko wywołaniem metody wprost): test używa
prawdziwego questa "talk" z `data/levels/level_2.tres` (`q2-squirrel`) przez prawdziwy
sygnał `EventBus.npc_talked`, dokładnie tą samą ścieżką co gracz rozmawiający z NPC.
Potwierdzone: dokładnie jeden toast na ukończenie (nie powtarza się przy kolejnych tickach
`_update_status()`, ~10/s), dokładnie jeden wpis w historii mimo wielokrotnych ticków.

**GUT: 131/131 PASS** (nowe pliki: `tests/economy/test_progress_store_quest_history.gd`,
`tests/integration/test_quest_completion_journal.gd`). Boot-check `Level2.tscn` czysty.
Świadomie bez ekranu dziennika w tej rundzie — jak `reputation`/statystyki życiowe, dane +
sygnał (tu: toast) gotowe, sam ekran historii (UI do przeglądania
`quest_completion_history`) zostaje w backlogu do czasu realnej potrzeby.

## 11i. Sekcja 11b — ZROBIONE (2026-08-31): sezonowe/dzienne promocje w automatach

**Sezonowe/dzienne promocje w automatach** (sekcja 11b) — `TimeManager.current_day`
(0=Poniedziałek..6=Niedziela) jako deterministyczny seed: `VendingMachine.PROMO_DAYS =
[2, 5]` (Środa, Sobota) daje 20% zniżkę (`PROMO_DISCOUNT = 0.8`), zastosowaną PO
mnożniku trudności z sekcji 11f (`Difficulty.scaled_price()` → promo na wierzchu, nie
zamiast). Nowy `$PromoBadge` (Label "PROMOCJA!", żółty) w `VendingMachine.tscn`,
widoczność aktualizowana w `_ready()` i na `TimeManager.day_changed`.

**Zweryfikowane wizualnie** — rozszerzony harness `UIVerify.gd` (sekcja 11g) o drugi
przypadek: instancjonuje `VendingMachine.tscn` bezpośrednio (nie tylko HUD), wymusza dzień
promocyjny i niepromocyjny, zapisuje oba zrzuty. Potwierdzone: plakietka "PROMOCJA!"
widoczna w środę, całkowicie ukryta w poniedziałek — dokładnie zgodnie z logiką.

**GUT: 134/134 PASS** (3 nowe testy w `tests/economy/test_vending_machine.gd`: zniżka w
dzień promocyjny, pełna cena poza nim, widoczność plakietki). Boot-check `TestCombat.tscn`
czysty.

## 11j. Sekcja 11b — ZROBIONE (2026-08-31): graffiti/ślady gracza po walce

**Graffiti/ślady gracza w miejscach walk** (sekcja 11b) — dziewiąty autoload
`GraffitiSpawner.gd`, ten sam wzorzec co `VfxSpawner` (pula, round-robin), ale BEZ
zanikania — ślad ma zostać, w odróżnieniu od krótkiego rozbłysku trafienia. Nowy sygnał
`EventBus.combat_trace_requested(position)`, emitowany przez `EnemyActor` w momencie
śmierci (`_health.died` handler, obok już istniejącego `enemy_died`). Sesyjne (nie
zapisywane w `ProgressStore`) — trwała wersja międzysesyjna wymagałaby przechowywania
pozycji per-poziom, realny zakres wykraczający poza "tani akcent atmosfery", o który
prosił backlog.

**Znaleziony i naprawiony realny bug (złapany przez test, nie przez oko)**: `Label` z
niezerowym `pivot_offset` przesuwa swój `global_position` przy ustawieniu `rotation` —
transform origin liczy się jako `position + pivot - rotate(pivot)`, więc ustawienie
`global_position` PRZED `rotation` dawało znak wylądowany kilka pikseli od zamierzonej
pozycji (np. żądane `(100, 200)` → realne `(102.97, 197.58)`). Naprawa: kolejność
odwrócona (`rotation` najpierw, `global_position` na końcu) — ten sam mechanizm co
`CompassArrow.pivot_offset` w HUD, ale tam nigdy nie wyszedł na jaw, bo kompas nigdy nie
zmienia `position`, tylko `rotation` samo w sobie.

**Zweryfikowane wizualnie** — harness `UIVerify.gd` rozszerzony o emisję 4 realnych
`combat_trace_requested` w rozproszonych pozycjach świata (nie HUD-CanvasLayer, prawdziwa
przestrzeń Node2D) — potwierdzone: 4 znaki widoczne, każdy lekko obrócony inaczej (efekt
"scatter" działa), żaden nie zniknął.

**GUT: 139/139 PASS** (nowy plik `tests/vfx/test_graffiti_spawner.gd` + jeden nowy test w
`tests/combat/test_combat.gd` potwierdzający, że `EnemyActor` faktycznie emituje sygnał
przy śmierci, prawdziwym łańcuchem `take_damage()` → `died` → `combat_trace_requested`,
nie przez wywołanie handlera wprost). Boot-check `TestCombat.tscn` czysty (przy okazji
naprawione też drobne ostrzeżenie shadowingu parametru `position` z wbudowaną właściwością
`Node2D.position`).

Dalej w kolejce:
1. **Kontynuacja ręcznego playtestu ze zrzutami ekranu** — metoda z sekcji 10c działa,
   używać jej dalej zamiast polegać wyłącznie na asercjach przy nowej pracy wizualnej.
2. **Druga fala backlogu** (sekcja 11) — duża lista pomysłów (tryby gry, QoL, "życie
   miasta", progresja, interakcje społeczne, ekonomia/przedmioty, atmosfera) — czeka na
   priorytetyzację.
3. **Ekwipunek/paperdoll gracza** i **balans liczb** — wciąż świadomie odłożone
   (sekcja 10).

## 8. Mobilne menu i zaawansowane sterowanie — ZROBIONE (2026-08-31)

- **Gotcha odkryty od razu**: klasa `class_name VirtualJoystick` **koliduje z natywną
  klasą silnika** w Godot 4.7 ("Parse Error: Class 'VirtualJoystick' hides a native
  class") — zmieniona na `TouchJoystick` wszędzie (plik, testy, sceny). Znalezione przez
  faktyczne uruchomienie ładowania, nie zgadnięte z dokumentacji.
- **`scripts/presentation/mobile/TouchJoystick.gd`** (nowy, `Control`) — wirtualny
  joystick sterujący **tymi samymi** akcjami `move_left/right/up/down` co klawiatura/pad,
  przez `Input.action_press(action, strength)`/`action_release(action)` — zero nowej
  logiki ruchu, `PlayerMovement.gd`'s `Input.get_vector(...)` po prostu widzi wejście z
  dowolnego źródła. Obsługuje realny dotyk (`InputEventScreenTouch`/`Drag`) **i** mysz
  (pseudo-touch id `-2`) — mysz nie jest dla graczy, tylko żeby dało się to ręcznie
  sprawdzić w edytorze bez sprzętu dotykowego.
- **`scripts/presentation/mobile/TouchButton.gd`** — cienki wrapper `TextureButton`,
  jedna akcja per przycisk przez `button_down`/`button_up`. `TextureButton` dostaje input
  dotykowy z automatu przez warstwę `Control` Godota — brak potrzeby własnej obsługi
  (w przeciwieństwie do joysticka, który nie jest przyciskiem z ustalonym hit-testem).
- **`scenes/ui/MobileControls.tscn`** — joystick (lewy dół, `mobile-controls-1`) +
  4 przyciski akcji (prawy dół, **`kenney_ui-pack`** — Attack/Blue, Hop/Green,
  Sprint/Yellow, Interact/Red, zgodnie z Twoją prośbą "do UI użyj kenney ui pack").
  Wpięte jako dziecko **`HUD.tscn`** (nested `CanvasLayer` w `CanvasLayer`, legalne w
  Godocie), `layer=15` (nad HUD-em, `layer=10`).
- **`SettingsStore.mobile_controls`** (nowe pole, `"auto"/"on"/"off"`, persystowane jak
  reszta ustawień) — `MobileControls.should_show()` w `"auto"` sprawdza
  `DisplayServer.is_touchscreen_available()`. Pierwszy realny konsument pola
  `ControlSettings`, o którym `SettingsStore.gd`'s stary komentarz mówił "no consumer
  exists yet" — komentarz zaktualizowany, nie zostawiony jako nieaktualny.
- **Zaawansowane sterowanie** (`docs/ROADMAP.md` sekcja 12, realny konkretny zakres, nie
  cała lista) w `InteractionDetector.gd`:
  1. **Buforowanie interakcji** — E naciśnięte do 150ms przed wejściem w zasięg nadal
     działa (`_buffer_remaining`, ten sam wzorzec co `PlayerHop.gd`'s jump-buffer).
  2. **"Lepki" cel interakcji** — histereza: obecny cel wygrywa, dopóki inny kandydat nie
     jest bliżej o **>15%** (`STICKY_MARGIN`), nie tylko odrobinę bliżej — zapobiega
     miganiu promptu/celu między dwoma prawie-równie-odległymi kandydatami.
- **`tests/ui/test_mobile_controls.gd`** (5 testów) + **`tests/player/
  test_interaction_detector.gd`** (6 testów, w tym sticky/buffer) — nowe.
  **Gotcha w teście**: symulowane `InputEventMouseButton` (pozycyjne) **nigdy nie
  docierają** do `_input()` w headless GUT (brak realnego okna/`DisplayServer`) —
  w przeciwieństwie do zdarzeń klawiszowych opartych na akcjach, które działają
  headless wszędzie indziej w tym projekcie. Naprawa: test woła
  `joystick._update()`/`_reset()` bezpośrednio zamiast przez pełny pipeline zdarzeń —
  weryfikuje prawdziwą logikę, nie plumbing zdarzeń systemowych (ta sama kategoria
  granicy co brak narzędzia zrzutu ekranu, udokumentowana już wcześniej w tym pliku).
- **Status walidacji**: pełny pakiet **45/45 PASS** (106 asercji), boot L1 czysty.

## 9. Dźwięki combat — ZROBIONE (2026-08-31)

Ostatni punkt z "poza zakresem tej rundy" (sekcja 5), zamknięty na wyraźną prośbę
użytkownika. Trzy nowe metody w `AudioService.gd`, **ten sam** proceduralny wzorzec sinus
+ obwiednia co istniejące `play_pickup`/`play_completion`/`play_danger` (zero próbek —
`AudioService.gd`'s własny nagłówek już dokumentuje, że nic do portowania nie istnieje):

- `play_swing()` — krótki wysoki "tick" na `PlayerAttack._start()` (gra niezależnie od
  trafienia — świst to inny dźwięk niż trafienie).
- `play_hit()` — niski, mocny "thud" na udanym trafieniu, w `PlayerHitbox.gd`/
  `EnemyHitbox.gd`, dokładnie tam gdzie już emitują `EventBus.hit_landed`.
- `play_enemy_defeated()` — opadające trójdźwięk (odwrotność `play_completion()`'s
  wznoszącego trójdźwięku), na `EnemyDeathState.enter()`.

**`tests/combat/test_combat_audio.gd`** (nowy, 3 testy) — sprawdza, że wołanie każdej
metody faktycznie aktywuje głos syntezatora z właściwą częstotliwością (czytając
`AudioService._voices` bezpośrednio — konwencja `_`-prefiksu w tym projekcie to nie
prawdziwa prywatność, ten sam wzorzec co reszta testów). Pełny pakiet **48/48 PASS**
(109 asercji), boot L1 czysty.

## 10a. Backlog "współczesne miasto" — pierwsza runda ZROBIONA (2026-08-31, bez telefonu)

Użytkownik doprecyzował: realizować backlog z sekcji 6, ale **"bez systemu smartfona"**
— telefon/SMS/aplikacje odpadają, reszta zostaje. Zrobione w tej rundzie:

- **`scripts/infrastructure/TimeManager.gd`** (nowy, **ósmy autoload**) — minuty/godziny/
  dni tygodnia, `signal hour_changed`/`day_changed`, `is_night()` (21:00-06:00, z
  zawijaniem przez północ), `advance_minutes(n)` do przyszłego użytku przez metro/fast
  travel (dodaje N minut, emitując `hour_changed` tylko za realnie przekroczone godziny,
  nie N razy).
- **`scripts/presentation/atmosphere/DayNightOverlay.gd`** + `.tscn` — **świadomie
  osobny** od `AtmosphereFX.gd`'s systemu `mood` (który ma już dostrojony, potwierdzony
  przez użytkownika efekt na L1) zamiast scalania w jeden system — półprzezroczysty
  `ColorRect` na własnym `CanvasLayer` (warstwa 8, pod HUD-em) zamiast `CanvasModulate`
  (ten drugi jest scenowo-globalny, drugi konkurowałby z pierwszym). Płynne przejście
  zmierzch (19-21) i świt (5-7), pełna noc między.
- **Ekonomia**: `ProgressStore.money` (nowe pole, `add_money()`/`spend_money()` z
  atomowym zapisem jak reszta), **`VendingMachine.gd`+`.tscn`** (automat z colą,
  `interact()`-kompatybilny z `InteractionDetector` bez żadnych zmian w nim), trzy nowe
  sygnały `EventBus` (`toast_requested`, `item_purchased`, `energy_restore_requested`) —
  automat nie zna `LevelRuntime` (prywatny `_energy`), prosi przez `EventBus`, tak samo
  jak reszta combat. `LevelRuntime.restore_energy()` (nowa publiczna metoda) łapie to.
  **Nie wpięte w `LevelBuilder`'s `kind`-switch** — to ręcznie stawiana scena (jak
  `EnemyActor` przed Punktem 5g), pełna integracja z danymi poziomu to naturalny,
  osobny następny krok.
- **`scripts/presentation/ui/ToastManager.gd`** — generyczny, animowany stos powiadomień
  (`EventBus.toast_requested`), pierwszy realny krok w stronę `docs/ROADMAP.md` sekcji 28
  ("Toasty zamiast MessageLabel") — budowany od razu jako generyczny mechanizm, nie
  jednorazówka pod automat.
- **`/give_money [n]`** w `DebugConsole.gd` — testowalność automatu bez ręcznego
  edytowania save'a.
- **Agent UI (`godot-ui-designer`) w tle** dopracował animacje: pop-in/pop-out toastów
  (scale+slide+fade, wyśrodkowany pivot), flash+shake paska HP przy trafieniu (bez
  reakcji na leczenie), idle bob+glow ikony automatu + pulsacja przy interakcji,
  `texture_pressed` na przyciskach dotykowych (Kenney `depth_gloss` warianty) + tween
  skali na `TouchButton`. Zero nowych systemów, czysto polish nad tym co zbudowane.
- **Gotcha złapany przy scalaniu**: nowe klasy (`TimeManager`/`DayNightOverlay`/
  `VendingMachine`/`ToastManager`) wymagały ponownego skanu edytora, zanim testy je
  zobaczyły — GUT po cichu **pomijał** 2 pliki testowe ("Ignoring script... because it
  does not extend GutTest", de facto "nie mogę go sparsować") zamiast je oblać, licznik
  "61/61 passed" był mylący dopóki nie doskanowano — złapane przez sprawdzenie output'u
  GUT-a linia po linii, nie zaufanie samej liczbie "passed".
- **Status walidacji**: pełny pakiet **67/67 PASS** (145 asercji, było 48 przed tą
  rundą), boot L1 i `TestCombat.tscn` (z dodanym automatem) czyste przez MCP.

## 10. Świadomie NIE zrobione w tej sesji (mimo prośby "jak kończysz wszystko rób")

Użytkownik poprosił o domknięcie całej listy z sekcji 5 razem z mobilnym sterowaniem.
Cztery z pięciu pozycji zamknięte (drugi wróg, osadzenie na poziomie, mobilne/zaawansowane
sterowanie, dźwięki combat — sekcje 5g/8/9). **Dwie pozycje świadomie zostawione:**

- **Ekwipunek broni / paperdoll gracza (Mana Seed)** — sekcja 1 planu już to nazwała
  "osobną, większą decyzją architektoniczną" explicite. Zaimplementowanie tego bez
  rozmowy o kształcie systemu (jaki ekwipunek, ile slotów, czy bronie mają staty) byłoby
  zgadywaniem wymagań w największym dotąd systemie tej sesji — dokładnie to, czego
  zasada 1 (`rpg.md` sekcja 0) zakazuje.
- **Balans liczb (HP/obrażenia)** — wartości są robocze **z założenia** (sekcja 5 mówi
  to wprost), a "strojenie" wymaga z definicji ludzkiego osądu z playtestu ("czy ten
  wróg jest za mocny"), nie czegoś, co da się rozstrzygnąć czytaniem kodu. Nic nie
  zmienione względem wartości z Punktu 2/5g.
- **Więcej wrogów poza `thug`/`bandit`** (Skeleton, Archer, Lancer) — częściowo zrobione
  (`bandit`, sekcja 5g), ale **Archer/Lancer nie są tym samym pipeline'em** co
  Warrior — mają broń dystansową (`Shoot`/pociski), co wymaga nowego systemu pocisków,
  nie tylko podmiany `SpriteFrames`. Zostawione jako osobna robota, nie "szybki dodatek".

## 12. Stan dokumentacji projektu (2026-09-01) — przegląd wszystkich plików .md

Na prośbę użytkownika przejrzano WSZYSTKIE pliki `.md` w projekcie (poza `node_modules`/
`.claude/worktrees`). Wniosek: **`rpg.md` jest jedynym w pełni aktualnym źródłem prawdy**
dla stanu migracji Godot. Reszta jest w różnym stopniu nieaktualna:

- **`docs/migration/MIGRATION_MATRIX.md`** — zero wzmianek o combat/RPG/mieście, nadal
  opisuje `run/main_scene → Level1.tscn` i 3 autoloady (realnie: 9 autoloadów,
  `run/main_scene` to od sekcji 11c `MainMenu.tscn`).
- **`godot/README.md`** — ta sama nieaktualność (6 autoloadów, `Level1.tscn`). Sam
  poprawnie zaznacza, że `MIGRATION_MATRIX.md` jest nieaktualny względem `plan31-08.md`,
  ale ta autokorekta nie obejmuje w ogóle pivotu combat/RPG.
- **`todo.md`** — całkowicie o starej appce Phaser/React (DebugOverlay, profiling Chrome
  DevTools). Sprzed migracji do Godota, nieistotne.
- **`planagent.md`** — plany rozbudowy UI React/TS (`ustawienia.tsx`, `koniec.tsx`,
  `osiagniecia.tsx`, Zen mode, Daily Challenge, NG+) dla zamrożonej apki `src/game/phaser/`,
  której CLAUDE.md zabrania ruszać. Ryzyko: przyszła sesja mogłaby próbować to wdrożyć w
  żywym kodzie Godota.
- **`plan31-08.md`** — poprawny historyczny log ery sprzed pivotu combat (poprawnie
  oznaczony jako historia przez `godot/README.md`), ale czytany SAM DA fałszywy obraz
  projektu (nadal "eksploracja bez walki").
- Mylące podobne nazwy: root `godot.md` (oryginalny prompt startowy migracji) vs
  `god/godot.md`/`god/godot2.md` (kanoniczne zasady wg CLAUDE.md) vs `godot/README.md`
  (własny status projektu, sam nieaktualny).

**Zapisane też w pamięci auto-memory** (`godot_docs_landscape.md`,
`godot_migration_status.md` zaktualizowany) — żeby przyszła sesja od razu wiedziała, gdzie
szukać prawdy, zamiast czytać na ślepo pierwszy trafiony plik `.md`.

**Nie zrobione w tej rundzie (realne zadanie na przyszłość, nie zaplanowane jeszcze)**:
odświeżenie/oznaczenie jako "SUPERSEDED" plików `MIGRATION_MATRIX.md`, `godot/README.md`,
`todo.md`, `planagent.md`.

**Sesja zakończona na dziś (2026-09-01)** na prośbę użytkownika ("jutro dokończymy") —
backlog sekcji 11/11b ma jeszcze otwarte pozycje (patrz sekcja 11 wyżej): rebindowanie
klawiszy, szybki zapis/mid-level resume, "ulubione miejsca", reakcje policji/reputacji,
plotki miejskie, losowe wydarzenia uliczne, jednorazowe znajdźki combat, kryjówki/skróty,
umiejętności pasywne, pogoda niezależna od cyklu dobowego, tryb bez walki, codzienne
wyzwanie miejskie, filtr dziennika transakcji. Kontynuacja jutro od tego punktu.

## 13. Rebindowanie klawiszy + dokończenie szybkiego zapisu — ZROBIONE (2026-09-01)

Dwie pozycje z otwartej listy sekcji 12 (kontynuacja "jutrzejszej" sesji).

### 13a. Odkrycie na starcie: mid-level resume był już zbudowany, tylko nieudokumentowany

Zanim cokolwiek napisano, przeczytanie `ProgressStore.gd`/`LevelRuntime.gd` pokazało, że
**backend "Szybki zapis / mid-level resume" już istnieje w całości** w drzewie roboczym
(niescommitowane): `ProgressStore.resume_level_id/resume_pos_x/resume_pos_y/resume_hp` +
`save_checkpoint()`/`clear_checkpoint()`/`has_checkpoint_for()`/`get_checkpoint_position()`,
`LevelRuntime._resume_checkpoint()`/`_setup_checkpoint_timer()`/`_save_checkpoint()`
(Timer 5s), `MainMenu._on_continue_pressed()` już preferuje `resume_level_id` nad
`unlocked_levels.back()`, i test `tests/economy/test_progress_store_checkpoint.gd` (5
testów) już istniał i przechodził. Brakowało wyłącznie **ręcznego wyzwalacza** — gracz
mógł polegać tylko na automatycznym tickowaniu co 5s, bez możliwości "zapisz teraz przed
ryzykowną walką". To, co faktycznie dodano w tej rundzie, jest węższe niż cały punkt z
listy — dopisanie brakującego kawałka, nie budowa systemu od zera.

### 13b. Ręczny quick-save — dopisany

- **`project.godot`** — nowa akcja `quick_save` (F5, `physical_keycode=4194336`, bez
  gamepada — to skrót dla graczy klawiaturowych, nie akcja czasu rzeczywistego jak atak).
- **`scripts/gameplay/world/LevelRuntime.gd`** — `_process()` dostał
  `Input.is_action_just_pressed("quick_save")` → `_quick_save()`, która woła to samo
  `_save_checkpoint(player)` co już istniejący Timer, plus
  `EventBus.toast_requested.emit("Zapisano grę.")` (natychmiastowy feedback, nie cichy
  zapis). No-op po ukończeniu poziomu (`_level_completed`), tak samo jak Timer.
- **Gotcha powtórzony z `PlayerAttack.gd`, nie odkryty od nowa**: pierwsza wersja użyła
  `_unhandled_input(event)` z `event.is_action_pressed(...)` — zgodnie z ogólną zasadą
  input-handling (dyskretna akcja = `_unhandled_input`, nie polling). W praktyce **4/4
  nowe testy quick-save oblały** dokładnie tym samym mechanizmem, który
  `tests/combat/test_combat.gd`'s nagłówek już udokumentował dla `attack`:
  `Input.parse_input_event()` w headless GUT nie dociera do `_unhandled_input()`/
  `event.is_action_pressed()`, tylko do `Input.is_action_just_pressed()` w normalnym
  pollingu. Naprawa: `_quick_save()` wywoływana z pollingu w `_process()` (`PlayerAttack.gd`
  robi to samo w `_physics_process()` dla ataku), zgodnie z już ustalonym w tym repo
  wzorcem, nie z ogólnym zaleceniem ze skilla `input-handling`. Udokumentowane wprost w
  komentarzu w kodzie, żeby nikt nie "poprawił" tego z powrotem na `_unhandled_input`.
- **`tests/save/test_quick_save.gd`** (nowy, 4 testy, prawdziwy `Level2.tscn` +
  `Input.parse_input_event(KEY_F5)`, ten sam wzorzec co `test_gameplay.gd`/
  `test_combat.gd`) — F5 zapisuje checkpoint natychmiast (nie czeka 5s), przechwytuje
  aktualne HP gracza po obrażeniach, emituje `toast_requested`, i jest no-opem po
  ukończeniu poziomu.

### 13c. Rebindowanie klawiszy — nowy system

- **`scripts/infrastructure/SettingsStore.gd`** rozszerzony (nie nowy autoload — czwarte
  pole tej samej "genuinely global, persisted" kategorii co `volume`/`difficulty`):
  `REBINDABLE_ACTIONS` (10 akcji gameplayowych z `project.godot`: ruch×4, `interact`,
  `inventory`, `pause`, `sprint`, `hop`, `attack`, plus nowe `quick_save` — bez
  `ui_*`-builtinów Godota i bez rebindowania gamepada, świadomie poza zakresem tej
  rundy), `DEFAULT_KEYBINDS` (kopia fizycznych keycode'ów z `project.godot`, potrzebna
  bo `InputMap` po rebindzie **nie pamięta** oryginalnego klawisza), `custom_keybinds:
  Dictionary` (`action -> physical_keycode`, tylko dla akcji faktycznie zmienionych —
  ten sam "purely additive" wzorzec co nowsze pola `ProgressStore`).
  `set_keybind()`/`reset_keybind()`/`reset_all_keybinds()`/`get_key_label()` +
  `apply_keybinds()` (wołane raz w `_ready()` po `load_settings()`, przywraca zapisane
  rebindy na żywy `InputMap` przy starcie).
- **Kolizje klawiszy obsłużone, nie zignorowane**: `set_keybind()` sprawdza, czy inna
  rebindowalna akcja już używa tego samego fizycznego klawisza — jeśli tak, **czyści**
  (nie zamienia miejscami) klawiaturowy bind tamtej akcji (`custom_keybinds[other] = -1`,
  UI pokazuje "—"). Jawna decyzja udokumentowana w kodzie: cichy swap byłby równie
  zaskakujący z drugiej strony, a dwie akcje na jednym klawiszu to gorszy stan niż jedna
  akcja bez klawisza (którą gracz od razu widzi i naprawia).
- **Tylko `InputEventKey` jest ruszany** — `InputEventJoypadButton`/`Motion` już
  podpięte pod akcję w `project.godot` (np. `attack`'s przycisk padu) zostają
  nietknięte, więc rebind klawiatury nigdy nie psuje gry na padzie.
- **`scenes/menu/KeybindMenu.tscn` + `scripts/presentation/menu/KeybindMenu.gd`** (nowa
  scena, wzorzec `SettingsMenu.gd`/`MainMenu.gd` — `Control`/`PanelContainer`/
  `SceneRouter.change_scene_to_file()`, zero nowego wzorca UI) — wiersze budowane w
  kodzie z `SettingsStore.REBINDABLE_ACTIONS` (nie ręcznie w `.tscn` — dodanie kolejnej
  rebindowalnej akcji w przyszłości to zmiana jednej listy w `SettingsStore.gd`, nie
  edycja sceny). Każdy wiersz: etykieta PL, przycisk z aktualnym klawiszem (klik →
  nasłuch następnego naciśnięcia), przycisk "Domyślny" per-akcja. Filtr modyfikatorów
  (Shift/Ctrl/Alt/Meta same w sobie odrzucane jako bind — zgodnie z checklistą skilla
  `input-handling`, "Key rebinding captures modifier keys"), Esc anuluje nasłuch bez
  zmiany. Przycisk "Przywróć domyślne" (wszystkie akcje naraz).
- **`scenes/menu/SettingsMenu.tscn`/`.gd`** dostały przycisk "Sterowanie (klawisze)" →
  `KeybindMenu.tscn`, obok istniejących Trudność/Głośność/Wycisz.
- **Gotcha #2, ten sam wzorzec co `ProgressStore.save_path` — `SAVE_PATH` zmienione z
  `const` na `var`**: `SettingsStore.gd` miało `const SAVE_PATH`, więc każdy test
  wołający `set_keybind()` (który autosave'uje) pisałby do prawdziwego
  `user://settings.json`. Naprawa: `const SAVE_PATH` → `var SAVE_PATH`, identyczny
  zabieg co `ProgressStore.save_path` (patrz commit "Testy: GUT przestaje pisac do
  prawdziwego user://progress.json") — `tests/save/test_input_rebind.gd` przekierowuje
  go w `before_all()`/przywraca w `after_all()`, żaden inny plik nie odwoływał się do
  `SettingsStore.SAVE_PATH` z zewnątrz (sprawdzone grepem), więc zmiana `const`→`var`
  jest bezpieczna wstecznie.
- **`tests/save/test_input_rebind.gd`** (nowy, 7 testów) — domyślna etykieta klawisza
  zgadza się z `project.godot`, rebind faktycznie zmienia `InputMap` (nie tylko
  wewnętrzny stan `SettingsStore`), odrzucenie nieznanej akcji, reset pojedynczej akcji,
  **kolizja dwóch akcji o ten sam klawisz faktycznie czyści tamtą** (główna teza tej
  funkcji), reset wszystkich naraz, i persystencja przez zapis+odczyt pliku.
  `before_each()`/`after_each()` zerują i odtwarzają `custom_keybinds`, żeby kolejność
  testów w pełnym pakiecie nigdy nie zostawiła klawiatury w stanie po-testowym.

### 13d. Walidacja

- **Gotcha #3 (powtórzony, znany z Punktu 1)**: nowa klasa `class_name KeybindMenu`
  wymagała jednego skanu edytora (`--headless --editor --quit-after 40`, ~40s), zanim
  GUT/silnik ją rozpoznały — ten sam mechanizm co `HealthComponent` w sekcji 5a.
- **GUT: pełny pakiet `tests/` (`-gdir=res://tests -ginclude_subdirs -gexit`)
  `158/158 PASS`** (294 asercje), zero warningów poza znanym, niezwiązanym
  "GUT może nie być w pełni kompatybilny z Godot 4.7.2" i "8 ObjectDB instances leaked"
  (oba widoczne też na czystym boot-checku bez żadnych zmian tej rundy — nie regresja).
- **Boot-check**: `godot --headless --quit-after 60` (main scene, `MainMenu.tscn`) czysty,
  bez `SCRIPT ERROR`/`Parse Error`. Próba dodatkowej ad-hoc weryfikacji `KeybindMenu.tscn`
  gołym `godot --headless -s` (instancjonowanie + odczyt liczby zbudowanych wierszy)
  **nie powiodła się z przyczyn narzędziowych, nie merytorycznych**: goły `-s` nie
  inicjalizuje autoloadów projektu, więc skrypt zgłosił `Identifier not found:
  SettingsStore` mimo poprawnego kodu — potwierdzone brakiem tego błędu zarówno w pełnym
  skanie edytora (który realnie ładuje autoloady), jak i w GUT. Rzeczywista liczba
  wierszy w `KeybindMenu` (11 — `SettingsStore.REBINDABLE_ACTIONS.size()`) nie została
  więc zweryfikowana wizualnie/programowo w tej rundzie, tylko wyprowadzona z kodu.
- **Nieprzetestowane wizualnie** (ta sama, powtarzana granica z całej reszty tego pliku):
  czy okno "Sterowanie" faktycznie czyta się dobrze, czy 5s auto-checkpoint + ręczny F5
  nie kolidują wizualnie (dwa toasty naraz to skrajny przypadek: auto-timer nie emituje
  toastu, tylko F5 — zaprojektowane świadomie tak, żeby auto-zapis zostawał cichy, a
  ręczny dawał potwierdzenie), i czy klawisz F5 nie koliduje z czymś systemowym w
  przeglądarce/eksporcie web (jeśli taki cel eksportu kiedyś wróci) — wymaga Twojego
  ręcznego potwierdzenia.

**Backlog sekcji 11/11b nadal otwarty** poza tymi dwoma punktami: "ulubione miejsca",
reakcje policji/reputacji, losowe wydarzenia uliczne, jednorazowe
znajdźki combat, kryjówki/skróty, umiejętności pasywne, tryb bez walki, codzienne
wyzwanie miejskie, filtr dziennika transakcji.

## 14. Dwie kolejne pozycje z backlogu + narzędzia deweloperskie (2026-09-01)

Robione równolegle do sekcji 13 (agent w tle robił rebind/quicksave), więc dwie proste
pozycje z listy plus zestaw narzędzi na wyraźną prośbę użytkownika (audyt narzędziowy
projektu — 3 tury próśb, patrz commit).

### 14a. Plotki miejskie — ZROBIONE

`scripts/gameplay/ambient/AmbientPedestrian.gd` + `.tscn` — nowy `GossipLabel` (dymek nad
głową), 35% szans na wyświetlenie jednej z 6 losowych, luźnych linijek przy każdym wejściu
w stan IDLE, fade in/out przez `create_tween()`. Celowo bez logiki warunkowej (reputacja/
pora dnia) — czysty flavor, nie system informacyjny. `tests/unit/test_ambient_pedestrian.gd`
+2 testy (9 łącznie).

### 14b. Pogoda niezależna od cyklu dobowego — ZROBIONE

Nowy `scripts/presentation/atmosphere/WeatherOverlay.gd` + `scenes/ui/WeatherOverlay.tscn`
— świadomie OSOBNA maszyna stanów od `DayNightOverlay.gd` (deszcz może trafić się w
południe, ta druga zależy wyłącznie od `TimeManager`). CLEAR/RAIN/FOG, losowy cykl 45-150s
na stan, przejścia tweenowane (4s), `ColorRect` tint + `GPUParticles2D` na krople. Wpięte
jako dziecko `HUD.tscn` obok `DayNightOverlay` (`layer=9`). `tests/unit/test_weather_overlay.gd`
(nowy, 7 testów).

### 14c. Narzędzia deweloperskie — ZROBIONE

- **`scripts/run_godot_tests.sh` / `.ps1`** (nowe, root repo) — jeden ustandaryzowany
  headless GUT runner (`GODOT_BIN=<ścieżka> ./scripts/run_godot_tests.sh [res://plik.gd ...]`)
  zamiast każda sesja składająca komendę Godota z pamięci. Udokumentowane w `AGENTS.md`
  (nowa sekcja "Godot headless test runner (GUT)"). To jedyny z narzędziowych dodatków tej
  rundy, który odpowiada na realny, powtórzony ból (kolizja dwóch agentów o edytor Godota
  w tej samej sesji) — reszta poniżej została świadomie **wycofana**.
- **`.editorconfig`** (nowy, root) — sekcja `[*.gd]` (tab, rozmiar 4), `[*.{tscn,tres,godot,import}]`,
  reszta projektu. Jednorazowy plik, zero utrzymania — zostaje.
- **`.gitignore`** — dodane `godot/**/*.tmp`. Sprawdzone: `.gd.uid` pliki NIE są ignorowane
  (potwierdzone `git check-ignore`), trafią do repo przy najbliższym commicie.
- **Walidacja**: pełny pakiet GUT **165/165 PASS** (303 asercje) po dodaniu 14a/14b, uruchomiony
  właśnie przez nowy `scripts/run_godot_tests.sh` (samo-weryfikujące — pierwszy realny użytkownik
  własnego narzędzia).

### 14d. Cofnięte tego samego dnia — overengineering na solo-dev projekcie we wczesnej fazie

Po dodaniu, użytkownik ocenił trafnie: to były rozwiązania na problemy, których projekt
jeszcze nie ma, w fazie gdzie sam zakres płynnie się zmienia tydzień w tydzień (pivot
combat/RPG w tym samym pliku jest tego dowodem). **Wycofane w tej samej rundzie:**

- **`.github/workflows/godot-tests.yml`** — usunięty. CI ma sens przy współpracownikach/PR-ach
  do review; solo-dev i tak odpala testy lokalnie przez `run_godot_tests.sh`.
- **`.husky/pre-commit` + `husky` jako devDependency** — usunięte (`npm uninstall husky`,
  `.husky/` skasowane, `prepare` script wyjęty z `package.json`). `gdformat` i tak nie jest
  zainstalowany lokalnie, więc hook był martwy z założenia.

**Świadomie NIE zrobione i NIE zaplanowane** (odrzucone jako przedwczesne, nie "do zrobienia
kiedyś" — wracać do tego tylko gdy pojawi się potwierdzony ból, nie prewencyjnie):

- Git worktree per agent / plik-blokada na `.tscn` — rozwiązywałoby jednorazową kolizję z tej
  sesji, która sama się rozwiązała, gdy tło-agent skończył.
- Wymuszone statyczne typowanie jako spisana reguła, docstringi na każdej metodzie autoloadów —
  koszt dyscypliny na każdy commit w projekcie o wciąż płynnej architekturze; ma sens dopiero
  gdy architektura się ustabilizuje.
- Split `rpg.md` na wiele plików — dopiero gdy realnie zacznie przeszkadzać (np. sesja zacznie
  gubić kontekst czytając go), nie prewencyjnie przy 1300 linii.
- Profiler baseline, audyt presetów importu assetów — realne, ale przedwczesne bez sygnału
  (spadku FPS / rozdętych rozmiarów paczki); podjąć dopiero gdy się pojawi.
- Synchronizacja `MIGRATION_MATRIX.md` / oznaczenie starych `.md` jako SUPERSEDED — jedyna
  pozycja z tej listy, która nie jest overengineeringiem (to zaległość dokumentacyjna
  zanotowana już w sekcji 12), ale nieprzypisana do żadnej rundy — czysto porządkowa, robić
  przy okazji, nie na osobnym branchu.

## 15. Losowe wydarzenia uliczne — ZROBIONE (2026-09-01)

Kolejna pozycja z otwartego backlogu, zrobiona równolegle do agenta w tle (filtr dziennika
transakcji + ulubione miejsca) — celowo dobrana tak, żeby nie dotykać żadnego pliku w jego
zakresie (`ProgressStore.gd`, UI menu, `InteractionDetector.gd`).

- **`scripts/gameplay/ambient/StreetEventSpawner.gd`** (nowy) — samodzielny `Node` (nie
  autoload — reguła "autoloady używane oszczędnie" z `god/godot2.md`), losowy timer
  60-180s, przy odpaleniu emituje jedną z 5 luźnych linijek flavor-tekstu przez istniejący
  `EventBus.toast_requested` (użycie tylko do odczytu, `EventBus.gd` nietknięty). Ten sam
  status co `VendingMachine.gd` przed swoją integracją — **nie wpięty jeszcze** w żadną
  scenę poziomu/`LevelBuilder`'s `kind`-switch, gotowy komponent do ręcznego postawienia.
- **`tests/unit/test_street_event_spawner.gd`** (nowy, 4 testy, `watch_signals(EventBus)`
  ten sam wzorzec co reszta testów sygnałowych w tym repo).
- **Walidacja**: nowy plik przepuszczony przez `scripts/run_godot_tests.sh` osobno (4/4
  PASS) — pełny pakiet nie przegoniony w tej samej chwili, bo agent w tle mógł mieć wtedy
  otwarty własny proces edytora; do przegonienia razem z jego zmianami po zakończeniu.

## 16. Dwie kolejne pozycje z backlogu sekcji 11/11b (2026-09-02): filtr dziennika transakcji + ulubione miejsca

Branch `feature/rpg-enemy` (kontynuacja bez zmiany gałęzi). Dwie konkretne pozycje z
otwartego backlogu ("Ulubione miejsca", "Filtr/sortowanie w dzienniku transakcji" z
sekcji 11b). W przeciwieństwie do 11e (dane-only, świadomie bez UI), obie pozycje
dostały tym razem realny ekran — backlog był już gotowy pod UI (transaction_history z
11e), a "ulubione miejsca" bez żadnego widoku nie miałoby żadnego sensownego "quick
reference".

### 15a. Filtr dziennika transakcji — ZROBIONE

Nowy ekran `scenes/menu/TransactionJournal.tscn` + `scripts/presentation/menu/
TransactionJournalMenu.gd`, dostępny z `SettingsMenu.tscn` (nowy przycisk "Dziennik
transakcji"). Czyta `ProgressStore.transaction_history` (sekcja 11e) — sprawdzone w
kodzie: format zna TYLKO dwa typy, `"earn"`/`"spend"` (nie ma osobnych podtypów zakup/
uzupełnienie energii/nagroda za quest — `VendingMachine.gd` i `ProgressStore.add_money()`
oba piszą przez te same dwa typy), więc filtr oferuje dokładnie to, co realnie istnieje w
danych: Wszystkie / Przychody / Wydatki (`OptionButton`), zamiast wymyślać podtypy, których
zapis nie rozróżnia. Lista renderowana od najnowszego wpisu (dane trzymane najstarszy-
pierwszy, ekran odwraca kolejność), format wiersza `"Dzień D, GG:MM — +/-kwota zł"`.
Pusta historia pokazuje `EmptyLabel` zamiast pustej listy.

### 15b. Ulubione miejsca — ZROBIONE (mniejsza, dobrze przycięta wersja)

Sprawdzone przed projektowaniem (zgodnie z instrukcją "nie zgaduj modelu danych"): w tym
repo NIE ma systemu szybkiej podróży do dowolnej pozycji — `TransitStation`/`TransitMenu`
(sekcja 6) przenosi tylko między autorsko zdefiniowanymi `TransitDestination` (zmiana
poziomu), nie do zapamiętanego punktu. Zgodnie z instrukcją wybrana została mniejsza,
dobrze przycięta wersja: zakładka znanych interaktywnych obiektów (automaty, questowi
NPC), nie nowy system podróży.

- **`ProgressStore.favorite_places: Array[Dictionary]`** — nowe pole, wpisy
  `{"level_id", "obj_id", "label"}`, trwałe (zapis/odczyt/reset), NIE ucięte (ograniczona
  liczba umieszczonych na sztywno interaktywnych obiektów na 6 poziomach, w
  przeciwieństwie do nieograniczonego strumienia transakcji). Nowe metody:
  `is_favorite()`, `toggle_favorite()` (zwraca nowy stan bool), `get_favorites()`.
- **Duck-typing zamiast wspólnego interfejsu** — dokładnie ten sam wzorzec co
  `interact()`: obiekt jest "favoritable", gdy ma metodę `get_favorite_label()` ORAZ
  niepusty `obj_id`. Dodane do `NpcActor.gd` (label = `npc_id`, jedyna czytelna nazwa,
  jaką ten skrypt niesie) i `VendingMachine.gd` (label = istniejące `item_label`, np.
  "🥤 Cola"; `VendingMachine` dostał też nowy, opcjonalny `@export var obj_id: String = ""`
  — puste = "nie da się zafavorite'ować", żaden istniejący plac dev-scenowy się nie psuje).
  `ItemPickup` świadomie pominięty — `queue_free()`uje się po zebraniu, favorite na
  znikającym obiekcie nie ma sensu.
- **Nowa akcja wejścia `"favorite"`** (klawisz F, `project.godot` [input], dodana też do
  `SettingsStore.REBINDABLE_ACTIONS`/`DEFAULT_KEYBINDS` i `KeybindMenu._ACTION_LABELS` —
  tak jak każda inna akcja w tym repo, w pełni rebindowalna z tego samego menu). Obsłużona
  w `InteractionDetector._unhandled_input()` (nowa gałąź obok istniejącej `"interact"`) —
  BEZ buforowania jak `interact` (favorite to nie akcja na czas reakcji).
- **Nowy sygnał `EventBus.favorite_toggle_requested(obj_id, label)`** — `InteractionDetector`
  nie zna `level.id` (nie ma do niego dostępu), więc emituje przez bus zamiast wołać
  `ProgressStore` bezpośrednio; `LevelRuntime._on_favorite_toggle_requested()` (jedyne
  miejsce, które zna `level.id`, ten sam powód co `record_item_collected()`/
  `record_talked()` też przechodzą przez `LevelRuntime`) woła `ProgressStore.toggle_favorite()`
  i pokazuje toast ("⭐ Dodano do ulubionych: X" / "Usunięto z ulubionych: X").
- **Ekran** `scenes/menu/FavoritePlaces.tscn` + `scripts/presentation/menu/
  FavoritePlacesMenu.gd`, dostępny z `SettingsMenu.tscn` (nowy przycisk "Ulubione
  miejsca") — czysto referencyjna lista ("⭐ Label — Poziom X"), bez teleportacji (patrz
  wyżej: nie ma do czego teleportować). Pusta lista pokazuje `EmptyLabel` z podpowiedzią
  klawisza.

### 15c. Gotcha z tej rundy

Pierwsza wersja edycji `VendingMachine.gd` (dodanie `get_favorite_label()`) trafiła
`old_string`/`new_string` na fragment `interact()`, który miał więcej linii niż widoczny
fragment (branch `if/else` z `item_purchased`/toast) — edycja rozerwała funkcję na pół,
`SCRIPT ERROR: Parse Error` na linii 82, które w konsekwencji ubijało **cały** GUT run
(GDScript nie umie sparsować pliku → `test_vending_machine.gd` i każdy plik odwołujący
się do klasy `VendingMachine` też się wysypywał z "Could not resolve class"). Naprawione
przeczytaniem pełnej funkcji przed edycją, nie tylko dopasowanego fragmentu — ten sam
"nie zgaduj, przeczytaj cały plik" nawyk z reszty projektu.

Drugi gotcha: dwa nowe pliki testowe UI (`test_transaction_journal_menu.gd`,
`test_favorite_places_menu.gd`) zostały po pierwszym uruchomieniu **po cichu pominięte**
przez GUT (`Ignoring script ... because it does not extend GutTest`) — nie dlatego, że
faktycznie nie rozszerzają `GutTest` (rozszerzają), tylko dlatego, że w tamtym przebiegu
`TransactionJournalMenu`/`FavoritePlacesMenu` jeszcze nie były zarejestrowane w cache'u
klas edytora (poprzedni headless-scan padł na powyższym parse errorze w
`VendingMachine.gd`, więc nowe `class_name`-y nigdy nie doleciały do cache'u). Drugi
`godot --headless --quit-after 2` PO naprawie `VendingMachine.gd` rozwiązał to w pełni —
dokładnie ten sam, już udokumentowany w tym pliku gotcha ("po dodaniu class_name'd .gd,
przegoń headless scan przed GUT"), tylko że tym razem maskowany przez niepowiązany parse
error zamiast brakującego skanu.

### 15d. Walidacja

- **GUT: 189 testów, 187 PASS, 2 FAIL na moment zgłoszenia przez agenta** (przed zmianami tej
  rundy: 165/165 — patrz sekcja 14c). `test_gameplay.gd` ("state machine settles in IDLE when
  stationary") jest PRZEDISTNIEJĄCY i niezwiązany z tą rundą (`PlayerStateMachine.gd` miał już
  niezacommitowane zmiany od wcześniejszej sesji). **Sprostowanie**: `test_police_reaction_system.gd`
  NIE był przedistniejący — to własny, równoległy test tej samej sesji (sekcja 15 wyżej,
  `PoliceReactionSystem.gd`), pisany w tym samym czasie co agentowa runda, i faktycznie
  łapał realny błąd off-by-one w kolejności progów reputacji (`-15` trafiał od razu w
  drugi, poważniejszy próg zamiast w pierwszy). Naprawiony tego samego dnia (`THRESHOLDS`
  uporządkowane wg surowości, nie liczbowo) — **pełny pakiet po naprawie: 189/189 PASS**
  (347 asercji), potwierdzone przez `scripts/run_godot_tests.sh`. Nowe testy tej
  rundy: `tests/economy/test_progress_store_favorite_places.gd` (5), 3 nowe w
  `tests/player/test_interaction_detector.gd` (favorite-action), `tests/ui/
  test_transaction_journal_menu.gd` (5), `tests/ui/test_favorite_places_menu.gd` (2).
- **Boot-check**: `MainMenu.tscn`, `SettingsMenu.tscn`, `TransactionJournal.tscn`,
  `FavoritePlaces.tscn` wszystkie czyste (0 SCRIPT ERROR/Parse Error) przez
  `godot --headless --quit-after 2`.
- **Bez wizualnej weryfikacji** — jak większość tej sesji (ograniczenie z sekcji 11d wciąż
  aktywne), oba ekrany zweryfikowane wyłącznie przez GUT + czyste headless boot, nie
  ręcznym playtestem. Panel `SettingsMenu` powiększony (`offset_top/bottom` z ±140 na
  ±190) pod dwa nowe przyciski — nieprzetestowane wizualnie, czy mieści się bez
  przycinania na wszystkich rozdzielczościach.

## 17. Reakcje policji/reputacji — ZROBIONE (2026-09-01)

Kolejna pozycja z backlogu, zrobiona równolegle do agenta w tle w tej samej sesji co sekcja
15 (stąd wcześniej wzmiankowana tylko w sprostowaniu w 15d, bez własnej sekcji — brakująca
wpis naprawiony teraz, zgodnie z zasadą "jedna runda = jeden wpis w rpg.md").

- **`scripts/gameplay/world/PoliceReactionSystem.gd`** (nowy) — samodzielny `Node`
  (`class_name PoliceReactionSystem`), opcjonalny `@export var zone_id: String` do
  filtrowania po strefie. Subskrybuje `EventBus.reputation_changed`, przy przekroczeniu
  progu emituje ostrzeżenie przez `EventBus.toast_requested` — tylko raz na poziom, nie
  powtarza się dopóki reputacja nie spadnie do kolejnego, poważniejszego progu.
  `THRESHOLDS := [-15, -30]` — kolejność wg surowości progu **przekraczanego jako
  pierwszy** w miarę spadku reputacji, NIE liczbowo rosnąco (-15 > -30 liczbowo, ale
  trafia pierwszy).
- **`tests/unit/test_police_reaction_system.gd`** (nowy, 5 testów): brak ostrzeżenia
  powyżej pierwszego progu, ostrzeżenie raz przy przekroczeniu pierwszego progu, brak
  powtórki na tym samym poziomie, kolejne ostrzeżenie przy przekroczeniu wyższego progu,
  ignorowanie zmian w innych strefach.
- **Błąd znaleziony i naprawiony w tej samej rundzie**: pierwotnie `THRESHOLDS := [-30,
  -15]` (liczbowo rosnąco) — wartość `-15` spełniała od razu WARUNEK obu progów
  (`-15 <= -15`), więc trafiał w indeks 1 (poważniejszy poziom) zamiast w indeks 0
  (łagodniejszy pierwszy poziom). Złapane przez `test_warns_once_crossing_first_threshold`
  (4/5 przy pierwszym uruchomieniu). Naprawione przez zmianę kolejności na `[-15, -30]` +
  przepisanie komentarza wyjaśniającego (oryginalny "Ordered low→high" był mylący/błędny).
- **Walidacja**: po naprawie pełny pakiet — **189/189 PASS, 347 asercji** —
  `scripts/run_godot_tests.sh` (ten sam przebieg, który potwierdza całą rundę sekcji 15/16,
  patrz 15d). Cache class_name odświeżony headless scanem przed uruchomieniem testów.
- **Nie wpięty jeszcze** w żaden konkretny poziom/scenę — komponent gotowy, ale wymaga
  ręcznego postawienia `PoliceReactionSystem` w drzewie sceny poziomu (analogicznie do
  `StreetEventSpawner.gd` z sekcji 15) i emisji `reputation_changed` z realnego systemu
  reputacji gracza (obecnie emitowany tylko przez testy).
- **Bez wizualnej weryfikacji** — jak reszta tej sesji, logika potwierdzona tylko przez GUT.

## 18. Jednorazowe znajdźki combat — ZROBIONE (2026-09-01)

Kolejna pozycja z backlogu ("Bronie/przedmioty jednorazowe ze świata — tymczasowy bonus do
ataku, lekki system bez pełnego ekwipunku" — sekcja "Rozbudowa combat/eksploracji").
Zaprojektowane jako rozszerzenie istniejącego, już modularnego `StatusEffectComponent.gd`
zamiast nowego równoległego systemu buffów.

- **`scripts/gameplay/player/StatusEffectComponent.gd`** — dodany `EffectType.ATTACK_BOOST`
  (`ATTACK_BOOST_MULTIPLIER = 2.0`) i pole `attack_damage_multiplier`, resetowane w
  `_clear_current()`/`_on_expired()` tak samo jak `speed_multiplier`/`paralyzed`. Nadal
  tylko jeden aktywny efekt naraz (bez stackowania) — nieskomicowana zasada modułu
  nietknięta.
- **`scripts/gameplay/player/PlayerHitbox.gd`** — `apply_hits()` czyta
  `StatusEffects.attack_damage_multiplier` (sibling node przez `get_node_or_null("../StatusEffects")`)
  i skaluje `attack_damage` przed `take_damage()`.
- **`scripts/gameplay/items/CombatPickup.gd`** (nowy) + `scenes/interactables/CombatPickup.tscn`
  — samodzielny, jednorazowy `Area2D` (ten sam overlap-triggered, one-shot kształt co
  `ItemPickup.gd`), świadomie NIE podpięty pod `ItemData`/`Inventory`/`ProgressStore` — to
  przejściowy combat-buff, nie trwały kolekcjonerski przedmiot, więc żadna maszyneria
  save/load ani chipów w HUD-zie nie ma zastosowania. Przy overlapie z graczem: aplikuje
  `ATTACK_BOOST` na 20s, gra `AudioService.play_pickup()`, emituje
  `EventBus.toast_requested`, `queue_free()`.
- **Testy** (8 nowych, `tests/combat/`): `test_status_effect_component.gd` (4, pierwszy
  bezpośredni test tego komponentu — wcześniej testowany tylko pośrednio przez
  `PlayerMovement`), `test_combat_pickup.gd` (3), plus jeden test end-to-end w
  `test_combat.gd` (`test_player_attack_with_attack_boost_deals_doubled_damage` — realny
  `Player.tscn`/`EnemyActor.tscn`, Input → PlayerAttack → PlayerHitbox → HealthComponent,
  potwierdza 3×2=6 obrażeń zamiast 3).
- **Walidacja**: `gdscript-toolkit:gdscript-format --verify-structure` na wszystkich
  zmienionych/nowych plikach, headless cache-refresh (nowy `class_name CombatPickup`) przed
  testami, pełny pakiet — **197/197 PASS, 360 asercji** (`scripts/run_godot_tests.sh`,
  poprzednio 189/189 — 8 nowych testów dokładnie zgadza się z liczbą dodanych).
  Nieszkodliwy segfault Godota **po** wypisaniu "All tests passed!" (znany, powtarzający
  się przy zamykaniu procesu headless GUT — nie wpływa na wynik).
- **Nie wpięte jeszcze** w żaden poziom — `CombatPickup.tscn` gotowy do ręcznego
  postawienia w scenie, analogicznie do wcześniejszych gotowych-ale-niepodłączonych
  komponentów tej sesji (`StreetEventSpawner`, `PoliceReactionSystem`).
- **Bez wizualnej weryfikacji** — jak reszta tej sesji.

## 19. Kryjówki/skróty odblokowywane po pokonaniu wroga lub zapłacie — ZROBIONE (2026-09-01)

Kolejna pozycja z backlogu ("Kryjówki/skróty odblokowywane po pokonaniu wroga lub
zapłacie"). Znaleziona jako uncommitted work na starcie tej rundy (`ProgressStore.gd`
zmodyfikowany, `ShortcutGate.gd`/`.tscn` i oba pliki testowe już napisane) — ta sekcja
domyka pracę: uruchamia format → cache-refresh → pełny pakiet testów i notuje wynik,
zgodnie z zasadą "jedna runda = jeden wpis w rpg.md" z tego pliku.

- **`ProgressStore.unlocked_shortcuts: Array[String]`** — nowe trwałe pole (zapis/odczyt/
  reset, ten sam wzorzec co `unlocked_levels`/`favorite_places`), plus
  `is_shortcut_unlocked()`/`unlock_shortcut()`. Brama raz odblokowana zostaje odblokowana
  na zawsze — brak ścieżki ponownego zablokowania.
- **`scripts/gameplay/world/ShortcutGate.gd`** (nowy, `class_name ShortcutGate`) +
  `scenes/interactables/ShortcutGate.tscn` — duck-typed `interact(player)`, ten sam wzorzec
  co `VendingMachine`/`NpcActor`/`TransitStation`, `InteractionDetector.gd` nietknięty. Dwie
  niezależne ścieżki odblokowania (OR, nie AND): zapłata `unlock_cost` przez
  `ProgressStore.spend_money()`, lub wcześniejsza śmierć `required_enemy_id` (nasłuch
  `EventBus.enemy_died`) — pusty `required_enemy_id` oznacza "tylko za pieniądze". Fizyczne
  blokowanie przejścia to osobny `StaticBody2D` (`Blocker`, warstwa World wg
  `COLLISION_MATRIX.md`), nie samo `Area2D` — po odblokowaniu tylko wyłącza
  `CollisionShape2D` bramy, sam węzeł zostaje w drzewie (identity/`obj_id` zachowane, bez
  `queue_free()`) jako trwały element poziomu, zgodnie z konwencją "permanent progress"
  reszty `ProgressStore`.
- **Testy**: `tests/economy/test_progress_store_shortcuts.gd` (5 — locked na starcie,
  unlock oznacza jako odblokowane, podwójny unlock bez duplikatu, reset relockuje, unlocks
  przeżywają save/load) + `tests/world/test_shortcut_gate.gd` (7 — blokuje przejście gdy
  zablokowana, brak pieniędzy nic nie robi + toast, wystarczające pieniądze odblokowuje i
  wyłącza blocker, pokonanie wymaganego wroga odblokowuje za darmo bez wydawania pieniędzy,
  śmierć niepowiązanego wroga nie odblokowuje, już-odblokowana brama startuje otwarta po
  `_ready()`, interakcja z już-odblokowaną bramą to no-op bez ponownego obciążenia).
- **Walidacja**: `gdscript-toolkit:gdscript-format --verify-structure` na wszystkich 4
  plikach (już sformatowane, bez zmian), headless cache-refresh (nowy `class_name
  ShortcutGate`) przed testami, pełny pakiet — **209/209 PASS, 376 asercji**
  (`scripts/run_godot_tests.sh`, poprzednio 197/197 — 12 nowych testów dokładnie zgadza
  się z liczbą dodanych). Boot-check (`godot --headless --quit-after 2`) czysty — 0 SCRIPT
  ERROR/Parse Error.
- **Nie wpięta jeszcze** w żaden poziom — `ShortcutGate.tscn` gotowa do ręcznego
  postawienia w scenie, ten sam status co `CombatPickup`/`StreetEventSpawner`/
  `PoliceReactionSystem` z poprzednich rund tej sesji.
- **Bez wizualnej weryfikacji** — jak reszta tej sesji, ale runtime boot-check zrobiony
  przez `godot-mcp` (`run_project`/`get_debug_output`) zamiast tylko headless
  `--quit-after` — czysty log, jedyne ostrzeżenie to przedistniejące i niezwiązane
  (`SettingsStore.gd:111`, enum-cast warning).
- **Code review** (`godot-code-reviewer` subagent, `godot-code-review` skill) po
  domknięciu rundy: dwa realne, ale niekrytyczne findingi naprawione od razu — węzły
  `$IconLabel`/`$DebugVisual`/`$Blocker/CollisionShape2D` przepisane na `@onready var`
  zamiast powtarzanego lookupu po ścieżce, i dodany `push_warning()` w `_ready()` gdy
  `gate_id` jest puste (kolizja unlock-state dwóch źle skonfigurowanych bram). Trzeci
  finding (brak jawnego `disconnect()` od `EventBus.enemy_died` w `_exit_tree()`) uznany
  za nieszkodliwy — Godot automatycznie zrywa połączenia węzła-odbiorcy przy `free()` —
  świadomie pominięty. Po poprawkach: format-clean, pełny pakiet ponownie **209/209
  PASS, 376 asercji**.

## 20. Umiejętności pasywne (Umiejętności... zamiast pełnego drzewka) — ZROBIONE (2026-09-02)

Kolejna pozycja z otwartego backlogu sekcji 11 ("'Umiejętności' jako pasywne bonusy za
pieniądze/reputację ... zamiast pełnego drzewka"). Zbadano najpierw stan pozostałych
pozycji z tej samej listy backlogu ("Toast przy niskiej energii/pieniądzach",
"Podsumowanie dnia", "Osiągnięcia/statystyki życiowe", "Kompas questa") — okazały się już
w pełni zrobione i udokumentowane wcześniej (sekcje 11d/11e), tylko zweryfikowane
ponownie (218/218 PASS przed tą rundą, bez zmian kodu) zamiast reimplementowane.

- **`ProgressStore.PASSIVE_SKILLS`** (nowy `const Dictionary`) — jedno źródło prawdy
  id/koszt/etykieta dla dwóch płaskich, jednorazowych zakupów (bez drzewka/poziomów/
  prerekwizytów): `cheaper_shopping` (-10% w automatach) i `faster_energy_regen`
  (+25% regeneracji energii), oba po 50 zł. Sam *efekt* każdej umiejętności żyje w
  miejscu użycia (`VendingMachine.gd`/`LevelRuntime.gd`), nie w `ProgressStore` — ten
  sam podział odpowiedzialności co `unlocked_shortcuts` (flaga tu, efekt u konsumenta).
- **`ProgressStore.purchased_skills: Array[String]`** — trwałe pole (zapis/odczyt/reset),
  `is_skill_purchased()`/`purchase_skill()` (zwraca `false` bez obciążenia przy
  nieznanym id, już posiadanej umiejętności lub niewystarczających środkach — reużywa
  `spend_money()`).
- **`VendingMachine.interact()`** — rabat -10% doliczany po rabacie promocyjnym (mnoży
  się z nim, nie zastępuje), przy `is_skill_purchased("cheaper_shopping")`.
- **`LevelRuntime._update_energy()`** — `rest_recover_mul *= 1.25` przy
  `is_skill_purchased("faster_energy_regen")`, na wierzchu mnożnika trudności (gracz
  "hard" z umiejętnością wciąż regeneruje wolniej niż "easy" bez niej — bonus, nie
  nadpisanie trudności).
- **Testy**: `tests/economy/test_progress_store_passive_skills.gd` (7 — start
  nieposiadana, udany zakup, zakup bez środków, podwójny zakup bez podwójnego
  obciążenia, nieznane id, reset relockuje, przetrwanie save/load) +
  `test_vending_machine.gd` (+1, rabat umiejętności na cenie skalowanej trudnością) +
  `test_low_energy_toast.gd` (+1, porównanie tempa regeneracji z realnym `Player.tscn`
  jako stopped/non-sprinting graczem — `velocity`/`is_sprinting` to prawdziwe pola
  `PlayerMovement.gd`, nie duck-type'owalne na stubie).
- **Gotcha złapany przez format→cache-refresh→test**: pierwsza wersja nowego testu
  regeneracji użyła `var without_skill := _level._energy` — `_level` jest celowo
  nietypowane (`var _level`, patrz komentarz w pliku), więc `:=` nie potrafił
  wywnioskować typu z `Variant` i całość kończyła się `SCRIPT ERROR: Parse Error`
  (widoczne dopiero w pełnym przebiegu GUT, 213/218 zamiast oczekiwanych 218 — plik z
  błędem parsowania GUT po cichu pomija, ten sam wzorzec co gotcha z sekcji 15c/16).
  Naprawione jawnym typem (`var without_skill: float = ...`).
- **Walidacja**: `gdscript-toolkit:gdscript-format --verify-structure`, headless
  cache-refresh, pełny pakiet — **218/218 PASS, 392 asercje** (poprzednio 209/209 — 9
  nowych testów dokładnie zgadza się z liczbą dodanych). Boot-check czysty.
- **Nie wpięte w UI** — świadomie data-only, ten sam wybór co sekcja 11e (dziennik
  transakcji dostał ekran później, w osobnej rundzie — sekcja 16 — gdy backlog był już
  gotowy pod UI; umiejętności czekają na tę samą decyzję).
- **Bez wizualnej weryfikacji** — jak reszta tej sesji.

## 21. Tryb "szybkiego dnia" (RestSpot) — ZROBIONE (2026-09-02)

Kolejna pozycja z otwartego backlogu sekcji 11b ("Tryb 'szybkiego dnia' — przyspieszenie
czasu w bezpiecznym miejscu zamiast biernego czekania"). Zbudowana na dwóch już
istniejących mechanizmach zamiast nowego systemu skoku czasu: `TimeManager.
advance_minutes()` (dotąd używane tylko przez `TransitStation` do fast-travel) i
`EventBus.energy_restore_requested` (dotąd tylko `VendingMachine`).

- **`scripts/gameplay/world/RestSpot.gd`** (nowy, `class_name RestSpot`) +
  `scenes/interactables/RestSpot.tscn` — placeable interactable (ławka/kryjówka),
  duck-typed `interact(player)` jak `VendingMachine`/`ShortcutGate`. Skacze zegar o
  `hours_to_advance` (domyślnie 4h) i w pełni odnawia energię
  (`Difficulty.MAX_ENERGY`). Świadomie **bez cooldownu/limitu dziennego** — zegar
  porusza się tylko w jedną stronę, więc nie ma sposobu na nadużycie poza pomijaniem
  czasu, który gracz i tak spędziłby bezczynnie ("prosty system" z treści backlogu).
  Duck-typed `get_favorite_label()` (jak `VendingMachine`) — od razu favoritable.
- **Testy**: `tests/world/test_rest_spot.gd` (5 — zegar przesuwa się o właściwą liczbę
  godzin, żąda pełnego odnowienia energii, emituje toast, można użyć wielokrotnie pod
  rząd, stabilna etykieta ulubionego).
- **Walidacja**: `gdscript-toolkit:gdscript-format --verify-structure`, headless
  cache-refresh (nowy `class_name RestSpot`), pełny pakiet — **223/223 PASS, 397
  asercji** (poprzednio 218/218 — 5 nowych testów dokładnie zgadza się z liczbą
  dodanych). Boot-check czysty.
- **Nie wpięte jeszcze** w żaden poziom — `RestSpot.tscn` gotowa do ręcznego
  postawienia w scenie, ten sam status co pozostałe gotowe-ale-niepodłączone
  komponenty tej sesji.
- **Bez wizualnej weryfikacji** — jak reszta tej sesji.

## 22. Losowe potyczki uliczne (zależne od pory dnia/reputacji) — ZROBIONE (2026-09-02)

Kolejna pozycja z backlogu sekcji 11 ("Rozbudowa combat/eksploracji... Losowe potyczki
uliczne (zależne od pory dnia/reputacji), nie tylko zaplanowane na poziomie"). Zbudowana
na trzech już istniejących mechanizmach zamiast nowego systemu spawnu: `EnemyRegistry.
load_all()` + `EnemyActor.tscn` (te same co `LevelBuilder._build_enemy()` używa dla
zaplanowanych wrogów), `ProgressStore.get_reputation(zone_id)` + `TimeManager.is_night()`
(te same warunki co `PoliceReactionSystem.gd` czyta), i wzorzec "standalone Node,
losowy timer" ze `StreetEventSpawner.gd`.

- **`scripts/gameplay/world/StreetAmbushSpawner.gd`** (nowy, `class_name
  StreetAmbushSpawner`) — losowy timer (90-240s), przy odpaleniu sprawdza
  `_can_ambush()`: tylko w nocy (`TimeManager.is_night()`) I przy reputacji w danej
  strefie `<= -15` (ten sam pierwszy, najłagodniejszy próg co
  `PoliceReactionSystem.THRESHOLDS[0]` — reużyty jako "wystarczająco niebezpiecznie na
  potyczki uliczne", nie nowa liczba wymyślona od zera). Spawnuje jednego losowego
  wroga z `enemy_ids` (domyślnie thug/bandit) w stałej odległości (`SPAWN_DISTANCE =
  220px`) od gracza pod losowym kątem, emituje ostrzegawczy toast ("Ktoś rusza w twoją
  stronę z cienia!").
- **Jedna aktywna potyczka naraz** — kolejny roll podczas gdy `_active_enemy` wciąż
  żyje jest pomijany zamiast kolejkowany/stackowany (świadome ograniczenie: rzadkie,
  pojedyncze ryzyko za wędrowanie po złej dzielnicy nocą, nie zalew wrogów).
  `_active_enemy` czyszczone przez `tree_exited` (po zakończeniu animacji śmierci i
  realnym `queue_free()`), nie przez sygnał `died` z `HealthComponent` — ten sam powód
  co `GraffitiSpawner`/`_health.died` już dokumentują w `EnemyActor.gd` (animacja
  śmierci gra jeszcze chwilę po `died`).
- **Testy**: `tests/world/test_street_ambush_spawner.gd` (6 — brak potyczki w dzień
  mimo złej reputacji, brak potyczki nocą przy dobrej reputacji, potyczka nocą przy złej
  reputacji, spawn dodaje jednego wroga w prawidłowej odległości od gracza, druga
  potyczka niemożliwa dopóki poprzedni wróg żyje, spawn emituje ostrzegawczy toast).
- **Gotcha złapany podczas pisania testu**: pierwsza wersja `test_spawn_ambush_adds_
  one_enemy_near_the_player` sprawdzała odległość PO `await wait_physics_frames(1)` —
  własna `EnemyStateMachine` świeżo zespawnowanego wroga zaczyna gonić gracza
  natychmiast, więc dystans zdążył się już zmienić o ~10px w jedną klatkę fizyki
  (210.6 zamiast 220 ±1.0). Naprawione sprawdzeniem dystansu od razu po
  `_spawn_ambush()`, przed jakąkolwiek klatką fizyki.
- **Walidacja**: `gdscript-toolkit:gdscript-format --verify-structure`, headless
  cache-refresh (nowy `class_name StreetAmbushSpawner`), pełny pakiet — **229/229 PASS,
  404 asercje** (poprzednio 223/223 — 6 nowych testów dokładnie zgadza się z liczbą
  dodanych). Boot-check czysty.
- **Nie wpięty jeszcze** w żaden poziom — gotowy komponent do ręcznego postawienia w
  scenie poziomu, ten sam status co `PoliceReactionSystem`/`StreetEventSpawner`.
- **Bez wizualnej weryfikacji** — jak reszta tej sesji; w szczególności balans (jak
  często/jak trudny wróg) nie był rozgrywany ręcznie.

## 23. Ekran statystyk życiowych (StatsMenu) — ZROBIONE (2026-09-02)

Dane (`ProgressStore.total_enemies_defeated`/`total_money_earned`/`total_days_survived`)
istniały od sekcji 11e, świadomie bez ekranu ("data-only"). Ten sam schemat co
`TransactionJournal`/`FavoritePlaces` dostały w sekcji 16 — backlog był gotowy pod UI,
dołożenie ekranu.

- **`scripts/presentation/menu/StatsMenu.gd`** (nowy, `class_name StatsMenu`) +
  `scenes/menu/StatsMenu.tscn` — trzy statyczne etykiety, bez listy/filtra (prostsze niż
  `FavoritePlacesMenu`, bo dane to trzy liczby, nie kolekcja). Dostępny z
  `SettingsMenu.tscn` (nowy przycisk "Statystyki"), panel powiększony `±190`→`±215`, ten
  sam wzorzec powiększania co przy dodaniu poprzednich dwóch przycisków w sekcji 16.
- **Testy**: `tests/ui/test_stats_menu.gd` (2 — świeży zapis pokazuje same zera, ekran
  odzwierciedla aktualne wartości pól).
- **Walidacja**: `gdscript-toolkit:gdscript-format --verify-structure`, headless
  cache-refresh (nowy `class_name StatsMenu`), pełny pakiet — **231/231 PASS, 410
  asercji** (poprzednio 229/229 — 2 nowe testy dokładnie zgadzają się z liczbą
  dodanych). Boot-check czysty.
- **Bez wizualnej weryfikacji** — jak reszta tej sesji; czy panel mieści się bez
  przycinania na wszystkich rozdzielczościach nieprzetestowane (ten sam standing gap co
  sekcja 16 już notowała dla `SettingsMenu`).
