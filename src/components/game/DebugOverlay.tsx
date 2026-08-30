import { useEffect, useState } from "react";
import type { LevelScene } from "@/game/phaser/LevelScene";

interface Props {
  getScene: () => LevelScene | null;
}

/**
 * Dev-only perf/state readout — FPS, cat position, active renderQuality,
 * movement flags. Only ever mounted when `import.meta.env.DEV` (see
 * PhaserGameCanvas.tsx); toggled with the backtick key so it doesn't clutter
 * the screen by default even during development.
 *
 * This exists because CLAUDE.md's own lesson from this session was "measure,
 * don't guess" — a live FPS/quality readout is cheaper than reaching for
 * `javascript_tool` + `performance.now()` every time a rendering change
 * needs a quick gut-check.
 */
export function DebugOverlay({ getScene }: Props) {
  const [visible, setVisible] = useState(false);
  const [stats, setStats] = useState<LevelScene["debugStats"] | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "`") setVisible((v) => !v);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (!visible) return;
    const t = setInterval(() => {
      const scene = getScene();
      if (scene) setStats(scene.debugStats);
    }, 250);
    return () => clearInterval(t);
  }, [visible, getScene]);

  if (!visible || !stats) return null;

  return (
    <div className="pointer-events-none fixed bottom-4 left-4 z-50 rounded-lg border border-lime-500/40 bg-black/80 px-3 py-2 font-mono text-[11px] text-lime-400">
      <div>FPS: {stats.fps.toFixed(0)}</div>
      <div>
        pos: {Math.round(stats.pos.x)}, {Math.round(stats.pos.y)}
      </div>
      <div>quality: {stats.renderQuality}</div>
      <div>
        hop: {stats.hopping ? "1" : "0"} sprint: {stats.sprinting ? "1" : "0"} patrol:{" "}
        {stats.patrolCount}
      </div>
      <div className="mt-1 text-lime-400/50">` to hide</div>
    </div>
  );
}
