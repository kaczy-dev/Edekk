import { useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useGameStore } from "@/store/gameStore";

enum TutorialStage {
  NotStarted = 0,
  Move = 1,
  Sprint = 2,
  Interact = 3,
  Ready = 4,
  Complete = 5,
}

interface Props {
  stage: number;
}

export function TutorialOverlay({ stage }: Props) {
  const setTutorialStage = useGameStore((s) => s.setTutorialStage);

  const steps = [
    { title: "Witaj, Edek!", desc: "Porusz joystick lub naciśnij WSAD, aby się poruszać" },
    { title: "Szybciej!", desc: "Naciśnij i przytrzymaj Shift (lub BIEG), aby przyspieszać" },
    { title: "Interakcja", desc: "Naciśnij E (lub przycisk E), aby wejść w interakcję z przedmiotami i postaciami" },
    { title: "Gotowy?", desc: "Teraz eksploruj świat i zbieraj przedmioty. Powodzenia!" },
  ];

  const current = steps[stage - 1];

  // Auto-advance after 4 seconds
  useEffect(() => {
    if (stage < TutorialStage.Move || stage >= TutorialStage.Complete) return;
    const timer = setTimeout(() => {
      if (stage === TutorialStage.Ready) setTutorialStage(TutorialStage.Complete);
      else setTutorialStage(stage + 1);
    }, 4000);
    return () => clearTimeout(timer);
  }, [stage, setTutorialStage]);

  if (!current) return null;

  return (
    <AnimatePresence>
      {stage > TutorialStage.NotStarted && stage < TutorialStage.Complete && (
        <motion.div
          key={`tutorial-${stage}`}
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          className="pointer-events-none fixed inset-0 z-40 flex flex-col items-center justify-center"
        >
          <div className="absolute inset-0 bg-black/40" />
          <motion.div
            initial={{ y: 20 }}
            animate={{ y: 0 }}
            className="relative z-10 max-w-md rounded-3xl border border-honey/40 bg-black/70 px-8 py-8 text-center backdrop-blur-xl"
          >
            <h2 className="font-display text-3xl font-bold text-honey">{current.title}</h2>
            <p className="mt-4 text-base text-white/85">{current.desc}</p>

            <motion.div
              key={`step-${stage}`}
              initial={{ scale: 0.85, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ type: "spring", stiffness: 300, damping: 20 }}
              className="mt-6 inline-block rounded-2xl border border-honey bg-honey/20 px-4 py-2 text-xs text-honey"
            >
              {stage}/4
            </motion.div>

            <button
              onClick={() => setTutorialStage(5)}
              className="pointer-events-auto absolute right-4 top-4 text-xs text-white/50 underline-offset-2 transition hover:text-white/80 hover:underline"
            >
              Pomiń
            </button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
