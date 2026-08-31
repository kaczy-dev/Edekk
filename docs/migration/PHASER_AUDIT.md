# PHASER_AUDIT.md — Faza 0, audyt "Przygody Edka"

> Audyt wykonany bez modyfikacji istniejącego kodu. Gra NIE jest projektem
> czysto-Phaserowym (jak zakłada `god/godot.md`) — to hybryda w trakcie
> własnej wewnętrznej migracji: silnik Canvas2D (dojrzały, produkcyjny) +
> Phaser 4.2.1 (spike jednego poziomu) + Three.js/R3F (świeży prototyp 3D,
> Faza 2+). Ten dokument opisuje wszystkie trzy warstwy.

## 1. Przegląd projektu

**Przygody Edka** — gra eksploracyjna 2D (z prototypem 3D) o kocie Edku,
6 poziomów w Szczecinie (Wały Chrobrego, Park Kasprowicza, Aleja Kasztanowa,
Strych, Ogród za blokiem, Łucznicza 43). Cała warstwa tekstowa gry — dialogi,
questy, UI — po polsku.

Stack: React 19 + TanStack Start/Router + Zustand + Tailwind v4, budowany
Vite → Nitro (Cloudflare). Trzy koegzystujące silniki renderujące gameplay:

| Silnik | Status | Gdzie |
|---|---|---|
| Canvas2D (`GameEngine`) | Produkcyjny, obsługuje wszystkie 6 poziomów | `src/game/engine.ts` + `GameCanvas.tsx` |
| Phaser 4.2.1 (`LevelScene`) | Spike — tylko Poziom 1 | `src/game/phaser/LevelScene.ts` + `PhaserGameCanvas.tsx` |
| Three.js/R3F (`World3D`) | Prototyp — capsule placeholder, geometria z `levels.ts` | `src/game/three/*` |

