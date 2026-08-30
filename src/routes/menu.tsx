import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { LEVELS } from "@/game/levels";
import { useGameStore } from "@/store/gameStore";
import { computeQuests, questCompletion } from "@/game/questUtils";
import { inventoryFromCollected } from "@/game/inventory";
import { Tilt3D } from "@/components/ui/tilt-3d";


export const Route = createFileRoute("/menu")({
  head: () => ({
    meta: [
      { title: "Wybierz poziom — Przygody Edka" },
      { name: "description", content: "Wybierz świat: salon, ogród, strych, dach nocą albo blokowisko." },
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
        <div className="flex items-center justify-between gap-2">
          <Link to="/" className="rounded-full border border-border bg-card/60 px-4 py-2 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card">← Tytuł</Link>
          <div className="flex gap-2">
            <Link to="/osiagniecia" className="rounded-full border border-border bg-card/60 px-4 py-2 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card">Osiągnięcia</Link>
            <Link to="/ustawienia" className="rounded-full border border-border bg-card/60 px-4 py-2 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card">Ustawienia</Link>
          </div>
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
            // derive saved counts from itemsCollected so cards reflect last save
            const inventoryForCounts = inventoryFromCollected(l, lp?.itemsCollected ?? []);
            const statuses = computeQuests(l, {
              inventory: inventoryForCounts,
              talked: talked[l.id] ?? [],
              levelCompleted: done,
              collected: lp?.itemsCollected ?? [],
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
                  <Tilt3D className="h-full" intensity={7} lift={18}>
                  <Link
                    to="/poziom/$id"
                    params={{ id: l.id }}
                    className="group relative block overflow-hidden rounded-3xl border border-border bg-card shadow-lg shadow-black/30 transition duration-300 hover:border-honey/50 hover:shadow-2xl hover:shadow-honey/10"
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
                  </Tilt3D>
                ) : (
                  <div className="block overflow-hidden rounded-3xl border border-border bg-card shadow-lg shadow-black/30">
                    <div className="relative aspect-[16/9] overflow-hidden">
                      <img
                        src={l.background}
                        alt=""
                        aria-hidden
                        className="h-full w-full object-cover opacity-25 blur-sm"
                        loading="lazy"
                        width={1536}
                        height={1024}
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-card via-card/30 to-transparent" />
                      <div className="absolute inset-0 flex items-center justify-center">
                        <span className="text-center">
                          <div className="text-4xl mb-2">🔒</div>
                          <div className="text-xs uppercase tracking-wider text-muted-foreground font-semibold">Zablokowane</div>
                        </span>
                      </div>
                      {i > 0 && unlocked.includes(LEVELS[i - 1].id) && (
                        <span className="absolute right-3 top-3 rounded-full border border-honey/60 bg-honey/10 px-3 py-1 text-xs font-semibold text-honey">
                          ➜ Następny
                        </span>
                      )}
                    </div>
                    <div className="p-5">
                      <div className="text-xs uppercase tracking-[0.25em] text-muted-foreground">Poziom {l.id}</div>
                      <h3 className="mt-1 font-display text-2xl font-semibold">{l.title}</h3>
                      <p className="text-sm text-muted-foreground">{l.subtitle}</p>
                      <div className="mt-3 rounded-xl border border-honey/20 bg-honey/5 px-3 py-2 text-[13px] text-honey/90">
                        <span className="mr-1">🔑</span>{l.unlockHint}
                      </div>
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

