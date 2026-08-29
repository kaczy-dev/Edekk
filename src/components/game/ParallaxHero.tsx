import { createContext, useContext, useRef, type ReactNode } from "react";
import { motion, useMotionValue, useSpring, useTransform, type MotionValue } from "framer-motion";
import { useGameStore } from "@/store/gameStore";

type Pointer = { x: MotionValue<number>; y: MotionValue<number> };

const ParallaxContext = createContext<Pointer | null>(null);

function usePointer(): Pointer {
  const ctx = useContext(ParallaxContext);
  if (!ctx) throw new Error("<ParallaxLayer> must be rendered inside <ParallaxHero>");
  return ctx;
}

/**
 * Mouse-driven parallax stage. The pointer is tracked once into spring-smoothed
 * motion values shared with every layer, so depth stays consistent and moving
 * the mouse animates on the compositor without re-rendering the subtree.
 */
export function ParallaxHero({ children, className = "" }: { children: ReactNode; className?: string }) {
  const reducedMotion = useGameStore((s) => s.controls.reducedMotion);
  const ref = useRef<HTMLDivElement>(null);
  const rawX = useMotionValue(0);
  const rawY = useMotionValue(0);
  const spring = { stiffness: 90, damping: 20, mass: 0.8 };
  const pointer: Pointer = { x: useSpring(rawX, spring), y: useSpring(rawY, spring) };

  const recentre = () => {
    rawX.set(0);
    rawY.set(0);
  };

  return (
    <div
      ref={ref}
      onPointerMove={(e) => {
        if (reducedMotion) return;
        const r = ref.current?.getBoundingClientRect();
        if (!r) return;
        rawX.set((e.clientX - r.left) / r.width - 0.5);
        rawY.set((e.clientY - r.top) / r.height - 0.5);
      }}
      onPointerLeave={recentre}
      className={className}
    >
      <ParallaxContext.Provider value={pointer}>{children}</ParallaxContext.Provider>
    </div>
  );
}

/** One depth plane. `depth` 0 stays put, higher values travel further. */
export function ParallaxLayer({
  depth,
  className = "",
  children,
}: {
  depth: number;
  className?: string;
  children: ReactNode;
}) {
  const pointer = usePointer();
  const range = 26 * depth;
  const x = useTransform(pointer.x, [-0.5, 0.5], [-range, range]);
  const y = useTransform(pointer.y, [-0.5, 0.5], [-range * 0.6, range * 0.6]);
  return (
    <motion.div style={{ x, y }} className={className}>
      {children}
    </motion.div>
  );
}
