import { motion, AnimatePresence } from "framer-motion";
import { ControlsHint } from "./ControlsHint";
import { useGameStore, type Difficulty, type SprintMode } from "@/store/gameStore";

interface Props {
  open: boolean;
  onClose: () => void;
  difficulty: Difficulty;
  sprintMode: SprintMode;
}

export function ControlsModal({ open, onClose, difficulty, sprintMode }: Props) {
  const setTutorialStage = useGameStore((s) => s.setTutorialStage);

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="pointer-events-auto fixed inset-0 z-40 scrim"
          />
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 8 }}
            transition={{ type: "spring", stiffness: 300, damping: 25 }}
            className="pointer-events-auto fixed top-1/2 left-1/2 z-50 max-w-md w-[90vw] -translate-x-1/2 -translate-y-1/2 panel-glass p-6 shadow-2xl"
          >
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-display text-lg font-semibold text-honey">Sterowanie</h2>
              <button
                onClick={onClose}
                aria-label="Zamknij"
                className="text-white/50 transition hover:text-white"
              >
                ✕
              </button>
            </div>
            <div className="space-y-4 text-sm">
              <ControlsHint
                difficulty={difficulty}
                sprintMode={sprintMode}
                inline
              />
              <div className="pt-2 border-t border-white/10 text-xs text-white/60">
                <p className="mb-2">
                  <span className="text-white/80">Na urządzeniach mobilnych:</span> użyj joysticka/D-pada do ruchu, przycisków BIEG i E.
                </p>
                <p className="mb-3">
                  Więcej opcji dostępnych w <span className="text-honey">Ustawieniach</span>.
                </p>
                <button
                  onClick={() => {
                    setTutorialStage(1);
                    onClose();
                  }}
                  className="text-xs text-honey underline-offset-2 transition hover:underline"
                >
                  Pokaż tutorial ponownie
                </button>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
