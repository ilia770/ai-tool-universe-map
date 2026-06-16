import type { ToolCategoryId, WorkflowStageId } from '../data/ai-tool-universe';
import {
  CATEGORY_RULES,
  DOMAIN_RULES,
  type DomainRule,
} from '../data/classifier-taxonomy';

export interface ClassificationResult {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  confidence: number;
  matchedKeywords: string[];
  relationIds: string[];
  reason: string;
}

const fallbackResult: ClassificationResult = {
  category: 'core',
  stage: 'planning',
  confidence: 0.34,
  matchedKeywords: [],
  relationIds: ['founder-os'],
  reason: 'No strong keyword match yet, so this starts near the AI Operating Core for manual review.',
};

const displayNameOverrides: Record<string, string> = {
  'api-mega-list': 'API Mega List',
  bolt: 'Bolt',
  buffer: 'Buffer',
  claude: 'Claude',
  codex: 'Codex',
  coderabbit: 'CodeRabbit',
  cursor: 'Cursor',
  dessn: 'Dessn',
  docker: 'Docker',
  figma: 'Figma',
  framer: 'Framer',
  genmedia: 'GenMedia',
  heygen: 'HeyGen',
  higgsfield: 'Higgsfield',
  kimi: 'Kimi',
  lovable: 'Lovable',
  omnisocials: 'OmniSocials',
  readwise: 'Readwise',
  remotion: 'Remotion',
  supadata: 'Supadata',
  tauri: 'Tauri',
  vercel: 'Vercel',
  warp: 'Warp',
  wisprflow: 'Wispr Flow',
  zed: 'Zed',
};

function stableHash(value: string): string {
  let h = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(36);
}

export const makeSlug = (value: string) => {
  const slug = value.trim().toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/^www\./, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 42);
  return slug || `tool-${stableHash(value.trim() || 'tool')}`;
};

export const getDisplayName = (value: string): string => {
  const trimmed = value.trim();
  try {
    const url = new URL(trimmed.startsWith('http') ? trimmed : `https://${trimmed}`);
    const hostName = url.hostname.replace(/^www\./, '').split('.')[0] || trimmed;
    return displayNameOverrides[hostName.toLowerCase()] ?? titleCase(hostName.replace(/[-_]/g, ' '));
  } catch {
    const normalized = trimmed.toLowerCase();
    return displayNameOverrides[normalized] ?? titleCase(trimmed);
  }
};

export const classifyToolDetailed = (value: string): ClassificationResult => {
  const normalized = getSearchableInput(value);
  const domainMatch = getDomainRule(value);
  if (domainMatch) {
    return {
      category: domainMatch.category,
      stage: domainMatch.stage,
      confidence: 0.88,
      matchedKeywords: [domainMatch.keyword],
      relationIds: domainMatch.anchors,
      reason: `Matched "${domainMatch.keyword}" and placed it into the closest workflow orbit.`,
    };
  }

  const ranked = CATEGORY_RULES
    .map((rule) => {
      const matchedKeywords = rule.keywords.filter((keyword) => normalized.includes(keyword));
      return {
        rule,
        matchedKeywords,
        score: matchedKeywords.reduce((total, keyword) => total + keyword.length / 10 + 1, 0),
      };
    })
    .sort((a, b) => b.score - a.score)[0];

  if (!ranked || ranked.score === 0) return fallbackResult;

  const confidence = Math.min(0.94, 0.46 + ranked.score * 0.11);
  const signals = ranked.matchedKeywords.slice(0, 4);

  return {
    category: ranked.rule.category,
    stage: ranked.rule.stage,
    confidence: Number(confidence.toFixed(2)),
    matchedKeywords: signals,
    relationIds: ranked.rule.anchors,
    reason: `Matched ${signals.map((signal) => `"${signal}"`).join(', ')} and placed it into the closest workflow orbit.`,
  };
};

export const classifyTool = (value: string): ToolCategoryId => classifyToolDetailed(value).category;

const getSearchableInput = (value: string) => {
  const trimmed = value.trim();
  try {
    const url = new URL(trimmed.startsWith('http') ? trimmed : `https://${trimmed}`);
    return [
      trimmed,
      url.hostname.replace(/^www\./, ''),
      url.hostname.replace(/^www\./, '').replace(/[.-]/g, ' '),
      url.pathname.replace(/[/-]/g, ' '),
    ].join(' ').toLowerCase();
  } catch {
    return trimmed.toLowerCase();
  }
};

const getDomainRule = (value: string) => {
  const trimmed = value.trim();
  try {
    const url = new URL(trimmed.startsWith('http') ? trimmed : `https://${trimmed}`);
    const hostname = url.hostname.replace(/^www\./, '').toLowerCase();
    if (hostname === 'github.com' && /\bskills?\b/.test(url.pathname.replace(/[/-]/g, ' ').toLowerCase())) {
      return {
        category: 'knowledge',
        stage: 'planning',
        anchors: ['founder-os', 'agent-skills', 'mattpocock-skills'],
        keyword: 'skills',
      } satisfies DomainRule;
    }

    return DOMAIN_RULES[hostname];
  } catch {
    return undefined;
  }
};

const titleCase = (value: string) =>
  value
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
