# Kompendium Assetów 2D dla Silnika Godot 4
*Poradnik i kuracja zasobów dla Senior Game Developera*

---

## 🌟 Najlepsze Darmowe Assety i Źródła (Pixel Art & HD/Vector)

Profesjonalni developerzy rzadko tworzą wszystko od zera podczas prototypowania lub produkcji indie. Oto wyselekcjonowane, w 100% legalne źródła darmowych assetów komercyjnych (CC0 lub MIT):

### 1. Kenney.nl ("Asset Jesus")
*   **Co tam znajdziesz:** Tysiące assetów podzielonych na paczki (Pixel Art, Vector, UI, Audio).
*   **Zastosowanie:** Absolutny standard do szarowania (greyboxing) i prototypowania mechaniki. Wszystko na licencji CC0 (domena publiczna).

### 2. Itch.io (Sekcja Free Game Assets)
*   **Co tam znajdziesz:** Unikalne zestawy teł (Parallax), animacje postaci oraz klocki do platformówek.
*   **Filtrowanie:** Szukaj z tagami: `LPC` (Liberated Pixel Cup), `CC0` lub `Free`. Szczególnie polecane serii autorstwa *Szadi Art* lub *Ansimuz*.

### 3. OpenGameArt.org
*   **Co tam znajdziesz:** Największa baza open-source assetów 2D (spritesheety, kafelki, muzyka).
*   **Wskazówka Seniora:** Zawsze sprawdzaj licencję (wybieraj wyłącznie CC0, CC-BY lub OGA-BY). Unikaj CC-BY-NC (zakaz komercyjnego użytku).

---

## 🛠️ Senior Workflow: Praca z Grafiką 2D w Godot 4

Efektywność w gamedevie zależy od czystego pipeline'u. Oto jak architekturę importu i pracy z grafiką organizują profesjonaliści:

### 📁 1. Struktura Katalogów (Clean Project Architecture)
Nigdy nie wrzucaj assetów bezpośrednio do głównego katalogu. Zastosuj strukturę modułową lub zorientowaną na typy:

```text
res://
├── assets/
│   ├── textures/
│   │   ├── environment/ (kafelki, tła)
│   │   ├── characters/  (spritesheety)
│   │   └── ui/          (tekstury interfejsu)
│   └── audio/
├── src/
│   ├── actors/          (sceny gracza, wrogów + skrypty)
│   └── levels/          (sceny poziomów)
```

### 🎯 2. Konfiguracja Importu (Pixel Art vs HD)
Godot stosuje globalne ustawienia importu, które mogą rozmazać Pixel Art lub popsuć kompresję wektorów. Zmień to w zakładce **Import** (obok zakładki Scena):

#### Dla Pixel Art:
1. Kliknij na plik `.png`.
2. W zakładce **Import** zmień **Texture -> Filter** z *Linear* na **Nearest**.
3. Kliknij **Reimport**.
4. *Tip Seniora:* Kliknij przycisk **Preset** -> **Set as Default for 'Texture2D'**, aby każdy kolejny plik Pixel Art importował się automatycznie z ostrymi krawędziami.

#### Dla Grafik HD / Wektorowych (Skalowanych do PNG):
1. Upewnij się, że **Filter** jest ustawiony na **Linear** lub **Mipmaps** (zapobiega to aliasingowi przy oddalaniu kamery).
2. Wyłącz kompresję stratną (VRAM Compression) dla krytycznych elementów UI, zmieniając **Compress -> Mode** na **Lossless**, aby napisy i ikony były idealnie czyste.

### 🧱 3. Wykorzystanie `TileMapLayer` (Nowość w Godot 4.3+)
W starszych wersjach Godota używano jednego monolitu `TileMap`. Seniorzy w Godot 4 wykorzystują dedykowane węzły **TileMapLayer**:
*   **Separacja warstw:** Każda warstwa (Tło, Ziemia, Dekoracje, Kolizje) to osobny węzeł `TileMapLayer` w drzewie sceny. Zwiększa to czytelność kodu i ułatwia dynamiczną modyfikację kafelków ze skryptu.
*   **Fizyka i Tereny:** Zamiast ręcznie układać ściany, skonfiguruj **Terrain Sets** (Auto-tiling). Rysujesz pędzlem, a Godot sam dopasowuje narożniki i krawędzie.

### ⚡ 4. Zarządzanie Pamięcią: Spritesheety vs Pojedyncze Pliki
*   **Dla Animacji Postaci:** Zawsze używaj **Spritesheetów** (jedna duża grafika zawierająca klatki animacji) w połączeniu z węzłem `AnimatedSprite2D` lub `AnimationPlayer` + `Sprite2D`. 
*   **Dlaczego?** Ogranicza to liczbę wywołań rysowania (Draw Calls) i drastycznie przyspiesza renderowanie 2D przez GPU, w przeciwieństwie do ładowania 50 osobnych plików `.png` dla jednej animacji biegu.