# Godot 4 — docelowa wersja gry (migracja z Phaser)

Status na 2026-09-01. **Kanoniczne, aktualne źródło prawdy o postępie migracji to
[`rpg.md`](../rpg.md) w repo-root** — datowany, sekcja-po-sekcji log każdej rundy pracy
(sekcje 1-17). Ten plik to tylko orientacyjny skrót "co tu jest" dla kogoś, kto otwiera
projekt pierwszy raz. `plan31-08.md` (era A tej migracji, HOP FSM/greybox) i
`docs/migration/MIGRATION_MATRIX.md` są w dużej mierze nieaktualne względem `rpg.md` —
sprawdzaj `rpg.md` jako pierwszy.

## O grze

Współczesna, dwuwymiarowa gra RPG/przygodowa osadzona w Szczecinie (Wały Chrobrego, Zamek
Książąt Pomorskich, Łasztownia i okolice) — eksploracja miasta, questy fabularne, dialogi
z NPC, prosty system ekonomii/reputacji oraz walka w czasie rzeczywistym z kilkoma typami wrogów
(bandyci, thugi, demony, "blood monster"). Gra jest **formalnie jednojęzyczna, polska**
(cała warstwa tekstowa gracza).

## Architektura (skrót)

- **Renderer**: GL Compatibility, viewport 1280×720.
- **9 autoloadów** (`project.godot`, sekcja `[autoload]`) — `ProgressStore` (zapis/wczytanie
  `user://progress.json`), `AudioService`, `SettingsStore` (`user://settings.json`,
  rebindowalne klawisze), `EventBus` (sygnałowy bus międzysystemowy, używany oszczędnie —
  patrz `god/godot2.md`), `DebugConsole`, `SceneRouter` (fade przejść), `VfxSpawner`,
  `TimeManager` (cykl dnia/nocy), `GraffitiSpawner`.
- **Gracz**: ruch/sprint/hop, atak (`PlayerAttack`/`PlayerHitbox`), state machine
  (`PlayerStateMachine` + stany w `state_machine/`), `InteractionDetector` ("Wciśnij E"),
  rebindowalne sterowanie i szybki zapis (F5).
- **Wrogowie**: `EnemyActor`/`EnemyHitbox` + własna state machine, dane per-typ jako
  `Resource` w `data/enemies/*.tres` (`EnemyRegistry.gd` jako loader), `HealthComponent`
  po obu stronach starcia, paski HP (`HealthBar`/`EnemyHealthBar`).
- **Miasto / ambient**: piesi (`AmbientPedestrian`, losowe plotki-dymki), pojazdy, pogoda
  niezależna od cyklu dnia/nocy (`WeatherOverlay` — deszcz/mgła/czyste niebo), losowe
  wydarzenia uliczne (`StreetEventSpawner`), reakcje policji na spadek reputacji gracza
  (`PoliceReactionSystem`), ekonomia (`gameplay/economy/`), transit (`gameplay/transit/`).
- **UI**: `MainMenu`, `SettingsMenu` (w tym `KeybindMenu`), `TransactionJournal`,
  `FavoritePlaces`, `HUD` (questy, inventory, toasty przez `ToastManager`), motyw budowany
  narzędziami `godot/tools/build_theme.gd`/`build_menu_theme.gd`, sterowanie mobilne
  (`presentation/mobile/`).
- **Assety**: pakiety sprite'ów/tile'ów/UI (Cute Fantasy Free, Mana Seed, Cozy UI) w
  `assets/assety/`, fonty w `assets/fonts/`.

## Testy

**GUT** (`addons/gut/`), uruchamiane headless — jedyny udokumentowany sposób:

```bash
GODOT_BIN="/path/to/Godot_v4.7.2-stable_win64.exe" ../scripts/run_godot_tests.sh          # pełny pakiet
GODOT_BIN="/path/to/Godot_v4.7.2-stable_win64.exe" ../scripts/run_godot_tests.sh res://tests/unit/test_weather_overlay.gd  # jeden plik
```

(PowerShell: `scripts/run_godot_tests.ps1`, ten sam kontrakt.) Szczegóły i znane pułapki
(np. GUT po cichu pomija nowy plik testowy `class_name`, dopóki nie odświeży się cache
edytora headless-skanem) — patrz `AGENTS.md` i `rpg.md`.

**Uwaga**: nie ma CI dla tego projektu (solo dev, brak PR-ów) — pakiet testów trzeba
uruchomić ręcznie (lub przez agenta) przed uznaniem jakiejkolwiek rundy pracy za
skończoną.

## Reguły migracji

- `src/game/phaser/` (oryginalne źródło Phaser) zostaje nietknięte, dopóki dany system nie
  jest w pełni zmigrowany, przetestowany i ręcznie playtestowany w Godot.
- Bez tłumaczenia 1:1 Phaser/TS → GDScript — każdy system projektowany od nowa w sposób
  idiomatyczny dla Godota (Node/Signal/Resource/CharacterBody2D).
- Jeden podsystem na raz, na osobnym branchu (`migration/*`), z walidacją przed przejściem
  dalej. Pełne zasady: `god/godot.md`, `god/godot2.md`.

## Standing gap

Weryfikacja wizualna (czy UI się nie nakłada, czy nowy panel mieści się na ekranie, czy
efekt faktycznie coś zmienia) jest robiona nieregularnymi, ręcznymi playtestami — GUT
łapie logikę, nie layout. Zobacz `rpg.md` dla listy elementów wciąż nieprzetestowanych
wizualnie.
