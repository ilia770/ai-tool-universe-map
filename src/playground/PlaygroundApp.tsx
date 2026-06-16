import { useEffect, useRef, useState, type ComponentType, type CSSProperties } from 'react';
import { ChevronDown, Plus } from 'lucide-react';
import { InAppBrowserProvider } from '../components/InAppBrowser';
import { ToolStoreProvider } from './store';
import { useToolStore } from './useToolStore';
import { AddToolModal } from './AddToolModal';
import { FindBar } from './FindBar';
import { ToolDetail } from './ToolDetail';
import { BrainGraph } from './variants/BrainGraph';
import { ObjectSpace } from './variants/ObjectSpace';
import { GalaxyMap } from './variants/GalaxyMap';
import { BrainHub } from './variants/BrainHub';
import { NeuralNet } from './variants/NeuralNet';
import { CityMap } from './variants/CityMap';
import { MetroMap } from './variants/MetroMap';
import { Organism } from './variants/Organism';
import { SemanticMap } from './variants/SemanticMap';
import { ForceCloud } from './variants/ForceCloud';
import { BloomGraph } from './variants/BloomGraph';
import { Firefly } from './variants/Firefly';
import { GlobeSwitch } from './variants/GlobeSwitch';
import { Force3D } from './variants/Force3D';
import { NeuralUniverse } from './variants/NeuralUniverse';
import { cx, EASE, FOCUS_RING, GLASS, TEXT, TYPE } from './designSystem';

interface Variant {
  id: string;
  /** Engineer codename (kept for the More menu + tooltip — never shown as chrome). */
  label: string;
  blurb: string;
  /** User-facing one-liner shown in the header (ship copy, not codenames). */
  ship: string;
  Component: ComponentType;
}

const VARIANTS: Variant[] = [
  { id: 'A', label: 'A · AI Brain', blurb: 'Force-directed graph · Obsidian feel', ship: 'The connected mind', Component: BrainGraph },
  { id: 'B', label: 'B · Object Space', blurb: 'Vision Pro restraint · floating worlds', ship: 'Floating worlds', Component: ObjectSpace },
  { id: 'C', label: 'C · AI Galaxy', blurb: 'Google-Earth scale · zoom hierarchy', ship: 'Zoom the galaxy', Component: GalaxyMap },
  { id: 'D', label: 'D · TheBrain', blurb: 'Click to re-centre · the world reorganises', ship: 'Re-centre the world', Component: BrainHub },
  { id: 'E', label: 'E · Neural Net', blurb: 'Layered neurons · pulsing synapses', ship: 'Pulsing synapses', Component: NeuralNet },
  { id: 'F', label: 'F · AI City', blurb: 'Districts & towers · fly through', ship: 'Fly the city', Component: CityMap },
  { id: 'G', label: 'G · Metro Map', blurb: 'Provider lines · tool stations', ship: 'Ride the lines', Component: MetroMap },
  { id: 'H', label: 'H · Organism', blurb: 'Living cells · pulsing synapses', ship: 'A living organism', Component: Organism },
  { id: 'I', label: 'I · WizMap', blurb: 'Semantic embedding map · density regions', ship: 'Semantic regions', Component: SemanticMap },
  { id: 'J', label: 'J · Cosmograph', blurb: 'GPU force graph · Obsidian on steroids', ship: 'The full cosmos', Component: ForceCloud },
  { id: 'K', label: 'K · Neo4j Bloom', blurb: 'Autofocus · progressive reveal', ship: 'Progressive bloom', Component: BloomGraph },
  { id: 'L', label: 'L · Firefly', blurb: 'Massive point cloud · LOD · filtering', ship: 'A field of fireflies', Component: Firefly },
  { id: 'M', label: 'M · Globe Switch', blurb: 'Globe → planet → tool · spatial zoom', ship: 'Globe to tool', Component: GlobeSwitch },
  { id: 'N', label: 'N · 3D Force', blurb: 'True 3D force graph · fly between nodes', ship: 'Fly through in 3D', Component: Force3D },
  { id: 'O', label: 'O · Neural Universe', blurb: 'Hybrid hero · big living nodes · drill-in', ship: 'The living universe', Component: NeuralUniverse },
];

/** Promoted finalists shown inline; the rest fold behind the More disclosure. */
const FINALIST_IDS = ['A', 'K', 'N', 'O'] as const;

function initialId(): string {
  if (typeof window === 'undefined') return 'A';
  const fromHash = window.location.hash.replace('#', '').toUpperCase();
  return VARIANTS.some((v) => v.id === fromHash) ? fromHash : 'A';
}

