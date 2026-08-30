import { createFileRoute, Link } from "@tanstack/react-router";
import { World3D } from "@/game/three/World3D";

/**
 * Phase 1 prototype route for the hybrid React + Three.js + Phaser
 * architecture (see World3D.tsx for the phasing/scope doc). Not linked from
 * the main menu — reach it directly at /poziom3d. Fully independent of the
 * existing 2D game at /poziom/$id, which this does not touch.
 */
export const Route = createFileRoute("/poziom3d")({
  head: () => ({
    meta: [{ title: "Prototyp 3D — Przygody Edka" }],
  }),
  component: Prototype3DPage,
});

function Prototype3DPage() {
  return (
    <div className="relative">
      <Link
        to="/menu"
        className="pointer-events-auto fixed right-4 top-4 z-10 rounded-full border border-border bg-card/80 px-4 py-2 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card"
      >
        ← Menu
      </Link>
      <World3D />
    </div>
  );
}
