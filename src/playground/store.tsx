import {
  useCallback,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { tools as seedTools, type AITool } from '../data/ai-tool-universe';
import { classifyToolDetailed, makeSlug, getDisplayName } from '../lib/classify-ai-tool';
import { getToolLogoUrl } from '../lib/tool-logos';
import {
  ToolStoreContext,
  type AddToolInput,
  type AddedTool,
  type ToolStore,
} from './toolStoreContext';

/* ------------------------------------------------------------------ *
 * Playground tool store
 *
 * One shared, reactive tool list for every visualization variant:
 * the 49 seed tools plus anything the user adds via the + button.
 * `addTool` runs the same rule-based classifier the production intake
 * uses (classifyToolDetailed) so a pasted name/URL is auto-placed into
 * the right category + workflow stage — the variants then lay it out
 * in its cluster automatically. Brand icons come from logo.dev
 * (getToolLogoUrl); a pasted/uploaded image overrides the icon.
 * ------------------------------------------------------------------ */

// Deterministic angle so a new tool gets a stable slot in its category.
function angleForSlug(slug: string): number {
  let h = 2166136261;
  for (let i = 0; i < slug.length; i += 1) {
    h ^= slug.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return ((h >>> 0) % 360);
}

function domainFromText(text: string): string | undefined {
  const trimmed = text.trim();
  const match = trimmed.match(/([a-z0-9-]+\.[a-z]{2,}(?:\.[a-z]{2,})?)/i);
  return match ? match[1].toLowerCase() : undefined;
}

function sameToolIdentity(tool: AITool, slug: string, name: string, domain?: string): boolean {
  return tool.id === slug
    || tool.name.toLowerCase() === name.toLowerCase()
    || (Boolean(domain) && (tool.logoDomain === domain || Boolean(tool.url?.includes(`//${domain}`))));
}

export function ToolStoreProvider({ children }: { children: ReactNode }) {
  const [added, setAdded] = useState<AddedTool[]>([]);
  const [icons, setIcons] = useState<Map<string, string>>(() => new Map());

  const tools = useMemo<AddedTool[]>(() => [...seedTools, ...added], [added]);
  const toolById = useMemo(() => {
    const map = new Map<string, AddedTool>();
    tools.forEach((t) => map.set(t.id, t));
    return map;
  }, [tools]);

  const addTool = useCallback(
    (input: AddToolInput): AddedTool => {
      const name = getDisplayName(input.text);
      const slug = makeSlug(input.text);
      const domain = domainFromText(input.text);
      const existing = [...seedTools, ...added].find((t) => sameToolIdentity(t, slug, name, domain));
      if (existing) return existing;

      const result = classifyToolDetailed(input.text);
      const tool: AddedTool = {
        id: slug,
        name,
        category: result.category,
        summary: result.reason,
        stage: result.stage,
        orbit: 2,
        angle: angleForSlug(slug),
        url: domain ? `https://${domain}` : undefined,
        logoDomain: domain,
        relationIds: result.relationIds.filter((id) => id !== slug),
        userAdded: true,
      };

      setAdded((prev) => (prev.some((t) => sameToolIdentity(t, slug, name, domain)) ? prev : [...prev, tool]));
      if (input.imageDataUrl) {
        setIcons((prev) => {
          const next = new Map(prev);
          next.set(slug, input.imageDataUrl as string);
          return next;
        });
      }
      return tool;
    },
    [added],
  );

  const iconUrlFor = useCallback(
    (tool: AITool, size = 96): string | undefined => icons.get(tool.id) ?? getToolLogoUrl(tool, size) ?? undefined,
    [icons],
  );

  const value = useMemo<ToolStore>(
    () => ({ tools, toolById, addTool, iconUrlFor }),
    [tools, toolById, addTool, iconUrlFor],
  );

  return <ToolStoreContext.Provider value={value}>{children}</ToolStoreContext.Provider>;
}
