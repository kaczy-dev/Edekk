import { useEffect, useMemo, useRef, useState } from "react";
import type { LevelDef, QuestStep, Vec2 } from "./types";
import { computeQuests } from "./questUtils";
import { goalProximity } from "./proximity";
import type { Tier } from "./tierStyle";
import { useGameStore } from "@/store/gameStore";

/** Shared cadence and smoothing so the HUD badge and the on-canvas arrows
 *  never disagree about where a goal is or how far away it reads. */
const TICK_MS = 33;
const DIST_RATE = 10;
const ANGLE_RATE = 8;
/** Closer than this, atan2 flips wildly — damp the angle so it eases instead of snapping. */
const ANGLE_DAMP_RADIUS = 80;

/** Shared fallback so absent store entries keep a stable reference across selector calls. */
const NO_IDS: string[] = [];

export type ReachQuest = Extract<QuestStep, { kind: "reach" }>;

export function isReachQuest(q: QuestStep): q is ReachQuest {
  return q.kind === "reach";
}

export function tierFor(dist: number, at: number, near: number, mid: number): Tier {
  return dist <= at ? "at" : dist <= near ? "near" : dist <= mid ? "mid" : "far";
}

export interface GoalTrack {
  id: string;
  /** world-space centre of the goal */
  gx: number;
  gy: number;
  /** smoothed distance in world px */
  dist: number;
  /** smoothed heading in radians, 0 = +X axis */
  angle: number;
  tier: Tier;
  at: number;
  near: number;
  mid: number;
  goalLabel: string;
  ready: boolean;
}

interface Options {
  /** When false the loop stops and tracks clear. */
  enabled?: boolean;
  /** Fired once per goal each time its tier changes. */
  onTierChange?: (track: GoalTrack, previous: Tier | undefined) => void;
}

/** Live distance/direction tracking for every unfinished reach quest. */
export function useGoalTracks(
  level: LevelDef,
  getCatPos: (() => Vec2 | null) | undefined,
  options: Options = {},
): GoalTrack[] {
  const { enabled = true, onTierChange } = options;
  const inventory = useGameStore((s) => s.inventory);
  const talked = useGameStore((s) => s.talkedNpcs[level.id] ?? NO_IDS);
  const completed = useGameStore((s) => s.levelProgress[level.id]?.completed ?? false);
  const collected = useGameStore((s) => s.levelProgress[level.id]?.itemsCollected ?? NO_IDS);
  const proximityScale = useGameStore((s) => s.controls.goalProximityScale);

  const goals = useMemo(() => {
    const statuses = computeQuests(level, {
      inventory,
      talked,
      levelCompleted: completed,
      collected,
    });
    return statuses.flatMap((s) => {
      const quest = s.quest;
      if (s.done) return [];

      if (isReachQuest(quest)) {
        const goal = level.objects.find((o) => o.id === quest.objId);
        if (!goal) return [];
        const p = goalProximity(goal, proximityScale);
        return [
          {
            id: s.quest.id,
            ready: !!s.ready,
            points: [{ x: goal.rect.x + goal.rect.w / 2, y: goal.rect.y + goal.rect.h / 2 }],
            at: p.at,
            near: p.near,
            mid: p.mid,
            goalLabel: p.profile.label,
          },
        ];
      }

      if (quest.kind === "collect") {
        // Point toward the *nearest* remaining instance of this item rather
        // than a fixed spot — picked per-frame in the tick loop below, since
        // "nearest" depends on the live cat position.
        const remaining = level.objects.filter(
          (o) => o.kind === "item" && o.itemId === quest.itemId && !collected.includes(o.id),
        );
        if (remaining.length === 0) return [];
        const sample = remaining[0];
        const p = goalProximity(sample, proximityScale);
        return [
          {
            id: s.quest.id,
            ready: false,
            points: remaining.map((o) => ({
              x: o.rect.x + o.rect.w / 2,
              y: o.rect.y + o.rect.h / 2,
            })),
            at: p.at,
            near: p.near,
            mid: p.mid,
            goalLabel: p.profile.label,
          },
        ];
      }

      return [];
    });
  }, [level, inventory, talked, completed, collected, proximityScale]);

  const [tracks, setTracks] = useState<GoalTrack[]>([]);
  const smoothRef = useRef(new Map<string, { dist: number; angle: number }>());
  const tierRef = useRef(new Map<string, Tier>());
  const tierChangeRef = useRef(onTierChange);
  useEffect(() => {
    tierChangeRef.current = onTierChange;
  });

  useEffect(() => {
    if (!enabled || !getCatPos || goals.length === 0) {
      smoothRef.current.clear();
      tierRef.current.clear();
      setTracks((t) => (t.length ? [] : t));
      return;
    }
    const alive = new Set(goals.map((g) => g.id));
    for (const k of smoothRef.current.keys()) if (!alive.has(k)) smoothRef.current.delete(k);
    for (const k of tierRef.current.keys()) if (!alive.has(k)) tierRef.current.delete(k);

    let raf = 0;
    let last = 0;
    const tick = (t: number) => {
      raf = requestAnimationFrame(tick);
      if (last && t - last < TICK_MS) return;
      const dt = last ? Math.min(0.2, (t - last) / 1000) : 0.016;
      last = t;
      const pos = getCatPos();
      if (!pos) return;

      const distK = 1 - Math.exp(-dt * DIST_RATE);
      const angleK = 1 - Math.exp(-dt * ANGLE_RATE);
      const next = goals.map((g): GoalTrack => {
        // Collect-quest goals carry every remaining instance; re-pick the
        // nearest one each tick since "nearest" moves with the cat.
        let nearest = g.points[0];
        let nearestD = Infinity;
        for (const pt of g.points) {
          const d = Math.hypot(pt.x - pos.x, pt.y - pos.y);
          if (d < nearestD) {
            nearestD = d;
            nearest = pt;
          }
        }
        const rawDist = nearestD;
        const rawAngle = Math.atan2(nearest.y - pos.y, nearest.x - pos.x);
        const prev = smoothRef.current.get(g.id);
        let dist = rawDist;
        let angle = rawAngle;
        if (prev) {
          // Shortest-arc lerp for radians.
          let delta = rawAngle - prev.angle;
          delta = ((delta + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
          const damp = Math.min(1, rawDist / ANGLE_DAMP_RADIUS);
          angle = prev.angle + delta * angleK * damp;
          angle = ((angle + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
          dist = prev.dist + (rawDist - prev.dist) * distK;
        }
        smoothRef.current.set(g.id, { dist, angle });
        return {
          id: g.id,
          ready: g.ready,
          at: g.at,
          near: g.near,
          mid: g.mid,
          goalLabel: g.goalLabel,
          gx: nearest.x,
          gy: nearest.y,
          dist,
          angle,
          tier: tierFor(dist, g.at, g.near, g.mid),
        };
      });

      for (const track of next) {
        const prevTier = tierRef.current.get(track.id);
        if (prevTier !== track.tier) {
          tierRef.current.set(track.id, track.tier);
          tierChangeRef.current?.(track, prevTier);
        }
      }
      setTracks(next);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [goals, getCatPos, enabled]);

  return tracks;
}
