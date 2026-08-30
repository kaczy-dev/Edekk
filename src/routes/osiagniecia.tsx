import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { LEVELS } from "@/game/levels";
import { useGameStore } from "@/store/gameStore";
import { computeQuests, questCompletion } from "@/game/questUtils";
import { inventoryFromCollected } from "@/game/inventory";

export const Route = createFileRoute("/osiagniecia")({
  head: () => ({
    meta: [
      { title: "Osiągnięcia — Przygody Edka" },
      { name: "description", content: "Zbiór odznak i osiągnięć w grze Przygody Edka." },
    ],
  }),
  component: AchievementsPage,
});

interface Achievement {
  id: string;
  icon: string;
  title: string;
  desc: string;
  /** Returns 0–1 progress; >=1 means unlocked. */
  progress: (ctx: ReturnType<typeof buildContext>) => number;
  /** Shown while locked, under the progress bar. */
  hint: (ctx: ReturnType<typeof buildContext>) => string;
}

function buildContext(
  levelProgress: ReturnType<typeof useGameStore.getState>["levelProgress"],
  talkedNpcs: ReturnType<typeof useGameStore.getState>["talkedNpcs"],
  controls: ReturnType<typeof useGameStore.getState>["controls"],
) {
  const perLevel = LEVELS.map((l) => {
    const lp = levelProgress[l.id];
    const done = lp?.completed ?? false;
    const inventory = inventoryFromCollected(l, lp?.itemsCollected ?? []);
    const statuses = computeQuests(l, {
      inventory,
      talked: talkedNpcs[l.id] ?? [],
      levelCompleted: done,
      collected: lp?.itemsCollected ?? [],
    });
    const counts = questCompletion(statuses);
    return { level: l, completed: done, statuses, counts };
  });

  const a11yFlags = [
    controls.colorBlindMode,
    controls.reducedMotion,
    controls.invertY,
    controls.vibration,
    controls.showHints,
    controls.goalIndicators,
  ];
  const a11yOn = a11yFlags.filter(Boolean).length;

  return { perLevel, a11yOn, a11yTotal: a11yFlags.length };
}

const ACHIEVEMENTS: Achievement[] = [
  {
    id: "salon_complete",
    icon: "🏰",
    title: "Puchaty Odkrywca",
    desc: "Ukończ Wały Chrobrego",
    progress: (ctx) => (ctx.perLevel.find((p) => p.level.id === "1")?.completed ? 1 : 0),
    hint: () => "Ukończ pierwszy poziom, Wały Chrobrego.",
  },
  {
    id: "garden_100",
    icon: "🌻",
    title: "Ogrodnik",
    desc: "100% zadań w Parku Kasprowicza",
    progress: (ctx) => {
      const p = ctx.perLevel.find((p) => p.level.id === "2");
      if (!p || p.counts.total === 0) return 0;
      return p.counts.done / p.counts.total;
    },
    hint: (ctx) => {
      const p = ctx.perLevel.find((p) => p.level.id === "2");
      return p
        ? `${p.counts.done}/${p.counts.total} zadań ukończonych`
        : "Odblokuj Park Kasprowicza";
    },
  },
  {
    id: "all_npcs",
    icon: "💬",
    title: "Rozmówca",
    desc: "Porozmawiaj ze wszystkimi napotkanymi mieszkańcami",
    progress: (ctx) => {
      const talkQuests = ctx.perLevel.flatMap((p) =>
        p.statuses.filter((s) => s.quest.kind === "talk"),
      );
      if (talkQuests.length === 0) return 0;
      return talkQuests.filter((s) => s.done).length / talkQuests.length;
    },
    hint: (ctx) => {
      const talkQuests = ctx.perLevel.flatMap((p) =>
        p.statuses.filter((s) => s.quest.kind === "talk"),
      );
      const done = talkQuests.filter((s) => s.done).length;
      return `${done}/${talkQuests.length} rozmów odbytych`;
    },
  },
  {
    id: "all_mice",
    icon: "🐭",
    title: "Łowca Myszek",
    desc: "Zbierz wszystkie myszki w Parku Kasprowicza",
    progress: (ctx) => {
      const q = ctx.perLevel
        .find((p) => p.level.id === "2")
        ?.statuses.find((s) => s.quest.kind === "collect" && s.quest.itemId === "mouse");
      if (!q) return 0;
      return q.current / q.total;
    },
    hint: (ctx) => {
      const q = ctx.perLevel
        .find((p) => p.level.id === "2")
        ?.statuses.find((s) => s.quest.kind === "collect" && s.quest.itemId === "mouse");
      return q ? `${q.current}/${q.total} myszek złapanych` : "Odblokuj Park Kasprowicza";
    },
  },
  {
    id: "accessibility",
    icon: "♿",
    title: "Guru Dostępności",
    desc: "Włącz 5 z 6 opcji dostępności w ustawieniach",
    progress: (ctx) => ctx.a11yOn / 5,
    hint: (ctx) => `${ctx.a11yOn}/6 opcji włączonych w Ustawieniach → Sterowanie`,
  },
  {
    id: "all_levels",
    icon: "⭐",
    title: "Mistrz Światów",
    desc: `Ukończ wszystkie ${LEVELS.length} poziomów`,
    progress: (ctx) => ctx.perLevel.filter((p) => p.completed).length / LEVELS.length,
    hint: (ctx) =>
      `${ctx.perLevel.filter((p) => p.completed).length}/${LEVELS.length} poziomów ukończonych`,
  },
  {
    id: "speedrun_5min",
    icon: "⚡",
    title: "Błyskawica",
    desc: "Ukończ poziom w mniej niż 5 minut",
    progress: () => 0,
    hint: () => "Wkrótce — pomiar czasu przejścia jeszcze nie jest śledzony.",
  },
  {
    id: "zero_energy",
    icon: "🔋",
    title: "Energetyk",
    desc: "Dotrzyj do celu z pełną energią",
    progress: () => 0,
    hint: () => "Wkrótce — stan energii przy celu nie jest jeszcze śledzony.",
  },
  {
    id: "roof_master",
    icon: "🌙",
    title: "Nocny Myśliwy",
    desc: 'Ukończ poziom "Dach nocą"',
    progress: (ctx) => {
      const roof = ctx.perLevel.find((p) => p.level.title.toLowerCase().includes("dach"));
      return roof?.completed ? 1 : 0;
    },
    hint: () => "Odblokuj i ukończ poziom Dach nocą.",
  },
];

