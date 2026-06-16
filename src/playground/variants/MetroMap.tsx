import { useMemo, useState } from 'react';
import {
  tools,
  categories,
  toolById,
  categoryById,
  type AITool,
  type ToolCategory,
} from '../../data/ai-tool-universe';

/**
 * Direction G — "Metro Map".
 *
 * A Beck-style (London Underground) octilinear transit diagram.
 * Research (octilinear / schematic transit layout, Bast et al. 2020;
 * Beck 1933): restrict every route to horizontal / vertical / 45° runs on a
 * grid, space stations evenly along a route rather than geographically, round
 * the corners where a line changes heading, and mark places where routes meet
 * with a distinctive "interchange" symbol (Beck's diamond → the modern
 * double-ring tick). We emulate that faithfully in SVG:
 *   LINES        = categories (each its own colour, an octilinear route).
 *   STATIONS     = tools, evenly spaced along their category's route.
 *   INTERCHANGES = tools that relate to a tool in another category, drawn as
 *                  the classic white double-ring; a thin connector traces the
 *                  cross-line relation, exactly like a passenger interchange.
 * Center is magnified (the core line) and peripheries fan out octilinearly.
 */

// --- geometry ---------------------------------------------------------------

const VIEW_W = 1600;
const VIEW_H = 1000;
const CENTER = { x: VIEW_W / 2, y: VIEW_H / 2 + 24 };
const STATION_GAP = 116; // distance between consecutive stations on a line
const FIRST_GAP = 150; // distance from hub to first station
const CORNER_R = 26; // rounded corner radius at bends

// 8 octilinear unit directions (N, NE, E, SE, S, SW, W, NW).
const OCTILINEAR: ReadonlyArray<{ x: number; y: number }> = [
  { x: 0, y: -1 },
  { x: 1, y: -1 },
  { x: 1, y: 0 },
  { x: 1, y: 1 },
  { x: 0, y: 1 },
  { x: -1, y: 1 },
  { x: -1, y: 0 },
  { x: -1, y: -1 },
];

function norm(v: { x: number; y: number }) {
  const m = Math.hypot(v.x, v.y) || 1;
  return { x: v.x / m, y: v.y / m };
}

/** Snap an arbitrary degree angle to the nearest octilinear unit direction. */
function snapOctilinear(angleDeg: number): { x: number; y: number } {
  const rad = (angleDeg * Math.PI) / 180;
  const raw = { x: Math.cos(rad), y: Math.sin(rad) };
  let best = OCTILINEAR[0];
  let bestDot = -Infinity;
  for (const d of OCTILINEAR) {
    const n = norm(d);
    const dot = n.x * raw.x + n.y * raw.y;
    if (dot > bestDot) {
      bestDot = dot;
      best = d;
    }
  }
  return norm(best);
}

interface Station {
  tool: AITool;
  x: number;
  y: number;
  /** index 0 = closest to hub */
  index: number;
}

interface Line {
  category: ToolCategory;
  dir: { x: number; y: number };
  /** perpendicular to dir, used for the dog-leg jog */
  perp: { x: number; y: number };
  stations: Station[];
  /** SVG path string for the route ribbon. */
  path: string;
}

/**
 * A line is a straight octilinear run out from the hub, but to avoid two
 * lines that snap to the same direction overlapping, lines are deterministically
 * given a small lateral "platform" offset and (for longer lines) a single
 * Beck-style dog-leg bend partway out — that bend is where we get to show off a
 * rounded corner.
 */