function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = useState(
    () =>
      typeof window !== 'undefined' &&
      !!window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  );
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = (e: MediaQueryListEvent) => setReduced(e.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);
  return reduced;
}

/** Variant nav tab — 44px, cyan-tinted active, tactile press, focus ring. */
function NavTab({
  variant,
  active,
  onSelect,
}: {
  variant: Variant;
  active: boolean;
  onSelect: (id: string) => void;
}) {
  return (
    <button
      type="button"
      onClick={() => onSelect(variant.id)}
      title={variant.blurb}
      aria-current={active ? 'true' : undefined}
      className={cx(
        'whitespace-nowrap rounded-xl px-3.5 py-2 transition-[background-color,color,transform] duration-200 active:scale-[0.96]',
        'min-h-[44px]',
        TYPE.body,
        'font-medium',
        active
          ? cx('bg-white/[0.14] text-cyan-200', '[box-shadow:inset_0_1px_0_0_rgba(255,255,255,0.14)]')
          : cx(TEXT.secondary, '[@media(hover:hover)]:hover:bg-white/10 [@media(hover:hover)]:hover:text-white/85'),
        FOCUS_RING,
      )}
      style={{ transitionTimingFunction: EASE.out }}
    >
      {variant.id}
    </button>
  );
}

export function PlaygroundApp() {
  return (
    <InAppBrowserProvider>
      <ToolStoreProvider>
        <PlaygroundShell />
      </ToolStoreProvider>
    </InAppBrowserProvider>
  );
}

