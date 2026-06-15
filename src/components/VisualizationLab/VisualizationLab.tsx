import { useMemo, useState, type ReactNode } from 'react';
import { ArrowLeft, Brain, Orbit, Sparkles } from 'lucide-react';
import { categories, tools, workflowLinks } from '../../data/ai-tool-universe';
import { BrainGraphVariant } from './BrainGraphVariant';
import { buildVisualizationData } from './visualization-data';

type LabVariant = 'brain' | 'vision' | 'galaxy';

interface VisualizationLabProps {
  onBack: () => void;
}

const variants: Array<{ id: LabVariant; label: string }> = [
  { id: 'brain', label: 'AI Brain' },
  { id: 'vision', label: 'Vision Space' },
  { id: 'galaxy', label: 'AI Galaxy' },
];

export function VisualizationLab({ onBack }: VisualizationLabProps) {
  const data = useMemo(() => buildVisualizationData({ categories, tools, workflowLinks }), []);
  const [variant, setVariant] = useState<LabVariant>('brain');
  const [selectedId, setSelectedId] = useState('founder-os');
  const selected = data.nodeById.get(selectedId) ?? data.nodes[0];

  return (
    <main className="min-h-[100dvh] bg-[#03040a] text-white">
      <header className="flex flex-wrap items-center justify-between gap-3 border-b border-white/10 px-4 py-3 lg:px-6">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onBack}
            className="inline-flex h-10 w-10 items-center justify-center rounded-full border border-white/15 bg-white/[0.06] text-white transition hover:bg-white/[0.12]"
            aria-label="Back to universe map"
          >
            <ArrowLeft size={18} />
          </button>
          <div>
            <p className="text-xs uppercase tracking-[0.22em] text-cyan-100/60">Visual Lab</p>
            <h1 className="text-xl font-semibold">AI map visualization variants</h1>
          </div>
        </div>

        <div className="flex rounded-full border border-white/10 bg-white/[0.05] p-1">
          {variants.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setVariant(item.id)}
              aria-pressed={variant === item.id}
              className={`rounded-full px-4 py-2 text-sm font-medium transition ${
                variant === item.id ? 'bg-white text-slate-950' : 'text-white/70 hover:text-white'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </header>

      <section className="grid min-h-[calc(100dvh-74px)] grid-cols-1 lg:grid-cols-[1fr_320px]">
        <div className="relative min-h-[620px] overflow-hidden">
          {variant === 'brain' ? (
            <BrainGraphVariant data={data} selectedId={selected.id} onSelect={setSelectedId} />
          ) : (
            <PendingVariant variant={variant} />
          )}
        </div>
        <aside className="border-t border-white/10 bg-black/30 p-5 lg:border-l lg:border-t-0">
          <div className="rounded-lg border border-white/10 bg-white/[0.05] p-4">
            <p className="text-xs uppercase tracking-[0.18em] text-white/45">Selected</p>
            <h2 className="mt-2 text-lg font-semibold">{selected.label}</h2>
            <p className="mt-2 text-sm leading-6 text-white/62">{selected.summary}</p>
            <div className="mt-4 flex flex-wrap gap-2">
              <span className="rounded-full bg-white/[0.08] px-3 py-1 text-xs text-white/70">
                {selected.categoryName}
              </span>
              <span className="rounded-full bg-white/[0.08] px-3 py-1 text-xs text-white/70">{selected.stage}</span>
            </div>
          </div>

          <div className="mt-5 space-y-3">
            <ComparisonNote
              icon={<Brain size={16} />}
              label="Relationship clarity"
              value={variant === 'brain' ? 'High' : 'Medium'}
            />
            <ComparisonNote
              icon={<Sparkles size={16} />}
              label="Premium feel"
              value={variant === 'vision' ? 'High' : 'Medium'}
            />
            <ComparisonNote icon={<Orbit size={16} />} label="Scale feeling" value={variant === 'galaxy' ? 'High' : 'Medium'} />
          </div>
        </aside>
      </section>
    </main>
  );
}

function PendingVariant({ variant }: { variant: LabVariant }) {
  return (
    <div className="flex h-full min-h-[620px] items-center justify-center bg-[radial-gradient(circle_at_50%_45%,rgba(34,211,238,0.12),transparent_42%),#03040a]">
      <p className="rounded-full border border-white/10 bg-white/[0.05] px-4 py-2 text-sm text-white/65">
        {variant} variant mounts in the next tasks
      </p>
    </div>
  );
}

function ComparisonNote({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-white/10 bg-white/[0.04] px-3 py-3 text-sm">
      <span className="flex items-center gap-2 text-white/62">
        {icon}
        {label}
      </span>
      <span className="font-semibold text-white">{value}</span>
    </div>
  );
}