function buildLine(category: ToolCategory, laneOffset: number): Line {
  const dir = snapOctilinear(category.angle);
  const perp = norm({ x: -dir.y, y: dir.x });
  const list = tools
    .filter((t) => t.category === category.id)
    .sort((a, b) => a.orbit - b.orbit || a.angle - b.angle);

  // Lateral offset so co-directional lines run on parallel platforms.
  const offX = perp.x * laneOffset;
  const offY = perp.y * laneOffset;

  // Single dog-leg: after the 3rd station the line jogs one lane sideways.
  const bendAt = list.length > 4 ? 3 : -1;
  const jog = 34;

  const stations: Station[] = list.map((tool, i) => {
    const along = FIRST_GAP + i * STATION_GAP;
    const bent = bendAt >= 0 && i >= bendAt ? jog : 0;
    const x = CENTER.x + dir.x * along + offX + perp.x * bent;
    const y = CENTER.y + dir.y * along + offY + perp.y * bent;
    return { tool, x, y, index: i };
  });

  const path = buildRoutePath(
    { x: CENTER.x + offX, y: CENTER.y + offY },
    stations,
  );

  return { category, dir, perp, stations, path };
}

/** Octilinear poly-path with rounded corners through all station points. */
function buildRoutePath(
  hub: { x: number; y: number },
  stations: Station[],
): string {
  const pts = [hub, ...stations.map((s) => ({ x: s.x, y: s.y }))];
  if (pts.length < 2) return '';
  let d = `M ${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`;
  for (let i = 1; i < pts.length - 1; i++) {
    const prev = pts[i - 1];
    const cur = pts[i];
    const next = pts[i + 1];
    const inDir = norm({ x: cur.x - prev.x, y: cur.y - prev.y });
    const outDir = norm({ x: next.x - cur.x, y: next.y - cur.y });
    const turning = Math.abs(inDir.x - outDir.x) > 0.01 || Math.abs(inDir.y - outDir.y) > 0.01;
    if (!turning) {
      d += ` L ${cur.x.toFixed(1)} ${cur.y.toFixed(1)}`;
      continue;
    }
    const r = Math.min(
      CORNER_R,
      Math.hypot(cur.x - prev.x, cur.y - prev.y) / 2,
      Math.hypot(next.x - cur.x, next.y - cur.y) / 2,
    );
    const a = { x: cur.x - inDir.x * r, y: cur.y - inDir.y * r };
    const b = { x: cur.x + outDir.x * r, y: cur.y + outDir.y * r };
    d += ` L ${a.x.toFixed(1)} ${a.y.toFixed(1)}`;
    d += ` Q ${cur.x.toFixed(1)} ${cur.y.toFixed(1)} ${b.x.toFixed(1)} ${b.y.toFixed(1)}`;
  }
  const last = pts[pts.length - 1];
  d += ` L ${last.x.toFixed(1)} ${last.y.toFixed(1)}`;
  return d;
}

// --- data assembly (module scope, no per-render allocation) -----------------

const NON_CORE = categories.filter((c) => c.id !== 'core');
const CORE = categoryById.get('core');

// Assign parallel-lane offsets to lines that snapped to the same direction.
const LINES: Line[] = (() => {
  const dirKey = (c: ToolCategory) => {
    const d = snapOctilinear(c.angle);
    return `${d.x}:${d.y}`;
  };
  const seen = new Map<string, number>();
  const out: Line[] = [];
  for (const cat of NON_CORE) {
    const key = dirKey(cat);
    const n = seen.get(key) ?? 0;
    seen.set(key, n + 1);
    const lane = (n - 0) * 30; // 0, 30, 60 ... for collisions
    out.push(buildLine(cat, lane));
  }
  return out;
})();

// The core line runs as a short horizontal "spine" through the hub.
const CORE_LINE: Line | null = CORE ? buildCoreLine(CORE) : null;

function buildCoreLine(category: ToolCategory): Line {
  const dir = { x: 1, y: 0 };
  const perp = { x: 0, y: 1 };
  const list = tools
    .filter((t) => t.category === category.id)
    .sort((a, b) => a.orbit - b.orbit || a.angle - b.angle);
  const span = (list.length - 1) * 92;
  const stations: Station[] = list.map((tool, i) => ({
    tool,
    x: CENTER.x - span / 2 + i * 92,
    y: CENTER.y,
    index: i,
  }));
  const pts = stations.map((s) => ({ x: s.x, y: s.y }));
  let path = '';
  if (pts.length) {
    path = `M ${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`;
    for (let i = 1; i < pts.length; i++) path += ` L ${pts[i].x.toFixed(1)} ${pts[i].y.toFixed(1)}`;
  }
  return { category, dir, perp, stations, path };
}

