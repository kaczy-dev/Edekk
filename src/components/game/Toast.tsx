import { motion, AnimatePresence } from "framer-motion";

export interface ToastItem {
  id: number;
  text: string;
}

interface Props {
  items: ToastItem[];
}

/** Stacks multiple toasts vertically instead of the newest replacing the last. */
export function Toast({ items }: Props) {
  return (
    <div className="pointer-events-none fixed top-6 right-6 z-30 flex flex-col gap-2">
      <AnimatePresence>
        {items.map((item) => (
          <motion.div
            key={item.id}
            layout
            initial={{ opacity: 0, y: -8, x: -8 }}
            animate={{ opacity: 1, y: 0, x: 0 }}
            exit={{ opacity: 0, y: -8, x: -8 }}
            transition={{ type: "spring", stiffness: 300, damping: 25 }}
            className="max-w-xs rounded-xl border border-honey/40 bg-honey/20 backdrop-blur-md px-4 py-3 shadow-lg"
            role="status"
            aria-live="polite"
          >
            <p className="text-sm font-medium text-honey">{item.text}</p>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
