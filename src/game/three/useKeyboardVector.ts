import { useEffect, useRef } from "react";

/**
 * WASD/arrow input as a normalized 2D vector, read imperatively via a ref
 * (not React state) so `useFrame` can poll it every frame without
 * re-rendering the component tree — same "don't mirror per-frame engine
 * values into React state" rule the 2D Phaser bridge already follows
 * (see PhaserGameCanvas.tsx, which reads `sceneRef.current` directly).
 */
export function useKeyboardVector() {
  const vec = useRef({ x: 0, y: 0 });
  const keys = useRef(new Set<string>());

  useEffect(() => {
    const onDown = (e: KeyboardEvent) => keys.current.add(e.key.toLowerCase());
    const onUp = (e: KeyboardEvent) => keys.current.delete(e.key.toLowerCase());
    window.addEventListener("keydown", onDown);
    window.addEventListener("keyup", onUp);
    return () => {
      window.removeEventListener("keydown", onDown);
      window.removeEventListener("keyup", onUp);
    };
  }, []);

  return () => {
    const k = keys.current;
    let x =
      (k.has("d") || k.has("arrowright") ? 1 : 0) - (k.has("a") || k.has("arrowleft") ? 1 : 0);
    let y = (k.has("s") || k.has("arrowdown") ? 1 : 0) - (k.has("w") || k.has("arrowup") ? 1 : 0);
    const len = Math.hypot(x, y);
    if (len > 1) {
      x /= len;
      y /= len;
    }
    vec.current.x = x;
    vec.current.y = y;
    return vec.current;
  };
}
