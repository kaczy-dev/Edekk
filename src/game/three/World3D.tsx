import { useEffect, useRef, useState } from "react";
import { Canvas } from "@react-three/fiber";
import * as THREE from "three";
import { EdekPlaceholder } from "./EdekPlaceholder";
import { FollowCamera } from "./FollowCamera";

/**
 * Phase 1 foundation for the hybrid React + Three.js + Phaser architecture:
 * Three.js/R3F owns the 3D world (this component) — objects, lighting,
 * camera. Phaser (not wired in yet) will own 2D overlay concerns: HUD,
 * dialogue, minimap, dynamic textures painted onto 3D surfaces. React (the
 * route this mounts into) owns menus, loading screens, and app-level state
 * via the existing Zustand store.
 *
 * This is a standalone prototype scene, not a port of any existing level —
 * it doesn't touch `LevelScene.ts`/`levels.ts`/the 2D game at all. Reachable
 * at /poziom3d, not linked from the main menu yet.
 *
 * Deliberately NOT yet included in this first slice (next phases):
 * - Phaser mounted as a 2D overlay/texture source
 * - Real Edek model/rig (capsule placeholder only)
 * - Zustand store bridge for position/energy/inventory
 * - Level geometry, collision, quests — anything from the existing 2D levels
 */
export function World3D() {
  // Mutated in place by EdekPlaceholder every frame and read in place by
  // FollowCamera every frame — the object identity never changes, so no
  // React re-render is needed to keep the camera's target current (mirrors
  // the "don't mirror per-frame engine values into React state" rule from
  // useKeyboardVector.ts).
  const targetRef = useRef(new THREE.Vector3(0, 0, 0));

  // R3F's <Canvas> touches the DOM/WebGL context during its own render
  // (unlike Phaser here, which is only ever constructed inside a
  // client-only useEffect — see PhaserGameCanvas.tsx) — mount it only after
  // hydration so TanStack Start's SSR pass never renders it server-side.
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  return (
    <div className="h-dvh w-full bg-black">
      {mounted && (
        <Canvas shadows camera={{ fov: 50 }}>
          <ambientLight intensity={0.5} />
          <directionalLight
            position={[5, 8, 3]}
            intensity={1.2}
            castShadow
            shadow-mapSize={[1024, 1024]}
          />

          <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
            <planeGeometry args={[60, 60]} />
            <meshStandardMaterial color="#3a5a3a" />
          </mesh>

          <EdekPlaceholder onMove={(pos) => targetRef.current.copy(pos)} />
          <FollowCamera target={targetRef.current} />
        </Canvas>
      )}
      <div className="pointer-events-none fixed left-4 top-4 rounded-lg bg-black/60 px-3 py-2 text-xs text-white/80">
        Prototyp 3D (Faza 1) — WASD do ruchu. Kapsuła = tymczasowy Edek.
      </div>
    </div>
  );
}
