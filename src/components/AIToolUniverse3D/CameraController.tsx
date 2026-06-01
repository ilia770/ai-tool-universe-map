import { useEffect, useRef } from 'react';
import { CameraControls, CameraControlsImpl } from '@react-three/drei';

const { ACTION } = CameraControlsImpl;

interface CameraControllerProps {
  targetKey: string;
  targetPosition: [number, number, number];
  viewMode: 'overview' | 'pocket' | 'node';
}

export function CameraController({ targetKey, targetPosition, viewMode }: CameraControllerProps) {
  // CameraControls instance type comes from camera-controls (indirect dep of drei)
  const controlsRef = useRef<React.ElementRef<typeof CameraControls>>(null);
  const lastTargetKeyRef = useRef<string | null>(null);

  useEffect(() => {
    if (!controlsRef.current || lastTargetKeyRef.current === targetKey) return;
    lastTargetKeyRef.current = targetKey;

    const [x, y, z] = targetPosition;
    const cameraY = y + (viewMode === 'overview' ? 6.3 : viewMode === 'pocket' ? 5.25 : 3.5);
    const cameraZ = z + (viewMode === 'overview' ? 19.5 : viewMode === 'pocket' ? 16.4 : 11.2);

    void controlsRef.current.setLookAt(
      x, cameraY, cameraZ,
      x, y, z,
      true,
    );
  }, [targetKey, targetPosition, viewMode]);

  return (
    <CameraControls
      ref={controlsRef}
      makeDefault
      minDistance={5.5}
      maxDistance={42}
      smoothTime={0.55}
      draggingSmoothTime={0.08}
      dollyToCursor
      mouseButtons={{
        left: ACTION.ROTATE,
        middle: ACTION.DOLLY,
        right: ACTION.TRUCK,
        wheel: ACTION.DOLLY,
      }}
      touches={{
        one: ACTION.TOUCH_ROTATE,
        two: ACTION.TOUCH_DOLLY_TRUCK,
        three: ACTION.TOUCH_DOLLY_TRUCK,
      }}
    />
  );
}
