import type { ToolCategoryId, WorkflowStageId } from '../data/ai-tool-universe';

type RelationSuggestionSource = 'category-anchor' | 'direct-match' | 'fallback-review' | 'workflow-anchor';

interface RelationSuggestionSeed {
  id: string;
  label: string;
  reason: string;
  source: Exclude<RelationSuggestionSource, 'direct-match' | 'fallback-review'>;
}

interface ClassifierRule {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  keywords: string[];
  anchors: RelationSuggestionSeed[];
}

export interface RelationSuggestion {
  id: string;
  label: string;
  reason: string;
  confidence: number;
  source: RelationSuggestionSource;
}

export interface ClassificationResult {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  confidence: number;
  matchedKeywords: string[];
  relationIds: string[];
  relationSuggestions: RelationSuggestion[];
  reason: string;
}

const relationSeed = (
  id: string,
  label: string,
  reason: string,
  source: RelationSuggestionSeed['source'],
): RelationSuggestionSeed => ({ id, label, reason, source });

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
    anchors: [
      relationSeed('codex', 'Codex implementation agent', 'Closest execution partner for repository changes and verification.', 'category-anchor'),
      relationSeed('claude-code', 'Claude Code partner', 'Pairs well when the task needs broad codebase investigation before edits.', 'category-anchor'),
      relationSeed('cursor', 'Cursor IDE loop', 'Connects coding tools back to an AI-first editor workflow.', 'category-anchor'),
      relationSeed('founder-os', 'Founder OS execution loop', 'Every dev tool should remain connected to the central operating workflow.', 'workflow-anchor'),
    ],
  },
  {
    category: 'design',
    stage: 'planning',
    keywords: ['design', 'dessn', 'figma', 'framer', 'interface', 'layout', 'mockup', 'paper', 'product', 'prototype', 'ui', 'ux'],
    anchors: [
      relationSeed('figma', 'Figma design canvas', 'Primary design and product UI planning surface.', 'category-anchor'),
      relationSeed('paper-design', 'Paper.design polish layer', 'Useful when the new tool improves visual composition or product polish.', 'category-anchor'),
      relationSeed('framer', 'Framer launch surface', 'Connects product UI work to interactive launch experiences.', 'category-anchor'),
      relationSeed('founder-os', 'Founder OS planning loop', 'Design tools should tie back to the planning stage of the operating workflow.', 'workflow-anchor'),
    ],
  },
  {
    category: 'research',
    stage: 'research',
    keywords: ['api', 'browse', 'crawl', 'data', 'deer-flow', 'intake', 'kimi', 'read', 'readwise', 'research', 'scrape', 'source', 'supadata', 'web'],
    anchors: [
      relationSeed('supadata', 'Supadata intake layer', 'Best anchor for tools that ingest external sources, websites, APIs, or datasets.', 'category-anchor'),
      relationSeed('readwise', 'Readwise knowledge capture', 'Useful when the new tool helps capture reading, notes, or long-term knowledge.', 'category-anchor'),
      relationSeed('api-mega-list', 'API discovery source', 'Connects API and integration research to a catalog of source options.', 'category-anchor'),
      relationSeed('founder-os', 'Founder OS research loop', 'Research tools feed the first step of the operating workflow.', 'workflow-anchor'),
    ],
  },
  {
    category: 'media',
    stage: 'execution',
    keywords: ['adobe', 'affinity', 'blender', 'creative', 'genmedia', 'heygen', 'higgsfield', 'image', 'media', 'motion', 'remotion', 'render', 'video'],
    anchors: [
      relationSeed('remotion', 'Remotion programmable media', 'Best anchor for code-driven video and motion generation.', 'category-anchor'),
      relationSeed('hyperframes', 'Hyperframes video layer', 'Useful when the tool creates AI video or presenter-led assets.', 'category-anchor'),
      relationSeed('genmedia', 'Generative media pipeline', 'Connects creative generation tools into the broader media production flow.', 'category-anchor'),
      relationSeed('distribution-loop', 'Distribution loop', 'Media assets usually continue into launch and social distribution.', 'workflow-anchor'),
    ],
  },
  {
    category: 'distribution',
    stage: 'approval',
    keywords: ['buffer', 'campaign', 'distribution', 'launch', 'linkedin', 'omnisocials', 'post', 'publish', 'social', 'twitter', 'x.com'],
    anchors: [
      relationSeed('buffer', 'Buffer scheduler', 'Best anchor for social scheduling, publishing, and launch cadence.', 'category-anchor'),
      relationSeed('omnisocials', 'OmniSocials operations', 'Useful when the tool manages multi-channel social workflows.', 'category-anchor'),
      relationSeed('approval-gate', 'approval gate', 'Publishing tools should pass through human approval before launch.', 'workflow-anchor'),
      relationSeed('distribution-loop', 'Distribution loop', 'Connects the tool to the post-build launch amplification stage.', 'workflow-anchor'),
    ],
  },
  {
    category: 'infrastructure',
    stage: 'execution',
    keywords: ['cloud', 'deploy', 'docker', 'runtime', 'server', 'tauri', 'terminal', 'vercel', 'warp', 'xterm'],
    anchors: [
      relationSeed('vercel', 'Vercel deploy rail', 'Best anchor for deploy previews, production hosting, and web release flow.', 'category-anchor'),
      relationSeed('docker', 'Docker runtime', 'Useful when the tool needs reproducible containers or local runtime parity.', 'category-anchor'),
      relationSeed('warp', 'Warp terminal loop', 'Connects shell-heavy tools to an AI-native terminal workflow.', 'category-anchor'),
      relationSeed('terminal', 'terminal command surface', 'Infrastructure tools usually need command-line install and verification steps.', 'workflow-anchor'),
    ],
  },
  {
    category: 'knowledge',
    stage: 'review',
    keywords: ['knowledge', 'memory', 'note', 'obsidian', 'prompt', 'skill', 'skills', 'workflow pack'],
    anchors: [
      relationSeed('agent-skills', 'Agent Skills library', 'Best anchor for reusable agent capabilities and task packs.', 'category-anchor'),
      relationSeed('designer-skills', 'Designer Skills pack', 'Useful when the tool teaches agents design or product UI behavior.', 'category-anchor'),
      relationSeed('mattpocock-skills', 'Matt Pocock skills reference', 'Connects skill libraries to practical examples and patterns.', 'category-anchor'),
      relationSeed('founder-os', 'Founder OS review loop', 'Knowledge tools should improve repeatable review and decision quality.', 'workflow-anchor'),
    ],
  },
];

