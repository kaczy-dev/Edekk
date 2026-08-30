import { useRef } from "react";
import { useFrame, useThree } from "@react-three/fiber";
import * as THREE from "three";

const OFFSET = new THREE.Vector3(0, 4.5, 6);

/** Simple third-person follow camera — smoothed lerp toward target + offset, no collision/occlusion handling yet. */
export function FollowCamera({ target }: { target: THREE.Vector3 }) {
  const { camera } = useThree();
  const desired = useRef(new THREE.Vector3());

  useFrame(() => {
    desired.current.copy(target).add(OFFSET);
    camera.position.lerp(desired.current, 0.08);
    camera.lookAt(target.x, target.y + 0.5, target.z);
  });

  return null;
}
