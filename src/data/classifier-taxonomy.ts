import type { ToolCategoryId, WorkflowStageId } from './ai-tool-universe';

export interface ClassifierRule {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  keywords: string[];
  anchors: string[];
}

export interface DomainRule {
  category: ToolCategoryId;
  stage: WorkflowStageId;
  anchors: string[];
  keyword: string;
}

/**
 * Canonical classifier taxonomy. Authored here, emitted to
 * `classifier-taxonomy.json` (web + iOS) by `scripts/gen-classifier-json.mjs`.
 * iOS decodes the same JSON so the two lanes can never silently diverge.
 */
export const CATEGORY_RULES: ClassifierRule[] = [
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
      'publish',
      'schedule post',
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
  {
    category: 'analytics',
    stage: 'review',
    keywords: [
      'amplitude',
      'analytics',
      'dashboards',
      'datadog',
      'grafana',
      'heap',
      'honeycomb',
      'logs',
      'mixpanel',
      'observability',
      'posthog',
      'sentry',
      'telemetry',
      'tracking',
    ],
    anchors: ['founder-os'],
  },
];

export const DOMAIN_RULES: Record<string, DomainRule> = {
  'amplitude.com': {
    category: 'analytics',
    stage: 'review',
    anchors: ['founder-os'],
    keyword: 'amplitude.com',
  },
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
  'datadoghq.com': {
    category: 'analytics',
    stage: 'review',
    anchors: ['founder-os'],
    keyword: 'datadoghq.com',
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
  'grafana.com': {
    category: 'analytics',
    stage: 'review',
    anchors: ['founder-os'],
    keyword: 'grafana.com',
  },
  'mixpanel.com': {
    category: 'analytics',
    stage: 'review',
    anchors: ['founder-os'],
    keyword: 'mixpanel.com',
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
  'posthog.com': {
    category: 'analytics',
    stage: 'review',
    anchors: ['founder-os'],
    keyword: 'posthog.com',
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
  'sentry.io': {
    category: 'analytics',
    stage: 'review',
    anchors: ['founder-os'],
    keyword: 'sentry.io',
  },
  'supabase.com': {
    category: 'infrastructure',
    stage: 'execution',
    anchors: ['founder-os', 'vercel', 'docker'],
    keyword: 'supabase.com',
  },
};

/**
 * Ambiguous brands that legitimately span multiple categories — adding them
 * blindly would be a wrong guess, so the intake asks "Ты уверен? Это <X>?".
 */
export const AMBIGUOUS: string[] = [];

/**
 * Giant mega-platforms. These are almost never what a user means to add as a
 * focused AI tool, so the intake asks for confirmation before adding.
 */
export const GIANT: string[] = [];
