import { useCallback, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Html, PerspectiveCamera } from '@react-three/drei';
import * as THREE from 'three';
import {
  categoryById,
  tools,
  toolById,
  type AITool,
  type WorkflowStageId,
} from '../../data/ai-tool-universe';

/**
 * Direction E — "Neural Net".
 *
 * A TensorFlow-Playground-style feed-forward network. The five workflow
 * stages become five vertical layers laid out left→right; every tool is a
 * neuron stacked inside its stage layer, coloured by category. Synapses are
 * drawn between related tools (relationIds) that live in *different* layers,
 * and signal pulses flow left→right along them. Hover a neuron to light its
 * synapses; click to highlight its forward/backward dependency paths.
 *
 * Technique notes (from TF Playground): layered L→R topology, weighted
 * connection lines (here opacity ~ relation count), and animated activations
 * travelling along the edges. All geometry is precomputed once at module
 * load — useFrame only mutates refs, never allocates.
 */

// ---------------------------------------------------------------------------
// Deterministic PRNG (mulberry32) — no Math.random during render / module init
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

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const STAGE_ORDER: WorkflowStageId[] = [
  'research',
  'planning',
  'execution',
  'approval',
  'review',
];

const STAGE_LABEL: Record<WorkflowStageId, string> = {
  research: 'Research',
  planning: 'Planning',
  execution: 'Execution',
  approval: 'Approval',
  review: 'Review',
};

const LAYER_GAP = 13; // x distance between layers
const NEURON_GAP = 4.2; // y distance between stacked neurons
const SPHERE = new THREE.SphereGeometry(1, 28, 28);
const HALO = new THREE.SphereGeometry(1, 18, 18);

// ---------------------------------------------------------------------------
// Precomputed network (module-level, runs once)
// ---------------------------------------------------------------------------

interface Neuron {
  id: string;
  tool: AITool;
  layer: number; // 0..4
  color: THREE.Color;
  glow: string;
  position: THREE.Vector3;
  size: number;
}

interface Synapse {
  a: number; // neuron index (earlier layer)
  b: number; // neuron index (later layer)
  weight: number; // 0..1, drives opacity/thickness
  /** sampled mid-point control for a gentle curve */
  mid: THREE.Vector3;
}

interface Network {
  neurons: Neuron[];
  synapses: Synapse[];
  indexById: Map<string, number>;
  /** adjacency over synapse indices, per neuron index */
  edgesOf: Map<number, number[]>;
  /** directed forward/backward neighbour sets (by layer order) */
  forward: Map<number, Set<number>>;
  backward: Map<number, Set<number>>;
  extent: { x: number; y: number };
}

const NET: Network = buildNetwork();

