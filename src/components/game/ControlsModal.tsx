import { motion, AnimatePresence } from "framer-motion";
import { ControlsHint } from "./ControlsHint";
import type { Difficulty, SprintMode } from "@/store/gameStore";

interface Props {
  open: boolean;
  onClose: () => void;
  difficulty: Difficulty;
  sprintMode: SprintMode;
}

export function ControlsModal({ open, onClose, difficulty, sprintMode }: Props) {
  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="pointer-events-auto fixed inset-0 z-40 bg-black/50 backdrop-blur-sm"
          />
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 8 }}
            transition={{ type: "spring", stiffness: 300, damping: 25 }}
            className="pointer-events-auto fixed top-1/2 left-1/2 z-50 max-w-md w-[90vw] -translate-x-1/2 -translate-y-1/2 rounded-2xl border border-white/10 bg-card/95 p-6 shadow-2xl backdrop-blur-md"
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
                <p>
                  Więcej opcji dostępnych w <span className="text-honey">Ustawieniach</span>.
                </p>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
