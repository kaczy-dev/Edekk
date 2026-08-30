import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { useGameStore } from "@/store/gameStore";

interface Props {
  text: string | null;
  onClose: () => void;
}

/** ms per revealed character — tuned for a cozy retro-adventure feel, not a race. */
const TYPE_SPEED_MS = 22;

export function DialogBox({ text, onClose }: Props) {
  const reducedMotion = useGameStore((s) => s.controls.reducedMotion);
  const [revealed, setRevealed] = useState(0);
  const typingRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const fullyRevealed = text !== null && revealed >= text.length;

  useEffect(() => {
    if (typingRef.current) clearInterval(typingRef.current);
    if (!text) {
      setRevealed(0);
      return;
    }
    if (reducedMotion) {
      setRevealed(text.length);
      return;
    }
    setRevealed(0);
    typingRef.current = setInterval(() => {
      setRevealed((n) => {
        if (n >= text.length) {
          if (typingRef.current) clearInterval(typingRef.current);
          return n;
        }
        return n + 1;
      });
    }, TYPE_SPEED_MS);
    return () => {
      if (typingRef.current) clearInterval(typingRef.current);
    };
  }, [text, reducedMotion]);

  // The interact/advance key first skips the typewriter to the full line,
  // then closes on a second press — mirrors how the visible "Dalej" click
  // already behaves below.
  const advance = () => {
    if (!text) return;
    if (revealed < text.length) setRevealed(text.length);
    else onClose();
  };

  useEffect(() => {
    if (!text) return;
    const onKey = (e: KeyboardEvent) => {
      const k = e.key.toLowerCase();
      if (k === "enter" || k === " " || k === "escape" || k === "e") {
        e.preventDefault();
        if (k === "escape") onClose();
        else advance();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text, revealed, onClose]);

  return (
    <AnimatePresence>
      {text && (
        <motion.div
          initial={{ opacity: 0, y: 24, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 16, scale: 0.98 }}
          transition={{ type: "spring", stiffness: 280, damping: 26 }}
          className="pointer-events-auto absolute inset-x-4 bottom-36 z-40 mx-auto max-w-2xl rounded-2xl border border-honey/30 bg-card/95 p-5 shadow-2xl backdrop-blur-md md:bottom-24"
          onClick={advance}
          role="dialog"
          aria-live="polite"
        >
          <div className="flex items-start gap-3">
            <span className="grid h-10 w-10 flex-none place-items-center rounded-full bg-primary/15 text-2xl ring-1 ring-honey/30">
              🐈
            </span>
            <div className="flex-1">
              <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-honey/80">
                Edek
              </div>
              <p className="mt-1 font-display text-lg leading-snug text-foreground">
                {text.slice(0, revealed)}
                {!fullyRevealed && <span className="animate-pulse text-honey">▍</span>}
              </p>
            </div>
          </div>
          <div className="mt-3 flex items-center justify-between">
            <span className="text-[10px] uppercase tracking-widest text-white/40">
              Spacja / Enter
            </span>
            <button
              onClick={(e) => {
                e.stopPropagation();
                advance();
              }}
              className="rounded-full bg-primary px-4 py-1.5 text-sm font-semibold text-primary-foreground transition hover:opacity-90 active:scale-95"
            >
              {fullyRevealed ? "Dalej →" : "Pomiń"}
            </button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
