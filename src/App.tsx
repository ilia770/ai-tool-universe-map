import { useState } from 'react';
import { AIToolUniverseMap } from './components/AIToolUniverseMap';
import { VisualizationLab } from './components/VisualizationLab';

type AppMode = 'map' | 'lab';

function getInitialMode(): AppMode {
  return window.location.hash === '#visual-lab' ? 'lab' : 'map';
}

export function App() {
  const [isOpen, setIsOpen] = useState(true);
  const [mode, setMode] = useState<AppMode>(getInitialMode);

  const openLab = () => {
    window.location.hash = 'visual-lab';
    setMode('lab');
  };

  const openMap = () => {
    window.history.replaceState(null, '', window.location.pathname);
    setMode('map');
  };

  if (mode === 'lab') {
    return <VisualizationLab onBack={openMap} />;
  }

  return (
    <div className="min-h-[100dvh] bg-[#03040a] text-text-primary">
      {isOpen ? (
        <AIToolUniverseMap onClose={() => setIsOpen(false)} />
      ) : (
        <main className="flex min-h-[100dvh] flex-col items-center justify-center gap-3 px-6">
          <button
            type="button"
            onClick={() => setIsOpen(true)}
            className="rounded-xl border border-white/15 bg-white/[0.08] px-5 py-3 text-sm font-semibold text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.12),0_24px_80px_rgba(0,0,0,0.45)] backdrop-blur-2xl transition hover:bg-white/[0.12] active:scale-[0.98]"
          >
            Open AI Tool Universe Map
          </button>
          <button
            type="button"
            onClick={openLab}
            className="rounded-xl border border-cyan-300/25 bg-cyan-300/[0.08] px-5 py-3 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/[0.14] active:scale-[0.98]"
          >
            Open Visual Lab
          </button>
        </main>
      )}
    </div>
  );
}
