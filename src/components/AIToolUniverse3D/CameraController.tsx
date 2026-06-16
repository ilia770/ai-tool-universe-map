import { useEffect, useRef } from 'react';
import { useThree } from '@react-three/fiber';
import { CameraControls, CameraControlsImpl } from '@react-three/drei';
import { overviewFraming } from './cameraFraming';

const { ACTION } = CameraControlsImpl;

const POCKET_HEIGHT = 6.8;
const POCKET_DEPTH = 19.0;
const NODE_HEIGHT = 5.0;
const NODE_DEPTH = 15.5;

interface CameraControllerProps {
  targetKey: string;
  targetPosition: [number, number, number];
  viewMode: 'overview' | 'pocket' | 'node';
  reducedMotion: boolean;
}

export function CameraController({ targetKey, targetPosition, viewMode, reducedMotion }: CameraControllerProps) {
  // CameraControls instance type comes from camera-controls (indirect dep of drei)
  const controlsRef = useRef<React.ElementRef<typeof CameraControls>>(null);
  const lastTargetKeyRef = useRef<string | null>(null);
  const lastAspectRef = useRef<number | null>(null);

  // Live viewport aspect drives the overview framing (QA findings 1+2):
  // a tall/narrow portrait pulls the camera back and flattens the tilt so
  // the wide, thin category ellipse fits without clipping or leaving an
  // empty band. Pocket/node framings are aspect-independent.
  const aspect = useThree((state) => state.size.width / state.size.height);

  useEffect(() => {
    if (!controlsRef.current) return;

    const targetChanged = lastTargetKeyRef.current !== targetKey;
    const aspectChanged = lastAspectRef.current !== aspect;
    // Re-frame on a new target always; on a pure resize only in overview
    // (that's the only mode whose framing depends on aspect).
    if (!targetChanged && !(viewMode === 'overview' && aspectChanged)) return;
    lastTargetKeyRef.current = targetKey;
    lastAspectRef.current = aspect;

    const [x, y, z] = targetPosition;
    let height: number;
    let depth: number;
    if (viewMode === 'overview') {
      ({ height, depth } = overviewFraming(aspect));
    } else if (viewMode === 'pocket') {
      height = POCKET_HEIGHT;
      depth = POCKET_DEPTH;
    } else {
      height = NODE_HEIGHT;
      depth = NODE_DEPTH;
    }

    // Animate when the target changes; snap on a pure resize so the camera
    // doesn't visibly slide while the user is dragging the window edge.
    const animate = !reducedMotion && targetChanged;
    void controlsRef.current.setLookAt(x, y + height, z + depth, x, y, z, animate);
  }, [reducedMotion, targetKey, targetPosition, viewMode, aspect]);

  return (
    <CameraControls
      ref={controlsRef}
      makeDefault
      minDistance={7.5}
      maxDistance={46}
      smoothTime={reducedMotion ? 0.04 : 0.55}
      draggingSmoothTime={reducedMotion ? 0.02 : 0.08}
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
