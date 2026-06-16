import { useState } from 'react';
import { InAppBrowserProvider } from './components/InAppBrowser';
import { AIToolUniverseMap } from './components/AIToolUniverseMap';

export function App() {
  const [isOpen, setIsOpen] = useState(true);

  return (
    <InAppBrowserProvider>
      <div className="min-h-[100dvh] bg-[#03040a] text-text-primary">
        {isOpen ? (
          <AIToolUniverseMap onClose={() => setIsOpen(false)} />
        ) : (
          <main className="flex min-h-[100dvh] items-center justify-center px-6">
            <button
              type="button"
              onClick={() => setIsOpen(true)}
              className="rounded-xl border border-white/15 bg-white/[0.08] px-5 py-3 text-sm font-semibold text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_24px_80px_rgba(0,0,0,0.45)] backdrop-blur-2xl transition hover:bg-white/[0.12] active:scale-[0.98]"
            >
              Open AI Tool Universe Map
            </button>
          </main>
        )}
      </div>
    </InAppBrowserProvider>
  );
}
