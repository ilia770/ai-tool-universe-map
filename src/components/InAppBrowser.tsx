import {
  useCallback,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { InAppBrowserContext, normalizeOpenUrl, type BrowserRequest } from './inAppBrowserContext';

export function InAppBrowserProvider({ children }: { children: ReactNode }) {
  const [request, setRequest] = useState<BrowserRequest | null>(null);

  const openInApp = useCallback((url: string, title?: string) => {
    const normalized = normalizeOpenUrl(url);
    if (!normalized) return;
    setRequest({ title, url: normalized });
  }, []);

  const value = useMemo(() => ({ openInApp }), [openInApp]);

  return (
    <InAppBrowserContext.Provider value={value}>
      {children}
      {request ? (
        <div className="fixed inset-0 z-[80] flex items-end justify-center bg-black/65 p-3 backdrop-blur-md sm:items-center sm:p-6">
          <div className="flex h-[88dvh] w-full max-w-5xl flex-col overflow-hidden rounded-2xl border border-white/12 bg-[#080b12]/92 shadow-[0_28px_90px_rgba(0,0,0,0.7)] backdrop-blur-2xl">
            <div className="flex min-h-14 items-center gap-3 border-b border-white/10 px-4">
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-semibold text-white">
                  {request.title ?? 'In-app browser'}
                </div>
                <div className="truncate text-[11px] text-white/45">{request.url}</div>
              </div>
              <button
                type="button"
                onClick={() => setRequest(null)}
                className="rounded-full border border-white/12 bg-white/[0.06] px-3 py-1.5 text-xs font-medium text-white/75 transition hover:bg-white/[0.12] hover:text-white active:scale-95"
              >
                Close
              </button>
            </div>
            <iframe
              key={request.url}
              src={request.url}
              title={request.title ?? request.url}
              sandbox="allow-forms allow-same-origin allow-scripts"
              referrerPolicy="no-referrer"
              className="min-h-0 flex-1 border-0 bg-white"
            />
          </div>
        </div>
      ) : null}
    </InAppBrowserContext.Provider>
  );
}
