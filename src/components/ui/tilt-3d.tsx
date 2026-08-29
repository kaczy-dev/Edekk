import { useRef, type ReactNode } from "react";
import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import { useGameStore } from "@/store/gameStore";

interface Props {
  children: ReactNode;
  className?: string;
  /** Max rotation in degrees at the card's edge. */
  intensity?: number;
  /** How far the content lifts toward the viewer, in px. */
  lift?: number;
  /** Render the moving specular sheen. */
  sheen?: boolean;
}

/**
 * Perspective tilt that follows the pointer.
 *
 * The pointer position is tracked in motion values (not React state), so moving
 * the mouse animates on the compositor without re-rendering the subtree.
 * Honours the player's reduced-motion setting by rendering a plain container.
 */
export function Tilt3D({
  children,
  className = "",
  intensity = 10,
  lift = 26,
  sheen = true,
}: Props) {
  const reducedMotion = useGameStore((s) => s.controls.reducedMotion);
  const ref = useRef<HTMLDivElement>(null);

  // -0.5 .. 0.5 relative to the element's centre.
  const px = useMotionValue(0);
  const py = useMotionValue(0);

  const spring = { stiffness: 220, damping: 22, mass: 0.6 };
  const rotateX = useSpring(useTransform(py, [-0.5, 0.5], [intensity, -intensity]), spring);
  const rotateY = useSpring(useTransform(px, [-0.5, 0.5], [-intensity, intensity]), spring);
  // Every hook must run before the reduced-motion early return.
  const sheenBackground = useTransform(
    [px, py],
    ([x, y]: number[]) =>
      `radial-gradient(600px circle at ${(x + 0.5) * 100}% ${(y + 0.5) * 100}%, rgba(255,255,255,0.35), transparent 45%)`
  );

  if (reducedMotion) {
    return <div className={className}>{children}</div>;
  }

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    px.set((e.clientX - r.left) / r.width - 0.5);
    py.set((e.clientY - r.top) / r.height - 0.5);
  };

  const reset = () => {
    px.set(0);
    py.set(0);
  };

  return (
    <motion.div
      ref={ref}
      onPointerMove={onPointerMove}
      onPointerLeave={reset}
      style={{ perspective: 1000 }}
      className={className}
    >
      <motion.div
        style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
        className="relative h-full w-full"
      >
        {/* Content is pushed forward in Z so it parallaxes against the card face. */}
        <div style={{ transform: `translateZ(${lift}px)`, transformStyle: "preserve-3d" }} className="h-full w-full">
          {children}
        </div>

        {sheen && (
          <motion.div
            aria-hidden
            className="pointer-events-none absolute inset-0 rounded-[inherit] mix-blend-soft-light"
            style={{ background: sheenBackground, transform: "translateZ(1px)" }}
          />
        )}
      </motion.div>
    </motion.div>
  );
}
