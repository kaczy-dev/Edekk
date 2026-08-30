import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";

export const Route = createFileRoute("/osiagniecia")({
  head: () => ({
    meta: [
      { title: "Osiągnięcia — Przygody Edka" },
      { name: "description", content: "Zbiór odznak i osiągnięć w grze Przygody Edka." },
    ],
  }),
  component: AchievementsPage,
});

const ACHIEVEMENTS = [
  { id: "salon_complete", icon: "🛋️", title: "Puchaty Odkrywca", desc: "Ukończ Salon" },
  { id: "all_mice", icon: "🐭", title: "Łowca Myszek", desc: "Zbierz wszystkie myszki" },
  { id: "all_levels", icon: "⭐", title: "Mistrz Światów", desc: "Ukończ wszystkie 4 poziomy" },
  { id: "speedrun_5min", icon: "⚡", title: "Błyskawica", desc: "Ukończ poziom w &lt;5 min" },
  { id: "zero_energy", icon: "🔋", title: "Energetyk", desc: "Osiągnij cel z pełną energią" },
  { id: "accessibility", icon: "♿", title: "Guru Dostępności", desc: "Włącz 5+ opcji dostępności" },
  { id: "garden_100", icon: "🌻", title: "Ogrodnik", desc: "100% zbiorów w Ogrodzie" },
  { id: "all_npcs", icon: "💬", title: "Rozmówca", desc: "Porozmawiaj ze wszystkimi NPC" },
  { id: "roof_master", icon: "🌙", title: "Nocny Myśliwy", desc: "Mistrz Dachu nocą" },
];

function AchievementsPage() {
  return (
    <main className="min-h-[100dvh] px-6 py-16">
      <div className="mx-auto max-w-4xl">
        <Link to="/menu" className="text-sm text-muted-foreground transition hover:text-foreground">
          ← Menu
        </Link>

        <motion.h1
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-6 font-display text-5xl font-bold"
        >
          Osiągnięcia
        </motion.h1>
        <p className="mt-2 text-muted-foreground">
          Zbierz odznaki i udowodnij swoją mistrzostwo w światach Edka.
        </p>

        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {ACHIEVEMENTS.map((ach, i) => (
            <motion.div
              key={ach.id}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: i * 0.05 }}
              className="group relative rounded-2xl border border-white/10 bg-card/60 p-5 backdrop-blur transition hover:border-honey/40 hover:bg-card/80"
            >
              {/* Locked overlay (demo — all unlocked for now) */}
              <div className="text-4xl mb-3">{ach.icon}</div>
              <h3 className="font-display font-semibold text-foreground">{ach.title}</h3>
              <p className="mt-1 text-sm text-muted-foreground">{ach.desc}</p>
              <div className="mt-3 text-[10px] uppercase tracking-wider text-white/50">
                Odblokowana
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </main>
  );
}
