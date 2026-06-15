import { useMemo, useRef, useState, useCallback, useEffect } from 'react';
import { Canvas, useFrame, useThree, type ThreeEvent } from '@react-three/fiber';
import * as THREE from 'three';
import {
  tools,
  categories,
  categoryById,
  type AITool,
} from '../../data/ai-tool-universe';

/* ----------------------------------------------------------------------------
 * Direction J — "Cosmograph"
 *
 * A GPU-style force-directed graph emulating Cosmograph / @cosmosgl/graph:
 * a many-body repulsion + link-spring + cluster-gravity simulation, baked into
 * a single THREE.Points cloud (additive category glow) and one LineSegments
 * buffer for every edge. Reads like Obsidian-graph-on-steroids: dense, fast,
 * with category clusters that resolve into glowing constellations.
 *
 * Cosmograph itself runs the whole n-body force sim in fragment/vertex shaders
 * via texture ping-pong (quadtree-free, all on GPU) to hit ~1M nodes. We have
 * 49 nodes, so we run an equivalent force model on the CPU across many
 * pre-baked iterations in a useMemo, then hand the *result* to the GPU as a
 * static Points/LineSegments buffer — visually identical, trivially fast.
 * -------------------------------------------------------------------------- */

// --- seeded PRNG (mulberry32) — no Math.random in render/module init ---------
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

function hexToRgb(hex: string): [number, number, number] {
  const c = new THREE.Color(hex);
  return [c.r, c.g, c.b];
}

interface Node {
  tool: AITool;
  x: number;
  y: number;
  z: number;
  color: [number, number, number];
  size: number;
}

interface Edge {
  a: number; // node index
  b: number;
  primary: boolean;
}

interface Layout {
  nodes: Node[];
  edges: Edge[];
  indexById: Map<string, number>;
  radius: number;
  // adjacency: for each node, the set of connected node indices
  adjacency: number[][];
}

const SIM_ITERATIONS = 320;

