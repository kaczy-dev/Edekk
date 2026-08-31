# GAMEPLAY_BEHAVIOR.md

Źródło prawdy: `src/game/phaser/LevelScene.ts` (silnik aktywny na
`/poziom/$id` dla wszystkich 6 poziomów). Canvas2D `engine.ts` opisany tylko
tam, gdzie zachowanie różni się — jako kontekst historyczny, NIE jako cel
parity (jest martwym kodem).

## Ruch podstawowy

- Wejście: WASD + strzałki, znormalizowany wektor 2D (diagonale nie są
  szybsze — `len > 1` przycina do jedności), plus dotyk (`scene.touch`) i
  brak obsługi gamepada w Phaser LevelScene (Canvas2D miał gamepad —
  **rozbieżność, do zdecydowania czy dodać w Godot**).
- Prędkość bazowa: 230 px/s (chód), 380 px/s (sprint), skalowane przez
  `sensitivity` w Canvas2D ale **NIE w Phaser LevelScene** (Phaser ignoruje
  `ControlSettings.sensitivity` — kolejna rozbieżność do zweryfikowania z
  użytkownikiem: czy to celowe uproszczenie czy przeoczenie migracji
  Canvas2D→Phaser).
- Akceleracja: 2200 px/s² z wejściem, 1300 px/s² tarcie bez wejścia
  (asymetryczne — zatrzymanie jest wolniejsze niż rozpędzanie, "kot ślizga
  się do zatrzymania, nie hamuje jak robot" — cytat z komentarza w kodzie).
- Kolizje: Arcade Physics `collider` między kotem a statyczną grupą
  przeszkód zbudowaną z `LevelObject.rect` gdzie `kind === "obstacle"`.
  Ściana zatrzymuje odpowiednią składową prędkości (Arcade robi to
  natywnie, nie ręczne sliding jak w Canvas2D).

## Hop (Space) — unikalna mechanika Phaser, brak w Canvas2D

- Naciśnięcie Space wywołuje kierunkowy "skok" (bez grawitacji/osi Y w
  sensie 3D — czysto wizualny łuk).
- Czas trwania: 320ms, prędkość podczas hopa: 361 px/s (`RUN_SPEED * 0.95`),
  wysokość łuku (wizualna, offset sprite'a): 22px.
- **Jump buffering**: naciśnięcie do 150ms przed gotowością wciąż
  odpala hop w momencie odblokowania.
- **Coyote time**: puszczenie kierunku do 120ms wcześniej wciąż liczy się
  jako "był ruch" — hop dostaje pełny impet zamiast słabego na miejscu.
- Cooldown: 260ms po zakończeniu hopa (łącznie ~580ms między hopami przy
  spamowaniu klawisza).
- Kierunek hopa: aktualny wektor ruchu, albo ostatni kierunek hopa (jeśli w
  oknie coyote), albo kierunek "twarzy" kota z bieżącej animacji (jeśli stał
  w miejscu).
- Wizualny feedback: przysiad-antycypacja (squash 1.3/0.68) przed startem,
  pył pod łapami na starcie i lądowaniu, cień przypięty do poziomu ziemi
  (kurczy się/blednie w szczycie łuku), lekki camera shake na lądowaniu
  (pomijany przy `reducedMotion`).
- **Do weryfikacji w Godot**: czy hop ma zostać zachowany jako mechanika
  rdzenia gry, czy był eksperymentem specyficznym dla spike'u Phaser.

## Sprint

- Trigger: Shift (hold) lub toggle (zależnie od `ControlSettings.sprintMode`),
  plus dotyk (`touchSprint`)/wirtualny przycisk BIEG.
- Warunek: `energy > DIFFICULTIES[difficulty].minSprintEnergy` ORAZ ruch
  aktywny (`isMoving`).
- Koszt energii: `sprintDrainMul * 6` jednostek/s (bazowa stawka 6, mnożnik
  zależny od trudności: easy 0.55×, medium 1.0×, hard 1.6×, explorer 0×).
- Regeneracja przy braku ruchu: `restRecoverMul * 4` jednostek/s.
- Efekty wizualne unikalne dla sprintu: ghost-trail (kopie klatki co 45ms,
  alfa 0.32, tint niebieski, zanikające w 220ms) — wyłączone przy
  `renderQuality === "low"`.
- Drift przy ostrym skręcie w sprincie (>90° zmiana kierunku przy prędkości
  > WALK_SPEED): zachowuje część starej prędkości przez 140ms zamiast
  natychmiastowej zmiany — efekt "poślizgu".

## Squash & stretch / animacja

- Start ruchu: squash 1.18×/0.85× w 100ms. Pełne zatrzymanie: 0.88×/1.15× w
  90ms. Zderzenie z przeszkodą (przy prędkości > 40 i rosnącym zboczu
  "zablokowany"): squash 1.2×/0.75× w 90ms + camera shake 70ms.
- Ciągłe rozciąganie proporcjonalne do prędkości podczas ruchu (do +8%/-6%
  przy pełnym sprincie).
- Idle breathing: sinusoidalna pulsacja skali (±1.8% amplitudy, 1.6 rad/s)
  gdy kot stoi — wyłączona przy `reducedMotion`.
- Lean przy skręcie: nachylenie sprite'a proporcjonalne do ostrości skrętu
  i prędkości (max 0.16 rad), tylko przy prędkości > 15% max.
- Animacja walk-cycle: 4 kierunki (down/left/right/up) × 3 klatki
  (0,1,2,1 — kontakt-przelot-kontakt-przelot), frameRate bazowy 8,
  `timeScale` skalowany 0.55–1.4× zależnie od prędkości względem sprintu.

## Interakcje

- **Item** (kolekcjonowanie): kontakt overlap → `collectItem()` — jednorazowe
  (guard `collectedIds`), niewielki camera punch (zoom 1.03×, 160ms),
  emisja `onPickUp`.
- **NPC**: overlap LUB naciśnięcie E w promieniu 100px (liczone do
  najbliższego z `kind === "npc" | "goal"`) → `onTalk`. Dar NPC (jeśli
  zdefiniowany w `NPC_GIFTS`) przyznawany raz, przy pierwszej rozmowie.
- **Goal**: overlap lub E → `onGoal`, sprawdzenie `requires` (Partial
  Record<ItemId, number>) — jeśli niespełnione, dialog z listą brakujących
  (emoji + liczba); jeśli spełnione, `completeLevel()`, dźwięk ukończenia,
  odblokowanie następnego poziomu.
- **Trigger (danger)**: overlap → `onDanger`, cooldown 1.2s (zapobiega
  wielokrotnemu obrywaniu w tej samej klatce/sekundzie kontaktu), odejmuje
  `dangerDamage` energii wg trudności (easy 5, medium 10, hard 18,
  explorer 0), wibracja na urządzeniach dotykowych, camera shake 9 (jeśli
  nie `reducedMotion`).
- Wskaźnik "można wejść w interakcję": ikona 💬 (NPC) lub 🚪 (goal) nad
  głową kota, pojawia się/znika przy zmianie `nearestInteractable` (radius
  100px), niezależnie od HTML-owego HUD (który tego nie pokazuje w wersji
  Phaser — świadomie, żeby nie dublować podpowiedzi).

## Patrol NPC

- Opcjonalny (`LevelObject.patrol: {range, speed}`) ruch NPC w poziomie,
  odbijający się na krańcach zakresu wokół pozycji spawnu, z odbiciem
  lustrzanym sprite'a (`setScale(dir, 1)`) przy zmianie kierunku.
- Przykłady w danych: wiewiórka (Poziom 2, range 140, speed 26), gołąb
  (Poziom 5, range 180, speed 34). Sąsiad-kot (Poziom 6) jest statyczny
  (brak `patrol`).

## Questy — trzy rodzaje (logika w `questUtils.ts`, silnik-agnostyczna)

1. **collect** — zbierz N sztuk `itemId`. Ukończony gdy
   `inventory[itemId] >= count`.
2. **talk** — porozmawiaj z obiektem `objId`. Ukończony gdy `objId` jest w
   liście `talkedNpcs[levelId]`.
3. **reach** — dotrzyj do `objId` (celu) spełniając jego `requires`.
   Ukończony gdy poziom jest oznaczony `completed` (co dzieje się wewnątrz
   handlera `onGoal`, nie automatycznie przy samym dojściu).

Każdy quest generuje `MissingHint[]` — lokalizacyjne podpowiedzi ("u góry
mapy, po lewej") wyliczane z ułamkowej pozycji obiektu na mapie
(`locationOf()`), plus fallbacki dla itemów niedostępnych na bieżącej
planszy (np. `yarn`/`feather` — dary NPC, nie leżą na ziemi).

## Difficulty (wpływ na gameplay)

| Trudność | startEnergy | sprintDrainMul | restRecoverMul | dangerDamage | minSprintEnergy |
|---|---|---|---|---|---|
| easy | 100 | 0.55× | 1.5× | 5 | 4 |
| medium (domyślna) | 100 | 1.0× | 1.0× | 10 | 8 |
| hard | 80 | 1.6× | 0.7× | 18 | 16 |
| explorer (zen mode) | 100 | 0× | 1× | 0 | 0 |

Zen mode (`useGameStore.zenMode`) tymczasowo wymusza `explorer` na czas
sesji, bez zmiany zapisanej trudności użytkownika.

## Kamera

- Podąża za kotem (`startFollow(cat, true, 0.12, 0.12)` — lerp 12%/klatkę
  na obu osiach).
- Bazowy zoom: `clamp(min(width,height)/620, 0.75, 1.3)`.
- Camera pulse (`pulseZoom`): używany przy otwarciu dialogu (1.06×, 260ms) i
  przy zbieraniu itemu (1.03×, 160ms) — względny do `baseZoom`, więc
  komponuje się między poziomami o różnym zoomie bazowym.
- Camera shake: przy zderzeniu ze ścianą (70ms, intensywność 0.0015) i przy
  lądowaniu z hopa (60ms, 0.001) — oba pomijane przy `reducedMotion`.

## Renderowanie zależne od jakości (`renderQuality`)

| Poziom | Atmosfera post-FX | Światło/cząstki ambient | Liście foreground | Cząstki pyłu |
|---|---|---|---|---|
| low | brak | brak | brak | brak (n=0 zawsze) |
| medium | tak | brak | brak | połowa liczby (`ceil(count/2)`) |
| high | tak | tak | tak | pełna liczba |
| ultra | tak | tak | tak | pełna liczba |

(`high` i `ultra` traktowane identycznie w obecnym kodzie poza samą flagą —
brak dodatkowej gałęzi dla `ultra`, do potwierdzenia czy to zamierzone.)

## Reduced Motion (dostępność)

Gdy włączone: brak idle-breathing, brak camera shake, brak drift/lean(?)
— sprawdzić szczegółowo przy migracji, obecnie `reducedMotion` gałęzi
dotyczy explicite: idle breath amount→0, camera shake pominięty (zderzenie
i lądowanie hopa), atmosfera (`AtmosphereFX`) otrzymuje flagę do własnej
logiki (nieprzeanalizowanej w tym audycie w pełni).

## Zapis / wznowienie

- Autosave co 2000ms (tylko gdy scena nie jest zapauzowana): zapisuje
  `levelId`, zaokrągloną pozycję, `energy`, `difficulty`, `savedAt`.
- Wznowienie (`startLevel(id, {resume: true})`) przywraca `save.energy`
  zamiast energii startowej trudności, ORAZ `initialPos` w
  `LevelSceneInit` (jeśli `save.levelId === level.id`).
- Ukończone poziomy pomijają intro dialog przy ponownym wejściu
  (`levelProgress[id].completed` gate w konstruktorze stanu `dialog`).

## Timer / rekordy

- `levelStartedAt` ustawiany przy `startLevel` (świeży start) lub zachowany
  (wznowienie — liczy realny czas łącznie z przerwą). `completeLevel()`
  liczy `elapsed`, aktualizuje `bestLevelTimes[id]` tylko jeśli lepszy niż
  poprzedni rekord.
- `totalHops`/`totalDistanceWalked` — liczniki lifetime, instrumentowane
  WYŁĄCZNIE przez `LevelScene` (Phaser) przez `onHop`/`onDistance` — jeśli
  ktoś kiedyś przywróci Canvas2D engine, te liczniki się nie zwiększą (brak
  wywołań w `engine.ts`; udokumentowane też w komentarzu przy polach w
  `gameStore.ts`).
