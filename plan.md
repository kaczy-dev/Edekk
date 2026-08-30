🎯 ROADMAP ROZBUDOWY: Przygody Edka

Agent skończył comprehensive strategic plan. Oto key takeaways:

Sprint 1-2 (Immediate) — "Onboarding & UX Polish"

┌───────────────────────────────────────────────────────────────────┬────────┬──────────┬──────────────────────────┐
│ Item │ Effort │ Priority │ Why │
├───────────────────────────────────────────────────────────────────┼────────┼──────────┼──────────────────────────┤
│ 1.2 Timeline Menu — Salon → Ogród → Strych → Dach progression viz │ LOW │ ⭐⭐⭐ │ HIGH impact, easy win │
├───────────────────────────────────────────────────────────────────┼────────┼──────────┼──────────────────────────┤
│ 1.1 Hero Section — Animated Edka intro + 4-layer parallax │ MEDIUM │ HIGH │ First impression matters │
├───────────────────────────────────────────────────────────────────┼────────┼──────────┼──────────────────────────┤
│ 1.4 Resume CTA — Show "Sala • 2/3 zadań" in button │ LOW │ MEDIUM │ Reduce bounce │
├───────────────────────────────────────────────────────────────────┼────────┼──────────┼──────────────────────────┤
│ 1.3 Micro-interactions — Sparkles on quest complete, sounds │ MEDIUM │ MEDIUM │ Polish │
└───────────────────────────────────────────────────────────────────┴────────┴──────────┴──────────────────────────┘

Sprint 3-4 (Medium-term) — "Replayability"

- 2.3 Achievements — 10-15 badges (unlock by completing quests/challenges)
- 2.2 Challenge Modes — Speedrun mode, darkness mode, hardcore mode + leaderboards
- 2.1 Cosmetics — 3-5 cat skins, unlock by progression

Long-term (2026+) — "Growth"

- Mobile app (Capacitor)
- Seasonal events (Summer/Autumn/Winter levels)
- Level editor + UGC
- Cloud saves + global leaderboards

WEEK 1 Priority Actions

1. ✅ 1.2 Timeline Menu — Render as linear progression view (Salon locked state shows unlock requirements)
2. ✅ Add Achievement UI — /achievements route, grid of 10 badges (mock locked/unlocked)
3. ✅ Resume CTA tuning — Button shows task count: "Sala • 2/3"
4. Investigate "nie mogę uruchomić gry" — Test level navigation

Gra jest funkcjonalnie bogata (4 poziomy, gamepad, audio, tutorial, energy feedback, achievements page), ale zbudowana w wielu sesjach — po drodze narosły regresje i luki, których nikt jeszcze nie posprzątał. Ten plan robi trzy rzeczy w kolejności: (0) gasi realne pożary znalezione podczas researchu, (1) daje aplikacji pierwszy prawdziwy backend (obecnie 100% localStorage, zero serwera), (2) domyka UI/UX niespójności i wykorzystuje 35 nieużywanych prymitywów shadcn, (3) dodaje QoL, których brak jest wyraźnie odczuwalny (auto-pauza, potwierdzenie restartu, wskaźnik zapisu).

Zbadałem aktualny stan trzema równoległymi agentami (backend/persistence, UI/UX/design system, engine/QoL) zamiast zakładać, że wcześniejsze ustalenia z tej sesji wciąż są aktualne — i dobrze, bo nie były.

---

0. KRYTYCZNE — zrób to jako pierwsze, przed czymkolwiek innym

0.1 Route poziomu żyje w fantomowym katalogu, niewidocznym dla gita

src/routes/poziom.$id.tsx nie istnieje. Zamiast tego jest src/routes/poziom.\$id.tsx — Windows/wcześniejszy Write stworzył prawdziwy podkatalog poziom. (z kropką) zawierający $id.tsx, zamiast płaskiego pliku poziom.$id.tsx (TanStack Router flat-routes używa kropki w nazwie pliku, nie separatora katalogu).

Dowód: git status -- src/routes/poziom./ zwraca błąd „could not open directory" — git w ogóle nie widzi tej ścieżki. routeTree.gen.ts importuje z ./routes/poziom./$id i działa lokalnie tylko dopóki ten nieśledzony katalog istnieje na dysku. Jeden git clean -fd, świeży clone, albo CI build od zera — i gra znów nie wczytuje /poziom/1 (dokładnie ten sam objaw, który użytkownik już raz zgłosił).

