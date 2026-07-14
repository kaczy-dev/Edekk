import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import edekPortrait from "@/assets/edek-portrait.jpg";

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
  return (
    <main className="relative min-h-[100dvh] overflow-hidden">
      <div className="absolute inset-0 -z-10">
        <img src={edekPortrait} alt="" aria-hidden className="h-full w-full object-cover opacity-40" width={1280} height={1280} />
        <div className="absolute inset-0 bg-gradient-to-b from-night/60 via-background/80 to-background" />
      </div>
      <section className="mx-auto flex min-h-[100dvh] max-w-3xl flex-col items-center justify-center px-6 text-center">
        <motion.span
          initial={{ scale: 0.5, opacity: 0, rotate: -15 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          className="text-7xl"
        >
          🌟
        </motion.span>
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15 }}
          className="text-balance mt-6 font-display text-5xl font-extrabold md:text-7xl"
        >
          Edek wraca do domu
        </motion.h1>
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
          className="text-balance mt-6 max-w-xl text-lg text-muted-foreground"
        >
          Cztery światy odkryte, wszystkie myszki odnalezione, gwiazdy zebrane. Edek mruczy z dumą i zwija się w kłębek na kanapie.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6 }}
          className="mt-10 flex flex-col gap-3 sm:flex-row"
        >
          <Link to="/menu" className="glow-amber rounded-full bg-primary px-8 py-3 font-semibold text-primary-foreground transition hover:scale-[1.02]">
            Zagraj jeszcze raz
          </Link>
          <Link to="/" className="rounded-full border border-border bg-card/60 px-6 py-3 text-sm font-medium backdrop-blur transition hover:bg-card">
            Tytuł
          </Link>
        </motion.div>
      </section>
    </main>
  );
}
