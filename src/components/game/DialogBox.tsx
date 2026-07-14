import { motion, AnimatePresence } from "framer-motion";
import { useEffect } from "react";

interface Props {
  text: string | null;
  onClose: () => void;
  action?: {
    label: string;
    onClick: () => void;
  } | null;
}

export function DialogBox({ text, onClose, action }: Props) {
  useEffect(() => {
    if (!text) return;
    const onKey = (e: KeyboardEvent) => {
      const k = e.key.toLowerCase();
      if (k === "enter" || k === " " || k === "escape" || k === "e") {
        e.preventDefault();
        onClose();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [text, onClose]);

  return (
    <AnimatePresence>
      {text && (
        <motion.div
          initial={{ opacity: 0, y: 24, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 16, scale: 0.98 }}
          transition={{ type: "spring", stiffness: 280, damping: 26 }}
          className="pointer-events-auto absolute inset-x-4 bottom-36 z-40 mx-auto max-w-2xl rounded-2xl border border-honey/30 bg-card/95 p-5 shadow-2xl backdrop-blur-md md:bottom-24"
          onClick={onClose}
          role="dialog"
          aria-live="polite"
        >
          <div className="flex items-start gap-3">
            <span className="grid h-10 w-10 flex-none place-items-center rounded-full bg-primary/15 text-2xl ring-1 ring-honey/30">🐈</span>
            <div className="flex-1">
              <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-honey/80">Edek</div>
              <p className="mt-1 font-display text-lg leading-snug text-foreground">{text}</p>
            </div>
          </div>
          <div className="mt-3 flex items-center justify-between gap-3">
            <span className="text-[10px] uppercase tracking-widest text-white/40">Spacja / Enter</span>
            <div className="flex items-center gap-2">
              {action && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    action.onClick();
                  }}
                  className="rounded-full border border-honey/55 bg-honey/15 px-4 py-1.5 text-sm font-semibold text-honey transition hover:bg-honey/25 active:scale-95"
                >
                  {action.label}
                </button>
              )}
              <button
                onClick={(e) => { e.stopPropagation(); onClose(); }}
                className="rounded-full bg-primary px-4 py-1.5 text-sm font-semibold text-primary-foreground transition hover:opacity-90 active:scale-95"
              >
                Dalej →
              </button>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