// --- build graph + run baked force simulation --------------------------------
function buildLayout(): Layout {
  const rand = mulberry32(0x51ed1a7e);
  const indexById = new Map<string, number>();
  tools.forEach((t, i) => indexById.set(t.id, i));

  // Category cluster anchors arranged on a ring (Cosmograph "communities").
  const catAnchors = new Map<string, { x: number; y: number; z: number }>();
  categories.forEach((cat, i) => {
    const ang = (i / categories.length) * Math.PI * 2;
    const R = 26;
    catAnchors.set(cat.id, {
      x: Math.cos(ang) * R,
      y: Math.sin(ang) * R * 0.62,
      z: (rand() - 0.5) * 10,
    });
  });

  // Initialise node positions jittered around their cluster anchor.
  const nodes: Node[] = tools.map((t) => {
    const anchor = catAnchors.get(t.category) ?? { x: 0, y: 0, z: 0 };
    const cat = categoryById.get(t.category);
    const isCore = t.orbit === 0;
    return {
      tool: t,
      x: anchor.x + (rand() - 0.5) * 9,
      y: anchor.y + (rand() - 0.5) * 9,
      z: anchor.z + (rand() - 0.5) * 9,
      color: hexToRgb(cat?.color ?? '#9ad'),
      size: isCore ? 3.6 : 1.55 + (t.orbit === 1 ? 0.7 : 0),
    };
  });

  // Edges: dedup relationIds (undirected) + everything tied to the core hub.
  const edgeSet = new Set<string>();
  const edges: Edge[] = [];
  const addEdge = (aId: string, bId: string, primary: boolean) => {
    const a = indexById.get(aId);
    const b = indexById.get(bId);
    if (a === undefined || b === undefined || a === b) return;
    const key = a < b ? `${a}-${b}` : `${b}-${a}`;
    if (edgeSet.has(key)) return;
    edgeSet.add(key);
    edges.push({ a, b, primary });
  };
  for (const t of tools) {
    for (const rid of t.relationIds) addEdge(t.id, rid, true);
  }
  // Category-hub edges: link each node to the first node in its category so
  // even relation-sparse clusters cohere (lightweight constellation spokes).
  const firstByCat = new Map<string, string>();
  for (const t of tools) if (!firstByCat.has(t.category)) firstByCat.set(t.category, t.id);
  for (const t of tools) {
    const hub = firstByCat.get(t.category);
    if (hub && hub !== t.id) addEdge(t.id, hub, false);
  }

  const adjacency: number[][] = nodes.map(() => []);
  for (const e of edges) {
    adjacency[e.a].push(e.b);
    adjacency[e.b].push(e.a);
  }

  // --- force simulation (Fruchterman-Reingold-ish, Cosmograph force model) ---
  const n = nodes.length;
  const vx = new Float32Array(n);
  const vy = new Float32Array(n);
  const vz = new Float32Array(n);

  const REPULSION = 240; // many-body push
  const SPRING = 0.045; // link attraction
  const SPRING_LEN = 6.5;
  const CLUSTER_GRAVITY = 0.018; // pull toward own category anchor
  const CENTER_GRAVITY = 0.0016; // pull whole graph toward origin
  const DAMPING = 0.82;

  for (let iter = 0; iter < SIM_ITERATIONS; iter++) {
    const cooling = 1 - iter / SIM_ITERATIONS; // simulated annealing
    // pairwise repulsion (O(n^2), trivial for 49 nodes)
    for (let i = 0; i < n; i++) {
      let fx = 0;
      let fy = 0;
      let fz = 0;
      const ni = nodes[i];
      for (let j = 0; j < n; j++) {
        if (i === j) continue;
        const nj = nodes[j];
        let dx = ni.x - nj.x;
        let dy = ni.y - nj.y;
        let dz = ni.z - nj.z;
        let d2 = dx * dx + dy * dy + dz * dz;
        if (d2 < 0.01) {
          dx = (rand() - 0.5) * 0.1;
          dy = (rand() - 0.5) * 0.1;
          dz = (rand() - 0.5) * 0.1;
          d2 = 0.01;
        }
        const d = Math.sqrt(d2);
        const f = (REPULSION / d2) * ni.size;
        fx += (dx / d) * f;
        fy += (dy / d) * f;
        fz += (dz / d) * f;
      }
      // cluster + center gravity
      const anchor = catAnchors.get(ni.tool.category) ?? { x: 0, y: 0, z: 0 };
      fx += (anchor.x - ni.x) * CLUSTER_GRAVITY;
      fy += (anchor.y - ni.y) * CLUSTER_GRAVITY;
      fz += (anchor.z - ni.z) * CLUSTER_GRAVITY;
      fx += -ni.x * CENTER_GRAVITY;
      fy += -ni.y * CENTER_GRAVITY;
      fz += -ni.z * CENTER_GRAVITY;

      vx[i] = (vx[i] + fx) * DAMPING;
      vy[i] = (vy[i] + fy) * DAMPING;
      vz[i] = (vz[i] + fz) * DAMPING;
    }
    // link springs
    for (const e of edges) {
      const a = nodes[e.a];
      const b = nodes[e.b];
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const dz = b.z - a.z;
      const d = Math.sqrt(dx * dx + dy * dy + dz * dz) || 0.001;
      const target = e.primary ? SPRING_LEN : SPRING_LEN * 1.7;
      const k = SPRING * (e.primary ? 1 : 0.55);
      const f = (d - target) * k;
      const ux = (dx / d) * f;
      const uy = (dy / d) * f;
      const uz = (dz / d) * f;
      vx[e.a] += ux;
      vy[e.a] += uy;
      vz[e.a] += uz;
      vx[e.b] -= ux;
      vy[e.b] -= uy;
      vz[e.b] -= uz;
    }
    // integrate
    const step = 0.16 * (0.4 + cooling);
    for (let i = 0; i < n; i++) {
      nodes[i].x += vx[i] * step;
      nodes[i].y += vy[i] * step;
      nodes[i].z += vz[i] * step;
    }
  }

  // center & measure radius
  let cx = 0;
  let cy = 0;
  let cz = 0;
  for (const nd of nodes) {
    cx += nd.x;
    cy += nd.y;
    cz += nd.z;
  }
  cx /= n;
  cy /= n;
  cz /= n;
  let radius = 1;
  for (const nd of nodes) {
    nd.x -= cx;
    nd.y -= cy;
    nd.z -= cz;
    radius = Math.max(radius, Math.hypot(nd.x, nd.y, nd.z));
  }

  return { nodes, edges, indexById, radius, adjacency };
}

// --- circular soft-glow sprite texture (module scope, built once) ------------
function makeGlowTexture(): THREE.Texture {
  const size = 128;
  const data = new Uint8Array(size * size * 4);
  const c = size / 2;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const dx = (x - c) / c;
      const dy = (y - c) / c;
      const d = Math.sqrt(dx * dx + dy * dy);
      // bright core + soft falloff
      let a = Math.max(0, 1 - d);
      a = Math.pow(a, 2.2);
      const core = Math.max(0, 1 - d * 3.2);
      a = Math.min(1, a + core * 0.9);
      const i = (y * size + x) * 4;
      data[i] = 255;
      data[i + 1] = 255;
      data[i + 2] = 255;
      data[i + 3] = Math.round(a * 255);
    }
  }
  const tex = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  tex.needsUpdate = true;
  return tex;
}

