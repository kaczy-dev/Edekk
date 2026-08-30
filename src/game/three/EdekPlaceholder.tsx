import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useKeyboardVector } from "./useKeyboardVector";

const WALK_SPEED = 4; // world units/sec — placeholder scale, retune once real geometry exists

/**
 * Stand-in for Edek in the 3D world: a capsule mesh, no model/rig yet.
 * Movement mirrors the 2D engine's own contract (normalized WASD vector,
 * frame-independent via delta) so swapping this for a real rigged
 * character later doesn't change the input/movement plumbing.
 */
export function EdekPlaceholder({
  onMove,
}: {
  /** Called every frame with the character's current world position, for the camera rig to follow. */
  onMove?: (pos: THREE.Vector3) => void;
}) {
  const meshRef = useRef<THREE.Mesh>(null);
  const getInput = useKeyboardVector();
  const facing = useRef(0);

  useFrame((_, delta) => {
    const mesh = meshRef.current;
    if (!mesh) return;
    const { x, y } = getInput();
    if (x !== 0 || y !== 0) {
      mesh.position.x += x * WALK_SPEED * delta;
      mesh.position.z += y * WALK_SPEED * delta;
      facing.current = Math.atan2(x, y);
      mesh.rotation.y = THREE.MathUtils.lerp(mesh.rotation.y, facing.current, 0.25);
    }
    onMove?.(mesh.position);
  });

  return (
    <mesh ref={meshRef} position={[0, 0.5, 0]} castShadow>
      <capsuleGeometry args={[0.35, 0.6, 4, 8]} />
      <meshStandardMaterial color="#b0b0b8" />
    </mesh>
  );
}
