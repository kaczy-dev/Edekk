<div align="center">

# Przygody Edka

**Współczesna, dwuwymiarowa gra RPG/przygodowa w Szczecinie.**

Eksploracja miasta, questy fabularne, dialogi z NPC i walka w czasie rzeczywistym.

`Godot 4.7` · `GDScript`

</div>

---

## O grze

Akcja toczy się we współczesnym Szczecinie (Wały Chrobrego, Zamek Książąt Pomorskich,
Łasztownia i okolice). Gracz eksploruje miasto, wykonuje questy fabularne, rozmawia z NPC, korzysta z prostej
ekonomii (automaty, dziennik transakcji, ulubione miejsca) i walczy w czasie rzeczywistym
z kilkoma typami wrogów (bandyci, thugi, demony, „blood monster"). Reputacja gracza wpływa
na reakcje policji. Cykl dnia/nocy i pogoda (deszcz/mgła/czyste niebo) działają niezależnie
od siebie. Gra jest formalnie jednojęzyczna — cała warstwa tekstowa po polsku.

### Sterowanie

| | |
|---|---|
| **Ruch** | `WSAD` lub strzałki |
| **Atak** | przypisywalny klawisz (domyślne bindowanie w Ustawieniach) |
| **Interakcja** | `E` |
| **Ulubione** | `F` |
| **Szybki zapis** | `F5` |

Sterowanie jest w pełni rebindowalne z menu Ustawień. Dostępne jest też sterowanie mobilne
(wirtualny joystick + przyciski).

---

## Uruchomienie

Projekt otwiera się jako standardowy projekt **Godot 4.7** (renderer GL Compatibility,
viewport 1280×720) — wystarczy wskazać folder [`godot/`](./godot) w edytorze Godota.

### Testy

Pakiet testów **GUT** (`godot/addons/gut/`), uruchamiany headless:

```bash
GODOT_BIN="/path/to/Godot_v4.7.2-stable_win64.exe" scripts/run_godot_tests.sh          # pełny pakiet
GODOT_BIN="/path/to/Godot_v4.7.2-stable_win64.exe" scripts/run_godot_tests.sh res://tests/unit/test_weather_overlay.gd  # jeden plik
```

(PowerShell: `scripts/run_godot_tests.ps1`, ten sam kontrakt.) Brak CI (solo dev) — pakiet
uruchamiany ręcznie przed uznaniem rundy pracy za skończoną.

---

## Jak to jest zbudowane

- **9 autoloadów** (`project.godot`, sekcja `[autoload]`) — `ProgressStore` (zapis/wczytanie
  `user://progress.json`), `AudioService`, `SettingsStore` (rebindowalne klawisze),
  `EventBus` (sygnałowy bus międzysystemowy, używany oszczędnie), `DebugConsole`,
  `SceneRouter` (fade przejść), `VfxSpawner`, `TimeManager` (cykl dnia/nocy),
  `GraffitiSpawner`.
- **Gracz**: ruch/sprint, atak (`PlayerAttack`/`PlayerHitbox`), state machine, interakcje
  z otoczeniem, rebindowalne sterowanie, szybki zapis.
- **Wrogowie**: `EnemyActor`/`EnemyHitbox` z własną state machine, dane per-typ jako
  `Resource` (`data/enemies/*.tres`), paski HP.
- **Miasto**: piesi z losowymi plotkami, pojazdy, pogoda, losowe wydarzenia uliczne,
  reakcje policji na reputację, ekonomia, tranzyt.
- **UI**: menu główne, ustawienia (w tym rebindowanie klawiszy), dziennik transakcji,
  ulubione miejsca, HUD (questy, ekwipunek, toasty), sterowanie mobilne.

```
godot/
├─ scripts/       Logika gry (autoloady, gameplay, infrastruktura, UI)
├─ scenes/        Sceny .tscn (poziomy, interaktywne obiekty, menu)
├─ data/          Zasoby danych (.tres) — wrogowie, przedmioty
├─ tests/         Pakiet testów GUT
└─ assets/        Grafiki, fonty, audio
```

**Chcesz zajrzeć głębiej?** [`godot/README.md`](./godot/README.md) opisuje architekturę
projektu Godot; [`rpg.md`](./rpg.md) jest kanonicznym, datowanym logiem każdej rundy pracy —
najbardziej aktualne źródło prawdy o stanie projektu; [AGENTS.md](./AGENTS.md) opisuje
konwencje i pułapki dla agentów pracujących w tym repo.

---

## Dokumentacja

| Plik | Dla kogo |
|---|---|
| [rpg.md](./rpg.md) | Kanoniczny, datowany log postępu — sprawdzaj jako pierwsze |
| [godot/README.md](./godot/README.md) | Architektura i testy projektu Godot |
| [AGENTS.md](./AGENTS.md) | Konwencje i pułapki dla agentów |
| [CLAUDE.md](./CLAUDE.md) | Punkt wejścia dla Claude Code |
| [SKILLS.md](./SKILLS.md) | Zainstalowane skille agentowe i zarządzanie nimi |

> Historyczna wersja przeglądarkowa (React + Canvas2D/Phaser) została zastąpiona migracją
> do Godota — zobacz `rpg.md` po szczegóły procesu migracji.