const GLOW_TEXTURE = makeGlowTexture();

// --- point cloud shader: per-point size attenuation + glow sprite ------------
const POINT_VERT = /* glsl */ `
  attribute float aSize;
  attribute vec3 aColor;
  attribute float aHi;
  varying vec3 vColor;
  varying float vHi;
  uniform float uPixelRatio;
  void main() {
    vColor = aColor;
    vHi = aHi;
    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    float boost = mix(1.0, 1.85, aHi);
    gl_PointSize = aSize * boost * uPixelRatio * (300.0 / -mv.z);
    gl_Position = projectionMatrix * mv;
  }
`;

const POINT_FRAG = /* glsl */ `
  uniform sampler2D uTex;
  uniform float uDim;
  varying vec3 vColor;
  varying float vHi;
  void main() {
    vec4 t = texture2D(uTex, gl_PointCoord);
    float a = t.a;
    if (a < 0.01) discard;
    vec3 col = vColor;
    // hot white core for highlighted nodes
    col = mix(col, vec3(1.0), vHi * 0.45);
    float dim = mix(uDim, 1.0, vHi);
    gl_FragColor = vec4(col * (1.3 + vHi * 1.4), a * dim);
  }
`;

interface GraphProps {
  layout: Layout;
  hovered: number | null;
  setHovered: (i: number | null) => void;
}

// All GPU buffers for the graph live here. Computed once from the layout and
// owned by a ref (not a hook return) so the frame loop is free to mutate the
// highlight + edge-color arrays without tripping react-hooks/immutability.
interface Buffers {
  positions: Float32Array;
  colors: Float32Array;
  sizes: Float32Array;
  hi: Float32Array; // mutable per-node highlight
  edgePos: Float32Array;
  edgeCol: Float32Array; // mutable per-vertex color
  baseEdgeCol: Float32Array; // immutable reference colors
  m: number;
}

function makeBuffers(layout: Layout): Buffers {
  const { nodes, edges } = layout;
  const n = nodes.length;
  const positions = new Float32Array(n * 3);
  const colors = new Float32Array(n * 3);
  const sizes = new Float32Array(n);
  nodes.forEach((nd, i) => {
    positions[i * 3] = nd.x;
    positions[i * 3 + 1] = nd.y;
    positions[i * 3 + 2] = nd.z;
    colors[i * 3] = nd.color[0];
    colors[i * 3 + 1] = nd.color[1];
    colors[i * 3 + 2] = nd.color[2];
    sizes[i] = nd.size;
  });

  const m = edges.length;
  const edgePos = new Float32Array(m * 2 * 3);
  const edgeCol = new Float32Array(m * 2 * 3);
  edges.forEach((e, i) => {
    const a = nodes[e.a];
    const b = nodes[e.b];
    edgePos[i * 6] = a.x;
    edgePos[i * 6 + 1] = a.y;
    edgePos[i * 6 + 2] = a.z;
    edgePos[i * 6 + 3] = b.x;
    edgePos[i * 6 + 4] = b.y;
    edgePos[i * 6 + 5] = b.z;
    for (let k = 0; k < 3; k++) {
      edgeCol[i * 6 + k] = a.color[k];
      edgeCol[i * 6 + 3 + k] = b.color[k];
    }
  });

  return {
    positions,
    colors,
    sizes,
    hi: new Float32Array(n),
    edgePos,
    edgeCol,
    baseEdgeCol: edgeCol.slice(),
    m,
  };
}

