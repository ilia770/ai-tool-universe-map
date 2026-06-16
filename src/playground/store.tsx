import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { tools as seedTools, categories as seedCategories, type AITool, type ToolCategory } from '../data/ai-tool-universe';
import { classifyToolDetailed, makeSlug, getDisplayName } from '../lib/classify-ai-tool';
import { classifyIntake } from '../lib/intake';
import { makeDynamicCategory } from '../lib/dynamic-category';
import { getToolLogoUrl } from '../lib/tool-logos';
import { inferRelationships } from '../lib/relationship-intelligence';
import type { InferredEdge } from '../lib/relationship-intelligence.types';
import { knowledgeFor } from './knowledge';
import {
  ToolStoreContext,
  type AddToolInput,
  type AddedTool,
  type Language,
  type PlaygroundSettings,
  type ToolStore,
} from './toolStoreContext';

const STORE_KEY = 'playground.store.v1';
/** Same key FindBar uses, so a reset clears the chat thread too. */
const FINDBAR_KEY = 'playground.findbar.turns.v1';
const MAX_STORE_BYTES = 400_000;

export const DEFAULT_SETTINGS: PlaygroundSettings = { language: 'en', variantId: 'A' };

export interface PersistedState {
  added: AddedTool[];
  icons: Record<string, string>;
  settings: PlaygroundSettings;
}

function isLanguage(v: unknown): v is Language {
  return v === 'en' || v === 'ru';
}

export function loadPersisted(): PersistedState {
  const empty: PersistedState = { added: [], icons: {}, settings: DEFAULT_SETTINGS };
  if (typeof localStorage === 'undefined') return empty;
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw || raw.length > MAX_STORE_BYTES) return empty;
    const parsed = JSON.parse(raw) as Partial<PersistedState> | null;
    if (!parsed || typeof parsed !== 'object') return empty;
    const added = Array.isArray(parsed.added)
      ? (parsed.added.filter((t) => t && typeof (t as AddedTool).id === 'string') as AddedTool[])
      : [];
    const icons =
      parsed.icons && typeof parsed.icons === 'object'
        ? (parsed.icons as Record<string, string>)
        : {};
    const s = (parsed.settings ?? {}) as Partial<PlaygroundSettings>;
    const settings: PlaygroundSettings = {
      language: isLanguage(s.language) ? s.language : DEFAULT_SETTINGS.language,
      variantId: typeof s.variantId === 'string' ? s.variantId : DEFAULT_SETTINGS.variantId,
    };
    return { added, icons, settings };
  } catch {
    return empty;
  }
}

export function persist(state: PersistedState): void {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state));
  } catch {
    /* storage full / unavailable — stay in-memory */
  }
}

export function serializeExport(added: AddedTool[], settings: PlaygroundSettings): string {
  return JSON.stringify(
    { exportedAt: new Date().toISOString(), settings, tools: added },
    null,
    2,
  );
}

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
  const [boot] = useState(loadPersisted);
  const [added, setAdded] = useState<AddedTool[]>(boot.added);
  const [dynamicCategories, setDynamicCategories] = useState<ToolCategory[]>([]);
  const [icons, setIcons] = useState<Map<string, string>>(
    () => new Map(Object.entries(boot.icons)),
  );
  const [settings, setSettingsState] = useState<PlaygroundSettings>(boot.settings);

  // Persist added tools, icon overrides, and settings on every change.
  useEffect(() => {
    persist({ added, icons: Object.fromEntries(icons), settings });
  }, [added, icons, settings]);

  const tools = useMemo<AddedTool[]>(() => [...seedTools, ...added], [added]);
  const allCategories = useMemo<ToolCategory[]>(
    () => [...seedCategories, ...dynamicCategories],
    [dynamicCategories],
  );
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

      // Resolve the intake outcome (caller may pass a pre-resolved one from a
      // URL fallback / confirmation flow). A newCategory outcome mints a fresh
      // branch instead of dumping the tool into `core`.
      const outcome = input.outcome
        ?? classifyIntake(input.text, input.text === domain ? {} : { url: domain ? `https://${domain}` : undefined });
      const result = outcome.kind === 'classified'
        || outcome.kind === 'ambiguous'
        || outcome.kind === 'newCategory'
        ? outcome.result
        : classifyToolDetailed(input.text);

      let category = result.category;
      if (outcome.kind === 'newCategory') {
        const dynamic = makeDynamicCategory(outcome.suggestedName, allCategories);
        category = dynamic.id;
        setDynamicCategories((prev) => (prev.some((c) => c.id === dynamic.id) ? prev : [...prev, dynamic]));
      }

      const tool: AITool = {
        id: slug,
        name,
        category,
        summary: result.reason,
        stage: result.stage,
        orbit: 2,
        angle: angleForSlug(slug),
        url: domain ? `https://${domain}` : undefined,
        logoDomain: domain,
        relationIds: result.relationIds.filter((id) => id !== slug),
      };

      // Pinpoint, explained relationship edges (P9): additive to the
      // classifier's hub anchors above. Inferred against the current
      // universe + P0 knowledge; derived at intake time, never persisted.
      const inferredEdges = inferRelationships(tool, [...seedTools, ...added], knowledgeFor);
      const stored: AddedTool = { ...tool, userAdded: true, inferredEdges };

      setAdded((prev) => (prev.some((t) => sameToolIdentity(t, slug, name, domain)) ? prev : [...prev, stored]));
      if (input.imageDataUrl) {
        setIcons((prev) => {
          const next = new Map(prev);
          next.set(slug, input.imageDataUrl as string);
          return next;
        });
      }
      return stored;
    },
    [added, allCategories],
  );

  const removeTool = useCallback((id: string) => {
    setAdded((prev) => prev.filter((t) => t.id !== id));
    setIcons((prev) => {
      if (!prev.has(id)) return prev;
      const next = new Map(prev);
      next.delete(id);
      return next;
    });
  }, []);

  const setSettings = useCallback((patch: Partial<PlaygroundSettings>) => {
    setSettingsState((prev) => ({ ...prev, ...patch }));
  }, []);

  const resetData = useCallback(() => {
    setAdded([]);
    setIcons(new Map());
    setDynamicCategories([]);
    setSettingsState(DEFAULT_SETTINGS);
    if (typeof localStorage !== 'undefined') {
      try {
        localStorage.removeItem(FINDBAR_KEY);
      } catch {
        /* ignore */
      }
    }
  }, []);

  const exportData = useCallback(() => serializeExport(added, settings), [added, settings]);

  const edgesFor = useCallback(
    (id: string): InferredEdge[] => toolById.get(id)?.inferredEdges ?? [],
    [toolById],
  );

  const iconUrlFor = useCallback(
    (tool: AITool, size = 96): string | undefined => icons.get(tool.id) ?? getToolLogoUrl(tool, size) ?? undefined,
    [icons],
  );

  const value = useMemo<ToolStore>(
    () => ({
      tools,
      toolById,
      allCategories,
      dynamicCategories,
      addTool,
      removeTool,
      iconUrlFor,
      edgesFor,
      settings,
      setSettings,
      resetData,
      exportData,
    }),
    [
      tools,
      toolById,
      allCategories,
      dynamicCategories,
      addTool,
      removeTool,
      iconUrlFor,
      edgesFor,
      settings,
      setSettings,
      resetData,
      exportData,
    ],
  );

  return <ToolStoreContext.Provider value={value}>{children}</ToolStoreContext.Provider>;
}
