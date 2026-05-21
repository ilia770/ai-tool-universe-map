import { useEffect, useRef } from 'react';
import { CameraControls } from '@react-three/drei';

interface CameraControllerProps {
  targetPosition: [number, number, number] | null;
}

export function CameraController({ targetPosition }: CameraControllerProps) {
  // CameraControls instance type comes from camera-controls (indirect dep of drei)
  const controlsRef = useRef<React.ElementRef<typeof CameraControls>>(null);

  useEffect(() => {
    if (!controlsRef.current || !targetPosition) return;
    const [x, y, z] = targetPosition;
    void controlsRef.current.setLookAt(
      x, y + 2, z + 5,
      x, y, z,
      true,
    );
  }, [targetPosition]);

  return (
    <CameraControls
      ref={controlsRef}
      minDistance={4}
      maxDistance={40}
      makeDefault
    />
  );
}