function PlaygroundShell() {
  const [activeId, setActiveId] = useState(initialId);
  const [addOpen, setAddOpen] = useState(false);
  const [addPrefill, setAddPrefill] = useState('');
  const [detailId, setDetailId] = useState<string | null>(null);
  const [moreOpen, setMoreOpen] = useState(false);
  const reduced = usePrefersReducedMotion();
  const { tools } = useToolStore();

  const active = VARIANTS.find((v) => v.id === activeId) ?? VARIANTS[0];
  const Active = active.Component;
  const finalists = VARIANTS.filter((v) => (FINALIST_IDS as readonly string[]).includes(v.id));
  const rest = VARIANTS.filter((v) => !(FINALIST_IDS as readonly string[]).includes(v.id));

  // Empty universe = the user hasn't mapped a tool of their own yet → invite the first add.
  const isEmptyUniverse = !tools.some((t) => t.userAdded);

  const select = (id: string) => {
    setActiveId(id);
    setMoreOpen(false);
    if (typeof window !== 'undefined') window.history.replaceState(null, '', `#${id}`);
  };

  const openAddToolFromQuery = (q: string) => {
    setAddPrefill(q);
    setAddOpen(true);
  };

  useEffect(() => {
    const onHash = () => {
      const id = window.location.hash.replace('#', '').toUpperCase();
      if (VARIANTS.some((v) => v.id === id)) setActiveId(id);
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  // Close the More disclosure on Escape / outside tap.
  const moreRef = useRef<HTMLDivElement | null>(null);
  useEffect(() => {
    if (!moreOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMoreOpen(false);
    };
    const onDown = (e: PointerEvent) => {
      if (moreRef.current && !moreRef.current.contains(e.target as Node)) setMoreOpen(false);
    };
    window.addEventListener('keydown', onKey);
    window.addEventListener('pointerdown', onDown);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('pointerdown', onDown);
    };
  }, [moreOpen]);

  // One source of truth for HUD/chrome top offset — kills the magic-number drift.
  const rootStyle = { '--hud-top': '8rem' } as CSSProperties;

  return (
    <div
      className="relative h-[100dvh] w-screen overflow-hidden bg-[#03040a] text-white [touch-action:manipulation]"
      style={rootStyle}
    >
      <div className="absolute inset-0">
        <Active />
      </div>

      {/* + Add-tool FAB — paste a tool, the classifier places it. */}
      <button
        type="button"
        onClick={() => {
          setAddPrefill('');
          setAddOpen(true);
        }}
        aria-label="Add a tool"
        className={cx(
          'absolute z-30 flex h-14 w-14 items-center justify-center text-white/90 transition',
          GLASS.floating,
          '[@media(hover:hover)]:hover:bg-white/[0.14] active:scale-95',
          FOCUS_RING,
          !reduced && 'motion-safe:animate-[fab-rise_0.36s_both]',
          !reduced && isEmptyUniverse && 'motion-safe:animate-[fab-pulse_2.4s_ease-in-out_infinite]',
        )}
        style={{
          bottom: 'max(1.5rem, calc(env(safe-area-inset-bottom) + 0.5rem))',
          right: 'max(1.5rem, env(safe-area-inset-right))',
          animationTimingFunction: EASE.out,
        }}
      >
        <Plus className="h-6 w-6" strokeWidth={2} aria-hidden="true" />
      </button>
      <AddToolModal
        open={addOpen}
        initialText={addPrefill}
        onClose={() => {
          setAddOpen(false);
          setAddPrefill('');
        }}
        onAdded={(id) => setDetailId(id)}
      />

      {/* Hyperbrain chat — kept mounted (hidden via CSS) so opening a tool window
          never destroys the conversation. */}
      <div className={detailId ? 'hidden' : 'contents'} aria-hidden={detailId ? true : undefined}>
        <FindBar onOpenTool={(id) => setDetailId(id)} onAddToolQuery={openAddToolFromQuery} />
      </div>
      <ToolDetail toolId={detailId} onClose={() => setDetailId(null)} onSelect={(id) => setDetailId(id)} />

      <header
        className="pointer-events-none absolute inset-x-0 top-0 z-10 flex flex-col gap-3 px-4 pb-4"
        style={{ paddingTop: 'max(1rem, env(safe-area-inset-top))' }}
      >
        {/* Title block — non-interactive ship copy (no engineer codenames). */}
        <div className="pointer-events-none select-none">
          <h1 className="text-sm font-semibold tracking-tight text-white/85">AI Tool Universe</h1>
          <p className={cx('mt-0.5', TYPE.chip, TEXT.meta)}>{active.ship}</p>
        </div>

        {/* Variant nav — finalists inline + the rest folded behind More. */}
        <div ref={moreRef} className="pointer-events-auto relative flex items-center gap-1">
          <nav
            aria-label="Visualization"
            className={cx('flex items-center gap-1 p-1', GLASS.bar)}
          >
            {finalists.map((v) => (
              <NavTab key={v.id} variant={v} active={activeId === v.id} onSelect={select} />
            ))}
            <button
              type="button"
              onClick={() => setMoreOpen((o) => !o)}
              aria-haspopup="menu"
              aria-expanded={moreOpen}
              title="More visualizations"
              className={cx(
                'flex min-h-[44px] items-center gap-1 whitespace-nowrap rounded-xl px-3.5 py-2 transition-[background-color,color,transform] duration-200 active:scale-[0.96]',
                TYPE.body,
                'font-medium',
                moreOpen || !(FINALIST_IDS as readonly string[]).includes(activeId)
                  ? 'bg-white/[0.14] text-cyan-200 [box-shadow:inset_0_1px_0_0_rgba(255,255,255,0.14)]'
                  : cx(TEXT.secondary, '[@media(hover:hover)]:hover:bg-white/10 [@media(hover:hover)]:hover:text-white/85'),
                FOCUS_RING,
              )}
              style={{ transitionTimingFunction: EASE.out }}
            >
              <span>More</span>
              <ChevronDown
                className={cx('h-3.5 w-3.5 transition-transform duration-200', moreOpen && 'rotate-180')}
                aria-hidden="true"
              />
            </button>
          </nav>

          {moreOpen && (
            <div
              role="menu"
              aria-label="More visualizations"
              className={cx(
                'absolute right-0 top-full z-20 mt-2 grid w-[min(20rem,calc(100vw-2rem))] grid-cols-2 gap-1 p-2',
                GLASS.floating,
                !reduced && 'motion-safe:animate-[findbar-fade_0.2s_ease-out]',
              )}
              style={{ animationTimingFunction: EASE.out }}
            >
              {rest.map((v) => {
                const isActive = activeId === v.id;
                return (
                  <button
                    key={v.id}
                    type="button"
                    role="menuitemradio"
                    aria-checked={isActive}
                    onClick={() => select(v.id)}
                    title={v.blurb}
                    className={cx(
                      'flex min-h-[44px] flex-col items-start justify-center rounded-xl px-3 py-2 text-left transition-[background-color,color,transform] duration-200 active:scale-[0.97]',
                      isActive
                        ? 'bg-white/[0.14] text-cyan-200'
                        : cx(TEXT.body, '[@media(hover:hover)]:hover:bg-white/10 [@media(hover:hover)]:hover:text-white/85'),
                      FOCUS_RING,
                    )}
                    style={{ transitionTimingFunction: EASE.out }}
                  >
                    <span className={cx(TYPE.body, 'font-medium leading-tight')}>{v.ship}</span>
                    <span className={cx(TYPE.eyebrow, TEXT.meta, 'mt-0.5')}>{v.id}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </header>
    </div>
  );
}
