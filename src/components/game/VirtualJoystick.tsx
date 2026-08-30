import { useEffect, useRef, useState } from "react";

interface Props {
  onChange: (v: { x: number; y: number } | null) => void;
  onSprintToggle?: (active: boolean) => void;
  side?: "left" | "right";
}

const SIZE = 160;
const KNOB = 64;
const DEADZONE = 0.10;

export function VirtualJoystick({ onChange, onSprintToggle, side = "left" }: Props) {
  const baseRef = useRef<HTMLDivElement>(null);
  const knobRef = useRef<HTMLDivElement>(null);
  const activeId = useRef<number | null>(null);
  const [active, setActive] = useState<{ x: number; y: number } | null>(null);
  const [sprintActive, setSprintActive] = useState(false);
  const lastTapTime = useRef(0);

  useEffect(() => {
    const base = baseRef.current;
    const knob = knobRef.current;
    if (!base || !knob) return;

    const reset = () => {
      knob.style.transform = `translate3d(0px, 0px, 0)`;
      onChange(null);
      setActive(null);
      activeId.current = null;
    };

    const onDown = (e: PointerEvent) => {
      activeId.current = e.pointerId;
      base.setPointerCapture(e.pointerId);
      const now = Date.now();
      if (now - lastTapTime.current < 300) {
        const newSprint = !sprintActive;
        setSprintActive(newSprint);
        onSprintToggle?.(newSprint);
      }
      lastTapTime.current = now;
      move(e);
    };
    const move = (e: PointerEvent) => {
      if (activeId.current !== e.pointerId) return;
      const r = base.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      let dx = e.clientX - cx;
      let dy = e.clientY - cy;
      const max = SIZE / 2 - KNOB / 4;
      const len = Math.hypot(dx, dy);
      if (len > max) { dx = (dx / len) * max; dy = (dy / len) * max; }
      knob.style.transform = `translate3d(${dx}px, ${dy}px, 0)`;
      const nx = dx / max;
      const ny = dy / max;
      const mag = Math.hypot(nx, ny);
      if (mag < DEADZONE) {
        onChange({ x: 0, y: 0 });
        setActive({ x: 0, y: 0 });
      } else {
        onChange({ x: nx, y: ny });
        setActive({ x: nx, y: ny });
      }
    };
    const up = (e: PointerEvent) => {
      if (activeId.current !== e.pointerId) return;
      reset();
    };
    base.addEventListener("pointerdown", onDown);
    base.addEventListener("pointermove", move);
    base.addEventListener("pointerup", up);
    base.addEventListener("pointercancel", up);
    return () => {
      base.removeEventListener("pointerdown", onDown);
      base.removeEventListener("pointermove", move);
      base.removeEventListener("pointerup", up);
      base.removeEventListener("pointercancel", up);
    };
  }, [onChange]);

  // dominant direction for arrow highlighting
  const dir = active && Math.hypot(active.x, active.y) > 0.3
    ? Math.abs(active.x) > Math.abs(active.y)
      ? (active.x > 0 ? "right" : "left")
      : (active.y > 0 ? "down" : "up")
    : null;

  const arrowCls = (d: string) =>
    "absolute text-white/55 text-xs font-bold select-none transition-all " +
    (dir === d ? "text-honey scale-125" : "");

  return (
    <div
      ref={baseRef}
      className={[
        "pointer-events-auto fixed bottom-8 z-40 touch-none rounded-full border-2 backdrop-blur-xl shadow-2xl md:hidden transition-colors",
        side === "left" ? "left-6" : "right-6",
        sprintActive
          ? "border-primary/80 bg-gradient-to-br from-primary/20 to-primary/5"
          : active ? "border-honey/70 bg-gradient-to-br from-white/25 to-white/5" : "border-white/20 bg-gradient-to-br from-white/15 to-white/5",
      ].join(" ")}
      style={{ width: SIZE, height: SIZE }}
      aria-label="Joystick"
    >
      {/* inner ring */}
      <div className="absolute inset-3 rounded-full border border-white/15" />
      {/* directional arrows */}
      <span className={arrowCls("up") + " left-1/2 top-1.5 -translate-x-1/2"}>▲</span>
      <span className={arrowCls("down") + " left-1/2 bottom-1.5 -translate-x-1/2"}>▼</span>
      <span className={arrowCls("left") + " left-1.5 top-1/2 -translate-y-1/2"}>◀</span>
      <span className={arrowCls("right") + " right-1.5 top-1/2 -translate-y-1/2"}>▶</span>
      {/* center dot */}
      <div className="absolute left-1/2 top-1/2 h-1.5 w-1.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white/30" />
      {/* knob */}
      <div
        ref={knobRef}
        className={[
          "absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full shadow-xl ring-2 transition-[box-shadow,ring-color] duration-75 ease-out",
          sprintActive
            ? "ring-primary/70 bg-gradient-to-br from-primary to-accent"
            : active ? "ring-honey/60 bg-gradient-to-br from-honey to-primary" : "ring-white/30 bg-gradient-to-br from-primary to-accent",
        ].join(" ")}
        style={{ width: KNOB, height: KNOB }}
      >
        <div className="absolute inset-2 rounded-full bg-white/15" />
      </div>
    </div>
  );
}
