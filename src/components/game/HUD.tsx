import { useGameStore, DIFFICULTIES } from "@/store/gameStore";
import { ITEMS } from "@/game/items";
import type { ItemId, LevelDef } from "@/game/types";
import { computeQuests, questCompletion, type QuestStatus } from "@/game/questUtils";
import { useGoalTracks, type GoalTrack } from "@/game/goalTracking";
import { TIER_ORDER, tierStyle } from "@/game/tierStyle";
import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useMemo, useRef, useState } from "react";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

/** Stable fallback so absent store entries keep one reference across selector calls. */
const NO_IDS: string[] = [];

interface Props {
  level: LevelDef;
  onPause: () => void;
  sprinting?: boolean;
  getCatPos?: () => { x: number; y: number } | null;
  onShowControls?: () => void;
}

export function HUD({ level, onPause, sprinting, getCatPos, onShowControls }: Props) {
  const energy = useGameStore((s) => s.energy);
  const inventory = useGameStore((s) => s.inventory);
  const talked = useGameStore((s) => s.talkedNpcs[level.id] ?? NO_IDS);
  const completed = useGameStore((s) => s.levelProgress[level.id]?.completed ?? false);
  const collected = useGameStore((s) => s.levelProgress[level.id]?.itemsCollected ?? NO_IDS);
  const difficulty = useGameStore((s) => s.difficulty);
  const levelStartedAt = useGameStore((s) => s.levelStartedAt);
  const bestTime = useGameStore((s) => s.bestLevelTimes[level.id]);
  const goalIndicators = useGameStore((s) => s.controls.goalIndicators);
  const colorBlind = useGameStore((s) => s.controls.colorBlindMode);
  const legendAutoCollapseSec = useGameStore((s) => s.controls.legendAutoCollapseSec);
  const legendExpanded = useGameStore((s) => s.controls.legendExpanded);
  const setControls = useGameStore((s) => s.setControls);
  const [open, setOpen] = useState(true);
  const [expandedQuest, setExpandedQuest] = useState<string | null>(null);
  const [onlyActive, setOnlyActive] = useState(false);

  // Auto-collapse the legend after a configurable grace period (0 = never).
  // Manual toggling cancels the timer for this session and is persisted.
  useEffect(() => {
    if (!goalIndicators || legendAutoCollapseSec <= 0 || !legendExpanded) return;
    const t = setTimeout(
      () => setControls({ legendExpanded: false }),
      legendAutoCollapseSec * 1000,
    );
    return () => clearTimeout(t);
  }, [goalIndicators, legendAutoCollapseSec, legendExpanded, setControls]);

  // Speedrun timer: a 1s tick is plenty for a readable clock and avoids
  // re-rendering the whole HUD every frame for a number nobody needs to the ms.
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!levelStartedAt) return;
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, [levelStartedAt]);
  const elapsedMs = levelStartedAt ? now - levelStartedAt : 0;

  const statuses = useMemo(
    () => computeQuests(level, { inventory, talked, levelCompleted: completed, collected }),
    [level, inventory, talked, completed, collected],
  );
  const { done, total } = questCompletion(statuses);
  const allDone = done === total;

  // Track "just completed" quests to flash them.
  const prevDoneRef = useRef<Set<string>>(new Set());
  const [flashIds, setFlashIds] = useState<Set<string>>(new Set());
  useEffect(() => {
    const prev = prevDoneRef.current;
    const nowDone = new Set(statuses.filter((s) => s.done).map((s) => s.quest.id));
    const justDone: string[] = [];
    nowDone.forEach((id) => {
      if (!prev.has(id)) justDone.push(id);
    });
    prevDoneRef.current = nowDone;
    if (!justDone.length) return;
    setFlashIds(new Set(justDone));
    const t = setTimeout(() => setFlashIds(new Set()), 1400);
    return () => clearTimeout(t);
  }, [statuses]);

  // Auto-open the checklist briefly when a quest completes so the tick is visible.
  useEffect(() => {
    if (flashIds.size > 0) setOpen(true);
  }, [flashIds]);

  // Live tracker: distance + direction from cat to each reach-quest goal.
  // Runs even with goalIndicators off — the textual tier badge is the
  // motion-free alternative to the on-canvas arrows.
  const tracks = useGoalTracks(level, getCatPos, { enabled: open });
  const trackById = useMemo(() => {
    const map: Record<string, GoalTrack> = {};
    for (const t of tracks) map[t.id] = t;
    return map;
  }, [tracks]);

  return (
    <div className="pointer-events-none absolute inset-0 z-30 flex flex-col p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="pointer-events-auto max-w-[78vw] rounded-2xl border border-white/10 bg-black/45 backdrop-blur-md">
          <button
            onClick={() => setOpen((o) => !o)}
            className="flex w-full items-center justify-between gap-4 px-4 py-2.5 text-left"
            aria-expanded={open}
          >
            <div className="min-w-0">
              <h2 className="font-display text-base font-semibold text-honey md:text-lg truncate">
                {level.title}
              </h2>
              <p className="text-[11px] uppercase tracking-widest text-white/50">
                Zadania {done}/{total}
                <span className="mx-1.5 text-white/30">·</span>
                <span className="text-honey/80">{DIFFICULTIES[difficulty].label}</span>
                {levelStartedAt && (
                  <>
                    <span className="mx-1.5 text-white/30">·</span>
                    {/* Green while still ahead of the standing best time — a live
                        "you're on pace for a record" cue, not just a plain clock. */}
                    <span
                      className={[
                        "tabular-nums",
                        bestTime && elapsedMs < bestTime
                          ? "font-semibold text-green-400"
                          : "text-white/70",
                      ].join(" ")}
                      title={bestTime ? `Najlepszy czas: ${formatElapsed(bestTime)}` : undefined}
                    >
                      ⏱ {formatElapsed(elapsedMs)}
                      {bestTime !== undefined && elapsedMs < bestTime && " 🏆"}
                    </span>
                  </>
                )}
                {allDone && (
                  <span className="ml-2 rounded-full bg-honey/20 px-1.5 py-[1px] text-[9px] font-bold text-honey">
                    Wszystko!
                  </span>
                )}
              </p>
              {/* Overall progress bar */}
              <div className="mt-1.5 h-[3px] w-40 max-w-full overflow-hidden rounded-full bg-white/10">
                <motion.div
                  className="h-full rounded-full bg-honey"
                  initial={false}
                  animate={{ width: `${total ? (done / total) * 100 : 0}%` }}
                  transition={{ type: "spring", stiffness: 120, damping: 20 }}
                />
              </div>
            </div>
            <span className="text-white/60 text-xs">{open ? "▾" : "▸"}</span>
          </button>
          <AnimatePresence initial={false}>
            {open && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: "auto", opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.2 }}
                className="overflow-hidden border-t border-white/10"
              >
                <div className="flex items-center justify-between gap-2 px-4 pt-2">
                  <span className="text-[10px] uppercase tracking-widest text-white/40">
                    {onlyActive ? "Tylko aktywne" : "Wszystkie"}
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setOnlyActive((v) => !v);
                    }}
                    aria-pressed={onlyActive}
                    className={[
                      "rounded-full border px-2 py-[2px] text-[10px] font-semibold uppercase tracking-wider transition",
                      onlyActive
                        ? "border-honey bg-honey/20 text-honey"
                        : "border-white/20 text-white/60 hover:border-honey/50 hover:text-honey",
                    ].join(" ")}
                  >
                    Tylko aktywne
                  </button>
                </div>
                <ul className="px-4 pb-2 pt-1 text-[13px]">
                  {(() => {
                    const visible = onlyActive ? statuses.filter((s) => !s.done) : statuses;
                    if (visible.length === 0) {
                      return (
                        <li className="px-1 py-2 text-[11px] text-white/50">
                          {onlyActive ? "Wszystkie zadania ukończone 🎉" : "Brak zadań."}
                        </li>
                      );
                    }
                    return visible.map((s) => (
                      <QuestRow
                        key={s.quest.id}
                        status={s}
                        flash={flashIds.has(s.quest.id)}
                        expanded={expandedQuest === s.quest.id}
                        onToggle={() =>
                          setExpandedQuest((cur) => (cur === s.quest.id ? null : s.quest.id))
                        }
                        tracker={trackById[s.quest.id]}
                      />
                    ));
                  })()}
                </ul>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        <div className="flex gap-2">
          {onShowControls && (
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger asChild>
                  <button
                    onClick={onShowControls}
                    className="pointer-events-auto rounded-full border border-white/15 bg-black/45 px-3 py-2 text-sm font-medium text-white/70 backdrop-blur-md transition hover:bg-black/60 hover:text-white active:scale-95"
                    aria-label="Pokaż sterowanie"
                  >
                    ?
                  </button>
                </TooltipTrigger>
                <TooltipContent>Sterowanie i podpowiedzi</TooltipContent>
              </Tooltip>
            </TooltipProvider>
          )}
          <button
            onClick={onPause}
            className="pointer-events-auto rounded-full border border-white/15 bg-black/45 px-4 py-2 text-sm font-medium text-white backdrop-blur-md transition hover:bg-black/60 active:scale-95"
          >
            Pauza
          </button>
        </div>
      </div>

      <div
        className={[
          "mt-3 pointer-events-auto w-56 max-w-[60vw] rounded-2xl border bg-black/40 p-1.5 backdrop-blur-md transition",
          energy < 30 ? "border-red-500/60 bg-red-950/20" : "border-white/10",
        ].join(" ")}
      >
        <div className="relative h-3 overflow-hidden rounded-full bg-white/10">
          <motion.div
            className="absolute inset-y-0 left-0 rounded-full"
            style={{
              background:
                energy < 30
                  ? `linear-gradient(90deg, #dc2626, #ef4444)`
                  : sprinting
                    ? `linear-gradient(90deg, #ff8a5b, var(--color-honey))`
                    : `linear-gradient(90deg, var(--color-amber), var(--color-honey))`,
            }}
            animate={{ width: `${energy}%` }}
            transition={{ type: "spring", stiffness: 80, damping: 20 }}
          />
        </div>
        <div className="mt-1 flex items-center justify-between px-2 text-[10px] uppercase tracking-widest text-white/60">
          <span className={energy < 30 ? "text-red-400 font-semibold" : ""}>
            Energia · {Math.round(energy)}
          </span>
          {energy < 30 && (
            <span className="rounded-full bg-red-500/20 px-2 py-0.5 text-[9px] font-bold text-red-400 animate-pulse">
              Zmęczenie
            </span>
          )}
          {sprinting && energy >= 30 && (
            <span className="rounded-full bg-honey/20 px-2 py-0.5 text-[9px] font-bold text-honey">
              BIEG
            </span>
          )}
        </div>
      </div>

      <div className="flex-1" />

      {/* Distance legend for reach-quest arrows — auto-collapses after a few seconds. */}
      {goalIndicators && (
        <div className="pointer-events-auto mb-2 self-start rounded-2xl border border-white/10 bg-black/50 p-2 backdrop-blur-md max-w-xs sm:max-w-none">
          <AnimatePresence initial={false} mode="wait">
            {legendExpanded ? (
              <motion.div
                key="legend"
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -10, height: 0 }}
                transition={{ duration: 0.2 }}
              >
                <div className="mb-1 flex items-center justify-between gap-3">
                  <span className="text-[10px] font-semibold uppercase tracking-wider text-white/70">
                    Dystans do celu
                  </span>
                  <button
                    onClick={() => setControls({ legendExpanded: false })}
                    aria-label="Zwiń legendę"
                    className="grid h-4 w-4 place-items-center rounded-full text-[10px] text-white/50 transition hover:bg-white/10 hover:text-white"
                  >
                    ×
                  </button>
                </div>
                <div className="flex flex-col gap-1 sm:gap-2 sm:flex-wrap sm:flex-row">
                  {TIER_ORDER.map((tier) => {
                    const st = tierStyle(tier, colorBlind);
                    const descriptions: Record<typeof tier, string> = {
                      at: "Tuż obok celu",
                      near: "Niedaleko, powinieneś być blisko",
                      mid: "Średni dystans do pokonania",
                      far: "Daleko, musisz się wiele poruszać",
                    };
                    return (
                      <TooltipProvider key={tier}>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <div className="flex items-center gap-1 sm:gap-1.5 text-[9px] sm:text-[10px] cursor-help">
                              <LegendSwatch shape={st.swatchShape} color={st.swatch} />
                              <span className="text-white/80 whitespace-nowrap">
                                {st.glyph ? `${st.glyph} ` : ""}
                                {st.label}
                              </span>
                            </div>
                          </TooltipTrigger>
                          <TooltipContent>{descriptions[tier]}</TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    );
                  })}
                </div>
              </motion.div>
            ) : (
              <motion.button
                key="legend-toggle"
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.9 }}
                transition={{ duration: 0.2 }}
                onClick={() => setControls({ legendExpanded: true })}
                aria-label="Pokaż legendę dystansu"
                className="flex items-center gap-1.5 rounded-full px-2 py-1 text-[10px] font-semibold text-white/70 transition hover:bg-white/10 hover:text-white"
              >
                <LegendSwatch
                  shape={tierStyle("near", colorBlind).swatchShape}
                  color={tierStyle("near", colorBlind).swatch}
                />
                Legenda dystansu
              </motion.button>
            )}
          </AnimatePresence>
        </div>
      )}

      <div className="pointer-events-auto mb-2 flex flex-wrap gap-2 self-end rounded-2xl border border-white/10 bg-black/40 p-2 backdrop-blur-md">
        {Object.keys(ITEMS).map((k) => {
          const id = k as ItemId;
          const n = inventory[id] ?? 0;
          if (!n) return null;
          return (
            <div
              key={id}
              className="flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1 text-sm text-white"
            >
              <span className="text-lg leading-none">{ITEMS[id].emoji}</span>
              <span className="font-semibold">×{n}</span>
            </div>
          );
        })}
        {Object.keys(inventory).length === 0 && (
          <span className="px-2 py-1 text-xs text-white/50">Pusty plecak</span>
        )}
      </div>
    </div>
  );
}

