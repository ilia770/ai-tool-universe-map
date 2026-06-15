import { useToolStore } from './useToolStore';
import { categoryById } from '../data/ai-tool-universe';
import { knowledgeFor } from './knowledge';
import { useInAppBrowser } from '../components/useInAppBrowser';

function initials(name: string): string {
  return name.split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('');
}

interface Props {
  toolId: string | null;
  onClose: () => void;
  onSelect: (id: string) => void;
}

/**
 * The rich "brand window": everything the hyperbrain knows about a tool —
 * killer features, what it's for, advantages, weaknesses, who uses it, and
 * pricing — plus connections and an in-app Open. Liquid glass, ≤ a third of
 * the screen on desktop, full-width sheet on phones.
 */
export function ToolDetail({ toolId, onClose, onSelect }: Props) {
  const { toolById, iconUrlFor } = useToolStore();
  const { openInApp } = useInAppBrowser();

  if (!toolId) return null;
  const tool = toolById.get(toolId);
  if (!tool) return null;

  const cat = categoryById.get(tool.category);
  const k = knowledgeFor(tool.id);
  const icon = iconUrlFor(tool, 96);
  const connections = tool.relationIds.map((id) => toolById.get(id)).filter((t): t is NonNullable<typeof t> => Boolean(t));

  return (
    <div className="pointer-events-auto absolute right-4 top-20 bottom-4 z-20 flex w-[min(380px,calc(100vw-2rem))] flex-col overflow-hidden rounded-3xl border border-white/10 bg-white/[0.07] shadow-[0_24px_80px_rgba(0,0,0,0.55)] backdrop-blur-2xl">
      <div className="flex items-center gap-3 border-b border-white/10 p-4">
        <div
          className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-2xl text-sm font-semibold text-white"
          style={{ background: cat?.color ?? '#3a3f55' }}
        >
          {icon ? <img src={icon} alt="" className="h-full w-full object-cover" /> : initials(tool.name)}
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-base font-semibold text-white">{tool.name}</div>
          <div className="mt-0.5 flex items-center gap-1.5 text-[11px] text-white/55">
            <span className="rounded-full px-2 py-0.5 font-medium" style={{ background: `${cat?.color ?? '#666'}33`, color: cat?.color ?? '#fff' }}>{cat?.name ?? tool.category}</span>
            <span className="capitalize">· {tool.stage}</span>
          </div>
        </div>
        <button type="button" onClick={onClose} className="rounded-lg px-2 py-1 text-white/50 transition hover:bg-white/10 hover:text-white active:scale-90">✕</button>
      </div>

      <div className="flex-1 space-y-4 overflow-y-auto p-4 text-sm">
        <Section title="What it does">
          <p className="text-white/75">{k?.whatFor || tool.summary}</p>
        </Section>

        {k?.enriched && k.killerFeatures.length > 0 ? (
          <Section title="Killer features">
            <ul className="space-y-1">
              {k.killerFeatures.map((f) => (
                <li key={f} className="flex gap-2 text-white/75"><span className="text-white/40">▸</span>{f}</li>
              ))}
            </ul>
          </Section>
        ) : null}

        {k?.enriched && (k.advantages.length > 0 || k.weaknesses.length > 0) ? (
          <div className="grid grid-cols-2 gap-3">
            {k.advantages.length > 0 ? (
              <Section title="Strengths"><ul className="space-y-1">{k.advantages.map((a) => <li key={a} className="text-emerald-300/80">+ {a}</li>)}</ul></Section>
            ) : null}
            {k.weaknesses.length > 0 ? (
              <Section title="Watch-outs"><ul className="space-y-1">{k.weaknesses.map((w) => <li key={w} className="text-amber-300/75">– {w}</li>)}</ul></Section>
            ) : null}
          </div>
        ) : null}

        {k?.enriched && k.whoUses ? (
          <Section title="Who uses it"><p className="text-white/75">{k.whoUses}</p></Section>
        ) : null}

        <Section title="Pricing">
          <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-3">
            <div className="text-xs font-medium uppercase tracking-wide text-white/45">{k?.pricing.model ?? 'unknown'}</div>
            <div className="mt-0.5 text-white/80">{k?.pricing.summary ?? 'Pricing not yet researched.'}</div>
          </div>
        </Section>

        {connections.length > 0 ? (
          <Section title={`Connected to · ${connections.length}`}>
            <div className="flex flex-wrap gap-1.5">
              {connections.map((c) => (
                <button
                  key={c.id}
                  type="button"
                  onClick={() => onSelect(c.id)}
                  className="rounded-lg border border-white/10 bg-white/[0.05] px-2 py-1 text-xs text-white/75 transition hover:bg-white/12 hover:text-white active:scale-95"
                >
                  {c.name}
                </button>
              ))}
            </div>
          </Section>
        ) : null}
      </div>

      {tool.url ? (
        <div className="border-t border-white/10 p-3">
          <button
            type="button"
            onClick={() => openInApp(tool.url as string, tool.name)}
            className="w-full rounded-2xl bg-white/90 py-2.5 text-sm font-semibold text-black transition hover:bg-white active:scale-[0.98]"
          >
            Open {tool.name} ↗
          </button>
        </div>
      ) : null}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="mb-1.5 text-[10px] font-medium uppercase tracking-wider text-white/35">{title}</div>
      {children}
    </div>
  );
}
