Testy na fizycznych słabszych urządzeniach (iPhone SE, Samsung A10 z planu) — nie mam do nich dostępu; zbudowałem w Priorytecie 3 DebugOverlay (klawisz `) właśnie po to, żebyś Ty mógł to zmierzyć.

- Profilowanie w Chrome DevTools — z tego samego powodu (brak stabilnego dostępu do przeglądarki w tej sesji) niezrobione; ten sam DebugOverlay to substytut.
- Nierozwiązana luka z audytu: canvas renderuje się w natywnym devicePixelRatio urządzenia niezależnie od renderQuality — na telefonie z DPR 3 to potraja koszt wypełnienia pikseli nawet na "low". Sprawdziłem typy Phaser 4 i nie znalazłem tam już pola resolution/DPR z Phaser 3 — celowo nie zgaduję poprawki bez weryfikacji, żeby nie powtórzyć błędu z Lights2D.
- "Level 7 template test" z planu — nieistotne, nie dodajemy nowego poziomu.
