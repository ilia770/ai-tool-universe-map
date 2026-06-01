import { useId, useState } from 'react';
import type { AITool } from '../data/ai-tool-universe';
import { categoryById } from '../data/ai-tool-universe';
import { getToolInitials, getToolLogoUrl } from '../lib/tool-logos';

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

  const style = {
    width: size,
    height: size,
  };

  if (logoUrl && !failed) {
    return (
      <span
        className={`inline-flex shrink-0 items-center justify-center overflow-hidden rounded-lg border border-white/12 bg-white/[0.07] shadow-[inset_0_1px_0_rgba(255,255,255,0.12)] ${className}`}
        style={style}
      >
        <img
          src={logoUrl}
          alt={`${tool.name} logo`}
          className="h-full w-full object-contain p-1.5"
          loading="lazy"
          decoding="async"
          onError={() => setFailedUrl(logoUrl)}
        />
      </span>
    );
  }

  return (
    <span
      className={`inline-flex shrink-0 items-center justify-center overflow-hidden rounded-lg border border-white/12 bg-white/[0.07] shadow-[inset_0_1px_0_rgba(255,255,255,0.12)] ${className}`}
      style={style}
      aria-label={`${tool.name} logo placeholder`}
    >
      <svg viewBox="0 0 40 40" role="img" aria-hidden="true" className="h-full w-full">
        <defs>
          <radialGradient id={gradientId} cx="34%" cy="22%" r="78%">
            <stop offset="0%" stopColor="rgba(255,255,255,0.9)" />
            <stop offset="38%" stopColor={accent} stopOpacity="0.42" />
            <stop offset="100%" stopColor="rgba(8,12,24,0.92)" />
          </radialGradient>
        </defs>
        <rect width="40" height="40" rx="10" fill={`url(#${gradientId})`} />
        <circle cx="30" cy="10" r="8" fill={accent} opacity="0.16" />
        <text
          x="20"
          y="23.5"
          fill="rgba(255,255,255,0.94)"
          fontFamily="ui-sans-serif, system-ui, sans-serif"
          fontSize={initials.length > 1 ? 11 : 13}
          fontWeight="700"
          letterSpacing="0"
          textAnchor="middle"
        >
          {initials}
        </text>
      </svg>
    </span>
  );
}