const ALL_LINES: Line[] = CORE_LINE ? [...LINES, CORE_LINE] : LINES;

// Flat station lookup by tool id -> {station, line}.
interface Placed {
  station: Station;
  line: Line;
}
const PLACED = new Map<string, Placed>();
for (const line of ALL_LINES) {
  for (const station of line.stations) PLACED.set(station.tool.id, { station, line });
}

// Interchange detection: a tool is an interchange if it relates (either
// direction) to a tool in a *different* category. Build the cross-line
// connectors once.
interface Interchange {
  a: Placed;
  b: Placed;
  key: string;
}
const INTERCHANGES: Interchange[] = (() => {
  const out: Interchange[] = [];
  const seen = new Set<string>();
  for (const t of tools) {
    const from = PLACED.get(t.id);
    if (!from) continue;
    for (const rid of t.relationIds) {
      const target = toolById.get(rid);
      if (!target || target.category === t.category) continue;
      const to = PLACED.get(rid);
      if (!to) continue;
      const key = [t.id, rid].sort().join('::');
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({ a: from, b: to, key });
    }
  }
  return out;
})();

const INTERCHANGE_IDS = new Set<string>();
for (const ix of INTERCHANGES) {
  INTERCHANGE_IDS.add(ix.a.station.tool.id);
  INTERCHANGE_IDS.add(ix.b.station.tool.id);
}

// Precompute, per tool, the related tool ids (for highlight on hover).
const RELATED = new Map<string, Set<string>>();
for (const t of tools) {
  const s = RELATED.get(t.id) ?? new Set<string>();
  for (const r of t.relationIds) {
    s.add(r);
    const back = RELATED.get(r) ?? new Set<string>();
    back.add(t.id);
    RELATED.set(r, back);
  }
  RELATED.set(t.id, s);
}

// Label placement: push label to whichever side has more room (away from hub).
function labelAnchor(s: Station): { dx: number; dy: number; anchor: 'start' | 'end' | 'middle' } {
  const vx = s.x - CENTER.x;
  const anchor: 'start' | 'end' | 'middle' = vx > 40 ? 'start' : vx < -40 ? 'end' : 'middle';
  const dx = anchor === 'start' ? 14 : anchor === 'end' ? -14 : 0;
  const dy = anchor === 'middle' ? -16 : 4;
  return { dx, dy, anchor };
}

// --- component --------------------------------------------------------------

