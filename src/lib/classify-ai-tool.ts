import type { ToolCategoryId, WorkflowStageId } from '../data/ai-tool-universe';

interface ClassifierRule {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  keywords: string[];
  anchors: string[];
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
      'ide',
      'repo',
      'vscode',
      'zed',
    ],
    anchors: ['founder-os', 'codex', 'claude-code', 'cursor'],
  },
  {
    category: 'design',
    stage: 'planning',
    keywords: ['design', 'dessn', 'figma', 'framer', 'interface', 'layout', 'mockup', 'paper', 'product', 'prototype', 'ui', 'ux'],
    anchors: ['founder-os', 'figma', 'framer', 'paper-design'],
  },
  {
    category: 'research',
    stage: 'research',
    keywords: ['api', 'browse', 'crawl', 'data', 'deer-flow', 'intake', 'kimi', 'read', 'readwise', 'research', 'scrape', 'source', 'supadata', 'web'],
    anchors: ['founder-os', 'supadata', 'readwise', 'api-mega-list'],
  },
  {
    category: 'media',
    stage: 'execution',
    keywords: ['adobe', 'affinity', 'blender', 'creative', 'genmedia', 'heygen', 'higgsfield', 'image', 'media', 'motion', 'remotion', 'render', 'video'],
    anchors: ['founder-os', 'remotion', 'hyperframes', 'genmedia'],
  },
  {
    category: 'distribution',
    stage: 'approval',
    keywords: ['buffer', 'campaign', 'distribution', 'launch', 'linkedin', 'omnisocials', 'post', 'publish', 'social', 'twitter', 'x.com'],
    anchors: ['founder-os', 'buffer', 'omnisocials', 'approval-gate'],
  },
  {
    category: 'infrastructure',
    stage: 'execution',
    keywords: ['cloud', 'deploy', 'docker', 'runtime', 'server', 'tauri', 'terminal', 'vercel', 'warp', 'xterm'],
    anchors: ['founder-os', 'vercel', 'docker', 'warp'],
  },
  {
    category: 'knowledge',
    stage: 'review',
    keywords: ['knowledge', 'memory', 'note', 'obsidian', 'prompt', 'skill', 'skills', 'workflow pack'],
    anchors: ['founder-os', 'agent-skills', 'designer-skills', 'mattpocock-skills'],
  },
];

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
  const normalized = value.toLowerCase();
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

const titleCase = (value: string) =>
  value
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
