import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { LEVELS } from "@/game/levels";
import { useGameStore } from "@/store/gameStore";
import { computeQuests, questCompletion } from "@/game/questUtils";


export const Route = createFileRoute("/menu")({
  head: () => ({
    meta: [
      { title: "Wybierz poziom — Przygody Edka" },
      { name: "description", content: "Wybierz świat: salon, ogród, strych albo dach nocą." },
    ],
  }),
  component: MenuPage,
});

function MenuPage() {
  const unlocked = useGameStore((s) => s.unlockedLevels);
  const progress = useGameStore((s) => s.levelProgress);
  const talked = useGameStore((s) => s.talkedNpcs);

  return (
    <main className="min-h-[100dvh] px-6 py-16 md:py-24">
      <div className="mx-auto max-w-5xl">
        <div className="flex items-center justify-between">
          <Link to="/" className="text-sm text-muted-foreground transition hover:text-foreground">← Tytuł</Link>
          <Link to="/ustawienia" className="text-sm text-muted-foreground transition hover:text-foreground">Ustawienia</Link>
        </div>

        <motion.h1
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-6 font-display text-5xl font-bold md:text-6xl"
        >
          Dziennik wypraw
        </motion.h1>
        <p className="mt-2 max-w-xl text-muted-foreground">
          Każdy świat ma swoje zadania. Ukończ wszystkie, aby otworzyć kolejne drzwi przed Edkiem.
        </p>

        <div className="mt-10 grid gap-4 md:grid-cols-2">
          {LEVELS.map((l, i) => {
            const isUnlocked = unlocked.includes(l.id);
            const lp = progress[l.id];
            const done = lp?.completed ?? false;
            const inventoryForCounts: Record<string, number> = {};
            // derive saved counts from itemsCollected so cards reflect last save
            for (const objId of lp?.itemsCollected ?? []) {
              const obj = l.objects.find((o) => o.id === objId);
              if (obj?.kind === "item" && obj.itemId) {
                inventoryForCounts[obj.itemId] = (inventoryForCounts[obj.itemId] ?? 0) + 1;
              }
            }
            // squirrel yarn gift is tracked as "<objId>-gift"
            if ((lp?.itemsCollected ?? []).some((id) => id.endsWith("-gift"))) {
              inventoryForCounts.yarn = (inventoryForCounts.yarn ?? 0) + 1;
            }
            const statuses = computeQuests(l, {
              inventory: inventoryForCounts,
              talked: talked[l.id] ?? [],
              levelCompleted: done,
            });
            const counts = questCompletion(statuses);

            return (
              <motion.div
                key={l.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.08 }}
              >
                {isUnlocked ? (
                  <Link
                    to="/poziom/$id"
                    params={{ id: l.id }}
                    className="group relative block overflow-hidden rounded-3xl border border-border bg-card transition hover:border-honey/50"
                  >
                    <div className="relative aspect-[16/9] overflow-hidden">
                      <img
                        src={l.background}
                        alt={l.title}
                        className="h-full w-full object-cover transition duration-700 group-hover:scale-105"
                        loading="lazy"
                        width={1536}
                        height={1024}
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-card via-card/30 to-transparent" />
                      {done ? (
                        <span className="absolute right-3 top-3 rounded-full bg-honey/90 px-3 py-1 text-xs font-bold text-background">
                          ✓ Ukończony
                        </span>
                      ) : (
                        <span className="absolute right-3 top-3 rounded-full border border-white/20 bg-black/40 px-3 py-1 text-xs font-medium text-white backdrop-blur-md">
                          {counts.done}/{counts.total} zadań
                        </span>
                      )}
                    </div>
                    <div className="p-5">
                      <div className="text-xs uppercase tracking-[0.25em] text-muted-foreground">Poziom {l.id}</div>
                      <h3 className="mt-1 font-display text-2xl font-semibold">{l.title}</h3>
                      <p className="text-sm text-muted-foreground">{l.subtitle}</p>
                      <ul className="mt-3 space-y-1 text-[13px]">
                        {statuses.map((s) => (
                          <li key={s.quest.id} className="flex items-center gap-2">
                            <span
                              className={[
                                "grid h-3.5 w-3.5 flex-none place-items-center rounded-[4px] text-[9px] font-bold",
                                s.done ? "bg-honey text-background" : "border border-muted-foreground/40 text-transparent",
                              ].join(" ")}
                            >
                              ✓
                            </span>
                            <span className={s.done ? "text-muted-foreground line-through" : "text-foreground/85"}>
                              {s.quest.label}
                            </span>
                            {s.total > 1 && (
                              <span className="ml-auto text-[11px] tabular-nums text-muted-foreground">
                                {s.current}/{s.total}
                              </span>
                            )}
                          </li>
                        ))}
                      </ul>
                    </div>
                  </Link>
                ) : (
                  <div className="block overflow-hidden rounded-3xl border border-dashed border-border bg-card/50">
                    <div className="relative aspect-[16/9] overflow-hidden">
                      <img
                        src={l.background}
                        alt=""
                        aria-hidden
                        className="h-full w-full object-cover opacity-20 blur-sm"
                        loading="lazy"
                        width={1536}
                        height={1024}
                      />
                      <div className="absolute inset-0 grid place-items-center text-4xl">🔒</div>
                    </div>
                    <div className="p-5 opacity-80">
                      <div className="text-xs uppercase tracking-[0.25em] text-muted-foreground">Poziom {l.id}</div>
                      <h3 className="mt-1 font-display text-2xl font-semibold">{l.title}</h3>
                      <p className="text-sm text-muted-foreground">{l.subtitle}</p>
                      <div className="mt-3 rounded-xl border border-honey/20 bg-honey/5 px-3 py-2 text-[13px] text-honey/90">
                        <span className="mr-1">🔑</span>{l.unlockHint}
                      </div>
                      <Link
                        to="/poziom/$id"
                        params={{ id: l.id }}
                        search={{ mode: "explore" }}
                        className="mt-3 flex w-full items-center justify-center gap-1.5 rounded-2xl border border-honey/40 bg-honey/10 py-2.5 text-xs font-semibold text-honey hover:bg-honey/20 transition active:scale-95"
                      >
                        Zwiedzaj planszę 👁️
                      </Link>
                    </div>
                  </div>
                )}
              </motion.div>
            );
          })}
        </div>
      </div>
    </main>
  );
}

