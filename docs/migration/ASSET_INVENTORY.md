# ASSET_INVENTORY.md

## Sprite'y postaci

| Plik | Użycie |
|---|---|
| `src/assets/edek-sprite.png` | Aktywny — spritesheet kota używany przez `PhaserGameCanvas.tsx` → `LevelScene` (3 kolumny walk-cycle × 4 rzędy kierunków, patrz `sliceCatFrames()`). |
| `src/assets/edek-topdown.png` | Referencjonowany przez martwy Canvas2D `GameEngine`/`GameCanvas.tsx` (do potwierdzenia przy czytaniu `GameCanvas.tsx`, nieprzeczytany w tym audycie — plik istnieje, `engine.ts` przyjmuje `catImg` jako parametr konstruktora). |
| `src/assets/edek-portrait.jpg` | Portret — prawdopodobnie UI (menu/tytuł), nieprzeanalizowany w tym audycie. |

## Tła poziomów

| Plik | Poziom |
|---|---|
| `waly-merged.jpeg` | 1 — Wały Chrobrego (import w `levels.ts`, plik nieznaleziony w glob — sprawdzić dokładną ścieżkę/rozszerzenie przed migracją). |
| `park-merged.jpeg` | 2 — Park Kasprowicza (jw.). |
| `alley-merged.jpeg` | 3 — Aleja Kasztanowa (jw.). |
| `level-attic.jpg` | 4 — Strych o zmroku. |
| `level-garden.jpg` | 5 — Ogród za blokiem. |
| `lu.jpeg` | 6 — Łucznicza 43 (jw., import as `lucznBg`). |
| `level-roof.jpg`, `level-salon.jpg`, `level-blok.jpg`, `real.jpg` | Znalezione w `src/assets/` ale **niereferencjonowane** w `levels.ts` obecnym stanie — martwe pliki lub pozostałości wcześniejszych wersji poziomów (AGENTS.md wspomina "Dach nocą" i "Salon" jako światy koncepcyjne spoza obecnych 6 poziomów — możliwe że to ich tła). Do potwierdzenia z użytkownikiem przed pominięciem w migracji.

> Uwaga: `levels.ts` importuje `waly-merged.jpeg`, `park-merged.jpeg`,
> `alley-merged.jpeg`, `lu.jpeg` — te dokładne nazwy plików nie pojawiły się
> w wykonanym globie `src/**/*.{png,jpg,svg,mp3,wav,json}` (który nie
> obejmował `.jpeg`). Zweryfikować rozszerzenie przy imporcie assetów do
> Godota — prawdopodobnie `.jpeg` a nie `.jpg`.

## Tileset (niewykorzystany w kodzie)

| Plik | Uwaga |
|---|---|
| `TopDownHouse_DoorsAndWindows.png` | Kenney-style top-down tileset. |
| `TopDownHouse_FloorsAndWalls.png` | jw. |
| `TopDownHouse_FloorsAndWalls_OpenDoors.png` | jw. |
| `TopDownHouse_FurnitureState1.png` / `State2.png` | jw. — dwa stany mebli (przed/po interakcji?). |
| `TopDownHouse_SmallItems.png` | jw. |

Żaden z powyższych nie jest importowany w `levels.ts`, `LevelScene.ts` ani
`engine.ts` (na podstawie przeszukanych plików). Możliwe zastosowanie:
przyszły poziom wnętrza domu ("Salon" wg AGENTS.md) jeszcze niezaimplementowany.
**Nie migrować bezmyślnie** — potwierdzić przeznaczenie z użytkownikiem.

## Obrazy o losowych nazwach

`src/obrazki/icaoCBqx.jpg`, `gRaCmUql.jpg`, `3JxOeBmA.jpg`, `ko6Y8vGm.jpg` —
nazwy sugerują automatyczne pobranie/eksport (np. z narzędzia AI-gen lub
CMS). Nieprzeanalizowane w tym audycie pod kątem importu w kodzie — do
zgrepowania (`grep -rn "obrazki" src/`) przed migracją, żeby ustalić czy są
używane.

## Ikony aplikacji

`public/icon.png`, `public/favicon.png` — poza zakresem gry (branding
przeglądarki/PWA), nie dotyczy migracji silnika.

## Audio

**Brak plików audio w repozytorium.** Wszystkie efekty dźwiękowe są
generowane proceduralnie w `src/lib/audio.ts` przez Web Audio API
(`OscillatorNode`, fale sinusoidalne). Nie ma muzyki w tle. `howler`
(biblioteka do plików audio) jest zależnością w `package.json`, ale nie
znaleziono jej użycia w przejrzanym kodzie — zweryfikować
(`grep -rn "howler" src/`) przed założeniem że jest potrzebna do migracji.

## Fonty

Fraunces, Plus Jakarta Sans — ładowane przez `<link>` w `__root.tsx` (Google
Fonts), używane wyłącznie w warstwie UI/HTML (Tailwind), nie w żadnym
canvasie gry. Nie dotyczy migracji silnika renderującego, chyba że UI też
migruje do Godota.

## Dane JSON / konfiguracje

Brak zewnętrznych plików `.json` z danymi gry — wszystkie dane (poziomy,
itemy, questy) są zakodowane jako moduły TypeScript (`levels.ts`, `items.ts`)
z pełnym typowaniem, nie w oddzielnych plikach danych. To ułatwia migrację do
Godot `Resource` (`.tres`) — trzeba je *wygenerować* z TS, nie ma gotowego
formatu pośredniego do zaimportowania.

## Shadery

Brak własnych shaderów GLSL. Cały "look" (vignette, glow, color grading) jest
realizowany: w Canvas2D — ręcznymi gradientami canvasa; w Phaser —
`AtmosphereFX.ts` przez wbudowane post-FX kamery Phasera (ColorMatrix,
presety typu sepia — patrz `LevelMood` w `types.ts`); w Three.js — brak
(placeholder materiały). Migracja do Godota może odtworzyć te efekty przez
`CanvasItem` post-processing / `WorldEnvironment` zamiast custom shaderów.
