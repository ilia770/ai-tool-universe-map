import { useState } from 'react';
import { BrainGraph } from './variants/BrainGraph';
import { ObjectSpace } from './variants/ObjectSpace';
import { GalaxyMap } from './variants/GalaxyMap';

type VariantId = 'A' | 'B' | 'C';

const VARIANTS: { id: VariantId; label: string; blurb: string }[] = [
  { id: 'A', label: 'A · AI Brain', blurb: 'Force-directed graph · Obsidian feel' },
  { id: 'B', label: 'B · Object Space', blurb: 'Vision Pro restraint · floating worlds' },
  { id: 'C', label: 'C · AI Galaxy', blurb: 'Google-Earth scale · zoom hierarchy' },
];

export function PlaygroundApp() {
  const [active, setActive] = useState<VariantId>('A');

  return (
    <div className="relative h-[100dvh] w-screen overflow-hidden bg-[#03040a] text-white">
      <div className="absolute inset-0">
        {active === 'A' && <BrainGraph />}
        {active === 'B' && <ObjectSpace />}
        {active === 'C' && <GalaxyMap />}
      </div>

      <header className="pointer-events-none absolute inset-x-0 top-0 z-10 flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="pointer-events-auto">
          <h1 className="text-sm font-semibold tracking-tight">AI Universe · Visualization Lab</h1>
          <p className="text-xs text-white/55">{VARIANTS.find((v) => v.id === active)?.blurb}</p>
        </div>
        <nav className="pointer-events-auto flex gap-1 rounded-xl border border-white/10 bg-white/[0.06] p-1 backdrop-blur-2xl">
          {VARIANTS.map((v) => (
            <button
              key={v.id}
              type="button"
              onClick={() => setActive(v.id)}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                active === v.id
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
  );
}
