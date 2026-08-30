import { useEffect, useRef, useState } from "react";

interface Props {
  onChange: (v: { x: number; y: number } | null) => void;
  side?: "left" | "right";
}

type Dir = "up" | "down" | "left" | "right";

export function DPad({ onChange, side = "left" }: Props) {
  const pressed = useRef<Set<Dir>>(new Set());
  const [, force] = useState(0);

  const emit = () => {
    let x = 0, y = 0;
    if (pressed.current.has("left")) x -= 1;
    if (pressed.current.has("right")) x += 1;
    if (pressed.current.has("up")) y -= 1;
    if (pressed.current.has("down")) y += 1;
    const len = Math.hypot(x, y);
    if (len > 0) { x /= len; y /= len; }
    if (pressed.current.size === 0) onChange(null);
    else onChange({ x, y });
    force((n) => n + 1);
  };

  const press = (d: Dir) => (e: React.PointerEvent) => {
    e.preventDefault();
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    pressed.current.add(d);
    emit();
  };
  const release = (d: Dir) => () => {
    if (!pressed.current.has(d)) return;
    pressed.current.delete(d);
    emit();
  };

  useEffect(() => () => { pressed.current.clear(); onChange(null); }, [onChange]);

  const btn = (d: Dir, label: string, extra: string) => (
    <button
      onPointerDown={press(d)}
      onPointerUp={release(d)}
      onPointerCancel={release(d)}
      onPointerLeave={release(d)}
      aria-label={d}
      className={[
        "pointer-events-auto grid place-items-center text-white/80 text-lg font-bold select-none transition active:scale-95 backdrop-blur-xl",
        pressed.current.has(d)
          ? "bg-honey/30 text-honey border-honey/70"
          : "bg-black/45 border-white/15",
        "border-2",
        extra,
      ].join(" ")}
    >
      {label}
    </button>
  );

  return (
    <div
      className={[
        "pointer-events-none fixed bottom-8 z-40 grid touch-none md:hidden",
        side === "left" ? "left-6" : "right-6",
      ].join(" ")}
      style={{
        width: 160,
        height: 160,
        gridTemplateColumns: "1fr 1fr 1fr",
        gridTemplateRows: "1fr 1fr 1fr",
        gap: 4,
      }}
    >
      <div />
      {btn("up", "▲", "rounded-t-2xl rounded-b-md")}
      <div />
      {btn("left", "◀", "rounded-l-2xl rounded-r-md")}
      <div className="grid place-items-center rounded-md border-2 border-white/10 bg-black/30 backdrop-blur">
        <div className="h-2 w-2 rounded-full bg-white/40" />
      </div>
      {btn("right", "▶", "rounded-r-2xl rounded-l-md")}
      <div />
      {btn("down", "▼", "rounded-b-2xl rounded-t-md")}
      <div />
    </div>
  );
}
