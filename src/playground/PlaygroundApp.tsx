import { useEffect, useState, type ComponentType } from 'react';
import { InAppBrowserProvider } from '../components/InAppBrowser';
import { ToolStoreProvider } from './store';
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

interface Variant {
  id: string;
  label: string;
  blurb: string;
  Component: ComponentType;
}

const VARIANTS: Variant[] = [
  { id: 'A', label: 'A · AI Brain', blurb: 'Force-directed graph · Obsidian feel', Component: BrainGraph },
  { id: 'B', label: 'B · Object Space', blurb: 'Vision Pro restraint · floating worlds', Component: ObjectSpace },
  { id: 'C', label: 'C · AI Galaxy', blurb: 'Google-Earth scale · zoom hierarchy', Component: GalaxyMap },
  { id: 'D', label: 'D · TheBrain', blurb: 'Click to re-centre · the world reorganises', Component: BrainHub },
  { id: 'E', label: 'E · Neural Net', blurb: 'Layered neurons · pulsing synapses', Component: NeuralNet },
  { id: 'F', label: 'F · AI City', blurb: 'Districts & towers · fly through', Component: CityMap },
  { id: 'G', label: 'G · Metro Map', blurb: 'Provider lines · tool stations', Component: MetroMap },
  { id: 'H', label: 'H · Organism', blurb: 'Living cells · pulsing synapses', Component: Organism },
  { id: 'I', label: 'I · WizMap', blurb: 'Semantic embedding map · density regions', Component: SemanticMap },
  { id: 'J', label: 'J · Cosmograph', blurb: 'GPU force graph · Obsidian on steroids', Component: ForceCloud },
  { id: 'K', label: 'K · Neo4j Bloom', blurb: 'Autofocus · progressive reveal', Component: BloomGraph },
  { id: 'L', label: 'L · Firefly', blurb: 'Massive point cloud · LOD · filtering', Component: Firefly },
  { id: 'M', label: 'M · Globe Switch', blurb: 'Globe → planet → tool · spatial zoom', Component: GlobeSwitch },
  { id: 'N', label: 'N · 3D Force', blurb: 'True 3D force graph · fly between nodes', Component: Force3D },
  { id: 'O', label: 'O · Neural Universe', blurb: 'Hybrid hero · big living nodes · drill-in', Component: NeuralUniverse },
];

function initialId(): string {
  if (typeof window === 'undefined') return 'A';
  const fromHash = window.location.hash.replace('#', '').toUpperCase();
  return VARIANTS.some((v) => v.id === fromHash) ? fromHash : 'A';
}

export function PlaygroundApp() {
  const [activeId, setActiveId] = useState(initialId);
  const [addOpen, setAddOpen] = useState(false);
  const [detailId, setDetailId] = useState<string | null>(null);
  const active = VARIANTS.find((v) => v.id === activeId) ?? VARIANTS[0];
  const Active = active.Component;

  const select = (id: string) => {
    setActiveId(id);
    if (typeof window !== 'undefined') window.history.replaceState(null, '', `#${id}`);
  };

  useEffect(() => {
    const onHash = () => {
      const id = window.location.hash.replace('#', '').toUpperCase();
      if (VARIANTS.some((v) => v.id === id)) setActiveId(id);
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  return (
    <InAppBrowserProvider>
    <ToolStoreProvider>
    <div className="relative h-[100dvh] w-screen overflow-hidden bg-[#03040a] text-white">
      <div className="absolute inset-0">
        <Active />
      </div>

      {/* + Add-tool FAB — paste a tool, the classifier places it. */}
      <button
        type="button"
        onClick={() => setAddOpen(true)}
        title="Add a tool"
        className="absolute bottom-6 right-6 z-20 flex h-14 w-14 items-center justify-center rounded-2xl border border-white/15 bg-white/[0.08] text-2xl font-light text-white shadow-[0_12px_40px_rgba(0,0,0,0.5)] backdrop-blur-2xl transition hover:bg-white/[0.14] active:scale-95"
      >
        +
      </button>
      <AddToolModal open={addOpen} onClose={() => setAddOpen(false)} onAdded={(id) => setDetailId(id)} />

      {/* Hyperbrain chat — hidden while a tool's window is open. */}
      {detailId ? null : <FindBar onOpenTool={(id) => setDetailId(id)} />}
      <ToolDetail toolId={detailId} onClose={() => setDetailId(null)} onSelect={(id) => setDetailId(id)} />

      <header className="pointer-events-none absolute inset-x-0 top-0 z-10 flex flex-col gap-3 p-4">
        <div className="pointer-events-auto">
          <h1 className="text-sm font-semibold tracking-tight">AI Universe · Visualization Lab</h1>
          <p className="text-xs text-white/55">{active.label.split('·')[1]?.trim()} — {active.blurb}</p>
        </div>
        <nav className="pointer-events-auto flex max-w-full gap-1 overflow-x-auto rounded-xl border border-white/10 bg-white/[0.06] p-1 backdrop-blur-2xl">
          {VARIANTS.map((v) => (
            <button
              key={v.id}
              type="button"
              onClick={() => select(v.id)}
              title={v.blurb}
              className={`whitespace-nowrap rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                activeId === v.id
                  ? 'bg-white/90 text-black'
                  : 'text-white/70 hover:bg-white/10 hover:text-white'
              }`}
            >
              {v.label}
            </button>
          ))}
        </nav>
      </header>
    </div>
    </ToolStoreProvider>
    </InAppBrowserProvider>
  );
}
