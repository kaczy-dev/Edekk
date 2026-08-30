import { useRef } from "react";
import { useFrame, useThree } from "@react-three/fiber";
import * as THREE from "three";
import { usePlayer3DStore } from "./usePlayer3DStore";

const OFFSET = new THREE.Vector3(0, 4.5, 6);

/** Simple third-person follow camera — smoothed lerp toward target + offset, no collision/occlusion handling yet. */
export function FollowCamera() {
  const { camera } = useThree();
  const desired = useRef(new THREE.Vector3());
  const playerPos = usePlayer3DStore((s) => s.position);

  useFrame(() => {
    desired.current.set(playerPos.x, playerPos.y, playerPos.z).add(OFFSET);
    camera.position.lerp(desired.current, 0.08);
    camera.lookAt(playerPos.x, playerPos.y + 0.5, playerPos.z);
  });

  return null;
}
