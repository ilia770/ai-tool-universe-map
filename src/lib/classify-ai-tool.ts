import type { ToolCategoryId, WorkflowStageId } from '../data/ai-tool-universe';

interface ClassifierRule {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  keywords: string[];
  anchors: string[];
}

interface DomainRule {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  anchors: string[];
  keyword: string;
}

export interface ClassificationResult {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  confidence: number;
  matchedKeywords: string[];
  relationIds: string[];
  reason: string;
}

const classifierRules: ClassifierRule[] = [
  {
    category: 'coding',
    stage: 'execution',
    keywords: [
      'agent',
      'app builder',
      'bolt',
      'claude',
      'code',
      'coder',
      'codex',
      'cursor',
      'dev',
      'github',
      'github copilot',
      'ide',
      'lovable',
      'replit',
      'repo',
      'stackblitz',
      'v0',
      'vscode',
      'windsurf',
      'zed',
    ],
    anchors: ['founder-os', 'codex', 'claude-code', 'cursor'],
  },
  {
    category: 'design',
    stage: 'planning',
    keywords: [
      'canva',
      'design',
      'dessn',
      'figma',
      'framer',
      'interface',
      'layout',
      'mockup',
      'paper',
      'product',
      'prototype',
      'uizard',
      'ui',
      'ux',
      'wireframe',
    ],
    anchors: ['founder-os', 'figma', 'framer', 'paper-design'],
  },
  {
    category: 'research',
    stage: 'research',
    keywords: [
      'api',
      'browse',
      'crawl',
      'data',
      'dataset',
      'deer-flow',
      'exa',
      'firecrawl',
      'intake',
      'jina',
      'kimi',
      'notebooklm',
      'perplexity',
      'read',
      'readwise',
      'research',
      'scrape',
      'search',
      'source',
      'supadata',
      'tavily',
      'web',
      'webbridge',
    ],
    anchors: ['founder-os', 'supadata', 'readwise', 'api-mega-list'],
  },
  {
    category: 'media',
    stage: 'execution',
    keywords: [
      'adobe',
      'affinity',
      'audio',
      'avatar',
      'blender',
      'creative',
      'elevenlabs',
      'genmedia',
      'heygen',
      'higgsfield',
      'image',
      'kling',
      'luma',
      'media',
      'midjourney',
      'motion',
      'pika',
      'remotion',
      'runway',
      'sora',
      'stable diffusion',
      'video',
      'voice',
    ],
    anchors: ['founder-os', 'remotion', 'hyperframes', 'genmedia'],
  },
  {
    category: 'distribution',
    stage: 'approval',
    keywords: [
      'beehiiv',
      'buffer',
      'campaign',
      'distribution',
      'hootsuite',
      'hubspot',
      'launch',
      'linkedin',
      'mailchimp',
      'newsletter',
      'omnisocials',
      'post',
      'publish',
      'social',
      'sproutsocial',
      'twitter',
      'x.com',
    ],
    anchors: ['founder-os', 'buffer', 'omnisocials', 'approval-gate'],
  },
  {
    category: 'infrastructure',
    stage: 'execution',
    keywords: [
      'auth',
      'aws',
      'cloud',
      'cloudflare',
      'database',
      'db',
      'deploy',
      'docker',
      'edge',
      'firebase',
      'fly.io',
      'mcp',
      'netlify',
      'postgres',
      'railway',
      'render',
      'runtime',
      'server',
      'storage',
      'supabase',
      'tauri',
      'terminal',
      'vercel',
      'warp',
      'worker',
      'xterm',
    ],
    anchors: ['founder-os', 'vercel', 'docker', 'warp'],
  },
  {
    category: 'knowledge',
    stage: 'review',
    keywords: [
      'docs',
      'knowledge',
      'knowledge base',
      'logseq',
      'memory',
      'mem',
      'note',
      'notion',
      'obsidian',
      'prompt',
      'skill',
      'skills',
      'tana',
      'wiki',
      'workflow pack',
    ],
    anchors: ['founder-os', 'agent-skills', 'designer-skills', 'mattpocock-skills'],
  },
];

const domainRules: Record<string, DomainRule> = {
  'base44.com': {
    category: 'coding',
    stage: 'execution',
    anchors: ['founder-os', 'lovable', 'vercel'],
    keyword: 'base44.com',
  },
  'bolt.new': {
    category: 'coding',
    stage: 'execution',
    anchors: ['founder-os', 'lovable', 'vercel'],
    keyword: 'bolt.new',
  },
  'canva.com': {
    category: 'design',
    stage: 'planning',
    anchors: ['founder-os', 'figma', 'framer'],
    keyword: 'canva.com',
  },
  'elevenlabs.io': {
    category: 'media',
    stage: 'execution',
    anchors: ['founder-os', 'remotion', 'hyperframes'],
    keyword: 'elevenlabs.io',
  },
  'exa.ai': {
    category: 'research',
    stage: 'research',
    anchors: ['founder-os', 'supadata', 'api-mega-list'],
    keyword: 'exa.ai',
  },
  'firecrawl.dev': {
    category: 'research',
    stage: 'research',
    anchors: ['founder-os', 'supadata', 'api-mega-list'],
    keyword: 'firecrawl.dev',
  },
  'netlify.com': {
    category: 'infrastructure',
    stage: 'execution',
    anchors: ['founder-os', 'vercel', 'docker'],
    keyword: 'netlify.com',
  },
  'notion.so': {
    category: 'knowledge',
    stage: 'review',
    anchors: ['founder-os', 'agent-skills', 'obsidian-skills'],
    keyword: 'notion.so',
  },
  'perplexity.ai': {
    category: 'research',
    stage: 'research',
    anchors: ['founder-os', 'supadata', 'readwise'],
    keyword: 'perplexity.ai',
  },
  'runwayml.com': {
    category: 'media',
    stage: 'execution',
    anchors: ['founder-os', 'remotion', 'genmedia'],
    keyword: 'runwayml.com',
  },
  'render.com': {
    category: 'infrastructure',
    stage: 'execution',
    anchors: ['founder-os', 'vercel', 'docker'],
    keyword: 'render.com',
  },
  'supabase.com': {
    category: 'infrastructure',
    stage: 'execution',
    anchors: ['founder-os', 'vercel', 'docker'],
    keyword: 'supabase.com',
  },
};

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

export const makeSlug = (value: string) =>
  value.trim().toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/^www\./, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 42);

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

  const ranked = classifierRules
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

    return domainRules[hostname];
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