function AchievementsPage() {
  const levelProgress = useGameStore((s) => s.levelProgress);
  const talkedNpcs = useGameStore((s) => s.talkedNpcs);
  const controls = useGameStore((s) => s.controls);
  const ctx = buildContext(levelProgress, talkedNpcs, controls);

  const unlockedCount = ACHIEVEMENTS.filter((a) => a.progress(ctx) >= 1).length;

  return (
    <main className="min-h-[100dvh] px-6 py-16">
      <div className="mx-auto max-w-4xl">
        <Link to="/menu" className="text-sm text-muted-foreground transition hover:text-foreground">
          ← Menu
        </Link>

        <div className="mt-6 flex flex-wrap items-end justify-between gap-3">
          <div>
            <motion.h1
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="font-display text-5xl font-bold"
            >
              Osiągnięcia
            </motion.h1>
            <p className="mt-2 text-muted-foreground">
              Zbierz odznaki i udowodnij swoje mistrzostwo w światach Edka.
            </p>
          </div>
          <span className="rounded-full border border-honey/40 bg-honey/10 px-4 py-1.5 text-sm font-semibold text-honey">
            {unlockedCount}/{ACHIEVEMENTS.length} odblokowanych
          </span>
        </div>

        <div className="mt-10 rounded-3xl border border-border bg-card/30 p-8 paper-grain">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {ACHIEVEMENTS.map((ach, i) => {
              const progress = Math.min(1, ach.progress(ctx));
              const unlocked = progress >= 1;
              return (
                <motion.div
                  key={ach.id}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: i * 0.05 }}
                  className={[
                    "group relative overflow-hidden rounded-2xl border p-5 backdrop-blur transition",
                    unlocked
                      ? "border-white/10 bg-card/60 hover:border-honey/40 hover:bg-card/80"
                      : "border-white/5 bg-card/30",
                  ].join(" ")}
                >
                  <div
                    className={[
                      "text-4xl mb-3 transition",
                      unlocked ? "" : "opacity-30 grayscale",
                    ].join(" ")}
                  >
                    {ach.icon}
                  </div>
                  <h3
                    className={[
                      "font-display font-semibold",
                      unlocked ? "text-foreground" : "text-foreground/60",
                    ].join(" ")}
                  >
                    {ach.title}
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">{ach.desc}</p>

                  {unlocked ? (
                    <div className="mt-3 flex items-center gap-1.5 text-[10px] uppercase tracking-wider text-honey">
                      <span aria-hidden>✓</span> Odblokowana
                    </div>
                  ) : (
                    <div className="mt-3 space-y-1.5">
                      <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/10">
                        <div
                          className="h-full rounded-full bg-honey/60 transition-[width]"
                          style={{ width: `${Math.round(progress * 100)}%` }}
                        />
                      </div>
                      <p className="text-[11px] text-muted-foreground/80">{ach.hint(ctx)}</p>
                    </div>
                  )}

                  {!unlocked && (
                    <span
                      aria-hidden
                      className="pointer-events-none absolute right-4 top-4 text-lg opacity-20"
                    >
                      🔒
                    </span>
                  )}
                </motion.div>
              );
            })}
          </div>
        </div>
      </div>
    </main>
  );
}