Napraw:
mkdir -p /tmp/fix && cp "src/routes/poziom./\$id.tsx" /tmp/fix/id.tsx # skopiuj zawartość
rm -rf "src/routes/poziom./" # usuń fantomowy katalog
cp /tmp/fix/id.tsx "src/routes/poziom.\$id.tsx" # utwórz płaski plik (uwaga: znak $ nie potrzebuje escape'a w Write tool)
git add src/routes/poziom.\$id.tsx
git status # potwierdź, że plik jest teraz tracked
Użyj narzędzia Write (nie Bash/cp) z file_path dosłownie C:\...\src\routes\poziom.$id.tsx — bez backslasha przed $. Backslash przed $ w poprzedniej próbie to była przyczyna problemu na Windows.

Po naprawie: npm run build musi przejść, git status musi pokazać plik jako nowy/tracked, i restart dev servera (świeże routeTree.gen.ts) musi nadal serwować /poziom/1.

0.2 Polish menu.tsx został cofnięty przez wcześniejszy git checkout

W trakcie tej sesji menu.tsx miał dodane: pigułkowe linki nawigacji (rounded-full border border-border bg-card/60 backdrop-blur) i wzbogacone zablokowane karty (gradient overlay + „➜ Następny" badge). Naprawa złamanego JSX (timeline eksperyment) użyła git checkout src/routes/menu.tsx, co cofnęło też te wcześniejsze, już zaakceptowane zmiany. Obecny stan pliku to gołe linki tekstowe i samo 🔒 na środku — dokładnie to, co plan UI z wcześniejszej sesji miał naprawić.

Napraw: ponownie zastosuj te dwie zmiany (nie timeline — to było zbyt ambitne i złamało JSX):

- Nawigacja górna → pigułki jak w index.tsx/koniec.tsx.
- Zablokowana karta → gradient overlay (bg-gradient-to-t from-card via-card/30 to-transparent) + label „🔒 Zablokowane" zamiast gołego emoji, plus „➜ Następny" na karcie bezpośrednio po ostatniej odblokowanej (prosty index-based check, bez timeline).

0.3 /osiagniecia to martwa, oszukująca strona

Istnieje, ale (a) nie jest linkowana znikąd — menu.tsx linkuje tylko /, /ustawienia, /poziom/$id — więc gracz nigdy jej nie zobaczy; (b) wszystkie odznaki są zahardkodowane jako „Odblokowana", nawet dla gracza, który nic nie zrobił — to wprowadza w błąd, jeśli ktoś kiedyś trafi na URL bezpośrednio; (c) literalny bug: desc: "Ukończ poziom w &lt;5 min" renderuje się jako dosłowny tekst &lt;5 min na ekranie zamiast <5 min.

Napraw teraz (kosmetycznie), rozbuduj w sekcji 2.3 (funkcjonalnie):

- Popraw &lt;5 → <5 w src/routes/osiagniecia.tsx.
- Dodaj link do /osiagniecia w menu.tsx (pigułka obok „Ustawienia").
- Zostaw „wszystko odblokowane" jako świadomy placeholder TYLKO jeśli sekcja 2.3 nie jest jeszcze robiona w tym samym przebiegu — inaczej wdroż real unlock state od razu (patrz 2.3).

---

1. BACKEND — pierwszy prawdziwy zapis poza przeglądarką

Ustalenie architektoniczne (ważne — różni się od wcześniejszego planu Supabase)

src/lib/config.server.ts ma w komentarzu: „Use this pattern [createServerFn] instead of Supabase Edge Functions for server logic." To jawna decyzja projektu. src/lib/api/example.functions.ts już demonstruje wzorzec: createServerFn({ method: "POST" }).inputValidator(zod schema).handler(...). Build celuje w Cloudflare (Nitro), ale nie ma jeszcze wrangler.toml ani żadnego bindingu KV/D1.

Rekomendacja: Cloudflare KV (nie Supabase, nie D1 na start). Uzasadnienie: dane są proste (jeden JSON blob per gracz — postęp, best times), nie potrzeba relacyjnych zapytań na starcie; KV ma zero-config binding w Nitro/Cloudflare preset, zero nowych zależności (@supabase/supabase-js nie jest zainstalowane — musiałby być dodany), i pasuje do istniejącego komentarza „nie Supabase". D1 (SQL) zostaje jako krok 2, jeśli leaderboardy z sortowaniem/rankingiem (sekcja 1.3) okażą się potrzebować realnych zapytań zamiast trzymania top-100 jako posortowanej listy w jednym KV kluczu.

1.1 Anonimowy player ID (fundament, wymagany przez wszystko dalej)

- src/lib/persistence/player-id.ts — crypto.randomUUID() przy pierwszym uruchomieniu, zapisany w localStorage (nie sessionStorage — gracz ma wracać do tego samego ID między sesjami przeglądarki, w przeciwieństwie do wcześniejszego planu agenta, który mylił to z tożsamością per-tab).
- Wpięcie: nowe pole playerId: string w gameStore.ts, inicjalizowane leniwie przy pierwszym startLevel() lub w __root.tsx na starcie aplikacji.

1.2 Cloud autosave (rozszerza istniejący autosave, nie zastępuje)

- GameCanvas.tsx już ma setInterval co 2s zapisujący do SaveSlot w Zustand/localStorage (src/components/game/GameCanvas.tsx, autosave timer). Rozszerz: co ~15s (rzadziej niż lokalny autosave — cloud sync nie musi być tak częsty), jeśli navigator.onLine, wyślij POST do nowego server function.
- src/lib/api/save.functions.ts:
  export const uploadSave = createServerFn({ method: "POST" })
  .inputValidator(z.object({
  playerId: z.string().uuid(),
  levelProgress: z.record(z.object({ completed: z.boolean(), itemsCollected: z.array(z.string()) })),
  unlockedLevels: z.array(z.string()),
  }))
  .handler(async ({ data, context }) => {
  await context.cloudflare.env.EDEK_SAVES.put(data.playerId, JSON.stringify(data));
  });
  (dokładny sposób dostępu do context.cloudflare.env zależy od tego, jak @lovable.dev/vite-tanstack-config eksponuje Cloudflare bindings w handlerach — zweryfikuj przy implementacji, to jeden nieznany szczegół w całym planie).
- wrangler.toml (nowy plik) z jednym KV namespace: EDEK_SAVES.
- Fallback offline: jeśli upload zawiedzie, dane i tak są bezpieczne w localStorage — cloud to nadmiarowa kopia, nigdy jedyne źródło prawdy na tym etapie.
- Nie buduj IndexedDB queue / conflict resolution z wcześniejszego planu agenta na tym etapie — to nadmiarowa złożoność dla gry z jednym urządzeniem na gracza i brakiem multi-device sync. Dodaj tylko jeśli 1.4 (cross-device) zostanie faktycznie zamówione.

1.3 Leaderboardy (opcjonalne rozszerzenie, po 1.1+1.2)

- Wymaga danych, których obecnie nie ma: czas ukończenia poziomu. Dodaj completionTimeSec do completeLevel() w gameStore.ts (licz od startLevel() timestamp).
- Jeden KV klucz per poziom: leaderboard:{levelId} = posortowana tablica top-50 {playerId (skrócone), timeSec, date}. Przy nowym wyniku: pobierz, wstaw, przytnij do 50, zapisz — prosty read-modify-write, akceptowalny przy niskim ruchu (nie potrzeba D1 na starcie).
- UI: nowa sekcja w /koniec.tsx pokazująca ranking, i mały „Twój najlepszy czas: X" w menu.tsx na karcie poziomu.

1.4 Co świadomie NIE wchodzi w ten plan

Cross-device cloud accounts (email/magic link), D1/SQL, device fingerprinting, monetyzacja, mobile app (Capacitor) — to wszystko było w poprzednim strategicznym roadmapie agenta jako long-term (Q3-Q4 2026+) i zostaje tam. Ten plan celuje w to, co realnie domyka obecną aplikację.

---

2. UI/UX I GRAFIKA

2.1 Wspólny „glass panel" utility — usuwa realną niespójność

Agent potwierdził: PauseMenu (bg-black/60, backdrop-blur-sm), ControlsModal (bg-black/50 scrim, backdrop-blur-md panel), TutorialOverlay (bg-black/40 scrim, backdrop-blur-xl panel), Toast — cztery różne kombinacje blur/scrim/border dla wizualnie tej samej rzeczy (overlay panel na canvasie gry).

Dodaj do src/styles.css w @layer utilities:
.panel-glass { @apply rounded-2xl border border-white/10 bg-black/50 backdrop-blur-md; }
.scrim { @apply bg-black/55 backdrop-blur-sm; }
Zastosuj w PauseMenu.tsx, ControlsModal.tsx, TutorialOverlay.tsx, Toast.tsx — zamień ręcznie skomponowane klasy na te dwie. Jeden plik, spójny rezultat, łatwe do zmiany w przyszłości w jednym miejscu.

2.2 Wykorzystaj zainstalowane, nieużywane prymitywy shadcn zamiast custom-rolled

48 komponentów zainstalowanych, ~13 używanych. Zamiast dalej pisać custom overlay markup (jak ControlsModal robi ręcznie to, co Dialog daje za darmo z focus trap + Esc + aria), podmień tam gdzie się opłaca:

- Tooltip (@/components/ui/tooltip, nieużywany) → hint na przycisku „?" w HUD, na ikonach dystansu w legendzie (tierStyle glyphs already exist, tooltip dodaje tekstowe wyjaśnienie na hover/focus — accessibility win, zero nowego kodu wizualnego).
- Dialog (nieużywany) → restart confirmation w PauseMenu (patrz 3.2) — Radix daje focus trap i Esc-to-close za darmo, czego ControlsModal's ręczny onClick={onClose} na scrimie nie ma (brak obsługi klawiatury Esc dzisiaj).
- Nie migruj ControlsModal/PauseMenu do Dialog w całości teraz — zbyt duży diff na jedną sesję. Użyj Dialog tylko dla nowego restart-confirm (3.2), zostaw istniejące moda le jak są po zastosowaniu 2.1.

2.3 Odznaki: z mocka na prawdziwy stan (dokańcza 0.3)

- Dodaj do gameStore.ts: unlockedAchievements: string[], akcja unlockAchievement(id: string).
- Wylicz warunki odznak z istniejących danych zamiast nowego trackingu tam, gdzie to możliwe:
  - „Puchaty Odkrywca" — levelProgress["1"].completed
  - „Mistrz Światów" — wszystkie 4 completed
  - „Łowca Myszek" / „Ogrodnik 100%" — z itemsCollected per poziom (już śledzone)
  - „Rozmówca" — z talkedNpcs (już śledzone)
  - „Błyskawica &lt;5min" — wymaga completionTimeSec z sekcji 1.3; jeśli 1.3 nie jest robione w tym przebiegu, zostaw tę jedną odznakę jako „wkrótce" zamiast fałszywie odblokowaną.
- Wylicz przy każdym renderze /osiagniecia (pure function computeAchievements(store state), wzorem questUtils.computeQuests) zamiast trzymać osobny synchronizowany stan — unika drugiego źródła prawdy.

2.4 Drobne domknięcia graficzne

- .paper-grain w styles.css jest zdefiniowana i nieużywana — albo usuń, albo nałóż na duże płaskie karty (np. tło /osiagniecia grida) dla tekstury bez nowych assetów. Niski priorytet, zdecyduj na miejscu.
- Achievement ikony to emoji (świadomy wybór, udokumentowany w SKILLS.md dla items.ts) — zachowaj spójność, nie mieszaj z SVG.

---

3. NOWE QOL

3.1 Auto-pauza gdy karta traci focus

Silnik dzisiaj nie pauzuje się na visibilitychange/pagehide — te eventy tylko zapisują stan, ale engine.update() leci dalej w tle: energia się drenuje, pszczoły żądlą, gracz wraca do karty ze stratami, których nie widział.

W GameCanvas.tsx, w istniejącym onHide handlerze (już podpiętym pod visibilitychange/pagehide) dodaj:
const onHide = () => {
const e = engineRef.current;
if (!e) return;
if (document.hidden) e.paused = true; // NOWE — istniejący kod tylko zapisywał
setSave({ ... }); // istniejące
};
I odpauzuj jawnie w PauseMenu/resume flow, żeby nie kolidowało z ręczną pauzą gracza (paused state w React) — użyj osobnej flagi engine.autoPaused żeby nie nadpisać intencji gracza, jeśli ręcznie zapauzował przed schowaniem karty.

3.2 Potwierdzenie restartu poziomu

PauseMenu.tsx → „Zacznij poziom od nowa" dzisiaj wykonuje się natychmiast po jednym kliknięciu, kasując cały postęp w poziomie bez ostrzeżenia. Użyj AlertDialog (już zaimportowany i używany w ustawienia.tsx dla „Zresetuj postęp gry" — kopiuj ten dokładny wzorzec, nie Dialog z 2.2, dla spójności z jedynym już istniejącym confirm flow w apce):
<AlertDialog>
<AlertDialogTrigger className="...">Zacznij poziom od nowa</AlertDialogTrigger>
<AlertDialogContent>
<AlertDialogHeader>
<AlertDialogTitle>Zacząć od nowa?</AlertDialogTitle>
<AlertDialogDescription>Stracisz postęp w tym poziomie.</AlertDialogDescription>
</AlertDialogHeader>
<AlertDialogFooter>
<AlertDialogCancel>Anuluj</AlertDialogCancel>
<AlertDialogAction onClick={restart}>Tak, zacznij od nowa</AlertDialogAction>
</AlertDialogFooter>
</AlertDialogContent>
</AlertDialog>

3.3 Wskaźnik zapisu

Autosave działa cicho co 2s (GameCanvas.tsx saveTimer). Dodaj mikro-feedback: mały „Zapisano" fade-in/out (podobny do istniejącego Toast.tsx, ale osobny, dyskretny — róg ekranu, 0.6 opacity, 800ms) po każdym udanym setSave(). Nie każdy tick — throttluj do widocznego sygnału raz na ~10s, żeby nie migotało.

3.4 Podłącz playDanger

src/lib/audio.ts ma gotową, nigdy niewywoływaną playDanger(). W GameCanvas.tsx, onDanger handler (już wywołuje drain(), wibrację, setDialog) — dodaj jedną linię: audio.playDanger(muted ? 0 : volume), analogicznie do już podpiętych playPickup/playCompletion.

3.5 Tutorial: replay affordance

Tutorial dzisiaj tylko dla poziomu 1, jednorazowy, 4s auto-advance na sztywno. Dodaj mały link „Pokaż tutorial ponownie" w ControlsModal.tsx (już otwierany przyciskiem „?" w HUD) który robi setTutorialStage(1) — jedna linia, wykorzystuje istniejącą infrastrukturę, zero nowego UI.

