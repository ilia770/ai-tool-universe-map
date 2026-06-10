import { useFrame } from '@react-three/fiber';
import { useEffect, useRef } from 'react';
import type { ToolCategoryId } from '../../data/ai-tool-universe';

interface Anchor {
  id: ToolCategoryId;
  position: [number, number, number];
}

interface ProximityCategoryWatcherProps {
  anchors: Anchor[];
  activeCategory: ToolCategoryId | 'all';
  /** Distance below which the nearest anchor triggers pocket entry. */
  enterDistance: number;
  /** Distance above which the active pocket auto-exits. Must be > enterDistance. */
  exitDistance: number;
  /** Minimum delay between auto-enter/exit in ms, prevents flicker. */
  cooldownMs: number;
  onEnter: (id: ToolCategoryId) => void;
  onExit: () => void;
}

/**
 * Polls camera distance every ~160ms (~6 Hz). When the user dollies the
 * camera below `enterDistance` of a category anchor while the map is in
 * the all-groups view, auto-selects that category so its PocketWorldShell
 * opens. Once a pocket is open, auto-exit is armed only after the camera
 * reaches the pocket region, so manual clicks do not immediately close while
 * the camera is still travelling from the overview.
 */
export function ProximityCategoryWatcher({
  anchors,
  activeCategory,
  enterDistance,
  exitDistance,
  cooldownMs,
  onEnter,
  onExit,
}: ProximityCategoryWatcherProps) {
  const lastTriggerRef = useRef(0);
  const lastTickRef = useRef(0);
  const exitArmedCategoryRef = useRef<ToolCategoryId | null>(null);

  useEffect(() => {
    if (activeCategory === 'all') {
      exitArmedCategoryRef.current = null;
      return;
    }

    if (exitArmedCategoryRef.current !== activeCategory) {
      exitArmedCategoryRef.current = null;
    }
  }, [activeCategory]);

  useFrame(({ camera, clock }) => {
    const nowMs = clock.elapsedTime * 1000;
    if (nowMs - lastTickRef.current < 160) return;
    lastTickRef.current = nowMs;
    if (nowMs - lastTriggerRef.current < cooldownMs) return;

    // Auto-exit: a pocket is open, but camera pulled back past exitDistance.
    if (activeCategory !== 'all') {
      const activeAnchor = anchors.find((a) => a.id === activeCategory);
      if (!activeAnchor) return;
      const dx = camera.position.x - activeAnchor.position[0];
      const dy = camera.position.y - activeAnchor.position[1];
      const dz = camera.position.z - activeAnchor.position[2];
      const distSq = dx * dx + dy * dy + dz * dz;
      const exitDistSq = exitDistance * exitDistance;
      const armDistSq = exitDistSq * 0.67;

      if (distSq <= armDistSq) {
        exitArmedCategoryRef.current = activeCategory;
      }

      if (exitArmedCategoryRef.current === activeCategory && distSq > exitDistSq) {
        lastTriggerRef.current = nowMs;
        exitArmedCategoryRef.current = null;
        onExit();
      }
      return;
    }

    // Auto-enter: no pocket open, find nearest anchor under enterDistance.
    const enterDistSq = enterDistance * enterDistance;
    let nearestId: ToolCategoryId | null = null;
    let nearestDistSq = enterDistSq;

    for (const anchor of anchors) {
      const dx = camera.position.x - anchor.position[0];
      const dy = camera.position.y - anchor.position[1];
      const dz = camera.position.z - anchor.position[2];
      const distSq = dx * dx + dy * dy + dz * dz;
      if (distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearestId = anchor.id;
      }
    }

    if (nearestId) {
      lastTriggerRef.current = nowMs;
      onEnter(nearestId);
    }
  });

  return null;
}
