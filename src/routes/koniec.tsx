import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import edekPortrait from "@/assets/edek-portrait.jpg";
import { ParallaxHero, ParallaxLayer } from "@/components/game/ParallaxHero";
import { useGameStore } from "@/store/gameStore";
import { LEVELS } from "@/game/levels";

export const Route = createFileRoute("/koniec")({
  head: () => ({
    meta: [
      { title: "Koniec przygody — Przygody Edka" },
      { name: "description", content: "Edek przeszedł wszystkie poziomy. Brawo!" },
    ],
  }),
  component: EndScreen,
});

function EndScreen() {
  const totalHops = useGameStore((s) => s.totalHops);
  const totalDistanceWalked = useGameStore((s) => s.totalDistanceWalked);
  const levelProgress = useGameStore((s) => s.levelProgress);
  // Photo collectibles aren't tracked as their own store counter — they're
  // derived here from the same itemsCollected lists everything else reads,
  // by checking each level's own "i-photo" object id.
  const photosFound = LEVELS.filter((l) =>
    l.objects.some((o) => o.id === "i-photo" && levelProgress[l.id]?.itemsCollected.includes("i-photo"))
  ).length;
  const totalPhotos = LEVELS.filter((l) => l.objects.some((o) => o.id === "i-photo")).length;
  const steps = Math.round(totalDistanceWalked / 32);

  return (
    <ParallaxHero className="relative min-h-[100dvh] overflow-hidden">
      <ParallaxLayer depth={0.35} className="absolute inset-0 -z-10">
        <img
          src={edekPortrait}
          alt=""
          aria-hidden
          className="h-[112%] w-[112%] -translate-x-[5%] -translate-y-[5%] object-cover opacity-40"
          width={1280}
          height={1280}
        />
        <div className="absolute inset-0 bg-gradient-to-b from-night/60 via-background/80 to-background" />
      </ParallaxLayer>

      <ParallaxLayer depth={0.9} className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute left-[8%] top-[24%] h-[42vmin] w-[42vmin] rounded-full bg-honey/20 blur-[100px]" />
        <div className="absolute right-[6%] top-[38%] h-[35vmin] w-[35vmin] rounded-full bg-primary/20 blur-[85px]" />
      </ParallaxLayer>

      <ParallaxLayer
        depth={1.6}
        className="mx-auto flex min-h-[100dvh] max-w-3xl flex-col items-center justify-center px-6 text-center"
      >
        <motion.span
          initial={{ scale: 0.5, opacity: 0, rotate: -15 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          transition={{ duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
          className="text-7xl"
        >
          🌟
        </motion.span>
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15, duration: 0.6, ease: [0.2, 0.8, 0.2, 1] }}
          className="text-balance mt-6 font-display text-5xl font-extrabold md:text-7xl"
        >
          Edek wraca do domu
        </motion.h1>
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4, duration: 0.5 }}
          className="text-balance mt-6 max-w-xl text-lg text-muted-foreground"
        >
          Pięć światów odkryte, wszystkie myszki odnalezione, gwiazdy zebrane, smakołyki znalezione. Edek mruczy z dumą i zwija się w kłębek na kanapie.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5, duration: 0.5 }}
          className="mt-8 flex flex-wrap items-center justify-center gap-3"
        >
          <StatChip icon="🐾" label="Hopów" value={totalHops} />
          <StatChip icon="🐈" label="Kroków" value={steps} />
          {totalPhotos > 0 && <StatChip icon="📷" label="Zdjęć" value={`${photosFound}/${totalPhotos}`} />}
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6, duration: 0.5, ease: [0.2, 0.8, 0.2, 1] }}
          className="mt-10 flex flex-col gap-3 sm:flex-row"
        >
          <motion.div whileHover={{ y: -2 }} whileTap={{ scale: 0.97 }}>
            <Link to="/menu" className="glow-amber block rounded-full bg-gradient-to-b from-primary to-primary/90 px-8 py-3 text-center font-semibold text-primary-foreground shadow-lg shadow-primary/20 transition">
              Zagraj jeszcze raz
            </Link>
          </motion.div>
          <motion.div whileHover={{ y: -2 }} whileTap={{ scale: 0.97 }}>
            <Link to="/" className="block rounded-full border border-border bg-card/60 px-6 py-3 text-center text-sm font-medium backdrop-blur transition hover:bg-card">
              Tytuł
            </Link>
          </motion.div>
        </motion.div>
      </ParallaxLayer>
    </ParallaxHero>
  );
}

function StatChip({ icon, label, value }: { icon: string; label: string; value: number | string }) {
  return (
    <div className="flex items-center gap-2 rounded-full border border-border bg-card/60 px-4 py-2 text-sm backdrop-blur">
      <span className="text-lg leading-none">{icon}</span>
      <span className="font-semibold tabular-nums">{value}</span>
      <span className="text-muted-foreground">{label}</span>
    </div>
  );
}
