import type { AITool } from '../data/ai-tool-universe';

const logoDevPublishableKey = import.meta.env.VITE_LOGO_DEV_PUBLISHABLE_KEY?.trim();

const logoDomainOverrides: Record<string, string> = {
  'agent-skills': 'github.com',
  'affinity-adobe-blender': 'adobe.com',
  'api-mega-list': 'github.com',
  'base44': 'base44.com',
  bolt: 'bolt.new',
  buffer: 'buffer.com',
  'claude-code': 'anthropic.com',
  'claude-design': 'anthropic.com',
  'chorus-skills': 'chorus.com',
  codex: 'openai.com',
  coderabbit: 'coderabbit.ai',
  cubic: 'cubic.dev',
  cursor: 'cursor.com',
  'deer-flow': 'github.com',
  'designer-skills': 'github.com',
  dessn: 'dessn.ai',
  docker: 'docker.com',
  figma: 'figma.com',
  framer: 'framer.com',
  genmedia: 'genmedia.sh',
  higgsfield: 'higgsfield.ai',
  hyperframes: 'heygen.com',
  'kimi-webbridge': 'kimi.com',
  lazyweb: 'lazyweb.com',
  lovable: 'lovable.dev',
  'mattpocock-skills': 'github.com',
  'obsidian-skills': 'obsidian.md',
  omnisocials: 'omnisocials.com',
  openclaw: 'openclaw.ai',
  openswarm: 'github.com',
  opendesign: 'open-design.ai',
  'paper-design': 'paper.design',
  paperclip: 'paperclip.ing',
  'react-tauri-xterm': 'tauri.app',
  readwise: 'readwise.io',
  remotion: 'remotion.dev',
  shannon: 'github.com',
  supadata: 'supadata.ai',
  terax: 'terax.app',
  terminal: 'apple.com',
  vercel: 'vercel.com',
  vscode: 'visualstudio.com',
  warp: 'warp.dev',
  wisprflow: 'wisprflow.ai',
  zed: 'zed.dev',
};

const logoDomainDisplayNames: Record<string, string> = {
  'adobe.com': 'Adobe',
  'anthropic.com': 'Anthropic',
  'apple.com': 'Apple',
  'github.com': 'GitHub',
  'heygen.com': 'HeyGen',
  'openai.com': 'OpenAI',
  'tauri.app': 'Tauri',
  'visualstudio.com': 'VS Code',
};

export const hasLogoDevKey = Boolean(logoDevPublishableKey);

export const getDomainFromUrl = (url?: string) => {
  if (!url) return null;

  try {
    const parsed = new URL(url);
    return parsed.hostname.replace(/^www\./, '');
  } catch {
    return null;
  }
};

export const getToolLogoDomain = (tool: Pick<AITool, 'id' | 'url' | 'logoDomain'>) =>
  tool.logoDomain ?? logoDomainOverrides[tool.id] ?? getDomainFromUrl(tool.url);

export const getToolLogoDisplayDomain = (tool: Pick<AITool, 'id' | 'url' | 'logoDomain'>) => {
  const domain = getToolLogoDomain(tool);
  if (!domain) return null;
  return logoDomainDisplayNames[domain] ?? domain.replace(/^app\./, '').split('.').slice(0, 2).join('.');
};

export const getToolLogoUrl = (tool: Pick<AITool, 'id' | 'url' | 'logoDomain'>, size = 96) => {
  const domain = getToolLogoDomain(tool);
  if (!logoDevPublishableKey || !domain) return null;

  const params = new URLSearchParams({
    token: logoDevPublishableKey,
    size: String(size),
    format: 'png',
    theme: 'dark',
    retina: 'true',
    fallback: 'monogram',
  });

  return `https://img.logo.dev/${domain}?${params.toString()}`;
};

export const getToolInitials = (name: string) => {
  const parts = name
    .replace(/[+/|]/g, ' ')
    .replace(/\.(?=\s|$)/g, '')
    .split(/\s+/)
    .filter(Boolean);

  const firstAllCaps = parts.find((part) => /^[A-Z0-9]{2,4}$/.test(part));
  if (firstAllCaps) return firstAllCaps.slice(0, 3);

  const initials = parts.slice(0, 2).map((part) => part.charAt(0).toUpperCase()).join('');
  return initials || '?';
};
