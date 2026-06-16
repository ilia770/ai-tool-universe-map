import { describe, expect, it } from 'vitest';
import vercelConfig from '../vercel.json';

const headerMap = new Map(
  vercelConfig.headers?.flatMap((entry) => entry.headers.map((header) => [header.key, header.value] as const)) ?? [],
);

describe('deployment security headers', () => {
  it('ships a CSP that blocks embedding and unsafe URL schemes', () => {
    const csp = headerMap.get('Content-Security-Policy') ?? '';

    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("object-src 'none'");
    expect(csp).toContain("base-uri 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).toContain('frame-src https:');
    expect(csp).not.toContain('http:');
    expect(csp).not.toContain('*');
  });

  it('sets browser hardening headers at the edge', () => {
    expect(headerMap.get('X-Content-Type-Options')).toBe('nosniff');
    expect(headerMap.get('Referrer-Policy')).toBe('no-referrer');
    expect(headerMap.get('X-Frame-Options')).toBe('DENY');
    expect(headerMap.get('Permissions-Policy')).toContain('camera=()');
    expect(headerMap.get('Permissions-Policy')).toContain('microphone=()');
  });
});
