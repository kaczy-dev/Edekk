
# Prawdziwy Edek — aktualizacja postaci

Dzięki za zdjęcie! Prawdziwy Edek to **smoke-grey Maine coon** z zielono-bursztynowymi oczami i jasnym podbrzuszem, a nie rudy, którego wygenerowałem. Muszę go przemalować w całej grze.

## Co zmienię

1. **Nowy portret Edka** (`src/assets/edek-portrait.jpg`) — wygeneruję jako standard/premium, używając Twojego zdjęcia jako referencji wizualnej przez `imagegen--edit_image`, żeby zachować umaszczenie smoke, kremowy podbródek, kępki na uszach i wyraz pyszczka.
2. **Nowy sprite top-down** (`src/assets/edek-sprite.png`) — przemalowany na smoke-grey z transparentnym tłem, ta sama poza chodząca z góry.
3. **Paleta motywu w `src/styles.css`** — odsunę dominujący pomarańcz na rzecz srebrno-grafitowych akcentów z ciepłym bursztynowym światłem (Edek to chłodne futro w ciepłym świecie). Zmieniam głównie `--primary` (smoke silver) i `--accent` (bursztyn pozostaje jako światło), tak aby ekran tytułowy i HUD odzwierciedlały kolor Edka.
4. **Drobne copy** — w introdukcji menu/tytułu zostawiam neutralne opisy ("puchaty Maine coon") bez "rudy".

## Co zostaje bez zmian

Cała mechanika, 4 poziomy, dialogi, zapisywanie postępu, sterowanie, joystick. To tylko reskin postaci i delikatna korekta palety pod nowy kolor futra.

Po zatwierdzeniu — generuję dwa nowe assety i podmieniam tokeny.
