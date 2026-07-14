import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useGameStore, DIFFICULTIES } from "@/store/gameStore";
import type { JoystickSide, SprintMode, TouchControl, Difficulty } from "@/store/gameStore";

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
  const { volume, setVolume, muted, setMuted, controls, setControls, resetControls, resetProgress, difficulty, setDifficulty } =
    useGameStore();
  const navigate = useNavigate();

  return (
    <main className="min-h-[100dvh] px-6 py-16">
      <div className="mx-auto max-w-xl">
        <Link to="/menu" className="text-sm text-muted-foreground transition hover:text-foreground">
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
                  onClick={() => setDifficulty(d)}
                  className={[
                    "rounded-2xl border px-3 py-3 text-sm font-semibold transition text-left",
                    active
                      ? "border-honey bg-honey/15 text-foreground"
                      : "border-border bg-muted/40 text-muted-foreground hover:text-foreground",
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
        <section className="mt-10 space-y-6 rounded-3xl border border-border bg-card p-6">
          <h2 className="font-display text-xl font-semibold">Dźwięk</h2>
          <div>
            <label className="flex items-center justify-between text-sm font-medium">
              Głośność
              <span className="text-muted-foreground">{Math.round(volume * 100)}%</span>
            </label>
            <input
              type="range"
              min={0}
              max={1}
              step={0.05}
              value={volume}
              onChange={(e) => setVolume(parseFloat(e.target.value))}
              className="mt-3 w-full accent-primary"
            />
          </div>

          <label className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Wyciszenie</span>
            <input
              type="checkbox"
              checked={muted}
              onChange={(e) => setMuted(e.target.checked)}
              className="h-5 w-5 accent-primary"
            />
          </label>
        </section>

        {/* Controls */}
        <section className="mt-6 space-y-6 rounded-3xl border border-border bg-card p-6">
          <div className="flex items-center justify-between">
            <h2 className="font-display text-xl font-semibold">Sterowanie</h2>
            <button
              onClick={resetControls}
              className="text-xs text-muted-foreground underline-offset-2 transition hover:text-foreground hover:underline"
            >
              Przywróć domyślne
            </button>
          </div>

          <div>
            <label className="flex items-center justify-between text-sm font-medium">
              Czułość ruchu
              <span className="text-muted-foreground">{controls.sensitivity.toFixed(2)}×</span>
            </label>
            <input
              type="range"
              min={0.5}
              max={1.5}
              step={0.05}
              value={controls.sensitivity}
              onChange={(e) => setControls({ sensitivity: parseFloat(e.target.value) })}
              className="mt-3 w-full accent-primary"
            />
            <p className="mt-1 text-xs text-muted-foreground">
              Wpływa na maksymalną prędkość Edka.
            </p>
          </div>

          <div>
            <p className="text-sm font-medium">Tryb biegu (Shift / BIEG)</p>
            <div className="mt-3 grid grid-cols-2 gap-2">
              {(["hold", "toggle"] as SprintMode[]).map((mode) => (
                <button
                  key={mode}
                  onClick={() => setControls({ sprintMode: mode })}
                  className={[
                    "rounded-2xl border px-4 py-3 text-sm font-medium transition",
                    controls.sprintMode === mode
                      ? "border-primary bg-primary/15 text-foreground"
                      : "border-border bg-muted/40 text-muted-foreground hover:text-foreground",
                  ].join(" ")}
                >
                  {mode === "hold" ? "Trzymaj" : "Przełącz"}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="text-sm font-medium">Sterowanie mobilne</p>
            <div className="mt-3 grid grid-cols-2 gap-2">
              {(["stick", "dpad"] as TouchControl[]).map((mode) => (
                <button
                  key={mode}
                  onClick={() => setControls({ touchControl: mode })}
                  className={[
                    "rounded-2xl border px-4 py-3 text-sm font-medium transition",
                    controls.touchControl === mode
                      ? "border-primary bg-primary/15 text-foreground"
                      : "border-border bg-muted/40 text-muted-foreground hover:text-foreground",
                  ].join(" ")}
                >
                  {mode === "stick" ? "🕹️ Joystick" : "✚ D-Pad"}
                </button>
              ))}
            </div>
            <p className="mt-2 text-xs text-muted-foreground">
              Joystick — płynny analog. D-Pad — 4 kierunkowe przyciski.
            </p>
          </div>

          <div>
            <p className="text-sm font-medium">Strona sterowania (mobile)</p>
            <div className="mt-3 grid grid-cols-2 gap-2">
              {(["left", "right"] as JoystickSide[]).map((side) => (
                <button
                  key={side}
                  onClick={() => setControls({ joystickSide: side })}
                  className={[
                    "rounded-2xl border px-4 py-3 text-sm font-medium transition",
                    controls.joystickSide === side
                      ? "border-primary bg-primary/15 text-foreground"
                      : "border-border bg-muted/40 text-muted-foreground hover:text-foreground",
                  ].join(" ")}
                >
                  {side === "left" ? "Po lewej" : "Po prawej"}
                </button>
              ))}
            </div>
          </div>

          <label className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Odwróć oś pionową (Y)</span>
            <input
              type="checkbox"
              checked={controls.invertY}
              onChange={(e) => setControls({ invertY: e.target.checked })}
              className="h-5 w-5 accent-primary"
            />
          </label>

          <label className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Wibracja przy uderzeniu</span>
            <input
              type="checkbox"
              checked={controls.vibration}
              onChange={(e) => setControls({ vibration: e.target.checked })}
              className="h-5 w-5 accent-primary"
            />
          </label>

          <label className="flex items-center justify-between rounded-2xl bg-muted/50 px-4 py-3">
            <span className="text-sm font-medium">Pokazuj podpowiedzi sterowania</span>
            <input
              type="checkbox"
              checked={controls.showHints}
              onChange={(e) => setControls({ showHints: e.target.checked })}
              className="h-5 w-5 accent-primary"
            />
          </label>
        </section>

        {/* Progress */}
        <section className="mt-6 rounded-3xl border border-border bg-card p-6">
          <button
            onClick={() => {
              if (confirm("Na pewno zresetować cały postęp?")) {
                resetProgress();
                navigate({ to: "/menu" });
              }
            }}
            className="w-full rounded-2xl border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm font-semibold text-destructive transition hover:bg-destructive/20"
          >
            Zresetuj postęp gry
          </button>
        </section>
      </div>
    </main>
  );
}