export function MetroMap() {
  const [active, setActive] = useState<string | null>(null);
  const [hover, setHover] = useState<string | null>(null);
  const [activeCat, setActiveCat] = useState<string | null>(null);

  const focus = hover ?? active;

  // The set of station ids that should stay lit given the current focus.
  const lit = useMemo(() => {
    if (activeCat) {
      const ids = new Set<string>();
      for (const t of tools) if (t.category === activeCat) ids.add(t.id);
      return ids;
    }
    if (!focus) return null;
    const ids = new Set<string>([focus]);
    const rel = RELATED.get(focus);
    if (rel) for (const r of rel) ids.add(r);
    return ids;
  }, [focus, activeCat]);

  const litCats = useMemo(() => {
    if (activeCat) return new Set([activeCat]);
    if (!lit) return null;
    const c = new Set<string>();
    for (const id of lit) {
      const t = toolById.get(id);
      if (t) c.add(t.category);
    }
    return c;
  }, [lit, activeCat]);

  const focusTool = active ? toolById.get(active) : null;

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#0a0d14] text-white">
      {/* subtle paper grid backdrop */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.05]"
        style={{
          backgroundImage:
            'linear-gradient(#ffffff 1px, transparent 1px), linear-gradient(90deg, #ffffff 1px, transparent 1px)',
          backgroundSize: '48px 48px',
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(1100px 800px at 50% 46%, rgba(40,52,82,0.45), transparent 70%)',
        }}
      />

      {/* title strip — generous top padding clears the lab chrome */}
      <div className="pointer-events-none absolute left-0 right-0 top-0 z-20 px-8 pt-16">
        <div className="text-[11px] font-semibold uppercase tracking-[0.45em] text-white/45">
          AI Tool Universe
        </div>
        <div className="mt-1 font-mono text-2xl font-bold tracking-tight text-white">
          Workflow Metro
        </div>
      </div>

      <svg
        viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}
        className="absolute inset-0 h-full w-full"
        preserveAspectRatio="xMidYMid meet"
        style={{ paddingTop: 64 }}
      >
        <defs>
          {ALL_LINES.map((l) => (
            <filter key={`g-${l.category.id}`} id={`glow-${l.category.id}`} x="-40%" y="-40%" width="180%" height="180%">
              <feGaussianBlur stdDeviation="6" result="b" />
              <feMerge>
                <feMergeNode in="b" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          ))}
        </defs>

        {/* Cross-line interchange connectors (drawn under the routes). */}
        <g>
          {INTERCHANGES.map((ix) => {
            const on =
              !lit ||
              (lit.has(ix.a.station.tool.id) && lit.has(ix.b.station.tool.id));
            return (
              <line
                key={ix.key}
                x1={ix.a.station.x}
                y1={ix.a.station.y}
                x2={ix.b.station.x}
                y2={ix.b.station.y}
                stroke="#ffffff"
                strokeWidth={on ? 2 : 1.2}
                strokeDasharray="2 7"
                strokeLinecap="round"
                opacity={on ? 0.5 : 0.07}
                style={{ transition: 'opacity 180ms, stroke-width 180ms' }}
              />
            );
          })}
        </g>

        {/* Route ribbons (casing + colour). */}
        <g>
          {ALL_LINES.map((l) => {
            const dim = litCats ? !litCats.has(l.category.id) : false;
            return (
              <g key={`route-${l.category.id}`} style={{ transition: 'opacity 180ms' }} opacity={dim ? 0.16 : 1}>
                <path
                  d={l.path}
                  fill="none"
                  stroke="#05070c"
                  strokeWidth={16}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d={l.path}
                  fill="none"
                  stroke={l.category.color}
                  strokeWidth={9}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  filter={!dim ? `url(#glow-${l.category.id})` : undefined}
                />
              </g>
            );
          })}
        </g>

        {/* Central interchange hub. */}
        <g>
          <circle cx={CENTER.x} cy={CENTER.y} r={26} fill="#05070c" stroke="#ffffff" strokeWidth={3} />
          <circle cx={CENTER.x} cy={CENTER.y} r={13} fill="#ffffff" />
        </g>

        {/* Stations. */}
        <g>
          {ALL_LINES.map((l) =>
            l.stations.map((s) => {
              const id = s.tool.id;
              const isInterchange = INTERCHANGE_IDS.has(id);
              const isLit = !lit || lit.has(id);
              const isFocus = focus === id;
              const dim = !isLit;
              const lab = labelAnchor(s);
              return (
                <g
                  key={id}
                  style={{ cursor: 'pointer', transition: 'opacity 180ms' }}
                  opacity={dim ? 0.18 : 1}
                  onMouseEnter={() => setHover(id)}
                  onMouseLeave={() => setHover(null)}
                  onClick={() => {
                    setActive((cur) => (cur === id ? null : id));
                    setActiveCat(null);
                  }}
                >
                  {isFocus && (
                    <circle cx={s.x} cy={s.y} r={20} fill="none" stroke={l.category.color} strokeWidth={2} opacity={0.6} />
                  )}
                  {isInterchange ? (
                    <>
                      {/* classic double-ring interchange tick */}
                      <circle cx={s.x} cy={s.y} r={10} fill="#0a0d14" stroke="#ffffff" strokeWidth={3.2} />
                      <circle cx={s.x} cy={s.y} r={4.4} fill={l.category.color} />
                    </>
                  ) : (
                    /* simple station tick */
                    <circle cx={s.x} cy={s.y} r={6.5} fill="#0a0d14" stroke={l.category.color} strokeWidth={3} />
                  )}
                  <text
                    x={s.x + lab.dx}
                    y={s.y + lab.dy}
                    textAnchor={lab.anchor}
                    fontSize={isInterchange ? 14 : 12.5}
                    fontWeight={isInterchange ? 700 : 600}
                    fill={isLit ? '#f3f6ff' : '#9aa3b8'}
                    style={{ pointerEvents: 'none', userSelect: 'none' }}
                  >
                    {s.tool.name}
                  </text>
                </g>
              );
            }),
          )}
        </g>
      </svg>

      {/* Legend — line key, Beck style. */}
      <div className="absolute bottom-6 left-6 z-20 max-w-[220px] rounded-xl border border-white/10 bg-black/45 p-3 backdrop-blur-md">
        <div className="mb-2 text-[10px] font-semibold uppercase tracking-[0.3em] text-white/40">
          Lines
        </div>
        <div className="flex flex-col gap-1.5">
          {ALL_LINES.map((l) => {
            const on = !activeCat || activeCat === l.category.id;
            return (
              <button
                key={l.category.id}
                type="button"
                onMouseEnter={() => setHover(null)}
                onClick={() => {
                  setActiveCat((cur) => (cur === l.category.id ? null : l.category.id));
                  setActive(null);
                }}
                className="flex items-center gap-2.5 rounded-md px-1.5 py-1 text-left transition hover:bg-white/5"
                style={{ opacity: on ? 1 : 0.4 }}
              >
                <span className="h-2.5 w-6 flex-none rounded-full" style={{ background: l.category.color }} />
                <span className="truncate text-xs font-medium text-white/85">{l.category.name}</span>
              </button>
            );
          })}
        </div>
        <div className="mt-2.5 flex items-center gap-2 border-t border-white/10 pt-2 text-[10px] text-white/45">
          <span className="inline-block h-3 w-3 flex-none rounded-full border-2 border-white bg-[#0a0d14]" />
          interchange
        </div>
      </div>

      {/* Station detail panel. */}
      {focusTool && (
        <div className="absolute bottom-6 right-6 z-20 w-[300px] rounded-2xl border border-white/12 bg-black/55 p-4 backdrop-blur-xl">
          <div className="flex items-center gap-2">
            <span
              className="h-2.5 w-2.5 flex-none rounded-full"
              style={{ background: categoryById.get(focusTool.category)?.color }}
            />
            <span className="text-[10px] font-semibold uppercase tracking-[0.22em] text-white/45">
              {categoryById.get(focusTool.category)?.name}
            </span>
          </div>
          <div className="mt-1.5 text-lg font-bold text-white">{focusTool.name}</div>
          <div className="mt-1 text-[13px] leading-relaxed text-white/65">{focusTool.summary}</div>
          <div className="mt-3 flex flex-wrap gap-1.5">
            <span className="rounded-full bg-white/8 px-2 py-0.5 text-[10px] uppercase tracking-wide text-white/55">
              {focusTool.stage}
            </span>
            {INTERCHANGE_IDS.has(focusTool.id) && (
              <span className="rounded-full bg-white/8 px-2 py-0.5 text-[10px] uppercase tracking-wide text-white/55">
                interchange
              </span>
            )}
          </div>
          {focusTool.relationIds.length > 0 && (
            <div className="mt-3">
              <div className="mb-1 text-[10px] uppercase tracking-[0.2em] text-white/35">Connects</div>
              <div className="flex flex-wrap gap-1.5">
                {focusTool.relationIds.map((rid) => {
                  const r = toolById.get(rid);
                  if (!r) return null;
                  return (
                    <button
                      key={rid}
                      type="button"
                      onClick={() => {
                        setActive(rid);
                        setActiveCat(null);
                      }}
                      className="rounded-md bg-white/6 px-2 py-1 text-[11px] text-white/75 transition hover:bg-white/12"
                    >
                      {r.name}
                    </button>
                  );
                })}
              </div>
            </div>
          )}
          <button
            type="button"
            onClick={() => setActive(null)}
            className="mt-3 text-[11px] text-white/35 transition hover:text-white/70"
          >
            close
          </button>
        </div>
      )}
    </div>
  );
}
