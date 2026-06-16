import { useCallback, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, type ThreeEvent } from '@react-three/fiber';
import { Html } from '@react-three/drei';
import * as THREE from 'three';
import {
  categories,
  categoryById,
  tools,
  toolById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

/**
 * Direction D — "TheBrain" plex navigation.
 *
 * TheBrain's plex always keeps one "active thought" at dead centre. Around it,
 * related thoughts are zoned by relationship: PARENTS sit above, CHILDREN below,
 * and lateral "jump"/related thoughts fan out to the sides. Clicking any visible
 * thought makes it the new active thought; the whole plex then smoothly slides
 * and reorganises so the clicked node animates to centre and its own relations
 * re-zone around it. The motion (eased recentre) is what makes it addictive —
 * you fall through the graph one thought at a time, never losing your bearings
 * because the focus is always centred.
 *
 * Here the focus tool is centred; its `relationIds` become the lower "children"
 * arc, its category siblings become the lateral "related" ring, and its
 * category hub / Founder OS becomes the "parent" placed above. Every node owns a
 * persistent THREE.Vector3 we re-target on focus change and ease toward each
 * frame (no per-frame allocation, no camera movement — the layout itself moves).
 */

// ---------------------------------------------------------------------------
// Seeded PRNG (mulberry32) — deterministic, no Math.random in render.
// ---------------------------------------------------------------------------

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Stable per-tool seed so idle jitter is reproducible across reloads.
function hashId(id: string): number {
  let h = 2166136261;
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// ---------------------------------------------------------------------------
// Static graph relationships (built once at module load).
// ---------------------------------------------------------------------------

const HUB_ID = 'founder-os';

// Undirected adjacency from relationIds (both endpoints must exist).
const ADJACENCY: Map<string, Set<string>> = (() => {
  const adj = new Map<string, Set<string>>();
  const ensure = (id: string) => {
    let s = adj.get(id);
    if (!s) {
      s = new Set<string>();
      adj.set(id, s);
    }
    return s;
  };
  for (const tool of tools) {
    ensure(tool.id);
    for (const relId of tool.relationIds) {
      if (!toolById.has(relId)) continue;
      ensure(tool.id).add(relId);
      ensure(relId).add(tool.id);
    }
  }
  return adj;
})();

// Category members, in stable order.
const CATEGORY_MEMBERS: Map<string, string[]> = (() => {
  const m = new Map<string, string[]>();
  for (const tool of tools) {
    const arr = m.get(tool.category);
    if (arr) arr.push(tool.id);
    else m.set(tool.category, [tool.id]);
  }
  return m;
})();

// ---------------------------------------------------------------------------
// Plex zoning — given a focus id, decide where every node should sit.
// ---------------------------------------------------------------------------

type Zone = 'focus' | 'parent' | 'child' | 'related' | 'far';

interface Placement {
  zone: Zone;
  target: THREE.Vector3;
}

const TMP_OUT = new THREE.Vector3(0, 0, -42); // resting place for far nodes

function colorOf(tool: AITool): THREE.Color {
  const cat = categoryById.get(tool.category);
  return new THREE.Color(cat?.color ?? '#9bd6ff');
}

/** Position helper: arc of `count` nodes around a centre angle on a radius. */
function arcPosition(
  index: number,
  count: number,
  radius: number,
  centreAngleDeg: number,
  spreadDeg: number,
  y: number,
  out: THREE.Vector3,
): void {
  const t = count <= 1 ? 0.5 : index / (count - 1);
  const angle = (centreAngleDeg + (t - 0.5) * spreadDeg) * (Math.PI / 180);
  out.set(Math.sin(angle) * radius, y, -Math.cos(angle) * radius * 0.42);
}

/**
 * Compute zone + target position for every tool given the active focus.
 *  - focus   → origin
 *  - parent  → above (hub for the focus, or Founder OS)
 *  - child   → lower arc (focus.relationIds)
 *  - related → lateral rings (category siblings not already children)
 *  - far     → pushed back out of frame
 */
function computePlacements(focusId: string): Map<string, Placement> {
  const result = new Map<string, Placement>();
  const focus = toolById.get(focusId);
  if (!focus) return result;

  const used = new Set<string>([focusId]);

  // Parent: for non-hub focus, parent is Founder OS (the operating core).
  // For the hub itself, there is no parent.
  const parentId = focusId === HUB_ID ? null : HUB_ID;

  // Children: relationIds that exist (excluding the parent so it stays above).
  const childIds = focus.relationIds.filter(
    (id) => toolById.has(id) && id !== parentId && id !== focusId,
  );

  // Related: category siblings + remaining graph neighbours, minus children.
  const sibling = CATEGORY_MEMBERS.get(focus.category) ?? [];
  const neighbours = ADJACENCY.get(focusId) ?? new Set<string>();
  const relatedSet = new Set<string>();
  for (const id of sibling) {
    if (id !== focusId && id !== parentId && !childIds.includes(id)) {
      relatedSet.add(id);
    }
  }
  for (const id of neighbours) {
    if (id !== focusId && id !== parentId && !childIds.includes(id)) {
      relatedSet.add(id);
    }
  }
  const relatedIds = [...relatedSet];

  const v = new THREE.Vector3();

  // Focus at centre.
  result.set(focusId, { zone: 'focus', target: new THREE.Vector3(0, 0, 0) });

  // Parent above.
  if (parentId && toolById.has(parentId)) {
    result.set(parentId, {
      zone: 'parent',
      target: new THREE.Vector3(0, 9.5, -2),
    });
    used.add(parentId);
  }

  // Children: lower arc (fan out below).
  childIds.forEach((id, i) => {
    arcPosition(i, childIds.length, 11, 0, Math.min(150, 30 + childIds.length * 18), -8.5, v);
    result.set(id, { zone: 'child', target: v.clone() });
    used.add(id);
  });

  // Related: two lateral clusters (left + right), gently staggered in depth.
  relatedIds.forEach((id, i) => {
    const onLeft = i % 2 === 0;
    const rank = Math.floor(i / 2);
    const radius = 13 + rank * 2.6;
    const baseAngle = onLeft ? -90 : 90;
    arcPosition(rank, Math.ceil(relatedIds.length / 2), radius, baseAngle, 64, 0, v);
    // vertical stagger so a long related list reads as a side column, not a line
    v.y += (rank % 3) * 2.4 - 2.4;
    result.set(id, { zone: 'related', target: v.clone() });
    used.add(id);
  });

  // Everything else parked far back (faded out).
  for (const tool of tools) {
    if (used.has(tool.id)) continue;
    result.set(tool.id, { zone: 'far', target: TMP_OUT });
  }

  return result;
}

// ---------------------------------------------------------------------------
// Shared GPU resources (created once).
// ---------------------------------------------------------------------------

const SPHERE_GEOM = new THREE.SphereGeometry(1, 28, 28);
const HALO_GEOM = new THREE.SphereGeometry(1, 20, 20);

const ZONE_SIZE: Record<Zone, number> = {
  focus: 2.5,
  parent: 1.7,
  child: 1.25,
  related: 1.0,
  far: 0.6,
};

const ZONE_EMISSIVE: Record<Zone, number> = {
  focus: 1.7,
  parent: 1.0,
  child: 0.85,
  related: 0.6,
  far: 0.08,
};

const ZONE_CORE_OPACITY: Record<Zone, number> = {
  focus: 1,
  parent: 0.95,
  child: 0.92,
  related: 0.85,
  far: 0.0,
};

const ZONE_HALO_OPACITY: Record<Zone, number> = {
  focus: 0.55,
  parent: 0.34,
  child: 0.28,
  related: 0.2,
  far: 0.0,
};

// ---------------------------------------------------------------------------
// Node — its live world position lives on the THREE.Group ref (mutating a ref
// is allowed; mutating props is not). Targets are read-only props. A shared
// ref registry lets the link layer read live positions without prop mutation.
// ---------------------------------------------------------------------------

interface NodeModel {
  tool: AITool;
  color: THREE.Color;
  glow: string;
  /** spawn position (read once to seed the group; never mutated) */
  readonly spawn: THREE.Vector3;
  /** deterministic idle phase offsets (read-only) */
  readonly phase: number;
  readonly bobAmp: number;
}

type GroupRegistry = Map<string, THREE.Group>;

interface NodeMeshProps {
  model: NodeModel;
  target: THREE.Vector3;
  zone: Zone;
  hovered: boolean;
  showLabel: boolean;
  registry: GroupRegistry;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}

function NodeMesh({
  model,
  target,
  zone,
  hovered,
  showLabel,
  registry,
  onSelect,
  onHover,
}: NodeMeshProps) {
  const groupRef = useRef<THREE.Group>(null);
  const coreRef = useRef<THREE.Mesh>(null);
  const haloRef = useRef<THREE.Mesh>(null);
  // Eased base position (excludes idle bob) kept on a ref so the group's own
  // position can carry bob without compounding. Mutating a ref is permitted.
  const baseRef = useRef<THREE.Vector3>(model.spawn.clone());

  // Precompute zone-driven targets; recompute only when zone/hover changes.
  const look = useMemo(() => {
    const size = ZONE_SIZE[zone];
    const emissive = ZONE_EMISSIVE[zone] * (hovered ? 1.4 : 1);
    const coreOpacity = ZONE_CORE_OPACITY[zone];
    const haloOpacity = ZONE_HALO_OPACITY[zone] * (hovered ? 1.6 : 1);
    const scale = size * (hovered ? 1.16 : 1);
    return { size, emissive, coreOpacity, haloOpacity, scale };
  }, [zone, hovered]);

  useFrame((state) => {
    const group = groupRef.current;
    const core = coreRef.current;
    const halo = haloRef.current;
    if (!group || !core || !halo) return;

    // Register on first frame so Links can read this group's position.
    if (registry.get(model.tool.id) !== group) registry.set(model.tool.id, group);

    // Ease base position toward target (the plex recentre motion).
    const base = baseRef.current;
    base.x += (target.x - base.x) * 0.12;
    base.y += (target.y - base.y) * 0.12;
    base.z += (target.z - base.z) * 0.12;

    // Gentle idle bob layered on top (cheap, deterministic).
    const time = state.clock.elapsedTime;
    const bob =
      model.bobAmp * Math.sin(time * 0.9 + model.phase) * (zone === 'focus' ? 0.4 : 1);
    group.position.set(base.x, base.y + bob, base.z);

    // Core material easing.
    const cmat = core.material as THREE.MeshStandardMaterial;
    cmat.emissiveIntensity += (look.emissive - cmat.emissiveIntensity) * 0.12;
    cmat.opacity += (look.coreOpacity - cmat.opacity) * 0.12;
    const s = core.scale.x + (look.scale - core.scale.x) * 0.14;
    core.scale.setScalar(s);

    // Halo material easing.
    const hmat = halo.material as THREE.MeshBasicMaterial;
    hmat.opacity += (look.haloOpacity - hmat.opacity) * 0.1;
    const hs = halo.scale.x + (look.size * 2.3 - halo.scale.x) * 0.1;
    halo.scale.setScalar(hs);

    // Hide far nodes from raycasting once faded.
    group.visible = cmat.opacity > 0.02 || zone !== 'far';
  });

  const stop = (e: ThreeEvent<PointerEvent | MouseEvent>) => e.stopPropagation();

  return (
    <group ref={groupRef} position={model.spawn}>
      <mesh
        ref={coreRef}
        geometry={SPHERE_GEOM}
        scale={look.size}
        onClick={(e) => {
          stop(e);
          onSelect(model.tool.id);
        }}
        onPointerOver={(e) => {
          stop(e);
          onHover(model.tool.id);
        }}
        onPointerOut={(e) => {
          stop(e);
          onHover(null);
        }}
      >
        <meshStandardMaterial
          color={model.color}
          emissive={model.color}
          emissiveIntensity={ZONE_EMISSIVE[zone]}
          roughness={0.3}
          metalness={0.1}
          transparent
          opacity={ZONE_CORE_OPACITY[zone]}
        />
      </mesh>
      <mesh ref={haloRef} geometry={HALO_GEOM} scale={look.size * 2.3}>
        <meshBasicMaterial
          color={model.color}
          transparent
          opacity={ZONE_HALO_OPACITY[zone]}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      {showLabel && (
        <Html
          center
          distanceFactor={26}
          position={[0, look.size + 1.5, 0]}
          zIndexRange={[40, 0]}
          style={{ pointerEvents: 'none' }}
        >
          <span
            style={{
              display: 'inline-block',
              whiteSpace: 'nowrap',
              padding: zone === 'focus' ? '3px 12px' : '2px 9px',
              borderRadius: 999,
              fontSize: zone === 'focus' ? 14 : 12,
              fontWeight: 600,
              letterSpacing: 0.2,
              color: '#eaf6ff',
              background: 'rgba(8,12,26,0.68)',
              border: `1px solid ${model.color.getStyle()}66`,
              boxShadow: `0 0 16px ${model.glow}`,
              backdropFilter: 'blur(4px)',
            }}
          >
            {model.tool.name}
          </span>
        </Html>
      )}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Curved links between focus and its zoned neighbours.
// ---------------------------------------------------------------------------

const LINK_SEGMENTS = 18; // points per curve
const LINK_VERTS = (LINK_SEGMENTS - 1) * 2; // gl.LINES vertex pairs per curve

interface LinksProps {
  registry: GroupRegistry;
  focusId: string;
  placements: Map<string, Placement>;
}

function Links({ registry, focusId, placements }: LinksProps) {
  const segRef = useRef<THREE.LineSegments>(null);

  // Which neighbour ids get a link to the focus (parent + children + related).
  const linkIds = useMemo(() => {
    const ids: string[] = [];
    placements.forEach((pl, id) => {
      if (id !== focusId && pl.zone !== 'far') ids.push(id);
    });
    return ids;
  }, [placements, focusId]);

  // Preallocate one geometry for all links as gl.LINES pairs. Created once via
  // a state initializer so the value is stable and readable in render; per-frame
  // we only mutate the contents of its position attribute array (allowed).
  const [geom] = useState(() => {
    const positions = new Float32Array(tools.length * LINK_VERTS * 3);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    return g;
  });

  // Scratch vectors on a ref so they are never treated as render values.
  const scratchRef = useRef({
    a: new THREE.Vector3(),
    b: new THREE.Vector3(),
    mid: new THREE.Vector3(),
    prev: new THREE.Vector3(),
    cur: new THREE.Vector3(),
  });

  useFrame(() => {
    const focusGroup = registry.get(focusId);
    const seg = segRef.current;
    if (!focusGroup || !seg) return;
    const attr = geom.getAttribute('position') as THREE.BufferAttribute;
    const positions = attr.array as Float32Array;
    let vert = 0; // running vertex count
    const { a, b, mid, prev, cur } = scratchRef.current;
    a.copy(focusGroup.position);

    for (const id of linkIds) {
      const g = registry.get(id);
      if (!g) continue;
      b.copy(g.position);
      // Control point bowed toward the viewer for a soft arc.
      mid.copy(a).add(b).multiplyScalar(0.5);
      mid.z -= 3.2;
      mid.y += (b.y - a.y) * 0.12;
      for (let s = 0; s < LINK_SEGMENTS; s++) {
        const u = s / (LINK_SEGMENTS - 1);
        const iu = 1 - u;
        // Quadratic bezier a → mid → b.
        cur.set(
          iu * iu * a.x + 2 * iu * u * mid.x + u * u * b.x,
          iu * iu * a.y + 2 * iu * u * mid.y + u * u * b.y,
          iu * iu * a.z + 2 * iu * u * mid.z + u * u * b.z,
        );
        if (s > 0) {
          // emit the pair (prev → cur) as one gl.LINES segment
          positions[vert * 3] = prev.x;
          positions[vert * 3 + 1] = prev.y;
          positions[vert * 3 + 2] = prev.z;
          vert++;
          positions[vert * 3] = cur.x;
          positions[vert * 3 + 1] = cur.y;
          positions[vert * 3 + 2] = cur.z;
          vert++;
        }
        prev.copy(cur);
      }
    }

    geom.setDrawRange(0, vert);
    attr.needsUpdate = true;
  });

  return (
    <lineSegments ref={segRef} geometry={geom} renderOrder={-1}>
      <lineBasicMaterial
        color="#bfe6ff"
        transparent
        opacity={0.32}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </lineSegments>
  );
}

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

interface SceneProps {
  focusId: string;
  hoveredId: string | null;
  onSelect: (id: string) => void;
  onHover: (id: string | null) => void;
}

function Scene({ focusId, hoveredId, onSelect, onHover }: SceneProps) {
  // Persistent per-tool models (created once, read-only thereafter).
  const models = useMemo(() => {
    const map = new Map<string, NodeModel>();
    for (const tool of tools) {
      const rng = mulberry32(hashId(tool.id));
      map.set(tool.id, {
        tool,
        color: colorOf(tool),
        glow: categoryById.get(tool.category)?.glow ?? 'rgba(155,214,255,0.3)',
        spawn: new THREE.Vector3(
          (rng() - 0.5) * 30,
          (rng() - 0.5) * 18,
          -10 - rng() * 20,
        ),
        phase: rng() * Math.PI * 2,
        bobAmp: 0.18 + rng() * 0.22,
      });
    }
    return map;
  }, []);

  // Shared registry of live node groups, populated by NodeMesh on mount.
  const registry = useMemo<GroupRegistry>(() => new Map(), []);

  // Placements (zone + target) recomputed only on focus change.
  const placements = useMemo(() => computePlacements(focusId), [focusId]);

  const rootRef = useRef<THREE.Group>(null);
  useFrame((state) => {
    if (!rootRef.current) return;
    // Very gentle parallax sway of the whole plex for life.
    const t = state.clock.elapsedTime;
    rootRef.current.rotation.y = Math.sin(t * 0.12) * 0.05;
    rootRef.current.rotation.x = Math.cos(t * 0.1) * 0.025;
  });

  return (
    <>
      <color attach="background" args={['#03040a']} />
      <fog attach="fog" args={['#03040a', 36, 90]} />
      <ambientLight intensity={0.6} />
      <pointLight position={[0, 6, 30]} intensity={1.3} color="#cfeaff" />
      <pointLight position={[-30, 20, -10]} intensity={0.5} color="#ff8bd2" />
      <pointLight position={[30, -16, -10]} intensity={0.4} color="#7fffd4" />

      <group ref={rootRef}>
        <Links registry={registry} focusId={focusId} placements={placements} />
        {tools.map((tool) => {
          const model = models.get(tool.id);
          const placement = placements.get(tool.id);
          if (!model || !placement) return null;
          const zone = placement.zone;
          const hovered = hoveredId === tool.id;
          const showLabel =
            zone === 'focus' ||
            zone === 'parent' ||
            zone === 'child' ||
            (zone === 'related' && hovered) ||
            hovered;
          return (
            <NodeMesh
              key={tool.id}
              model={model}
              target={placement.target}
              zone={zone}
              hovered={hovered}
              showLabel={showLabel}
              registry={registry}
              onSelect={onSelect}
              onHover={onHover}
            />
          );
        })}
      </group>
    </>
  );
}

// ---------------------------------------------------------------------------
// Public component
// ---------------------------------------------------------------------------

export function BrainHub() {
  const [focusId, setFocusId] = useState<string>(HUB_ID);
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const focusTool: AITool | undefined = toolById.get(focusId);
  const focusCategory: ToolCategory | undefined = focusTool
    ? categoryById.get(focusTool.category)
    : undefined;

  const handleSelect = useCallback((id: string) => setFocusId(id), []);
  const handleHover = useCallback((id: string | null) => setHoveredId(id), []);
  const resetToHub = useCallback(() => setFocusId(HUB_ID), []);

  // Quick category jump chips re-centre on each category's first member.
  const categoryChips = useMemo(
    () =>
      categories.map((cat) => {
        const first = CATEGORY_MEMBERS.get(cat.id)?.[0] ?? HUB_ID;
        return { cat, target: first };
      }),
    [],
  );

  return (
    <div className="absolute inset-0 h-full w-full">
      <Canvas
        className="h-full w-full"
        style={{ width: '100%', height: '100%' }}
        camera={{ position: [0, 1.5, 30], fov: 50, near: 0.1, far: 2000 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: false }}
        frameloop="always"
      >
        <Scene
          focusId={focusId}
          hoveredId={hoveredId}
          onSelect={handleSelect}
          onHover={handleHover}
        />
      </Canvas>

      {/* Radial vignette */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(circle at 50% 46%, transparent 38%, rgba(2,3,9,0.5) 78%, rgba(2,3,9,0.92) 100%)',
        }}
      />

      {/* Zone legend (top-left) — pushed below the lab's top chrome */}
      <div className="pointer-events-none absolute left-5 top-16 select-none">
        <p className="text-[11px] font-medium uppercase tracking-[0.28em] text-cyan-200/70">
          TheBrain · Plex
        </p>
        <p className="mt-1 text-[11px] text-white/35">
          Click any node to re-centre · parent ↑ · children ↓ · related ↔
        </p>
      </div>

      {/* Category jump chips (top-right) — pushed below the lab's top chrome */}
      <div className="absolute right-4 top-16 flex max-w-[60%] flex-wrap justify-end gap-1.5">
        {categoryChips.map(({ cat, target }) => (
          <button
            key={cat.id}
            type="button"
            onClick={() => handleSelect(target)}
            className="rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] backdrop-blur transition"
            style={{
              borderColor: `${cat.color}55`,
              color: cat.color,
              background: 'rgba(6,9,20,0.6)',
            }}
          >
            {cat.shortName}
          </button>
        ))}
      </div>

      {/* Focus detail card (bottom-left) */}
      {focusTool && (
        <div
          className="absolute bottom-5 left-5 max-w-xs rounded-2xl border p-4 backdrop-blur"
          style={{
            borderColor: `${focusCategory?.color ?? '#9bd6ff'}55`,
            background: 'rgba(6,9,20,0.72)',
            boxShadow: `0 0 30px ${focusCategory?.glow ?? 'rgba(155,214,255,0.3)'}`,
          }}
        >
          <p
            className="text-[10px] font-semibold uppercase tracking-[0.22em]"
            style={{ color: focusCategory?.color ?? '#9bd6ff' }}
          >
            {focusCategory?.shortName ?? focusTool.category}
          </p>
          <p className="mt-1 text-base font-semibold text-white">{focusTool.name}</p>
          <p className="mt-1.5 text-xs leading-relaxed text-white/60">
            {focusTool.summary}
          </p>
          {focusId !== HUB_ID && (
            <button
              type="button"
              onClick={resetToHub}
              className="mt-3 rounded-full border border-white/15 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-white/70 transition hover:text-white"
            >
              ↑ Back to Founder OS
            </button>
          )}
        </div>
      )}
    </div>
  );
}