3.6 Świadomie pominięte w tym planie

Keyboard remapping UI i pełne ARIA/screen-reader wsparcie dla canvas-driven gry — realne gapy znalezione przez agenta, ale duży, osobny nakład (custom key-binding UI + persistence + conflict detection dla remappingu; audio-description layer dla ARIA) nieproporcjonalny do reszty tego planu. Warte osobnej sesji, nie wrzucania na koniec tej listy.

---

Kolejność wykonania (rekomendowana)

1. 0.1 → 0.2 → 0.3 (krytyczne naprawy, ~30 min, zero ryzyka regresji bo to przywracanie znanego dobrego stanu)
2. 3.1, 3.2, 3.4 (szybkie QoL, każde &lt;20 linii, wysoki odczuwalny efekt)
3. 2.1 (glass-panel utility — mechaniczna, niskiego ryzyka zmiana w 4 plikach)
4. 1.1 → 1.2 (backend fundament — player ID + cloud autosave, wymaga wrangler.toml i decyzji o dostępie do Cloudflare bindings w handlerze, jedyny prawdziwie niepewny krok w planie)
5. 2.3 (odznaki na realnych danych — zależy częściowo od 1.2 dla jednej odznaki, reszta niezależna)
6. 3.3, 3.5, 2.2, 2.4 (dopełniacze, dowolna kolejność)
7. 1.3 (leaderboardy — opcjonalne, największy dodatkowy zakres, rób na końcu i tylko jeśli 1.1/1.2 wyszły gładko)

Weryfikacja

- Po 0.1: rm -rf src/routes/poziom.$id.tsx (upewnij się że NIE usuwasz katalogu), npm run build, restart npm run dev, otwórz /poziom/1 — musi się wczytać. git status musi pokazać plik jako tracked/staged.
- Po każdej sekcji: npm run typecheck && npm run build (oba muszą przechodzić — standard tego repo).
- grep -rn "TEMP_\|__engine\|__stats" src/ przed uznaniem czegokolwiek za gotowe (konwencja z AGENTS.md).
- Ręczna weryfikacja w przeglądarce (claude-in-chrome skill jeśli dostępny) dla: /poziom/1 (auto-pauza — przełącz kartę i wróć, sprawdź energię), restart confirm w pauzie, /osiagniecia (dostępne z menu, realne stany), /menu (pigułki nawigacji, wzbogacone locked cards).
- Backend (1.2): sprawdź wrangler.toml binding nazwę zgadza się z tym, czego oczekuje handler; jeśli context.cloudflare.env nie jest dostępne w sposób, jaki @lovable.dev/vite-tanstack-config eksponuje — to jedyne miejsce w planie wymagające eksperymentu/doczytania dokumentacji tego presetu przed dalszą pracą nad 1.3.