function QuestRow({
  status,
  flash,
  expanded,
  onToggle,
  tracker,
}: {
  status: QuestStatus;
  flash: boolean;
  expanded: boolean;
  onToggle: () => void;
  tracker?: GoalTrack;
}) {
  const { quest, done, current, total, ready, missing } = status;
  const showBar = total > 1;
  const pct = total > 0 ? Math.min(100, (current / total) * 100) : 0;
  const hasDetails = !done && missing.length > 0;
  const showTracker = quest.kind === "reach" && !done && !!tracker;

  return (
    <motion.li
      layout
      animate={
        flash
          ? {
              backgroundColor: [
                "rgba(255,205,102,0)",
                "rgba(255,205,102,0.22)",
                "rgba(255,205,102,0)",
              ],
            }
          : {}
      }
      transition={{ duration: 1.2 }}
      className="flex flex-col gap-1 rounded-md px-1 py-1"
    >
      <div className="flex items-center gap-2">
        <motion.span
          animate={flash ? { scale: [1, 1.35, 1] } : {}}
          transition={{ duration: 0.5 }}
          className={[
            "grid h-4 w-4 flex-none place-items-center rounded-[5px] text-[10px] font-bold",
            done
              ? "bg-honey text-background"
              : ready
                ? "border border-honey/70 text-honey"
                : "border border-white/30 text-transparent",
          ].join(" ")}
        >
          {done ? "✓" : ready ? "!" : "✓"}
        </motion.span>
        <span
          className={[
            "flex-1 truncate",
            done ? "text-white/55 line-through" : ready ? "text-honey" : "text-white/90",
          ].join(" ")}
        >
          {quest.label}
        </span>
        {ready && !done && (
          <span className="rounded-full bg-honey/15 px-2 py-[1px] text-[9px] font-bold uppercase tracking-wider text-honey">
            Gotowe
          </span>
        )}
        {showTracker && tracker && <DistanceBadge track={tracker} ready={!!ready} />}
        {showBar && (
          <span
            className={[
              "ml-1 tabular-nums text-[11px]",
              done ? "text-white/50" : "text-white/70",
            ].join(" ")}
          >
            {current}/{total}
          </span>
        )}
        {hasDetails && (
          <button
            onClick={onToggle}
            aria-label={expanded ? "Ukryj podpowiedzi" : "Pokaż podpowiedzi"}
            aria-expanded={expanded}
            className={[
              "ml-1 grid h-5 w-5 flex-none place-items-center rounded-full border text-[10px] font-bold transition",
              expanded
                ? "border-honey bg-honey/20 text-honey"
                : "border-white/25 text-white/70 hover:border-honey/60 hover:text-honey",
            ].join(" ")}
          >
            ?
          </button>
        )}
      </div>
      {showBar && (
        <div className="h-[3px] w-full overflow-hidden rounded-full bg-white/10">
          <motion.div
            className={done ? "h-full rounded-full bg-honey/60" : "h-full rounded-full bg-honey"}
            initial={false}
            animate={{ width: `${pct}%` }}
            transition={{ type: "spring", stiffness: 130, damping: 22 }}
          />
        </div>
      )}
      <AnimatePresence initial={false}>
        {hasDetails && expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="overflow-hidden"
          >
            <ul className="mt-1 ml-6 space-y-1 rounded-lg border border-honey/25 bg-honey/5 px-2.5 py-2 text-[11px] leading-snug">
              {missing.map((m, i) => (
                <li key={i} className="flex items-start gap-1.5 text-white/85">
                  <span className="flex-none text-sm leading-none">{m.emoji ?? "•"}</span>
                  <span className="min-w-0">
                    <span className="font-medium text-white">{m.label}</span>
                    <span className="block text-[10px] text-white/60">📍 {m.where}</span>
                  </span>
                </li>
              ))}
            </ul>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.li>
  );
}

/** Compact live indicator: textual tier + optional rotating arrow + distance in "kroki". */
function DistanceBadge({ track, ready }: { track: GoalTrack; ready: boolean }) {
  const { dist, angle, at, tier, goalLabel } = track;
  const steps = Math.max(1, Math.round(dist / 32));
  const colorBlind = useGameStore((s) => s.controls.colorBlindMode);
  const showArrow = useGameStore((s) => s.controls.goalIndicators);
  const reducedMotion = useGameStore((s) => s.controls.reducedMotion);
  const st = tierStyle(tier, colorBlind);
  const tierLabel =
    tier === "at" ? "Tuż obok" : tier === "near" ? "Blisko" : tier === "mid" ? "Średnio" : "Daleko";
  return (
    <span
      className={[
        "ml-1 inline-flex items-center gap-1 rounded-full border px-1.5 py-[1px] text-[10px] font-semibold tabular-nums transition",
        tier === "at"
          ? "border-honey bg-honey/25 text-honey"
          : ready
            ? "border-honey/50 bg-honey/10 text-honey"
            : "border-white/20 bg-white/5 text-white/70",
      ].join(" ")}
      title={`${goalLabel} — dystans: ~${steps} kroków (próg „tuż obok”: ~${Math.max(1, Math.round(at / 32))} kr.)`}
      aria-live="polite"
    >
      {showArrow && (
        <motion.span
          aria-hidden
          className="inline-block text-[11px] leading-none"
          animate={{ rotate: (angle * 180) / Math.PI + 90 }}
          transition={
            reducedMotion ? { duration: 0 } : { type: "spring", stiffness: 140, damping: 18 }
          }
        >
          ↑
        </motion.span>
      )}
      {st.glyph && (
        <span aria-hidden style={{ color: st.swatch }}>
          {st.glyph}
        </span>
      )}
      <span>{tierLabel}</span>
      <span className="text-white/50">·</span>
      <span>{tier === "at" ? `${Math.max(1, Math.round(at / 32))} kr.` : `${steps} kr.`}</span>
    </span>
  );
}

/** Legend marker: circle by default, distinct shapes in colour-blind mode. */
function LegendSwatch({
  shape,
  color,
}: {
  shape: "circle" | "square" | "diamond" | "triangle";
  color: string;
}) {
  if (shape === "triangle") {
    return (
      <svg viewBox="0 0 10 10" aria-hidden className="h-2.5 w-2.5">
        <path d="M5 0 L10 10 L0 10 Z" fill={color} />
      </svg>
    );
  }
  return (
    <span
      aria-hidden
      className={[
        "inline-block h-2.5 w-2.5",
        shape === "circle" ? "rounded-full" : shape === "square" ? "rounded-[2px]" : "rotate-45",
      ].join(" ")}
      style={{ backgroundColor: color }}
    />
  );
}

/** mm:ss for the in-HUD speedrun clock — this game's runs are minutes, not hours. */
function formatElapsed(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}
