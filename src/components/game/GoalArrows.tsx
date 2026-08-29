import { useCallback, useEffect, useRef } from "react";
import type { LevelDef } from "@/game/types";
import { useGameStore } from "@/store/gameStore";
import { playPing } from "@/lib/ping";
import { useGoalTracks, type GoalTrack } from "@/game/goalTracking";
import { tierStyle } from "@/game/tierStyle";

import type { Tier } from "@/game/tierStyle";

const EDGE_MARGIN = 42;
const TIER_RANK: Record<Tier, number> = { far: 0, mid: 1, near: 2, at: 3 };

interface Props {
  level: LevelDef;
  getCatPos: () => { x: number; y: number } | null;
  getCamera: () => { x: number; y: number; zoom: number } | null;
  containerRef: React.RefObject<HTMLDivElement | null>;
}

/** On-canvas edge-arrows pointing to active reach-quest goals. */
export function GoalArrows({ level, getCatPos, getCamera, containerRef }: Props) {
  const volume = useGameStore((s) => s.volume);
  const muted = useGameStore((s) => s.muted);
  const goalIndicators = useGameStore((s) => s.controls.goalIndicators);
  const colorBlind = useGameStore((s) => s.controls.colorBlindMode);
  const reducedMotion = useGameStore((s) => s.controls.reducedMotion);

  const audioRef = useRef({ volume, muted });
  useEffect(() => {
    audioRef.current = { volume, muted };
  });

  // Audio proximity cues follow the sound settings, not the visual arrow toggle,
  // so turning arrows off still leaves the non-visual cue intact.
  const onTierChange = useCallback((track: GoalTrack, previous: Tier | undefined) => {
    const { volume: vol, muted: mut } = audioRef.current;
    if (mut || !previous || TIER_RANK[track.tier] <= TIER_RANK[previous]) return;
    if (track.tier === "near") playPing(660, 0.045 * vol, 120);
    else if (track.tier === "at") playPing(990, 0.09 * vol, 170);
  }, []);

  const tracks = useGoalTracks(level, getCatPos, { onTierChange });

  const container = containerRef.current;
  const cam = getCamera();
  if (!goalIndicators || !tracks.length || !container || !cam) return null;

  const w = container.clientWidth;
  const h = container.clientHeight;
  const cx = w / 2;
  const cy = h / 2;

  return (
    <div className="pointer-events-none absolute inset-0 z-20">
      {tracks.map((t) => {
        const sx = (t.gx - cam.x) * cam.zoom;
        const sy = (t.gy - cam.y) * cam.zoom;
        const onScreen =
          sx > EDGE_MARGIN && sx < w - EDGE_MARGIN && sy > EDGE_MARGIN && sy < h - EDGE_MARGIN;

        let x = sx;
        let y = sy;
        if (!onScreen) {
          // Clamp the marker to the viewport edge along the direction of the goal.
          const rx = sx - cx;
          const ry = sy - cy;
          const scale = Math.min(
            Math.abs(rx) > 0.001 ? (cx - EDGE_MARGIN) / Math.abs(rx) : Infinity,
            Math.abs(ry) > 0.001 ? (cy - EDGE_MARGIN) / Math.abs(ry) : Infinity
          );
          x = cx + rx * scale;
          y = cy + ry * scale;
        }

        const angle = (t.angle * 180) / Math.PI + 90;
        const steps = Math.max(1, Math.round(t.dist / 32));
        const atStep = Math.max(1, Math.round(t.at / 32));
        const palette = tierStyle(t.tier, colorBlind);
        const scaleCls = t.tier === "at" ? "scale-125" : t.tier === "near" ? "scale-110" : "scale-100";
        const showGlow = t.tier === "at" || t.tier === "near";
        const label =
          t.tier === "at" ? "tuż obok" : t.dist <= t.at * 1.4 ? `~${atStep} kr.` : `${steps} kr.`;

        return (
          <div
            key={t.id}
            style={{
              transform: `translate(${x}px, ${y}px) translate(-50%, -50%) rotate(${angle}deg)`,
              transition: reducedMotion ? "none" : "transform 220ms cubic-bezier(0.22, 1, 0.36, 1)",
            }}
            className={["absolute left-0 top-0", reducedMotion ? "" : "animate-fade-in"].join(" ")}
          >
            <div
              className={[
                ["relative grid h-10 w-10 place-items-center", reducedMotion ? "" : "transition-transform duration-200"].join(" "),
                scaleCls,
              ].join(" ")}
            >
              {showGlow && (
                <span
                  aria-hidden
                  className={[
                    ["absolute inset-0 rounded-full blur-md", reducedMotion ? "" : "animate-pulse"].join(" "),
                    palette.glow,
                  ].join(" ")}
                />
              )}
              <svg
                viewBox="0 0 24 24"
                className={[
                  ["relative h-9 w-9 drop-shadow-[0_2px_6px_rgba(0,0,0,0.6)]", reducedMotion ? "" : "transition-opacity duration-200"].join(" "),
                  onScreen ? "opacity-80" : "opacity-95",
                ].join(" ")}
              >
                <path
                  d={palette.path}
                  fill={palette.fill}
                  stroke="rgba(0,0,0,0.55)"
                  strokeWidth="1.2"
                  strokeLinejoin="round"
                  strokeDasharray={palette.dash}
                />
              </svg>
              <span
                style={{ transform: `rotate(${-angle}deg)`, transition: reducedMotion ? "none" : "transform 220ms cubic-bezier(0.22, 1, 0.36, 1)" }}
                className={[
                  "absolute -bottom-4 rounded-full border bg-black/75 px-1.5 py-[1px] text-[9px] font-bold tabular-nums backdrop-blur-sm",
                  palette.chip,
                ].join(" ")}
              >
                {palette.glyph ? <span aria-hidden>{palette.glyph} </span> : null}
                {label}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
