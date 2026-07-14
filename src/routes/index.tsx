import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import edekPortrait from "@/assets/edek-portrait.jpg";
import { useGameStore } from "@/store/gameStore";
import { getLevel } from "@/game/levels";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Przygody Edka — gra o kocie Maine coon" },
      { name: "description", content: "Wyrusz z Edkiem, dymnym Maine coonem, w przygodową grę eksploracyjną przez salon, ogród, strych i dach nocą." },
      { property: "og:title", content: "Przygody Edka — gra o kocie Maine coon" },
      { property: "og:description", content: "Cztery światy, zagadki i mruczący bohater. Zagraj w grę o Edku." },
    ],
  }),
  component: TitleScreen,
});

function TitleScreen() {
  const save = useGameStore((s) => s.save);
  const resumeLevel = save ? getLevel(save.levelId) : null;

  return (
    <main className="relative min-h-[100dvh] overflow-hidden">
      <div className="absolute inset-0 -z-10">
        <img
          src={edekPortrait}
          alt="Portret Edka, dymnego srebrnego kota Maine coon"
          className="h-full w-full object-cover opacity-50"
          width={1280}
          height={1280}
        />
        <div className="absolute inset-0 bg-gradient-to-b from-background/40 via-background/70 to-background" />
      </div>

      <section className="mx-auto flex min-h-[100dvh] max-w-5xl flex-col items-center justify-center px-6 py-16 text-center">
        <motion.span
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-full border border-honey/40 bg-honey/10 px-4 py-1.5 text-xs uppercase tracking-[0.3em] text-honey"
        >
          Gra przygodowa · Maine coon
        </motion.span>

        <motion.h1
          initial={{ opacity: 0, y: 20, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ delay: 0.1, duration: 0.7, ease: [0.2, 0.8, 0.2, 1] }}
          className="text-balance mt-6 font-display text-6xl font-extrabold leading-[0.95] md:text-8xl"
        >
          Przygody
          <span className="block bg-gradient-to-br from-primary to-honey bg-clip-text text-transparent">
            Edka
          </span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="text-balance mt-6 max-w-xl text-base text-muted-foreground md:text-lg"
        >
          Cztery światy. Jeden puchaty bohater. Eksploruj salon, ogród, strych i dach nocą u boku srebrnodymnego Maine coona.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.55 }}
          className="mt-10 flex flex-col items-center gap-3 sm:flex-row"
        >
          {resumeLevel && (
            <Link
              to="/poziom/$id"
              params={{ id: resumeLevel.id }}
              className="glow-amber group inline-flex items-center gap-2 rounded-full bg-primary px-8 py-3.5 text-base font-semibold text-primary-foreground transition hover:scale-[1.02]"
            >
              Wznów: {resumeLevel.title}
              <span className="transition group-hover:translate-x-1">→</span>
            </Link>
          )}
          <Link
            to="/menu"
            className={
              resumeLevel
                ? "rounded-full border border-border bg-card/60 px-6 py-3 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card"
                : "glow-amber group inline-flex items-center gap-2 rounded-full bg-primary px-8 py-3.5 text-base font-semibold text-primary-foreground transition hover:scale-[1.02]"
            }
          >
            {resumeLevel ? "Wybierz poziom" : "Zagraj"}
            {!resumeLevel && <span className="transition group-hover:translate-x-1">→</span>}
          </Link>
          <Link
            to="/ustawienia"
            className="rounded-full border border-border bg-card/60 px-6 py-3 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card"
          >
            Ustawienia
          </Link>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 0.6 }}
          transition={{ delay: 0.9 }}
          className="mt-16 text-xs text-muted-foreground"
        >
          Sterowanie: WASD / strzałki · E lub Spacja by wejść w interakcję · na telefonie: joystick i przycisk E
        </motion.p>
      </section>
    </main>
  );
}
