import { type CSSProperties, useId, useState } from 'react';
import type { AITool } from '../data/ai-tool-universe';
import { categoryById } from '../data/ai-tool-universe';
import { getToolInitials, getToolLogoDisplayDomain, getToolLogoUrl } from '../lib/tool-logos';
import { trackUniverseEvent } from '../lib/universe-analytics';

interface ToolLogoProps {
  tool: Pick<AITool, 'id' | 'name' | 'category' | 'url' | 'logoDomain'>;
  size?: number;
  className?: string;
}

export function ToolLogo({ tool, size = 40, className = '' }: ToolLogoProps) {
  const gradientId = useId().replace(/:/g, '');
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  const logoUrl = getToolLogoUrl(tool, Math.max(64, size * 2));
  const failed = Boolean(logoUrl && failedUrl === logoUrl);
  const category = categoryById.get(tool.category);
  const accent = category?.color ?? '#67e8f9';
  const initials = getToolInitials(tool.name);
  const displayDomain = getToolLogoDisplayDomain(tool);
  const label = displayDomain ?? category?.shortName ?? 'AI';

  const style = {
    width: size,
    height: size,
    '--tool-logo-accent': accent,
  } as CSSProperties;

  if (logoUrl && !failed) {
    return (
      <span
        className={`inline-flex shrink-0 items-center justify-center overflow-hidden rounded-lg border border-white/12 bg-white/[0.07] shadow-[inset_0_1px_0_rgba(255,255,255,0.12)] ${className}`}
        style={style}
        data-logo-source="logo-dev"
      >
        <img
          src={logoUrl}
          alt={`${tool.name} logo`}
          className="h-full w-full object-contain p-1"
          loading="lazy"
          decoding="async"
          onError={() => {
            setFailedUrl(logoUrl);
            trackUniverseEvent('logo_fallback', {
              toolId: tool.id,
              reason: 'image-error',
            });
          }}
        />
      </span>
    );
  }

  return (
    <span
      className={`inline-flex shrink-0 items-center justify-center overflow-hidden rounded-lg border border-white/12 bg-white/[0.07] shadow-[inset_0_1px_0_rgba(255,255,255,0.12)] ${className}`}
      style={style}
      data-logo-source="fallback"
      aria-label={`${tool.name} logo placeholder`}
    >
      <svg viewBox="0 0 40 40" role="img" aria-hidden="true" className="h-full w-full">
        <defs>
          <radialGradient id={gradientId} cx="34%" cy="22%" r="78%">
            <stop offset="0%" stopColor="rgba(255,255,255,0.98)" />
            <stop offset="34%" stopColor={accent} stopOpacity="0.62" />
            <stop offset="100%" stopColor="rgba(4,8,18,0.96)" />
          </radialGradient>
        </defs>
        <rect width="40" height="40" rx="11" fill={`url(#${gradientId})`} />
        <path d="M6 30 C13 22 22 21 34 10 L34 35 L6 35 Z" fill={accent} opacity="0.18" />
        <circle cx="30" cy="10" r="8" fill={accent} opacity="0.22" />
        <circle cx="9" cy="31" r="3" fill="rgba(255,255,255,0.38)" />
        <text
          x="20"
          y={initials.length > 2 ? '22.6' : '23.4'}
          fill="rgba(255,255,255,0.94)"
          fontFamily="ui-sans-serif, system-ui, sans-serif"
          fontSize={initials.length > 2 ? 9 : initials.length > 1 ? 12 : 15}
          fontWeight="800"
          letterSpacing="0"
          textAnchor="middle"
        >
          {initials}
        </text>
        <text
          x="20"
          y="32.2"
          fill="rgba(226,237,255,0.68)"
          fontFamily="ui-sans-serif, system-ui, sans-serif"
          fontSize="4.2"
          fontWeight="700"
          letterSpacing="0"
          textAnchor="middle"
        >
          {label.slice(0, 15)}
        </text>
      </svg>
    </span>
  );
}