function Graph({ layout, hovered, setHovered }: GraphProps) {
  const { nodes, edges, adjacency } = layout;
  const n = nodes.length;
  const { gl } = useThree();

  // single owner of every GPU buffer + the shader uniforms; built once via a
  // lazy useState initializer. useState values are stable and not tracked by
  // the react-hooks immutability rule, so the frame loop may freely mutate
  // the highlight / edge-color arrays and uniform values in place.
  const [buf] = useState(() => makeBuffers(layout));
  const [uniforms] = useState(() => ({
    uTex: { value: GLOW_TEXTURE },
    uPixelRatio: { value: Math.min(gl.getPixelRatio(), 2) },
    uDim: { value: 1.0 },
    uTime: { value: 0 },
  }));

  const hiAttrRef = useRef<THREE.BufferAttribute>(null);
  const edgeColAttrRef = useRef<THREE.BufferAttribute>(null);
  const matRef = useRef<THREE.ShaderMaterial>(null);

  // Highlight is recomputed in the frame loop whenever the hovered index
  // changes. All mutation is routed through ref `.current` handles (attribute
  // arrays + material uniforms), which is the only mutation eslint's purity
  // rule permits inside useFrame.
  const lastApplied = useRef<number | null>(-2);
  const group = useRef<THREE.Group>(null);

  useFrame((state, delta) => {
    if (group.current && hovered === null) {
      group.current.rotation.y += delta * 0.045;
    }
    if (matRef.current) {
      matRef.current.uniforms.uTime.value = state.clock.elapsedTime;
    }

    if (lastApplied.current === hovered) return;
    lastApplied.current = hovered;

    const hiAttr = hiAttrRef.current;
    const colAttr = edgeColAttrRef.current;
    if (!hiAttr || !colAttr) return;

    const linked = new Set<number>();
    if (hovered !== null) {
      linked.add(hovered);
      for (const j of adjacency[hovered]) linked.add(j);
    }
    const hi = hiAttr.array as Float32Array;
    for (let i = 0; i < n; i++) {
      hi[i] = hovered === null ? 0 : linked.has(i) ? (i === hovered ? 1 : 0.6) : 0;
    }
    const col = colAttr.array as Float32Array;
    const base = buf.baseEdgeCol;
    for (let i = 0; i < buf.m; i++) {
      const e = edges[i];
      const connected = hovered !== null && (e.a === hovered || e.b === hovered);
      const dim = hovered === null ? (e.primary ? 0.5 : 0.16) : connected ? 1.6 : 0.05;
      for (let k = 0; k < 6; k++) col[i * 6 + k] = base[i * 6 + k] * dim;
    }
    hiAttr.needsUpdate = true;
    colAttr.needsUpdate = true;
    if (matRef.current) {
      matRef.current.uniforms.uDim.value = hovered === null ? 1.0 : 0.32;
    }
  });

  // raycast picking against points -----------------------------------------
  const handleMove = useCallback(
    (e: ThreeEvent<PointerEvent>) => {
      if (e.index !== undefined && e.index !== null) {
        setHovered(e.index);
      }
    },
    [setHovered],
  );

  return (
    <group ref={group}>
      {/* edges — one draw call */}
      <lineSegments renderOrder={0}>
        <bufferGeometry>
          <bufferAttribute
            attach="attributes-position"
            args={[buf.edgePos, 3]}
          />
          <bufferAttribute
            ref={edgeColAttrRef}
            attach="attributes-color"
            args={[buf.edgeCol, 3]}
          />
        </bufferGeometry>
        <lineBasicMaterial
          vertexColors
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
          opacity={0.85}
        />
      </lineSegments>

      {/* nodes — one draw call, additive glow */}
      <points
        renderOrder={1}
        onPointerMove={handleMove}
        onPointerOut={() => setHovered(null)}
      >
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[buf.positions, 3]} />
          <bufferAttribute attach="attributes-aColor" args={[buf.colors, 3]} />
          <bufferAttribute attach="attributes-aSize" args={[buf.sizes, 1]} />
          <bufferAttribute
            ref={hiAttrRef}
            attach="attributes-aHi"
            args={[buf.hi, 1]}
          />
        </bufferGeometry>
        <shaderMaterial
          ref={matRef}
          vertexShader={POINT_VERT}
          fragmentShader={POINT_FRAG}
          uniforms={uniforms}
          transparent
          depthWrite={false}
          blending={THREE.AdditiveBlending}
        />
      </points>
    </group>
  );
}

// --- scroll-zoom + drag-pan camera rig (raw, Cosmograph-style) ---------------
function CameraRig({ radius }: { radius: number }) {
  const { camera, gl } = useThree();
  const distRef = useRef(radius * 2.4);
  const targetDist = useRef(radius * 2.4);
  const panRef = useRef(new THREE.Vector2(0, 0));
  const targetPan = useRef(new THREE.Vector2(0, 0));
  const dragging = useRef(false);
  const last = useRef(new THREE.Vector2());

  // wire DOM listeners once
  useEffect(() => {
    const el = gl.domElement;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const f = Math.exp(e.deltaY * 0.0011);
      targetDist.current = THREE.MathUtils.clamp(
        targetDist.current * f,
        radius * 0.9,
        radius * 5.5,
      );
    };
    const onDown = (e: PointerEvent) => {
      dragging.current = true;
      last.current.set(e.clientX, e.clientY);
    };
    const onUp = () => {
      dragging.current = false;
    };
    const onMove = (e: PointerEvent) => {
      if (!dragging.current) return;
      const dx = e.clientX - last.current.x;
      const dy = e.clientY - last.current.y;
      last.current.set(e.clientX, e.clientY);
      const scale = targetDist.current * 0.0016;
      targetPan.current.x -= dx * scale;
      targetPan.current.y += dy * scale;
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    el.addEventListener('pointerdown', onDown);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointermove', onMove);
    return () => {
      el.removeEventListener('wheel', onWheel);
      el.removeEventListener('pointerdown', onDown);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointermove', onMove);
    };
  }, [gl, radius]);

  useFrame(() => {
    distRef.current += (targetDist.current - distRef.current) * 0.12;
    panRef.current.lerp(targetPan.current, 0.12);
    camera.position.set(panRef.current.x, panRef.current.y, distRef.current);
    camera.lookAt(panRef.current.x, panRef.current.y, 0);
  });

  return null;
}