**Ustalone przez odczyt `poziom.$id.tsx`:** trasa `/poziom/$id` renderuje
`PhaserGameCanvas` dla WSZYSTKICH 6 poziomów (komentarz w kodzie: "All levels
now run on the Phaser engine — LevelScene.ts is built generically from
LevelDef"). **`GameEngine`/`GameCanvas` (Canvas2D) jest martwym kodem**,
świadomie zostawionym jako fallback na wypadek regresji, ale nieużywanym w
żadnej trasie. To oznacza: **Phaser `LevelScene.ts` jest jedynym źródłem
prawdy** dla zachowania gameplay 2D do zachowania w Godot — nie Canvas2D.
`/poziom3d` to oddzielny, niepodlinkowany z menu prototyp 3D+Phaser-HUD.

## 2. Entry points

- `src/router.tsx`, `src/start.ts`, `src/server.ts` — TanStack Start bootstrap.
- `src/routeTree.gen.ts` — generowany routing (nie edytować ręcznie).
- Trasy (`src/routes/`): `/` (tytuł), `/menu`, `/poziom/$id` (gameplay 2D),
  `/poziom3d` (prototyp 3D), `/ustawienia`, `/osiagniecia`, `/koniec`.
- `GameCanvas.tsx` — właściciel instancji `GameEngine` (Canvas2D) w ref,
  komunikacja przez `EngineEvents` → akcje Zustand. Silnik nigdy nie importuje
  Reacta ani nie dotyka store'a bezpośrednio.
- `PhaserGameCanvas.tsx` — analogiczny most dla `LevelScene` (Phaser), ładuje
  `phaser` i `LevelScene` dynamicznym `import()` wewnątrz efektu client-only
  (Phaser dotyka `window` przy imporcie, co psuje SSR).
- `World3D.tsx` — R3F `<Canvas>` montowany dopiero po hydracji (`mounted`
  state), analogicznie do Phasera.

## 3. Sceny / poziomy

Brak klasycznych scen "Boot/Preloader/MainMenu" w rozumieniu Phasera —
odpowiadają im trasy TanStack. Poziomy gry to dane, nie sceny silnika:

- `src/game/levels.ts` — `LEVELS: LevelDef[]`, 6 zdefiniowanych poziomów
  (`getLevel(id)`). Każdy: tło (obraz), rozmiar świata w px, punkt spawn,
  ambient (`day`/`dim`/`night`), `ambientFx` (motes/petals/dust/stars),
  `mood` (color grading), `quests`, `objects` (obstacle/item/npc/goal/trigger).
- `LevelScene.ts` (Phaser) obsługuje tylko poziom przekazany w `init()` —
  obecnie okablowany wyłącznie dla Poziomu 1 przez `PhaserGameCanvas`.
- `World3D.tsx` na sztywno ładuje `getLevel("1")` — brak przełączania poziomów
  w 3D.

## 4. Systemy gameplay

### Player / ruch
- **Canvas2D** (`engine.ts`): pozycja/prędkość jako `Vec2`, accel/friction
  (2200/2400 px/s²), walk 230 / run 380 px/s, sliding collision (osobno X/Y),
  4-kierunkowa animacja z histerezą (`resolveDirection`), 3-klatkowy
  walk-cycle bake'owany do atlasu canvasów.
- **Phaser** (`LevelScene.ts`): Arcade Physics body, ten sam model
  accel/friction ale z innymi stałymi (FRICTION=1300 vs Canvas2D 2400),
  dodatkowo: **hop** (Space — buffered + coyote-time lunge, czego Canvas2D
  NIE ma), drift przy ostrych skrętach w sprincie, squash&stretch, ghost-trail
  przy sprincie, camera shake przy zderzeniu. To zestaw zachowań gameplay,
  których nie ma w silniku bazowym — świadome novum, nie 1:1 port.
- **Three.js** (`EdekPlaceholder.tsx`): kapsuła, ruch w płaszczyźnie XZ,
  `WALK_SPEED=4` (jednostki świata/s — inna skala niż 2D), brak sprintu,
  kolizji, hopa. Czysty placeholder ruchu.

### Input
- `src/game/input.ts` (`InputState`) — dla Canvas2D: klawiatura (WASD+strzałki),
  dotyk (joystick/D-pad), gamepad (oś + przyciski, LB/RB=sprint, A=interakcja),
  `sprintMode: "hold"|"toggle"`, `invertY`.
- `LevelScene.ts` ma **własną, zduplikowaną** obsługę klawiatury przez
  `Phaser.Input.Keyboard.Key` (nie używa `InputState`) — osobny model wejścia.
- `src/game/three/useKeyboardVector.ts` — trzeci, niezależny model wejścia
  (imperatywny ref, tylko WASD/strzałki, bez gamepada/dotyku).
- **Ryzyko**: trzy równoległe implementacje input mappingu do ujednolicenia
  pod `InputMap` Godota.

### Fizyka / kolizje
- Canvas2D: ręczne AABB (`rectsOverlap`), sliding collision osobno per oś,
  brak silnika fizyki.
- Phaser: `Phaser.Physics.Arcade` — `StaticGroup` dla przeszkód, `collider`
  z catem, `overlap` dla stref interakcji (`Zone` + `getData("obj")`).
- Three.js: brak fizyki/kolizji — czysta geometria (`LevelLoader3D.ts` tworzy
  meshe bez ciał fizycznych). Ruch gracza nie jest ograniczany przez obstacles.

### Interakcje / questy
- `src/game/questUtils.ts` — `computeQuests()` (czysta funkcja, testowana),
  3 rodzaje questów: `collect` (zbierz N sztuk), `talk` (porozmawiaj z NPC),
  `reach` (dojdź do celu spełniając `requires`). Generuje też `MissingHint[]`
  — podpowiedzi "czego brakuje i gdzie" (lokalizacja opisowa w ułamkach mapy).
- `src/game/inventory.ts` — `NPC_GIFTS` (mapowanie npcId→ItemId), synteyczne
  id przedmiotu-daru `"<npcObjId>-gift"`, `inventoryFromCollected()` odtwarza
  ekwipunek z listy zebranych obiektów (źródło prawdy to `itemsCollected`,
  nie sam `inventory` w store).
- `src/game/proximity.ts` — klasyfikacja archetypów celu (`gate/chest/food/spot`)
  po dopasowaniu **całych słów** w id obiektu (świadomie, żeby "box" nie
  łapało "boxing") + rozmiarze obiektu, dająca promienie "tuż obok / blisko
  / średnio" używane przez `GoalArrows`/`goalTracking.ts`.
- `src/game/goalTracking.ts` — `useGoalTracks()`, jeden hook wygładzający
  dystans/kierunek do celów `reach`.

### Inventory
Brak osobnego "systemu ekwipunku" — inventory to `Partial<Record<ItemId,number>>`
w Zustand store, rebuildowany na starcie poziomu z `itemsCollected` (lista
stringowych id obiektów). Zbiór 11 przedmiotów w `src/game/items.ts`
(`ITEMS: Record<ItemId, ItemDef>` — wyczerpujący rekord, brakujący item to
błąd kompilacji).

### Dialog
`DialogBox.tsx` (komponent React) — czysto prezentacyjny, sterowany stanem
`dialog: string | null` w `PhaserGameCanvas`/`GameCanvas`. Brak drzewa
dialogowego / systemu rozgałęzień — pojedyncza linijka tekstu na
interakcję, ustawiana przy `onTalk`/`onGoal`/`onDanger`.

### Daily Challenge
`src/game/daily.ts` — czyste funkcje: `dailyDateKey()` (lokalna strefa
czasowa), `pickDaily()` (deterministyczny wybór na bazie hash djb2 z klucza
daty), `previousDayKey()`. Stan w `gameStore.dailyHistory` (mapa
`YYYY-MM-DD → levelId`).

### Save/Load
Jeden slot autosave w `useGameStore` (`SaveSlot`: `levelId`, `pos`, `energy`,
`difficulty`, `savedAt`), zapisywany co 2s (`setInterval` w
`PhaserGameCanvas`/`GameCanvas`) via `useGameStore.getState().setSave(...)`.
Trwały postęp (`levelProgress`, `unlockedLevels`, `talkedNpcs`, `bestLevelTimes`,
`dailyHistory`, `settings`) persystowany do `localStorage` pod kluczem
`edek-game-v1` przez `zustand/persist` z `partialize` (patrz DATA_MODEL.md) —
`energy`/`inventory` świadomie wykluczone z persystencji (odbudowywane z
`itemsCollected` przy starcie poziomu).

### Audio
`src/lib/audio.ts` (`SimpleAudio`) — proceduralne dźwięki syntetyzowane
`AudioContext`/`OscillatorNode` (sine wave tony), NIE pliki audio. 3 efekty:
pickup (akord wznoszący), completion (dur triada), danger (buczenie). Brak
muzyki w tle, brak systemu miksowania — głośność liczona ręcznie z
`useGameStore.volume`/`muted` przy każdym wywołaniu. `howler` jest w
zależnościach (`package.json`) ale nieużywany w znalezionym kodzie — martwa
zależność do zweryfikowania.

### UI
React (nie silnik): `HUD.tsx`, `DialogBox.tsx`, `PauseMenu.tsx`,
`ControlsModal.tsx`, `GoalArrows.tsx`, `Toast.tsx`, `TutorialOverlay.tsx`,
`DebugOverlay.tsx` (dev-only), `VirtualJoystick.tsx`/`DPad.tsx` (dotyk).
`PhaserHUD.tsx` to wyjątek — Phaser Scene renderujący UI (pasek energii,
lista questów, debug pos/state) jako overlay nad R3F Canvas w `/poziom3d`,
zamiast HTML/React.

## 5. Assety

Patrz `ASSET_INVENTORY.md`. Skrót: sprite kota (`edek-sprite.png`,
`edek-topdown.png`), tła poziomów (JPG/JPEG per lokacja), zestaw kafli
TopDown House (PNG, Kenney-style: podłogi/ściany/drzwi/meble/małe przedmioty)
— **niewykorzystany w kodzie** (żaden `import` w `levels.ts` go nie
referencuje — prawdopodobnie materiał przygotowawczy pod przyszły poziom
"wnętrze domu" albo pozostałość). Obrazy w `src/obrazki/` (losowe nazwy
plikowe) — nieprzypisane do żadnego importu w przejrzanych plikach, do
zweryfikowania czy używane.

## 6. Zależności zewnętrzne

Kluczowe dla migracji (z `package.json`):
- `phaser@^4.2.1` — silnik 2D (nie 3.x; API RenderNodes, część rzeczy z
  Phaser 3 usunięta).
- `three@^0.185.1`, `@react-three/fiber@^9.7.0`, `@react-three/drei@^10.7.8`
  — silnik 3D.
- `zustand@^5.0.14` (+ `persist` middleware) — cały stan gry.
- `@tanstack/react-router` + `router-plugin` — routing plikowy.
- `howler@^2.2.4` — zależność audio, brak potwierdzonego użycia (do weryfikacji).
- `framer-motion` — animacje UI (dialog, przejścia).
- Reszta to UI/design system (Radix, Tailwind) niezwiązane z silnikiem gry —
  będą pozostać po stronie "menu/HUD" niezależnie od wyniku migracji do Godota,
  chyba że menu też migruje z przeglądarki do Godota (co nie wynika z próśb
  użytkownika na tym etapie).

## 7. Event system

`src/game/three/EventBus.ts` (`gameEventBus`) — typowany pub/sub
(`ThreeWorldEvents`/`PhaserOverlayEvents`/`ReactAppEvents`), używany **tylko**
w warstwie 3D (`EdekPlaceholder` emituje `player:moved`, `PhaserHUD` nasłuchuje
ale nic nie robi z payloadem — pusty handler, zanotowane w `AGENTS.md` jako
świadome: "loguje ruch ale nie zapisuje go" — teraz nawet log nie występuje,
handler jest pusty). Warstwa Canvas2D/Phaser 2D **nie używa** tego busa —
komunikuje się przez callbacki `EngineEvents`/`LevelSceneEvents` przekazywane
w konstruktorze/`init()`. To dwa niezależne mechanizmy zdarzeń w tym samym
repo.

## 8. Rendering / VFX

- Canvas2D: ręczne bake'owanie sprite'ów do offscreen canvasów (unikanie
  resample co klatkę — udokumentowany w `AGENTS.md` gotcha #4), pooled
  particle system (`particles.ts`: ambient drift, pickup sparkle, sting
  burst, paw dust), ręczne warstwy światła (radial gradient sprites),
  vignette per-ambient, screen shake, y-sort po dolnej krawędzi obiektu.
- Phaser: `AtmosphereFX.ts` — post-FX camera filters, world lighting (Lights2D
  pipeline — **wymaga weryfikacji API względem Phaser 4.2.1**, patrz
  `CLAUDE.md` ostrzeżenie o RenderNodes), ambient particles, foreground
  leaves — bramkowane przez `renderQuality` (`low/medium/high/ultra`).
  Squash&stretch, camera shake, ghost-trail, hop-arc — gameplay juice
  nieobecny w Canvas2D.
- Three.js: `MeshStandardMaterial`, `castShadow`/`receiveShadow`, proste
  bryły (Box/Sphere/Capsule) jako placeholdery — brak tekstur/modeli.

## 9. Dependency graph (opisowo)

```
LEVELS (levels.ts)                      <- ITEMS (items.ts)
   │                                          ▲
   ├──> GameEngine (Canvas2D) ──> InputState  │
   │        │                                 │
   │        └──> events ──> GameCanvas.tsx ──> useGameStore
   │
   ├──> LevelScene (Phaser) ──> (własny input) ──> AtmosphereFX
   │        │
   │        └──> events ──> PhaserGameCanvas.tsx ──> useGameStore
   │
   └──> LevelLoader3D ──> World3D.tsx ──> EdekPlaceholder ──> usePlayer3DStore
                              │                  │                 │
                              └──> FollowCamera <┘                 │
                                                                    ▼
                                                            gameEventBus <── PhaserHUD (reads useGameStore + usePlayer3DStore)

questUtils.ts / inventory.ts / proximity.ts / daily.ts  — czyste funkcje,
konsumowane przez GameCanvas/PhaserGameCanvas/PhaserHUD/HUD/GoalArrows,
niezależne od żadnego silnika renderującego.
```

Trzy silniki NIE dzielą stanu runtime poza `useGameStore` (settings/progress)
— pozycja/energia/hop per-frame żyje osobno w każdym (`GameEngine.pos`,
`LevelScene.pos` getter/setter na sprite'a, `usePlayer3DStore` dla 3D).

## 10. Znany dług techniczny

1. Trzy równoległe implementacje ruchu/inputu z różnymi stałymi fizyki
   (WALK_SPEED 230 w dwóch silnikach 2D, ale FRICTION różni się 2400 vs 1300;
   3D ma zupełnie inną skalę jednostek).
2. `PhaserHUD.tsx` ma pusty listener `gameEventBus.on("player:moved", ...)`
   — martwy kod / niedokończona funkcja.
3. `PhaserGameCanvas.tsx` istnieje i jest kompletny, ale niejasne czy jest
   aktualnie podpięty pod `/poziom/$id` (do zweryfikowania czytając
   `poziom.$id.tsx` — to trzeba potwierdzić przed migracją, bo wpływa na to,
   który silnik 2D jest "źródłem prawdy" behawioru do zachowania).
4. Assety TopDownHouse (Kenney-style) leżą w `src/assets/` nieużywane w
   `levels.ts` — martwe pliki albo materiał na przyszłość.
5. `howler` w zależnościach, `SimpleAudio` używa gołego `AudioContext` —
   potencjalnie martwa zależność.
6. `src/obrazki/*.jpg` — losowe nazwy, nieprzeanalizowane pod kątem użycia.
7. Phaser 4.2.1 to nietypowa/świeża wersja — część Phaser-3-kształtnych API
   (Lights2D, postFX) może się kompilować ale wybuchać runtime (udokumentowane
   w `CLAUDE.md`). `AtmosphereFX.ts` wymaga weryfikacji wobec faktycznego
   zainstalowanego API przed jakąkolwiek migracją logiki oświetlenia do Godota.
8. World3D/Three.js nie ma kolizji ani granic świata — spacer poza mapę jest
   możliwy; to nie jest "brakująca funkcja do zachowania", tylko stan
   nieukończonego prototypu.

## 11. Ryzyka migracji

Patrz `MIGRATION_RISKS.md` dla pełnej listy z oceną wpływu.

## 12. Rekomendowana kolejność migracji

1. **Rozstrzygnięte:** `LevelScene.ts` (Phaser) jest jedynym aktywnym
   silnikiem 2D (`GameEngine`/Canvas2D jest martwym fallbackiem, nieużywanym
   przez żadną trasę). GAMEPLAY_BEHAVIOR.md opisuje Phaser jako źródło
   prawdy; Canvas2D jest wspomniany tylko dla kontrastu/historii.
2. Dane (`levels.ts`, `items.ts`, `types.ts`) → Godot `Resource` — najniższe
   ryzyko, brak zależności od silnika.
3. Input (WASD + dotyk + gamepad) → `InputMap`.
4. Player movement + collision (jeden wybrany model fizyki).
5. Interakcje (item/npc/goal/trigger) + questy (`computeQuests` jako czysta
   logika, łatwa do przeniesienia 1:1 na GDScript bez zmiany kształtu).
6. UI/HUD (dialog, quest list, energy bar, goal arrows).
7. Audio (proceduralne tony → `AudioStreamGenerator` lub zamiana na
   przygotowane próbki — decyzja projektowa, nie techniczna konieczność).
8. Save/load (`SaveSlot` + `levelProgress` → Godot `Resource`-based save).
9. Daily challenge, best times, tutorial stage — drobne systemy pomocnicze.
10. Warstwa 3D (Three.js) — potraktować jako odrębny, mniej dojrzały strumień
    pracy; nie jest wymagana do zachowania parity z głównym gameplayem 2D.

## 13. Sekcja: warstwa Three.js/R3F (poza zakresem oryginalnego planu Phaser-only)

Ta warstwa nie ma odpowiednika w planach `god/godot.md`/`godot2.md`
(pisanych z założeniem czystego Phasera). Kluczowe fakty:
- To eksperymentalny prototyp (Faza 2+), nie produkcyjna ścieżka gry — jedyna
  dostępna trasa to niepodlinkowany `/poziom3d`.
- Godot 4 natywnie wspiera 3D (Node3D/CharacterBody3D), więc migracja tej
  warstwy nie wymaga równoległego "silnika 3D" — cały R3F/Three.js kod
  (`LevelLoader3D.ts`, `EdekPlaceholder.tsx`, `FollowCamera.tsx`) można
  zastąpić wprost natywnymi węzłami Godot 3D, jeśli użytkownik zdecyduje się
  kontynuować wątek 3D w Godocie.
- Zalecenie: potwierdzić z użytkownikiem, czy warstwa 3D w ogóle wchodzi w
  zakres migracji do Godota, czy migrujemy tylko dojrzałą grę 2D. To
  bezpośrednio wpływa na `MIGRATION_MATRIX.md` (osobny wiersz/status dla 3D).
