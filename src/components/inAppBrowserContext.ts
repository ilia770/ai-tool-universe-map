import { createContext } from 'react';

export interface BrowserRequest {
  title?: string;
  url: string;
}

export interface InAppBrowserValue {
  openInApp: (url: string, title?: string) => void;
}

export const InAppBrowserContext = createContext<InAppBrowserValue | null>(null);

export function normalizeOpenUrl(value: string): string | null {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') return null;
    return url.toString();
  } catch {
    return null;
  }
}
