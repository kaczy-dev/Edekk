import { useEffect, useRef } from "react";
import * as Phaser from "phaser";
import { usePlayer3DStore } from "./usePlayer3DStore";
import { gameEventBus } from "./EventBus";
import { useGameStore } from "@/store/gameStore";

/**
 * Phase 2: Phaser overlay HUD for the 3D world.
 * Renders on a separate canvas on top of Three.js R3F.
 * Displays: player energy, position debug, movement state.
 *
 * This component demonstrates the hybrid architecture:
 * - Three.js renders the 3D world
 * - Phaser handles 2D UI overlay
 * - Both read from the same Zustand stores
 * - Communication through EventBus for loose coupling
 */

export function PhaserHUD() {
  const containerRef = useRef<HTMLDivElement>(null);
  const gameRef = useRef<Phaser.Game | null>(null);
  const energy = useGameStore((s) => s.energy);
  const playerPos = usePlayer3DStore((s) => s.position);
  const playerRotation = usePlayer3DStore((s) => s.rotation);
  const isMoving = usePlayer3DStore((s) => s.isMoving);

  useEffect(() => {
    if (!containerRef.current || gameRef.current) return;

    // Scene class for HUD
    class HUDScene extends Phaser.Scene {
      private energyText?: Phaser.GameObjects.Text;
      private positionText?: Phaser.GameObjects.Text;
      private stateText?: Phaser.GameObjects.Text;

      constructor() {
        super({ key: "HUD" });
      }

      create() {
        const width = this.cameras.main.width;
        const height = this.cameras.main.height;

        // Energy bar background
        this.add.rectangle(20, 20, 100, 20, 0x333333);
        this.add.rectangle(20, 20, 100 * 0.8, 20, 0x00aa00);

        // Energy text
        this.energyText = this.add.text(130, 12, "Energy: 100", {
          font: "12px monospace",
          color: "#ffffff",
        });

        // Position text (debug)
        this.positionText = this.add.text(10, height - 60, "Pos: (0, 0, 0)", {
          font: "11px monospace",
          color: "#aaaaaa",
        });

        // Movement state text
        this.stateText = this.add.text(10, height - 40, "State: idle", {
          font: "11px monospace",
          color: "#aaaaaa",
        });

        // Listen to EventBus for player movement
        gameEventBus.on("player:moved", (data) => {
          console.log("[HUD] Player moved:", data);
        });
      }

      update() {
        // Update energy
        if (this.energyText) {
          this.energyText.setText(`Energy: ${Math.round(energy)}`);
        }

        // Update position (debug)
        if (this.positionText) {
          this.positionText.setText(
            `Pos: (${playerPos.x.toFixed(1)}, ${playerPos.y.toFixed(1)}, ${playerPos.z.toFixed(1)})`
          );
        }

        // Update state
        if (this.stateText) {
          this.stateText.setText(`State: ${isMoving ? "moving" : "idle"}`);
        }
      }
    }

    // Phaser config — render on top layer
    const config: Phaser.Types.Core.GameConfig = {
      type: Phaser.AUTO,
      parent: containerRef.current,
      width: "100%",
      height: "100%",
      transparent: true, // Important: render over Three.js
      scene: HUDScene,
      render: {
        pixelArt: false,
        antialias: true,
      },
    };

    const game = new Phaser.Game(config);
    gameRef.current = game;

    return () => {
      game.destroy(true);
      gameRef.current = null;
    };
  }, [energy, playerPos, isMoving]);

  return (
    <div
      ref={containerRef}
      className="pointer-events-none fixed inset-0"
      style={{ zIndex: 100 }}
    />
  );
}