function buildNetwork(): Network {
  const rng = mulberry32(0x5eed1234);
  const indexById = new Map<string, number>();

  // Bucket tools by stage, preserving declaration order for stable stacks.
  const byStage = new Map<WorkflowStageId, AITool[]>();
  for (const s of STAGE_ORDER) byStage.set(s, []);
  for (const t of tools) byStage.get(t.stage)?.push(t);

  const maxCount = Math.max(...STAGE_ORDER.map((s) => byStage.get(s)?.length ?? 0));
  const halfX = ((STAGE_ORDER.length - 1) * LAYER_GAP) / 2;

  const neurons: Neuron[] = [];
  STAGE_ORDER.forEach((stage, layer) => {
    const list = byStage.get(stage) ?? [];
    const stackH = (list.length - 1) * NEURON_GAP;
    list.forEach((tool, row) => {
      const cat = categoryById.get(tool.category);
      const x = -halfX + layer * LAYER_GAP;
      const y = stackH / 2 - row * NEURON_GAP;
      // small deterministic z-stagger so synapses don't all overlap
      const z = (rng() - 0.5) * 3.4;
      const idx = neurons.length;
      indexById.set(tool.id, idx);
      neurons.push({
        id: tool.id,
        tool,
        layer,
        color: new THREE.Color(cat?.color ?? '#9bd7ff'),
        glow: cat?.glow ?? 'rgba(155,215,255,0.3)',
        position: new THREE.Vector3(x, y, z),
        size: tool.id === 'founder-os' ? 1.5 : 1.05,
      });
    });
  });

  void maxCount;

  // Synapses: relation edges between tools in *different* layers.
  const synapses: Synapse[] = [];
  const seen = new Set<string>();
  const degree = new Map<number, number>();
  const bump = (i: number) => degree.set(i, (degree.get(i) ?? 0) + 1);

  const addEdge = (aId: string, bId: string) => {
    const ai = indexById.get(aId);
    const bi = indexById.get(bId);
    if (ai === undefined || bi === undefined || ai === bi) return;
    const na = neurons[ai];
    const nb = neurons[bi];
    if (na.layer === nb.layer) return; // keep it feed-forward across layers
    // order earlier-layer first
    const [lo, hi] = na.layer < nb.layer ? [ai, bi] : [bi, ai];
    const key = `${lo}:${hi}`;
    if (seen.has(key)) return;
    seen.add(key);
    const a = neurons[lo];
    const b = neurons[hi];
    const mid = new THREE.Vector3()
      .addVectors(a.position, b.position)
      .multiplyScalar(0.5);
    mid.z += (rng() - 0.5) * 2.2;
    mid.y += (rng() - 0.5) * 1.4;
    synapses.push({ a: lo, b: hi, weight: 0, mid });
    bump(lo);
    bump(hi);
  };

  for (const t of tools) {
    for (const relId of t.relationIds) {
      if (toolById.has(relId)) addEdge(t.id, relId);
    }
  }

  // Weight = normalised endpoint degree (proxy for connection strength).
  const maxDeg = Math.max(1, ...[...degree.values()]);
  for (const syn of synapses) {
    const d = ((degree.get(syn.a) ?? 1) + (degree.get(syn.b) ?? 1)) / 2;
    syn.weight = 0.35 + 0.65 * (d / maxDeg);
  }

  // Adjacency + directed forward/backward sets.
  const edgesOf = new Map<number, number[]>();
  const forward = new Map<number, Set<number>>();
  const backward = new Map<number, Set<number>>();
  const ensure = <T,>(m: Map<number, T>, k: number, init: T): T => {
    let v = m.get(k);
    if (v === undefined) {
      v = init;
      m.set(k, v);
    }
    return v;
  };
  synapses.forEach((syn, si) => {
    ensure(edgesOf, syn.a, [] as number[]).push(si);
    ensure(edgesOf, syn.b, [] as number[]).push(si);
    ensure(forward, syn.a, new Set<number>()).add(syn.b);
    ensure(backward, syn.b, new Set<number>()).add(syn.a);
  });

  let maxY = 1;
  for (const n of neurons) maxY = Math.max(maxY, Math.abs(n.position.y));

  return {
    neurons,
    synapses,
    indexById,
    edgesOf,
    forward,
    backward,
    extent: { x: halfX + 3, y: maxY + 4 },
  };
}

