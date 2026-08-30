import { motion, AnimatePresence } from "framer-motion";

interface Props {
  text: string | null;
}

export function Toast({ text }: Props) {
  return (
    <AnimatePresence>
      {text && (
        <motion.div
          initial={{ opacity: 0, y: -8, x: -8 }}
          animate={{ opacity: 1, y: 0, x: 0 }}
          exit={{ opacity: 0, y: -8, x: -8 }}
          transition={{ type: "spring", stiffness: 300, damping: 25 }}
          className="pointer-events-none fixed top-6 right-6 z-30 max-w-xs rounded-xl border border-honey/40 bg-honey/20 backdrop-blur-md px-4 py-3 shadow-lg"
          role="status"
          aria-live="polite"
        >
          <p className="text-sm font-medium text-honey">{text}</p>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
