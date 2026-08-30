# Plan rozbudowy — podsumowanie 3 agentów (QoL / nowe tryby / mikrointerakcje)

Trzy niezależne plany wygenerowane przez agentów `react-coder`, `senior-code-reviewer` i `ui-engineer` na bazie stanu kodu z tej sesji. To plany, nie zaimplementowane zmiany.

## 1. QoL / szkielet aplikacji (react-coder)

Ranking: najpierw naprawy "martwych końców" (utrata stanu bez ostrzeżenia), potem dostępność, potem spójność z istniejącymi wzorcami.

**Wysoka wartość / mały koszt:**
1. "Wyjdź do menu" w pauzie nie ma potwierdzenia (w przeciwieństwie do restartu) — ryzyko utraty żywego speedrun-timera jednym dotknięciem.
2. Ekran błędu (`__root.tsx`) nie ma opcji powrotu *do trwającego poziomu* — tylko restart/strona główna.
3. Karty poziomów w menu bez stanu ładowania obrazków (nagłe pojawianie się).
4. Zablokowane karty poziomów są martwe dla klawiatury/czytnika ekranu — brak `role`/`aria-disabled`.
5. Reset ustawień (`resetControls`) nie daje żadnego potwierdzenia wykonania.
6. Tytuł poziomu w HUD-zie ucina się bez tooltipa mimo że `TooltipProvider` już jest zaimportowany w tym pliku.

**Średnia wartość:** brak wyjaśnienia przy pierwszym auto-zwinięciu legendy dystansu; plecak/ekwipunek bez animacji wejścia mimo `framer-motion` już obecnego w pliku; zmiana trudności resetuje autosave tylko z biernym podpisem (bez potwierdzenia jak przy resecie postępu); nieistniejący poziom (`poziom.$id.tsx`) nie ma linku powrotnego; brak podglądu sterowania (D-pad/joystick) w ustawieniach mimo że komponenty już istnieją.

**Niżej priorytetowe:** brak globalnego wskaźnika "Zapisano"; audyt focus-trap na `PauseMenu` (custom overlay obok w pełni poprawnych Radix Dialogów).

## 2. Nowe tryby gry — ocena architektoniczna (senior-code-reviewer)

Zakotwiczone w `LevelDef`/`QuestStep`/`GameState` (`types.ts`, `gameStore.ts`).

- **Zen mode → zrób jako pierwsze.** Zero zmian schematu — `level.quests: []` + flaga sesyjna `zenMode`. Nie dotyka `levelProgress`/`unlockedLevels`/save.
- **Daily Challenge → zrób jako drugie.** Wymaga **własnego, odizolowanego** wycinka store'a (`dailyHistory` keyed by date), NIE wolno go wpychać do `levelProgress` (kolizja z postępem kampanii). Seed pozycji przedmiotów jako czysta funkcja `seed → Rect[]`, gotowa pod przyszły backend (Supabase).
- **New Game+ → wstrzymać.** Realnie wymaga zmiany klucza `levelProgress` (dziś: 1 slot na poziom *na zawsze*) na klucz złożony (`levelId#cykl`), plus mechanizmu nadpisywania pozycji obiektów w statycznych `LevelDef`. Rekomendacja: zamiast pełnego NG+, tańszy substytut — dodatkowy, trudniejszy poziom trudności (reużycie `DIFFICULTIES`), NG+ dopiero gdy będzie więcej poziomów uzasadniających drugą progresję.

**Zasada ogólna:** Zen i Daily jako osobne, ortogonalne wycinki stanu — nigdy jako doklejone booleany do `levelProgress`/`unlockedLevels`.

## 3. Mikrointerakcje / polish wizualny (ui-engineer)

Top 5 przy krótkim przebiegu: **licznik statystyk na `koniec.tsx` bez animacji zliczania** (największa luka emocjonalna — ekran nagrody, liczby po prostu się pojawiają), **zablokowane karty poziomów bez żadnej reakcji na hover/tap**, **`ustawienia.tsx` jako ściana identycznych kart bez akcentów sekcji + skoki bez przejść**, **pasek energii w HUD zmienia kolor na czerwony twardym cięciem dokładnie w gameplayowo krytycznym momencie**, **strona osiągnięć nie ma momentu "właśnie odblokowane"**.

Pełna lista 25 pozycji obejmuje też: brak `AnimatePresence` na liście przedmiotów w plecaku (mimo że `framer-motion` jest już w tym pliku), statyczne paski postępu na `osiagniecia.tsx` (CSS transition zamiast spring jak wszędzie indziej), ciągła (nieustająca) pulsacja licznika kroków w tutorialu — czyta się jako niepokojąca, nie uspokajająca, brak stakowania w `Toast.tsx` (drugi toast po prostu podmienia pierwszy bez śladu).

## Status wdrożenia (na teraz)

Zatwierdzone i **w trakcie/zrobione** w tej sesji, poza powyższymi planami: migracja wszystkich 6 poziomów na Phaser, nowe tła poziomów 4/5, presety jakości grafiki, płynna interpolacja dzień/noc — patrz bieżąca rozmowa po szczegóły.

Powyższe 3 plany **nie są jeszcze wdrożone** — to lista do priorytetyzacji na kolejne tury.
