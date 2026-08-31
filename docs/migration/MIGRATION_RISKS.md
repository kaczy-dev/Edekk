# MIGRATION_RISKS.md

Ryzyka specyficzne dla TEGO projektu (nie generyczne ryzyka "migracji silnika
gry" — te są już opisane w `god/godot.md`/`godot2.md`).

## Wysokie

### R1 — Trzy równoległe implementacje ruchu/inputu — ROZWIĄZANE (2026-08-31)
Było: Canvas2D (`engine.ts`/`input.ts`), Phaser (`LevelScene.ts`), Three.js
(`useKeyboardVector.ts`) miały różne stałe fizyki i różny zakres funkcji
(gamepad tylko w Canvas2D; hop/drift/ghost-trail tylko w Phaser). Warstwa
Three.js została usunięta z repo (decyzja R4). Pozostają dwie implementacje:
Phaser `LevelScene.ts` (aktywna, jedyne źródło prawdy) i Canvas2D `engine.ts`
(martwy fallback). Traktować `LevelScene.ts` jako jedyne źródło prawdy dla
Godota; Canvas2D ignorować poza ewentualnym odzyskaniem funkcji gamepada
jeśli użytkownik jej zechce w Godot.

### R2 — Phaser 4.2.1 API niepewność
`AtmosphereFX.ts` prawdopodobnie używa API oświetlenia/post-FX, które w
Phaser 4.2.1 (RenderNodes) różni się od udokumentowanego zachowania Phaser 3
— `CLAUDE.md` już to flaguje jako ryzyko ("compiles under type defs, throws
at runtime"). Jeśli ta logika ma wpływ na GAMEPLAY_BEHAVIOR.md (np. wpływa na
odczuwalność poziomu), błędne założenia co do jej *rzeczywistego* zachowania
w przeglądarce (a nie w typach) zniekształcą specyfikację referencyjną dla
Godota. **Mitygacja:** przed pisaniem `GOLDEN_MASTER`-style scenariuszy
referencyjnych dla atmosfery, zweryfikować `AtmosphereFX.ts` w żywej
przeglądarce (`claude-in-chrome` skill), nie tylko czytając kod.

### R3 — Silnik 2D wciąż aktywnie rozwijany równolegle z prototypem 3D — ZDEZAKTUALIZOWANE
Repo było w trakcie WŁASNEJ migracji (2D→hybryda 3D+Phaser). Nieaktualne od
usunięcia warstwy 3D (R4) — zostaje tylko Phaser, więc ten konkretny konflikt
zniknął. Ogólna zasada nadal obowiązuje: re-czytać `GAMEPLAY_BEHAVIOR.md`
przed każdym większym etapem implementacji Godota, nie ufać mu jako trwałemu
zamrożonemu obrazowi po tygodniach.

### R4 — Brak zakresu: czy warstwa 3D wchodzi w migrację? — ROZWIĄZANE (2026-08-31)
Decyzja użytkownika: NIE. Warstwa 3D (Three.js/R3F, `/poziom3d`) była
niepodłączonym, niedojrzałym prototypem — usunięta z repo wraz z
zależnościami (`three`, `@react-three/drei`, `@react-three/fiber`). Migracja
do Godota dotyczy wyłącznie dojrzałej gry 2D (Phaser).

## Średnie

### R5 — Rozbieżność `sensitivity` między silnikami — ROZWIĄZANE (2026-08-31)
Decyzja użytkownika: usunięte jako niepotrzebne. `sensitivity` usunięte z
`ControlSettings`/`DEFAULT_CONTROLS` (`gameStore.ts`), z UI (`ustawienia.tsx`)
i z odczytu w `engine.ts` (dead Canvas2D fallback). Brak odpowiednika do
migrowania do Godot.

### R6 — Proceduralne audio nie ma odpowiednika 1:1 w typowym pipeline Godota
`SimpleAudio` generuje dźwięki przez `OscillatorNode` w locie. Typowy
pipeline Godota (opisany w `godotassets.md`) zakłada gotowe próbki audio.
Odtworzenie identycznego brzmienia wymaga `AudioStreamGenerator` (mniej
typowe, więcej kodu) albo świadomej zmiany na nagrane próbki (zmiana
doświadczenia dźwiękowego). **Mitygacja:** decyzja projektowa z
użytkownikiem, udokumentować jako `INTENTIONAL_DIVERGENCE.md` jeśli wybrana
zostanie zamiana na próbki.

### R7 — Martwe/niepewne assety — ROZWIĄZANE (2026-08-31)
Decyzja użytkownika: zachować w repo jako materiał na przyszłe
levele/dekoracje, nie migrować hurtem teraz. Tileset TopDownHouse i część teł
(`level-roof.jpg`, `level-salon.jpg`, `real.jpg`, obrazy w `src/obrazki/`)
zostają skatalogowane w `ASSET_INVENTORY.md`; decyzja o faktycznym użyciu
per-level zapada przy Fazie World (import assetów per level, nie wcześniej).

### R8 — `howler` zależność niepewnego przeznaczenia
Widoczna w `package.json`, brak potwierdzonego użycia w kodzie źródłowym.
Jeśli jest martwa, nie trzeba jej odpowiednika w Godot; jeśli jest gdzieś
użyta (nieznaleziona w tym audycie), pominięcie złamie parity audio.
**Mitygacja:** `grep -rn "howler" src/` przed uznaniem systemu audio za
w pełni opisany.

### R9 — Discriminated unions (`QuestStep`) nie mają natywnego odpowiednika w GDScript/Resource
Wymaga decyzji architektonicznej (jedna klasa z opcjonalnymi polami vs
dziedziczenie) — złe podejście na starcie utrudni później dodawanie nowych
typów questów. Patrz DATA_MODEL.md, sekcja "Godot target".

## Niskie

### R10 — Stringowe sprzężenia między plikami (nie łapane przez kompilator)
`quest.objId` ↔ `object.id`, klasyfikacja `proximity.ts` po słowach w id,
konwencja `"<npcId>-gift"`. Renaming w Godot musi ręcznie zachować te same
konwencje albo świadomie je zastąpić czymś bezpieczniejszym typowo (np.
eksportowane referencje zamiast stringów) — dobra okazja do poprawy podczas
migracji, nie problem do "zachowania 1:1".

### R11 — `renderQuality` "high" i "ultra" identyczne w obecnym kodzie
Brak dodatkowej gałęzi dla `ultra` w `LevelScene.ts`/`AtmosphereFX.ts` (na
ile stwierdzono bez pełnego audytu `AtmosphereFX.ts`). Niskie ryzyko, ale
warto potwierdzić przed zaimplementowaniem 4 rzeczywiście różnych presetów
jakości w Godocie zamiast odtworzenia tej samej niedokończonej drabinki.

### R12 — Pusty listener w `PhaserHUD.tsx` — NIEAKTUALNE
Dotyczyło wyłącznie usuniętego prototypu 3D (R4); plik nie istnieje już w
repo.
