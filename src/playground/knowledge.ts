import { toolById, type AITool } from '../data/ai-tool-universe';
import { ENRICHED_DATA } from './knowledge.data';

/* ------------------------------------------------------------------ *
 * Hyperbrain knowledge layer
 *
 * Rich, structured facts per tool — killer features, what it's for,
 * advantages, weaknesses, who uses it, and pricing — so the app can
 * orient fast and answer "find me X" queries.
 *
 * The deep, web-researched entries are filled by the enrichment agents
 * (one record per tool id in ENRICHED). Until a tool is enriched,
 * `knowledgeFor` derives a sensible interim record from the seed data
 * (summary + category + stage) so the chat and detail panel always have
 * something useful to show.
 * ------------------------------------------------------------------ */

export type PricingModel =
  | 'free'
  | 'open-source'
  | 'freemium'
  | 'subscription'
  | 'usage-based'
  | 'enterprise'
  | 'mixed'
  | 'unknown';

export interface ToolPricing {
  model: PricingModel;
  summary: string;
}

export interface ToolKnowledge {
  killerFeatures: string[];
  whatFor: string;
  advantages: string[];
  weaknesses: string[];
  whoUses: string;
  pricing: ToolPricing;
  /** True when this came from deep research, false when interim-derived. */
  enriched: boolean;
}

/**
 * Web-researched knowledge, keyed by tool id. Populated by the
 * enrichment agents (P1). Empty entries fall back to interim derivation.
 */
export const ENRICHED: Record<string, Omit<ToolKnowledge, 'enriched'>> = ENRICHED_DATA;

function interim(tool: AITool): ToolKnowledge {
  return {
    killerFeatures: [],
    whatFor: tool.summary,
    advantages: [],
    weaknesses: [],
    whoUses: '',
    pricing: { model: 'unknown', summary: 'Pricing not yet researched.' },
    enriched: false,
  };
}

/** Best available knowledge for a tool id — enriched if present, else interim. */
export function knowledgeFor(id: string): ToolKnowledge | null {
  const tool = toolById.get(id);
  if (!tool) return null;
  const rich = ENRICHED[id];
  if (rich) return { ...rich, enriched: true };
  return interim(tool);
}

/** A flat searchable blob of everything we know about a tool. */
export function searchableText(tool: AITool): string {
  const k = ENRICHED[tool.id];
  const parts = [tool.name, tool.category, tool.stage, tool.summary];
  if (k) {
    parts.push(k.whatFor, k.whoUses, k.pricing.summary, ...k.killerFeatures, ...k.advantages);
  }
  return parts.join(' ').toLowerCase();
}