const fallbackRelationSuggestions: RelationSuggestion[] = [
  {
    id: 'founder-os',
    label: 'manual review in Founder OS',
    reason: 'No strong keyword matched, so this should stay near the operating core until a human connects it.',
    confidence: 0.34,
    source: 'fallback-review',
  },
];

const fallbackResult: ClassificationResult = {
  category: 'core',
  stage: 'planning',
  confidence: 0.34,
  matchedKeywords: [],
  relationIds: fallbackRelationSuggestions.map((suggestion) => suggestion.id),
  relationSuggestions: fallbackRelationSuggestions,
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
  const roundedConfidence = Number(confidence.toFixed(2));
  const signals = ranked.matchedKeywords.slice(0, 4);
  const relationSuggestions = makeRelationSuggestions(ranked.rule.anchors, normalized, roundedConfidence);

  return {
    category: ranked.rule.category,
    stage: ranked.rule.stage,
    confidence: roundedConfidence,
    matchedKeywords: signals,
    relationIds: relationSuggestions.map((suggestion) => suggestion.id),
    relationSuggestions,
    reason: `Matched ${signals.map((signal) => `"${signal}"`).join(', ')} and suggested ${relationSuggestions.length} relation anchors in the closest workflow orbit.`,
  };
};

export const classifyTool = (value: string): ToolCategoryId => classifyToolDetailed(value).category;

const makeRelationSuggestions = (
  seeds: RelationSuggestionSeed[],
  normalizedInput: string,
  baseConfidence: number,
): RelationSuggestion[] =>
  seeds.map((seed, index) => {
    const directMatch = normalizedInput.includes(seed.id) || normalizedInput.includes(seed.label.toLowerCase());
    const confidence = Math.min(0.98, Math.max(0.35, baseConfidence - index * 0.07 + (directMatch ? 0.08 : 0)));

    return {
      ...seed,
      confidence: Number(confidence.toFixed(2)),
      source: directMatch ? 'direct-match' : seed.source,
    };
  });

const titleCase = (value: string) =>
  value
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
