import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useKeyboardVector } from "./useKeyboardVector";
import { usePlayer3DStore } from "./usePlayer3DStore";
import { gameEventBus } from "./EventBus";

const WALK_SPEED = 4; // world units/sec — placeholder scale, retune once real geometry exists

/**
 * Stand-in for Edek in the 3D world: a capsule mesh, no model/rig yet.
 * Synced with usePlayer3DStore every frame, emits events via gameEventBus.
 * Movement mirrors the 2D engine's own contract (normalized WASD vector,
 * frame-independent via delta) so swapping this for a real rigged
 * character later doesn't change the input/movement plumbing.
 */
export function EdekPlaceholder() {
  const meshRef = useRef<THREE.Mesh>(null);
  const getInput = useKeyboardVector();
  const facing = useRef(0);
  const lastEmitPos = useRef({ x: 0, z: 0 });

  const setPosition = usePlayer3DStore((s) => s.setPosition);
  const setRotation = usePlayer3DStore((s) => s.setRotation);
  const setIsMoving = usePlayer3DStore((s) => s.setIsMoving);

  useFrame((_, delta) => {
    const mesh = meshRef.current;
    if (!mesh) return;

    const { x, y } = getInput();
    const isMoving = x !== 0 || y !== 0;

    if (isMoving) {
      mesh.position.x += x * WALK_SPEED * delta;
      mesh.position.z += y * WALK_SPEED * delta;
      facing.current = Math.atan2(x, y);
      mesh.rotation.y = THREE.MathUtils.lerp(mesh.rotation.y, facing.current, 0.25);
    }

    // Sync position to store
    setPosition(mesh.position.x, mesh.position.y, mesh.position.z);
    setRotation(mesh.rotation.y);
    setIsMoving(isMoving);

    // Emit player:moved event when position changes significantly (avoid spam)
    const dist = Math.hypot(
      mesh.position.x - lastEmitPos.current.x,
      mesh.position.z - lastEmitPos.current.z
    );
    if (dist > 0.1) {
      gameEventBus.emit("player:moved", {
        x: mesh.position.x,
        z: mesh.position.z,
        y: mesh.position.y,
      });
      lastEmitPos.current = { x: mesh.position.x, z: mesh.position.z };
    }
  });

  return (
    <mesh ref={meshRef} position={[0, 0.5, 0]} castShadow>
      <capsuleGeometry args={[0.35, 0.6, 4, 8]} />
      <meshStandardMaterial color="#b0b0b8" />
    </mesh>
  );
}
