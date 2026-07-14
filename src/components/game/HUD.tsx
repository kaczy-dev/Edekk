import { useGameStore, DIFFICULTIES } from "@/store/gameStore";
import { ITEMS } from "@/game/items";
import type { ItemId, LevelDef } from "@/game/types";
import { computeQuests, questCompletion, type QuestStatus } from "@/game/questUtils";
import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useMemo, useRef, useState } from "react";

interface Props {
  level: LevelDef;
  onPause: () => void;
  sprinting?: boolean;
  mode?: "play" | "explore";
}

export function HUD({ level, onPause, sprinting, mode = "play" }: Props) {
  const isExplore = mode === "explore";
  const energy = useGameStore((s) => s.energy);
  const inventory = useGameStore((s) => s.inventory);
  const talked = useGameStore((s) => s.talkedNpcs[level.id] ?? []);
  const completed = useGameStore((s) => s.levelProgress[level.id]?.completed ?? false);
  const difficulty = useGameStore((s) => s.difficulty);
  const [open, setOpen] = useState(true);

  const statuses = useMemo(
    () => computeQuests(level, { inventory, talked, levelCompleted: completed }),
    [level, inventory, talked, completed]
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
    nowDone.forEach((id) => { if (!prev.has(id)) justDone.push(id); });
    if (justDone.length) {
      setFlashIds(new Set(justDone));
      const t = setTimeout(() => setFlashIds(new Set()), 1400);
      prevDoneRef.current = nowDone;
      return () => clearTimeout(t);
    }
    prevDoneRef.current = nowDone;
  }, [statuses]);

  // Auto-open the checklist briefly when a quest completes so the tick is visible.
  useEffect(() => {
    if (flashIds.size > 0) setOpen(true);
  }, [flashIds]);

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
              <h2 className="font-display text-base font-semibold text-honey md:text-lg truncate">{level.title}</h2>
              <p className="text-[11px] uppercase tracking-widest text-white/50">
                {isExplore ? (
                  <span className="text-honey font-bold">👁️ Tryb zwiedzania</span>
                ) : (
                  <>
                    Zadania {done}/{total}
                    <span className="mx-1.5 text-white/30">·</span>
                    <span className="text-honey/80">{DIFFICULTIES[difficulty].label}</span>
                    {allDone && (
                      <span className="ml-2 rounded-full bg-honey/20 px-1.5 py-[1px] text-[9px] font-bold text-honey">
                        Wszystko!
                      </span>
                    )}
                  </>
                )}
              </p>
              {/* Overall progress bar */}
              {!isExplore && (
                <div className="mt-1.5 h-[3px] w-40 max-w-full overflow-hidden rounded-full bg-white/10">
                  <motion.div
                    className="h-full rounded-full bg-honey"
                    initial={false}
                    animate={{ width: `${total ? (done / total) * 100 : 0}%` }}
                    transition={{ type: "spring", stiffness: 120, damping: 20 }}
                  />
                </div>
              )}
            </div>
            <span className="text-white/60 text-xs">{open ? "▾" : "▸"}</span>
          </button>
          <AnimatePresence initial={false}>
            {open && (
              <motion.ul
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: "auto", opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.2 }}
                className="overflow-hidden border-t border-white/10 px-4 py-2 text-[13px]"
              >
                {isExplore ? (
                  <li className="text-white/70 italic leading-relaxed py-1">
                    Zwiedzasz tę lokację. Zadania są wyłączone. Możesz swobodnie biegać i oglądać planszę!
                  </li>
                ) : (
                  statuses.map((s) => (
                    <QuestRow key={s.quest.id} status={s} flash={flashIds.has(s.quest.id)} />
                  ))
                )}
              </motion.ul>
            )}
          </AnimatePresence>
        </div>
        <button
          onClick={onPause}
          className="pointer-events-auto rounded-full border border-white/15 bg-black/45 px-4 py-2 text-sm font-medium text-white backdrop-blur-md transition hover:bg-black/60"
        >
          Pauza
        </button>
      </div>

      <div className="mt-3 pointer-events-auto w-56 max-w-[60vw] rounded-2xl border border-white/10 bg-black/40 p-1.5 backdrop-blur-md">
        <div className="relative h-3 overflow-hidden rounded-full bg-white/10">
          <motion.div
            className="absolute inset-y-0 left-0 rounded-full"
            style={{
              background: sprinting
                ? `linear-gradient(90deg, #ff8a5b, var(--color-honey))`
                : `linear-gradient(90deg, var(--color-amber), var(--color-honey))`,
            }}
            animate={{ width: `${energy}%` }}
            transition={{ type: "spring", stiffness: 80, damping: 20 }}
          />
        </div>
        <div className="mt-1 flex items-center justify-between px-2 text-[10px] uppercase tracking-widest text-white/60">
          <span>Energia · {Math.round(energy)}</span>
          {sprinting && (
            <span className="rounded-full bg-honey/20 px-2 py-0.5 text-[9px] font-bold text-honey">BIEG</span>
          )}
        </div>
      </div>

      <div className="flex-1" />

      <div className="pointer-events-auto mb-2 flex flex-wrap gap-2 self-end rounded-2xl border border-white/10 bg-black/40 p-2 backdrop-blur-md">
        {Object.keys(ITEMS).map((k) => {
          const id = k as ItemId;
          const n = inventory[id] ?? 0;
          if (!n) return null;
          return (
            <div key={id} className="flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1 text-sm text-white">
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

function QuestRow({ status, flash }: { status: QuestStatus; flash: boolean }) {
  const { quest, done, current, total, ready } = status;
  const showBar = total > 1;
  const pct = total > 0 ? Math.min(100, (current / total) * 100) : 0;

  return (
    <motion.li
      layout
      animate={flash ? { backgroundColor: ["rgba(255,205,102,0)", "rgba(255,205,102,0.22)", "rgba(255,205,102,0)"] } : {}}
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
    </motion.li>
  );
}
