import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { TIER_ORDER, tierStyle } from "@/game/tierStyle";
import { GOAL_PROXIMITY, PROXIMITY_SCALE_RANGE, type GoalArchetype } from "@/game/proximity";
import { useGameStore, DIFFICULTIES } from "@/store/gameStore";
import type { JoystickSide, SprintMode, TouchControl, Difficulty, ArrowAnimation } from "@/store/gameStore";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Switch } from "@/components/ui/switch";
import { Slider } from "@/components/ui/slider";
import { SegmentedControl } from "@/components/ui/segmented-control";

export const Route = createFileRoute("/ustawienia")({
  head: () => ({
    meta: [
      { title: "Ustawienia — Przygody Edka" },
      { name: "description", content: "Dostosuj sterowanie, poziom trudności i dźwięk w grze o kocie Edku." },
    ],
  }),
  component: SettingsPage,
});

function SettingsPage() {
  const { volume, setVolume, muted, setMuted, controls, setControls, resetControls, resetProgress, difficulty, setDifficulty, save } =
    useGameStore();
  const navigate = useNavigate();
  const [pendingDifficulty, setPendingDifficulty] = useState<Difficulty | null>(null);

  return (
    <main className="min-h-[100dvh] px-6 py-16">
      <div className="mx-auto max-w-xl">
        <Link to="/menu" className="text-sm text-muted-foreground transition hover:text-foreground active:opacity-60">
          ← Menu
        </Link>
        <h1 className="mt-6 font-display text-5xl font-bold">Ustawienia</h1>

        {/* Difficulty */}
        <section className="mt-10 space-y-4 rounded-3xl border border-border bg-card p-6">
          <div>
            <h2 className="font-display text-xl font-semibold">Poziom trudności</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Wpływa na zużycie energii, siłę biegu i szkody od pszczół. Zmiana resetuje bieżący autozapis.
            </p>
          </div>
          <div className="grid grid-cols-3 gap-2">
            {(Object.keys(DIFFICULTIES) as Difficulty[]).map((d) => {
              const cfg = DIFFICULTIES[d];
              const active = difficulty === d;
              return (
                <button
                  key={d}
                  onClick={() => {
                    if (active) return;
                    if (save) {
                      setPendingDifficulty(d);
                    } else {
                      setDifficulty(d);
                    }
                  }}
                  className={[
                    "rounded-2xl border px-3 py-3 text-sm font-semibold transition text-left active:scale-[0.97]",
                    active
                      ? "border-honey bg-honey/15 text-foreground"
                      : "border-border bg-muted/40 text-muted-foreground hover:text-foreground hover:border-honey/30",
                  ].join(" ")}
                >
                  <div className="text-base">{cfg.label}</div>
                  <div className="mt-1 text-[10px] font-normal uppercase tracking-wider text-muted-foreground">
                    Start {cfg.startEnergy} · bieg ×{cfg.sprintDrainMul}
                  </div>
                </button>
              );
            })}
          </div>
        </section>

        <AlertDialog open={pendingDifficulty !== null} onOpenChange={(o) => !o && setPendingDifficulty(null)}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Zmienić trudność?</AlertDialogTitle>
              <AlertDialogDescription>
                Masz aktywny zapis w trakcie poziomu. Zmiana trudności skasuje ten zapis i będziesz
                musiał zacząć poziom od nowa.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel onClick={() => setPendingDifficulty(null)}>Anuluj</AlertDialogCancel>
              <AlertDialogAction
                onClick={() => {
                  if (pendingDifficulty) setDifficulty(pendingDifficulty);
                  setPendingDifficulty(null);
                }}
              >
                Tak, zmień trudność
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        {/* Render quality (Phaser levels) */}
        <section className="mt-10 space-y-4 rounded-3xl border border-border bg-card p-6">
          <div>
            <h2 className="font-display text-xl font-semibold">Jakość grafiki</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Steruje gęstością cząstek, świateł i efektów kamery. Obniż na słabszym urządzeniu.
            </p>
          </div>
          <div className="grid grid-cols-4 gap-2">
            {(["low", "medium", "high", "ultra"] as const).map((q) => {
              const active = controls.renderQuality === q;
              const labels: Record<typeof q, string> = { low: "Niska", medium: "Średnia", high: "Wysoka", ultra: "Ultra" };
              return (
                <button
                  key={q}
                  onClick={() => setControls({ renderQuality: q })}
                  className={[
                    "rounded-2xl border px-2 py-3 text-sm font-semibold transition active:scale-[0.97]",
                    active
                      ? "border-honey bg-honey/15 text-foreground"
                      : "border-border bg-muted/40 text-muted-foreground hover:text-foreground hover:border-honey/30",
                  ].join(" ")}
                >
                  {labels[q]}
                </button>
              );
            })}
          </div>
        </section>

        <section className="mt-10 space-y-6 rounded-3xl border border-border bg-card p-6">
          <h2 className="font-display text-xl font-semibold">Dźwięk</h2>
          <div>
            <label className="flex items-center justify-between text-sm font-medium">
              Głośność
              <span className="text-muted-foreground">{Math.round(volume * 100)}%</span>
            </label>
            <div className="mt-3">
              <Slider
                min={0}
                max={1}
                step={0.05}
                value={[volume]}
                onValueChange={(value) => setVolume(value[0])}
              />
            </div>
          </div>

          <div className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Wyciszenie</span>
            <Switch
              checked={muted}
              onCheckedChange={setMuted}
            />
          </div>
        </section>

        {/* Controls */}
        <section className="mt-6 space-y-6 rounded-3xl border border-border bg-card p-6">
          <div className="flex items-center justify-between">
            <h2 className="font-display text-xl font-semibold">Sterowanie</h2>
            <AlertDialog>
              <AlertDialogTrigger className="text-xs text-muted-foreground underline-offset-2 transition hover:text-foreground hover:underline">
                Przywróć domyślne
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Przywrócić ustawienia sterowania?</AlertDialogTitle>
                  <AlertDialogDescription>
                    Wszystkie zmiane ustawień sterowania zostaną anulowane.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Anuluj</AlertDialogCancel>
                  <AlertDialogAction onClick={resetControls}>
                    Przywróć
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>

          <div>
            <label className="flex items-center justify-between text-sm font-medium">
              Czułość ruchu
              <span className="text-muted-foreground">{controls.sensitivity.toFixed(2)}×</span>
            </label>
            <div className="mt-3">
              <Slider
                min={0.5}
                max={1.5}
                step={0.05}
                value={[controls.sensitivity]}
                onValueChange={(value) => setControls({ sensitivity: value[0] })}
              />
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              Wpływa na maksymalną prędkość Edka.
            </p>
          </div>

          <div>
            <p className="text-sm font-medium">Tryb biegu (Shift / BIEG)</p>
            <div className="mt-3">
              <SegmentedControl
                options={[
                  { value: "hold" as SprintMode, label: "Trzymaj" },
                  { value: "toggle" as SprintMode, label: "Przełącz" },
                ]}
                value={controls.sprintMode}
                onChange={(mode) => setControls({ sprintMode: mode })}
              />
            </div>
          </div>

          <div>
            <p className="text-sm font-medium">Sterowanie mobilne</p>
            <div className="mt-3">
              <SegmentedControl
                options={[
                  { value: "stick" as TouchControl, label: "🕹️ Joystick" },
                  { value: "dpad" as TouchControl, label: "✚ D-Pad" },
                ]}
                value={controls.touchControl}
                onChange={(mode) => setControls({ touchControl: mode })}
              />
            </div>
            <p className="mt-2 text-xs text-muted-foreground">
              Joystick — płynny analog. D-Pad — 4 kierunkowe przyciski.
            </p>
          </div>

          <div>
            <p className="text-sm font-medium">Strona sterowania (mobile)</p>
            <div className="mt-3">
              <SegmentedControl
                options={[
                  { value: "left" as JoystickSide, label: "Po lewej" },
                  { value: "right" as JoystickSide, label: "Po prawej" },
                ]}
                value={controls.joystickSide}
                onChange={(side) => setControls({ joystickSide: side })}
              />
            </div>
          </div>

          <div className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Odwróć oś pionową (Y)</span>
            <Switch
              checked={controls.invertY}
              onCheckedChange={(checked) => setControls({ invertY: checked })}
            />
          </div>

          <div className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Wibracja przy uderzeniu</span>
            <Switch
              checked={controls.vibration}
              onCheckedChange={(checked) => setControls({ vibration: checked })}
            />
          </div>

          <div className="flex items-center justify-between gap-4 rounded-2xl bg-muted/50 px-4 py-3">
            <span>
              <span className="block text-sm font-medium">Pokazuj podpowiedzi sterowania</span>
            </span>
            <Switch
              checked={controls.showHints}
              onCheckedChange={(checked) => setControls({ showHints: checked })}
            />
          </div>

          <div className="mt-3 flex items-center justify-between gap-4 rounded-2xl bg-muted/50 px-4 py-3">
            <span>
              <span className="block text-sm font-medium">Wskaźniki celu (strzałka i dystans)</span>
              <span className="mt-1 block text-xs text-muted-foreground">
                Obracające się strzałki i licznik kroków dla zadań „dotrzyj do celu". Wyłącz, jeśli
                jesteś wrażliwy na ruch — cele nadal opisane są w liście zadań.
              </span>
            </span>
            <Switch
              checked={controls.goalIndicators}
              onCheckedChange={(checked) => setControls({ goalIndicators: checked })}
            />
          </div>

          <div className="mt-3 flex items-center justify-between gap-4 rounded-2xl bg-muted/50 px-4 py-3">
            <span>
              <span className="block text-sm font-medium">Ograniczony ruch</span>
              <span className="mt-1 block text-xs text-muted-foreground">
                Wyłącza pulsujące poświaty i płynne przejścia („ease") wskaźników celu — strzałki i
                dystanse zmieniają się natychmiast, bez animacji.
              </span>
            </span>
            <Switch
              checked={controls.reducedMotion}
              onCheckedChange={(checked) => setControls({ reducedMotion: checked })}
            />
          </div>

          <div className="mt-3 rounded-2xl bg-muted/50 px-4 py-3">
            <label className="flex items-center justify-between text-sm font-medium">
              Automatyczne zwijanie legendy dystansu
              <span className="text-muted-foreground">
                {controls.legendAutoCollapseSec <= 0
                  ? "Nigdy"
                  : `${controls.legendAutoCollapseSec.toFixed(1)} s`}
              </span>
            </label>
            <div className="mt-3">
              <Slider
                min={0}
                max={15}
                step={0.5}
                value={[controls.legendAutoCollapseSec]}
                onValueChange={(value) => setControls({ legendAutoCollapseSec: value[0] })}
              />
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              Po tym czasie legenda kolorów dystansu na HUD zwija się do małego przycisku. Ustaw 0,
              żeby legenda była zawsze rozwinięta.
            </p>
          </div>

          <div className="mt-3 flex items-center justify-between gap-4 rounded-2xl bg-muted/50 px-4 py-3">
            <span>
              <span className="block text-sm font-medium">Tryb dla daltonistów</span>
              <span className="mt-1 block text-xs text-muted-foreground">
                Dystans do celu pokazywany jest kształtem, wzorem obrysu i symbolem, a nie samym
                kolorem. Używa palety bezpiecznej dla zaburzeń widzenia barw.
              </span>
              {controls.colorBlindMode && (
                <span className="mt-2 flex flex-wrap gap-2">
                  {TIER_ORDER.map((t) => {
                    const st = tierStyle(t, true);
                    return (
                      <span
                        key={t}
                        className="inline-flex items-center gap-1 rounded-full border px-2 py-[2px] text-[11px] font-semibold"
                        style={{ borderColor: st.swatch, color: st.swatch }}
                      >
                        <span>{st.glyph}</span>
                        {st.label}
                      </span>
                    );
                  })}
                </span>
              )}
            </span>
            <Switch
              checked={controls.colorBlindMode}
              onCheckedChange={(checked) => setControls({ colorBlindMode: checked })}
            />
          </div>

          {controls.goalIndicators && (
            <>
              <div className="mt-3">
                <p className="text-sm font-medium">Animacja strzałek do celu</p>
                <div className="mt-3">
                  <SegmentedControl
                    options={[
                      { value: "smooth" as const, label: "Płynna" },
                      { value: "snap" as const, label: "Skok" },
                      { value: "off" as const, label: "Brak" },
                    ]}
                    value={controls.arrowAnimation}
                    onChange={(anim) => setControls({ arrowAnimation: anim })}
                  />
                </div>
                <p className="mt-1 text-xs text-muted-foreground">
                  Płynna: rotacja ze wskazówkami. Skok: natychmiast bez animacji. Brak: wyłącz strzałki (pozostają dane dystansu).
                </p>
              </div>

              <div className="mt-3 rounded-2xl bg-muted/50 px-4 py-3">
                <label className="flex items-center justify-between text-sm font-medium">
                  Kalibracja progu „tuż obok"
                <span className="text-muted-foreground">
                  {controls.goalProximityScale.toFixed(2)}×
                </span>
              </label>
              <div className="mt-3">
                <Slider
                  min={PROXIMITY_SCALE_RANGE.min}
                  max={PROXIMITY_SCALE_RANGE.max}
                  step={PROXIMITY_SCALE_RANGE.step}
                  value={[controls.goalProximityScale]}
                  onValueChange={(value) =>
                    setControls({ goalProximityScale: value[0] })
                  }
                />
              </div>
              <p className="mt-1 text-xs text-muted-foreground">
                Skaluje wszystkie progi. Bazowy zasięg zależy od rozmiaru i typu celu:
              </p>
              <ul className="mt-2 grid gap-1 text-xs text-muted-foreground">
                {(Object.keys(GOAL_PROXIMITY) as GoalArchetype[]).map((k) => {
                  const p = GOAL_PROXIMITY[k];
                  const lo = Math.round((p.min * controls.goalProximityScale) / 32);
                  const hi = Math.round((p.max * controls.goalProximityScale) / 32);
                  return (
                    <li key={k} className="flex items-center justify-between gap-3">
                      <span>{p.label}</span>
                      <span className="tabular-nums">
                        {lo}–{hi} kr.
                      </span>
                    </li>
                  );
                })}
              </ul>
              </div>
            </>
          )}
        </section>


        {/* Progress */}
        <section className="mt-6 rounded-3xl border border-border bg-card p-6">
          <AlertDialog>
            <AlertDialogTrigger className="w-full rounded-2xl border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm font-semibold text-destructive transition hover:bg-destructive/20">
              Zresetuj postęp gry
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Zresetować cały postęp?</AlertDialogTitle>
                <AlertDialogDescription>
                  Stracisz ukończone poziomy, zebrane przedmioty i zapis gry. Odblokowany
                  zostanie ponownie tylko pierwszy poziom. Tej operacji nie można cofnąć.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Anuluj</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => {
                    resetProgress();
                    navigate({ to: "/menu" });
                  }}
                >
                  Tak, zresetuj
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </section>
      </div>
    </main>
  );
}
