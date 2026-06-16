import { describe, expect, it } from 'vitest';
import { normalizeOpenUrl } from './inAppBrowserContext';

describe('normalizeOpenUrl', () => {
  it('allows HTTPS URLs for the in-app browser', () => {
    expect(normalizeOpenUrl('https://example.com/path?q=1')).toBe('https://example.com/path?q=1');
  });

  it('rejects non-HTTPS URLs before they reach the iframe', () => {
    expect(normalizeOpenUrl('http://example.com')).toBeNull();
    expect(normalizeOpenUrl('javascript:alert(1)')).toBeNull();
    expect(normalizeOpenUrl('data:text/html,<script>alert(1)</script>')).toBeNull();
    expect(normalizeOpenUrl('file:///etc/passwd')).toBeNull();
  });
});