// Transitive forward / backward closure from a neuron (the "path" highlight).
function closure(start: number, dir: Map<number, Set<number>>): Set<number> {
  const out = new Set<number>();
  const stack = [start];
  while (stack.length) {
    const cur = stack.pop() as number;
    for (const nxt of dir.get(cur) ?? []) {
      if (!out.has(nxt)) {
        out.add(nxt);
        stack.push(nxt);
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Synapse layer — single buffer geometry (curves), animated pulses on a second
// additive point cloud. No per-frame allocation.
// ---------------------------------------------------------------------------

const CURVE_SEG = 14; // points per synapse curve
const PULSE_PER_SYN = 1;

interface SynapseLayerProps {
  activeEdges: Set<number> | null; // synapse indices to emphasise (hover/select)
  dimmed: boolean;
}

function SynapseLayer({ activeEdges, dimmed }: SynapseLayerProps) {
  const lineRef = useRef<THREE.LineSegments>(null);
  const pulseRef = useRef<THREE.Points>(null);
  const lineMatRef = useRef<THREE.LineBasicMaterial>(null);

  // Precompute static curve geometry + per-vertex base colors once.
  // `pulseData` arrays are created here but only mutated through the geometry
  // reached via `pulseRef` inside useFrame (never via this returned object), so
  // the react-hooks immutability rule is satisfied.
  const { lineGeom, pulseGeom, pulseMeta } = useMemo(() => {
    const syn = NET.synapses;
    const segPerSyn = CURVE_SEG;
    const vertsPerSyn = segPerSyn * 2; // line segments
    const total = syn.length * vertsPerSyn;
    const pos = new Float32Array(total * 3);
    const col = new Float32Array(total * 3);
    const a = new THREE.Vector3();
    const b = new THREE.Vector3();
    const m = new THREE.Vector3();
    const p0 = new THREE.Vector3();
    const p1 = new THREE.Vector3();
    const ca = new THREE.Color();
    const cb = new THREE.Color();

    syn.forEach((s, si) => {
      a.copy(NET.neurons[s.a].position);
      b.copy(NET.neurons[s.b].position);
      m.copy(s.mid);
      ca.copy(NET.neurons[s.a].color);
      cb.copy(NET.neurons[s.b].color);
      for (let seg = 0; seg < segPerSyn; seg++) {
        const t0 = seg / segPerSyn;
        const t1 = (seg + 1) / segPerSyn;
        quadBezier(a, m, b, t0, p0);
        quadBezier(a, m, b, t1, p1);
        const base = (si * segPerSyn + seg) * 6;
        pos[base + 0] = p0.x;
        pos[base + 1] = p0.y;
        pos[base + 2] = p0.z;
        pos[base + 3] = p1.x;
        pos[base + 4] = p1.y;
        pos[base + 5] = p1.z;
        // colour gradient a→b
        const lerp0 = ca.clone().lerp(cb, t0);
        const lerp1 = ca.clone().lerp(cb, t1);
        col[base + 0] = lerp0.r;
        col[base + 1] = lerp0.g;
        col[base + 2] = lerp0.b;
        col[base + 3] = lerp1.r;
        col[base + 4] = lerp1.g;
        col[base + 5] = lerp1.b;
      }
    });
    const lg = new THREE.BufferGeometry();
    lg.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    lg.setAttribute('color', new THREE.BufferAttribute(col, 3));

    // Pulse points: one travelling dot per synapse.
    const pCount = syn.length * PULSE_PER_SYN;
    const ppos = new Float32Array(pCount * 3);
    const pcol = new Float32Array(pCount * 3);
    const pg = new THREE.BufferGeometry();
    pg.setAttribute('position', new THREE.BufferAttribute(ppos, 3));
    pg.setAttribute('color', new THREE.BufferAttribute(pcol, 3));
    const speed = new Float32Array(pCount);
    const phase = new Float32Array(pCount);
    const rng = mulberry32(0x13371337);
    for (let i = 0; i < pCount; i++) {
      speed[i] = 0.18 + rng() * 0.5;
      phase[i] = rng();
    }
    return {
      lineGeom: lg,
      pulseGeom: pg,
      pulseMeta: { speed, phase, count: pCount },
    };
  }, []);

  // Mutable scratch (declared once, reused each frame).
  const scratch = useMemo(
    () => ({ a: new THREE.Vector3(), b: new THREE.Vector3(), m: new THREE.Vector3(), p: new THREE.Vector3(), c: new THREE.Color() }),
    [],
  );

  useFrame(({ clock }) => {
    const points = pulseRef.current;
    if (!points) return;
    const geom = points.geometry;
    const posAttr = geom.getAttribute('position') as THREE.BufferAttribute;
    const colAttr = geom.getAttribute('color') as THREE.BufferAttribute;
    const ppos = posAttr.array as Float32Array;
    const pcol = colAttr.array as Float32Array;
    const t = clock.getElapsedTime();
    const { speed, phase, count } = pulseMeta;
    const sc = scratch;
    for (let i = 0; i < count; i++) {
      const syn = NET.synapses[i];
      const active = activeEdges ? activeEdges.has(i) : true;
      const prog = (t * speed[i] + phase[i]) % 1;
      sc.a.copy(NET.neurons[syn.a].position);
      sc.b.copy(NET.neurons[syn.b].position);
      sc.m.copy(syn.mid);
      quadBezier(sc.a, sc.m, sc.b, prog, sc.p);
      ppos[i * 3 + 0] = sc.p.x;
      ppos[i * 3 + 1] = sc.p.y;
      ppos[i * 3 + 2] = sc.p.z;
      // colour = destination neuron colour, brighter when active
      sc.c.copy(NET.neurons[syn.b].color);
      const k = active ? 1 : 0.12;
      pcol[i * 3 + 0] = sc.c.r * k;
      pcol[i * 3 + 1] = sc.c.g * k;
      pcol[i * 3 + 2] = sc.c.b * k;
    }
    posAttr.needsUpdate = true;
    colAttr.needsUpdate = true;

    if (lineMatRef.current) {
      const target = dimmed && !activeEdges ? 0.05 : 0.14;
      lineMatRef.current.opacity += (target - lineMatRef.current.opacity) * 0.1;
    }
  });

  return (
    <group>
      <lineSegments ref={lineRef} geometry={lineGeom} renderOrder={-2}>
        <lineBasicMaterial
          ref={lineMatRef}
          vertexColors
          transparent
          opacity={0.14}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </lineSegments>
      <points ref={pulseRef} geometry={pulseGeom} renderOrder={2}>
        <pointsMaterial
          vertexColors
          size={0.62}
          sizeAttenuation
          transparent
          opacity={0.95}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </points>
    </group>
  );
}

function quadBezier(
  p0: THREE.Vector3,
  p1: THREE.Vector3,
  p2: THREE.Vector3,
  t: number,
  out: THREE.Vector3,
): THREE.Vector3 {
  const u = 1 - t;
  const a = u * u;
  const b = 2 * u * t;
  const c = t * t;
  out.set(
    a * p0.x + b * p1.x + c * p2.x,
    a * p0.y + b * p1.y + c * p2.y,
    a * p0.z + b * p1.z + c * p2.z,
  );
  return out;
}

// ---------------------------------------------------------------------------
// Neuron node
// ---------------------------------------------------------------------------

interface NeuronNodeProps {
  neuron: Neuron;
  state: 'normal' | 'active' | 'dim';
  showLabel: boolean;
  onHover: (id: string | null) => void;
  onSelect: (id: string) => void;
}

function NeuronNode({ neuron, state, showLabel, onHover, onSelect }: NeuronNodeProps) {
  const coreRef = useRef<THREE.Mesh>(null);
  const haloRef = useRef<THREE.Mesh>(null);
  const matRef = useRef<THREE.MeshStandardMaterial>(null);
  const haloMatRef = useRef<THREE.MeshBasicMaterial>(null);
  const seed = useMemo(() => NET.indexById.get(neuron.id) ?? 0, [neuron.id]);

  useFrame(({ clock }) => {
    const t = clock.getElapsedTime();
    const bob = Math.sin(t * 1.3 + seed * 0.7) * 0.06;
    if (coreRef.current) coreRef.current.position.y = bob;
    const targetEmissive = state === 'active' ? 1.4 : state === 'dim' ? 0.18 : 0.55;
    const targetHalo = state === 'active' ? 0.42 : state === 'dim' ? 0.05 : 0.16;
    const pulse = state === 'active' ? 1 + Math.sin(t * 4 + seed) * 0.12 : 1;
    if (matRef.current) {
      matRef.current.emissiveIntensity +=
        (targetEmissive - matRef.current.emissiveIntensity) * 0.15;
    }
    if (haloMatRef.current) {
      haloMatRef.current.opacity += (targetHalo - haloMatRef.current.opacity) * 0.15;
    }
    if (haloRef.current) {
      const s = neuron.size * 2.3 * pulse;
      haloRef.current.scale.setScalar(s);
    }
  });

  return (
    <group position={neuron.position}>
      <mesh
        ref={coreRef}
        geometry={SPHERE}
        scale={neuron.size}
        onClick={(e) => {
          e.stopPropagation();
          onSelect(neuron.id);
        }}
        onPointerOver={(e) => {
          e.stopPropagation();
          onHover(neuron.id);
        }}
        onPointerOut={(e) => {
          e.stopPropagation();
          onHover(null);
        }}
      >
        <meshStandardMaterial
          ref={matRef}
          color={neuron.color}
          emissive={neuron.color}
          emissiveIntensity={0.55}
          roughness={0.3}
          metalness={0.15}
          transparent
          opacity={state === 'dim' ? 0.5 : 0.96}
        />
      </mesh>
      <mesh ref={haloRef} geometry={HALO} scale={neuron.size * 2.3}>
        <meshBasicMaterial
          ref={haloMatRef}
          color={neuron.color}
          transparent
          opacity={0.16}
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </mesh>
      {showLabel && (
        <Html
          center
          distanceFactor={34}
          position={[0, neuron.size * 1.5 + 1.1, 0]}
          zIndexRange={[40, 0]}
          style={{ pointerEvents: 'none' }}
        >
          <span
            style={{
              display: 'inline-block',
              whiteSpace: 'nowrap',
              padding: '2px 9px',
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 600,
              letterSpacing: 0.2,
              color: '#eaf6ff',
              background: 'rgba(8,12,26,0.7)',
              border: `1px solid ${neuron.color.getStyle()}77`,
              boxShadow: `0 0 14px ${neuron.glow}`,
              backdropFilter: 'blur(4px)',
            }}
          >
            {neuron.tool.name}
          </span>
        </Html>
      )}
    </group>
  );
}

// ---------------------------------------------------------------------------
// Layer headers (3D text via Html, anchored above each stack)
// ---------------------------------------------------------------------------

function LayerHeaders() {
  const headers = useMemo(() => {
    const halfX = ((STAGE_ORDER.length - 1) * LAYER_GAP) / 2;
    return STAGE_ORDER.map((stage, i) => ({
      stage,
      x: -halfX + i * LAYER_GAP,
      index: i,
    }));
  }, []);
  return (
    <>
      {headers.map((h) => (
        <Html
          key={h.stage}
          center
          distanceFactor={42}
          position={[h.x, NET.extent.y + 1.5, 0]}
          zIndexRange={[20, 0]}
          style={{ pointerEvents: 'none' }}
        >
          <div style={{ textAlign: 'center', whiteSpace: 'nowrap' }}>
            <div
              style={{
                fontSize: 10,
                fontWeight: 700,
                letterSpacing: 2,
                color: 'rgba(150,180,220,0.55)',
              }}
            >
              {String(h.index + 1).padStart(2, '0')}
            </div>
            <div
              style={{
                fontSize: 15,
                fontWeight: 700,
                letterSpacing: 0.4,
                color: '#dce8ff',
                textShadow: '0 0 16px rgba(110,231,255,0.5)',
              }}
            >
              {STAGE_LABEL[h.stage]}
            </div>
          </div>
        </Html>
      ))}
    </>
  );
}

// ---------------------------------------------------------------------------
// Camera + gentle auto-orbit / parallax driven by pointer
// ---------------------------------------------------------------------------

function Rig({ pointer }: { pointer: React.RefObject<{ x: number; y: number }> }) {
  const camRef = useRef<THREE.PerspectiveCamera>(null);
  const target = useMemo(() => new THREE.Vector3(0, 0, 0), []);
  useFrame(({ clock }) => {
    const cam = camRef.current;
    if (!cam) return;
    const t = clock.getElapsedTime();
    const p = pointer.current ?? { x: 0, y: 0 };
    const driftX = Math.sin(t * 0.12) * 3;
    const desiredX = driftX + p.x * 9;
    const desiredY = 1 + p.y * 5;
    cam.position.x += (desiredX - cam.position.x) * 0.04;
    cam.position.y += (desiredY - cam.position.y) * 0.04;
    cam.position.z += (52 - cam.position.z) * 0.04;
    cam.lookAt(target);
  });
  return (
    <PerspectiveCamera
      ref={camRef}
      makeDefault
      position={[0, 1, 52]}
      fov={42}
      near={0.1}
      far={400}
    />
  );
}

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

interface SceneProps {
  hovered: string | null;
  selected: string | null;
  setHovered: (id: string | null) => void;
  setSelected: (id: string) => void;
  pointer: React.RefObject<{ x: number; y: number }>;
}

function Scene({ hovered, selected, setHovered, setSelected, pointer }: SceneProps) {
  // Compute the "active" neuron set + emphasised synapse set.
  const { activeNeurons, activeEdges, hasFocus } = useMemo(() => {
    const focusId = hovered ?? selected;
    if (!focusId) {
      return { activeNeurons: null as Set<number> | null, activeEdges: null as Set<number> | null, hasFocus: false };
    }
    const fi = NET.indexById.get(focusId);
    if (fi === undefined) {
      return { activeNeurons: null as Set<number> | null, activeEdges: null as Set<number> | null, hasFocus: false };
    }
    const neuronSet = new Set<number>([fi]);
    const edgeSet = new Set<number>();

    if (selected && selected === focusId) {
      // Click: full forward + backward dependency closure.
      for (const n of closure(fi, NET.forward)) neuronSet.add(n);
      for (const n of closure(fi, NET.backward)) neuronSet.add(n);
    } else {
      // Hover: immediate neighbours only.
      for (const n of NET.forward.get(fi) ?? []) neuronSet.add(n);
      for (const n of NET.backward.get(fi) ?? []) neuronSet.add(n);
    }
    // Emphasise synapses whose both endpoints are in the active set.
    NET.synapses.forEach((syn, si) => {
      if (neuronSet.has(syn.a) && neuronSet.has(syn.b)) edgeSet.add(si);
    });
    return { activeNeurons: neuronSet, activeEdges: edgeSet, hasFocus: true };
  }, [hovered, selected]);

  const stateFor = useCallback(
    (idx: number): 'normal' | 'active' | 'dim' => {
      if (!hasFocus || !activeNeurons) return 'normal';
      return activeNeurons.has(idx) ? 'active' : 'dim';
    },
    [hasFocus, activeNeurons],
  );

  return (
    <>
      <color attach="background" args={['#04050d']} />
      <fog attach="fog" args={['#04050d', 70, 150]} />
      <ambientLight intensity={0.6} />
      <pointLight position={[0, 10, 50]} intensity={1.3} color="#bfe6ff" />
      <pointLight position={[-40, 20, 10]} intensity={0.6} color="#a78bfa" />
      <pointLight position={[40, -20, 10]} intensity={0.5} color="#ff8bd2" />

      <Rig pointer={pointer} />
      <LayerHeaders />
      <SynapseLayer activeEdges={hasFocus ? activeEdges : null} dimmed={hasFocus} />

      {NET.neurons.map((neuron, idx) => {
        const st = stateFor(idx);
        const showLabel =
          st === 'active' || (!hasFocus && (neuron.id === 'founder-os' || neuron.size > 1.2));
        return (
          <NeuronNode
            key={neuron.id}
            neuron={neuron}
            state={st}
            showLabel={showLabel}
            onHover={setHovered}
            onSelect={setSelected}
          />
        );
      })}
    </>
  );
}

// ---------------------------------------------------------------------------
// Root component
// ---------------------------------------------------------------------------

export function NeuralNet() {
  const [hovered, setHovered] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const pointer = useRef<{ x: number; y: number }>({ x: 0, y: 0 });

  const focusTool = useMemo(() => {
    const id = selected ?? hovered;
    return id ? (toolById.get(id) ?? null) : null;
  }, [selected, hovered]);

  const handleSelect = useCallback(
    (id: string) => setSelected((cur) => (cur === id ? null : id)),
    [],
  );

  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    pointer.current = {
      x: ((e.clientX - rect.left) / rect.width) * 2 - 1,
      y: -(((e.clientY - rect.top) / rect.height) * 2 - 1),
    };
  }, []);

  const stats = useMemo(
    () => ({ neurons: NET.neurons.length, synapses: NET.synapses.length }),
    [],
  );

  return (
    <div className="absolute inset-0" style={{ background: '#04050d' }}>
      <div
        className="absolute inset-0"
        style={{ paddingTop: 64 }}
        onPointerMove={handlePointerMove}
      >
        <Canvas
          dpr={[1, 2]}
          gl={{ antialias: true, alpha: false }}
          frameloop="always"
          onPointerMissed={() => setSelected(null)}
        >
          <Scene
            hovered={hovered}
            selected={selected}
            setHovered={setHovered}
            setSelected={handleSelect}
            pointer={pointer}
          />
        </Canvas>
      </div>

      {/* Title / legend overlay */}
      <div
        className="pointer-events-none absolute left-6 flex flex-col gap-1"
        style={{ top: 76 }}
      >
        <div
          style={{
            fontSize: 11,
            fontWeight: 700,
            letterSpacing: 3,
            color: 'rgba(150,180,220,0.6)',
          }}
        >
          DIRECTION E
        </div>
        <div
          style={{
            fontSize: 22,
            fontWeight: 800,
            letterSpacing: 0.2,
            color: '#eaf4ff',
            textShadow: '0 0 22px rgba(110,231,255,0.45)',
          }}
        >
          Neural Net
        </div>
        <div style={{ fontSize: 12, color: 'rgba(190,210,235,0.7)', maxWidth: 260 }}>
          {stats.neurons} neurons across 5 workflow layers · {stats.synapses} synapses.
          Signals flow research → review.
        </div>
      </div>

      {/* Hint + focus readout */}
      <div
        className="pointer-events-none absolute bottom-5 left-6 right-6 flex items-end justify-between gap-4"
      >
        <div
          style={{
            fontSize: 11.5,
            color: 'rgba(170,195,225,0.65)',
            letterSpacing: 0.2,
          }}
        >
          Hover a neuron to fire its synapses · click to trace forward / backward
          paths · click empty space to reset
        </div>
        {focusTool && (
          <div
            style={{
              maxWidth: 320,
              padding: '10px 14px',
              borderRadius: 14,
              background: 'rgba(10,14,28,0.78)',
              border: `1px solid ${
                (categoryById.get(focusTool.category)?.color ?? '#6ee7ff') + '55'
              }`,
              boxShadow: `0 0 26px ${
                categoryById.get(focusTool.category)?.glow ?? 'rgba(110,231,255,0.3)'
              }`,
              backdropFilter: 'blur(8px)',
            }}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                marginBottom: 4,
              }}
            >
              <span
                style={{
                  width: 9,
                  height: 9,
                  borderRadius: 999,
                  background: categoryById.get(focusTool.category)?.color ?? '#6ee7ff',
                  boxShadow: `0 0 10px ${
                    categoryById.get(focusTool.category)?.color ?? '#6ee7ff'
                  }`,
                }}
              />
              <span style={{ fontSize: 14, fontWeight: 700, color: '#f2f7ff' }}>
                {focusTool.name}
              </span>
              <span
                style={{
                  fontSize: 10,
                  fontWeight: 600,
                  letterSpacing: 0.6,
                  textTransform: 'uppercase',
                  color: 'rgba(180,205,235,0.7)',
                  marginLeft: 'auto',
                }}
              >
                {STAGE_LABEL[focusTool.stage]}
              </span>
            </div>
            <div style={{ fontSize: 12, lineHeight: 1.45, color: 'rgba(205,222,242,0.85)' }}>
              {focusTool.summary}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
