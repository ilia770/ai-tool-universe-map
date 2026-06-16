import type { AITool } from '../data/ai-tool-universe';
import { searchableText, knowledgeFor } from './knowledge';

/* ------------------------------------------------------------------ *
 * Hyperbrain query engine
 *
 * On-device retrieval over the tool knowledge: a natural-language ask
 * like "find me the service to quickly build a database" is tokenised,
 * mapped to category/stage intent, scored against every tool's
 * searchable text, and answered with the best matches. No backend — the
 * "brain" is the structured knowledge + this ranker, so it's instant.
 * ------------------------------------------------------------------ */

const STOPWORDS = new Set([
  'a', 'an', 'the', 'to', 'for', 'me', 'my', 'i', 'we', 'find', 'show', 'get',
  'need', 'want', 'which', 'what', 'that', 'can', 'with', 'and', 'or', 'of',
  'is', 'are', 'how', 'do', 'use', 'using', 'best', 'good', 'service',
  'services', 'tool', 'tools', 'app', 'apps', 'some', 'any', 'quickly', 'fast',
]);

// Word → category-id hints, so intent words steer ranking.
const CATEGORY_HINTS: Record<string, string> = {
  code: 'coding', coding: 'coding', dev: 'coding', developer: 'coding', agent: 'coding',
  app: 'coding', build: 'coding', programming: 'coding', ide: 'coding',
  design: 'design', ui: 'design', ux: 'design', figma: 'design', logo: 'design', brand: 'design',
  research: 'research', search: 'research', data: 'research', knowledge: 'research', answer: 'research',
  image: 'media', video: 'media', audio: 'media', music: 'media', media: 'media', art: 'media',
  social: 'distribution', marketing: 'distribution', content: 'distribution', post: 'distribution',
  database: 'infrastructure', db: 'infrastructure', backend: 'infrastructure', deploy: 'infrastructure',
  host: 'infrastructure', infra: 'infrastructure', server: 'infrastructure', api: 'infrastructure',
  skill: 'knowledge', skills: 'knowledge', learn: 'knowledge', prompt: 'knowledge',
};

export interface QueryResult {
  matches: AITool[];
  answer: string;
}

function tokens(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 1 && !STOPWORDS.has(w));
}

/** Rank tools for a natural-language query and build a short answer. */
export function runQuery(text: string, tools: AITool[]): QueryResult {
  const qTokens = tokens(text);
  if (qTokens.length === 0) return { matches: [], answer: '' };

  const wantedCategories = new Set(
    qTokens.map((t) => CATEGORY_HINTS[t]).filter((c): c is string => Boolean(c)),
  );

  const scored = tools
    .map((tool) => {
      const hay = searchableText(tool);
      let score = 0;
      for (const t of qTokens) {
        if (tool.name.toLowerCase().includes(t)) score += 5;
        else if (hay.includes(t)) score += 2;
      }
      if (wantedCategories.has(tool.category)) score += 3;
      return { tool, score };
    })
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score);

  const matches = scored.slice(0, 5).map((s) => s.tool);

  if (matches.length === 0) {
    return { matches: [], answer: `No tool in the map matches that yet. Try the + button to add one — the classifier will place it.` };
  }

  const top = matches[0];
  const k = knowledgeFor(top.id);
  const why = k?.killerFeatures.length
    ? ` — ${k.killerFeatures[0]}`
    : k?.whatFor
      ? ` — ${k.whatFor}`
      : top.summary
        ? ` — ${top.summary}`
        : '';
  const others = matches.slice(1, 3).map((m) => m.name);
  const tail = others.length ? ` Also worth a look: ${others.join(', ')}.` : '';
  return {
    matches,
    answer: `${top.name}${why}.${tail}`,
  };
}
