import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import edekPortrait from "@/assets/edek-portrait.jpg";
import { useGameStore } from "@/store/gameStore";
import { getLevel } from "@/game/levels";
import { ParallaxHero, ParallaxLayer } from "@/components/game/ParallaxHero";
import { Tilt3D } from "@/components/ui/tilt-3d";

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
    <ParallaxHero className="relative flex h-[100dvh] flex-col overflow-hidden">
      {/* Deepest plane: a soft wash of the portrait, barely visible, sets the mood. */}
      <ParallaxLayer depth={0.35} className="absolute inset-0 -z-10">
        <img
          src={edekPortrait}
          alt=""
          aria-hidden
          className="h-full w-full scale-110 object-cover object-top opacity-[0.12] blur-sm"
          width={1280}
          height={1280}
        />
        <div className="absolute inset-0 bg-gradient-to-b from-background/60 via-background/80 to-background" />
      </ParallaxLayer>

      {/* Mid plane: warm light pools drifting behind the medallion. */}
      <ParallaxLayer depth={0.9} className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-1/2 top-[16%] h-[52vmin] w-[52vmin] -translate-x-1/2 rounded-full bg-honey/25 blur-[100px]" />
        <div className="absolute right-[6%] top-[38%] h-[26vmin] w-[26vmin] rounded-full bg-primary/20 blur-[70px]" />
      </ParallaxLayer>

      {/* Top: eyebrow badge, thumb-safe top zone. */}
      <div className="flex justify-center pt-[max(1.75rem,env(safe-area-inset-top))]">
        <motion.span
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-full border border-honey/40 bg-honey/10 px-4 py-1.5 text-[11px] uppercase tracking-[0.3em] text-honey"
        >
          Gra przygodowa · Maine coon
        </motion.span>
      </div>

      {/* Signature: a tilting storybook medallion — Edek behind glass, not a page background. */}
      <div className="flex flex-1 flex-col items-center justify-center px-6">
        <motion.div
          initial={{ opacity: 0, scale: 0.85, y: 16 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.7, ease: [0.2, 0.8, 0.2, 1] }}
          className="relative"
        >
          <motion.div
            animate={{ y: [0, -8, 0] }}
            transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
          >
            <Tilt3D
              className="h-40 w-40 sm:h-48 sm:w-48"
              intensity={14}
              lift={30}
            >
              <div className="glow-amber relative h-full w-full rounded-full border-[3px] border-honey/50 bg-card p-1.5">
                <div className="h-full w-full overflow-hidden rounded-full border border-white/10">
                  <img
                    src={edekPortrait}
                    alt="Portret Edka, dymnego srebrnego kota Maine coon"
                    className="h-full w-full object-cover"
                    width={400}
                    height={400}
                  />
                </div>
                {/* Stitched storybook-plate ring */}
                <div
                  aria-hidden
                  className="pointer-events-none absolute inset-[6px] rounded-full border border-dashed border-honey/30"
                />
              </div>
            </Tilt3D>
          </motion.div>
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
          className="text-balance mt-7 text-center font-display text-5xl font-extrabold leading-[0.95] text-foreground sm:text-6xl md:text-7xl"
        >
          Przygody
          <span className="relative mt-1 inline-block text-honey">
            Edka
            <svg
              aria-hidden
              viewBox="0 0 160 14"
              className="absolute -bottom-2 left-0 h-3 w-full text-honey/60"
              preserveAspectRatio="none"
            >
              <path
                d="M2 8 C 40 2, 90 12, 158 6"
                fill="none"
                stroke="currentColor"
                strokeWidth="3"
                strokeLinecap="round"
              />
            </svg>
          </span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="text-balance mt-4 max-w-xs text-center text-sm text-muted-foreground sm:max-w-md sm:text-base"
        >
          Cztery światy. Jeden puchaty bohater. Eksploruj salon, ogród, strych i dach nocą.
        </motion.p>
      </div>

      {/* Bottom action sheet: primary CTA in the thumb zone, mobile-app style. */}
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5, duration: 0.5, ease: [0.2, 0.8, 0.2, 1] }}
        className="panel-glass mx-4 mb-[max(1.25rem,env(safe-area-inset-bottom))] flex flex-col gap-2.5 rounded-3xl p-4 sm:mx-auto sm:w-full sm:max-w-sm"
      >
        {resumeLevel ? (
          <>
            <Link
              to="/poziom/$id"
              params={{ id: resumeLevel.id }}
              className="glow-amber group flex items-center justify-center gap-2 rounded-2xl bg-primary px-6 py-4 text-base font-semibold text-primary-foreground transition active:scale-[0.98]"
            >
              Wznów: {resumeLevel.title}
              <span className="transition group-hover:translate-x-1">→</span>
            </Link>
            <div className="flex gap-2.5">
              <Link
                to="/menu"
                className="flex-1 rounded-2xl border border-border bg-card/60 px-4 py-3 text-center text-sm font-medium text-foreground transition active:scale-[0.98]"
              >
                Wybierz poziom
              </Link>
              <Link
                to="/ustawienia"
                className="flex-1 rounded-2xl border border-border bg-card/60 px-4 py-3 text-center text-sm font-medium text-foreground transition active:scale-[0.98]"
              >
                Ustawienia
              </Link>
            </div>
          </>
        ) : (
          <>
            <Link
              to="/menu"
              className="glow-amber group flex items-center justify-center gap-2 rounded-2xl bg-primary px-6 py-4 text-base font-semibold text-primary-foreground transition active:scale-[0.98]"
            >
              Zagraj
              <span className="transition group-hover:translate-x-1">→</span>
            </Link>
            <Link
              to="/ustawienia"
              className="rounded-2xl border border-border bg-card/60 px-4 py-3 text-center text-sm font-medium text-foreground transition active:scale-[0.98]"
            >
              Ustawienia
            </Link>
          </>
        )}
        <p className="mt-1 text-center text-[11px] text-muted-foreground">
          WASD / strzałki · E lub Spacja — interakcja · telefon: joystick i przycisk E
        </p>
      </motion.div>
    </ParallaxHero>
  );
}