export function ForceCloud() {
  const layout = useMemo(() => buildLayout(), []);
  const [hovered, setHovered] = useState<number | null>(null);

  const hoveredTool = hovered !== null ? layout.nodes[hovered].tool : null;
  const hoveredCat = hoveredTool ? categoryById.get(hoveredTool.category) : null;
  const links =
    hoveredTool && hovered !== null
      ? layout.adjacency[hovered]
          .map((i) => layout.nodes[i].tool)
          .filter((t): t is AITool => Boolean(t))
      : [];

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#04060f]">
      {/* deep-space gradient backdrop */}
      <div
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse at 50% 42%, rgba(40,52,96,0.45) 0%, rgba(8,10,24,0.85) 48%, #04060f 100%)',
        }}
      />

      <Canvas
        camera={{ position: [0, 0, layout.radius * 2.4], fov: 55, near: 0.1, far: 4000 }}
        gl={{ antialias: true, alpha: true }}
        dpr={[1, 2]}
        style={{ position: 'absolute', inset: 0 }}
      >
        <Graph layout={layout} hovered={hovered} setHovered={setHovered} />
        <CameraRig radius={layout.radius} />
      </Canvas>

      {/* top chrome / legend ------------------------------------------------ */}
      <div className="pointer-events-none absolute inset-x-0 top-0 px-6 pt-16">
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="text-[11px] font-medium uppercase tracking-[0.28em] text-cyan-300/70">
              Direction J · Cosmograph
            </div>
            <h2 className="mt-1 text-xl font-semibold text-white/90">
              Force-Directed Tool Graph
            </h2>
            <p className="mt-0.5 max-w-sm text-xs leading-relaxed text-white/45">
              {layout.nodes.length} nodes · {layout.edges.length} edges · GPU points +
              single LineSegments buffer. Scroll to zoom, drag to pan, hover a node to
              light its constellation.
            </p>
          </div>

          {/* category legend */}
          <div className="hidden flex-col items-end gap-1.5 sm:flex">
            {categories.map((c) => (
              <div key={c.id} className="flex items-center gap-2">
                <span className="text-[11px] text-white/55">{c.shortName}</span>
                <span
                  className="h-2.5 w-2.5 rounded-full"
                  style={{ background: c.color, boxShadow: `0 0 10px ${c.color}` }}
                />
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* hovered tool detail card ------------------------------------------ */}
      {hoveredTool && (
        <div className="pointer-events-none absolute bottom-6 left-6 max-w-xs rounded-2xl border border-white/10 bg-black/55 p-4 backdrop-blur-md">
          <div className="flex items-center gap-2">
            <span
              className="h-3 w-3 rounded-full"
              style={{
                background: hoveredCat?.color ?? '#9ad',
                boxShadow: `0 0 12px ${hoveredCat?.color ?? '#9ad'}`,
              }}
            />
            <span className="text-sm font-semibold text-white/90">
              {hoveredTool.name}
            </span>
            <span className="ml-auto text-[10px] uppercase tracking-wider text-white/40">
              {hoveredTool.stage}
            </span>
          </div>
          <div className="mt-1 text-[11px] uppercase tracking-wide text-white/40">
            {hoveredCat?.name}
          </div>
          <p className="mt-2 text-xs leading-relaxed text-white/60">
            {hoveredTool.summary}
          </p>
          {links.length > 0 && (
            <div className="mt-3 border-t border-white/10 pt-2">
              <div className="mb-1 text-[10px] uppercase tracking-wider text-white/35">
                Connected · {links.length}
              </div>
              <div className="flex flex-wrap gap-1.5">
                {links.slice(0, 8).map((t) => (
                  <span
                    key={t.id}
                    className="rounded-md bg-white/8 px-1.5 py-0.5 text-[10px] text-white/65"
                  >
                    {t.name}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
