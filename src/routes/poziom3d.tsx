import { createFileRoute, Link } from "@tanstack/react-router";
import { World3D } from "@/game/three/World3D";
import { PhaserHUD } from "@/game/three/PhaserHUD";

/**
 * Phase 2 prototype route for the hybrid React + Three.js + Phaser
 * architecture. World3D renders the 3D scene (Three.js), PhaserHUD renders
 * the 2D overlay (Phaser), both synced through Zustand + EventBus.
 * Not linked from the main menu — reach it directly at /poziom3d.
 * Fully independent of the existing 2D game at /poziom/$id.
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
      <World3D />
      <PhaserHUD />
      <Link
        to="/menu"
        className="pointer-events-auto fixed right-4 top-4 z-20 rounded-full border border-border bg-card/80 px-4 py-2 text-sm font-medium text-foreground backdrop-blur transition hover:bg-card"
      >
        ← Menu
      </Link>
    </div>
  );
}
