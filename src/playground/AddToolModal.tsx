import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ChangeEvent,
  type ClipboardEvent,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import { useToolStore } from './useToolStore';
import { categoryById } from '../data/ai-tool-universe';
import { classifyToolDetailed, getDisplayName } from '../lib/classify-ai-tool';
import { getToolLogoUrl } from '../lib/tool-logos';

const MAX_ICON_BYTES = 1_500_000;
const ALLOWED_ICON_TYPES = new Set(['image/png', 'image/jpeg', 'image/webp']);
const EXIT_MS = 260;
const DISMISS_THRESHOLD = 110;

function initials(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function haptic(): void {
  if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(8);
}

interface Props {
  open: boolean;
  onClose: () => void;
  onAdded?: (id: string) => void;
}

export function AddToolModal({ open, onClose, onAdded }: Props) {
  const { tools, addTool } = useToolStore();
  const [text, setText] = useState('');
  const [imageDataUrl, setImageDataUrl] = useState<string | undefined>(undefined);
  const [imageError, setImageError] = useState<string | null>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // Mount/visibility lifecycle so the panel animates IN and OUT (not pop).
  const [mounted, setMounted] = useState(open);
  const [visible, setVisible] = useState(false);
  const [reduced, setReduced] = useState(prefersReducedMotion);

  // Swipe-to-dismiss drag state (follows the pointer, springs back under threshold).
  const [drag, setDrag] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ y: number; id: number } | null>(null);

  // Long-press peek on an existing-match chip.
  const [peekId, setPeekId] = useState<string | null>(null);
  const longPressTimer = useRef<number | null>(null);

  const closeWithExit = useCallback(() => {
    if (prefersReducedMotion()) {
      onClose();
      return;
    }
    setVisible(false);
    window.setTimeout(onClose, EXIT_MS);
  }, [onClose]);

  // Subscribe to the reduced-motion media query (external system).
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  // Drive enter/exit transitions from the `open` prop.
  useEffect(() => {
    if (open) {
      let raf2 = 0;
      const raf1 = requestAnimationFrame(() => {
        setMounted(true);
        setDrag(0);
        if (reduced) {
          setVisible(true);
          return;
        }
        raf2 = requestAnimationFrame(() => setVisible(true));
      });
      return () => {
        cancelAnimationFrame(raf1);
        cancelAnimationFrame(raf2);
      };
    }
    let timer = 0;
    const raf = requestAnimationFrame(() => {
      setVisible(false);
      timer = window.setTimeout(() => setMounted(false), reduced ? 0 : EXIT_MS);
    });
    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(timer);
    };
  }, [open, reduced]);

  const trimmed = text.trim();
  const preview = useMemo(() => {
    if (!trimmed) return null;
    const result = classifyToolDetailed(trimmed);
    const name = getDisplayName(trimmed);
    const cat = categoryById.get(result.category);
    const domainMatch = trimmed.match(/([a-z0-9-]+\.[a-z]{2,})/i)?.[1]?.toLowerCase();
    const logo =
      imageDataUrl ??
      getToolLogoUrl({ id: name.toLowerCase(), url: domainMatch ? `https://${domainMatch}` : undefined, logoDomain: domainMatch }, 96);
    return { name, cat, stage: result.stage, confidence: result.confidence, logo };
  }, [trimmed, imageDataUrl]);

  const matches = useMemo(() => {
    if (!trimmed) return [];
    const q = trimmed.toLowerCase();
    return tools.filter((t) => t.name.toLowerCase().includes(q)).slice(0, 4);
  }, [trimmed, tools]);

  useEffect(() => {
    if (!mounted) return;

    const previousActiveElement = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        closeWithExit();
        return;
      }

      if (event.key !== 'Tab') return;
      const dialog = dialogRef.current;
      if (!dialog) return;

      const focusableElements = Array.from(
        dialog.querySelectorAll<HTMLElement>(
          'button:not([disabled]), input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      ).filter((element) => element.offsetParent !== null);

      if (focusableElements.length === 0) {
        event.preventDefault();
        dialog.focus();
        return;
      }

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      const activeElement = document.activeElement;

      if (event.shiftKey && activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      } else if (!event.shiftKey && activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      } else if (!dialog.contains(activeElement)) {
        event.preventDefault();
        firstElement.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown, true);
    requestAnimationFrame(() => dialogRef.current?.querySelector<HTMLInputElement>('input[type="text"]')?.focus());

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', handleKeyDown, true);
      previousActiveElement?.focus({ preventScroll: true });
    };
  }, [mounted, closeWithExit]);

  if (!mounted) return null;

  const readImage = (file: File | undefined) => {
    setImageError(null);
    if (!file) return;
    if (!ALLOWED_ICON_TYPES.has(file.type)) {
      setImageError('Use PNG, JPEG, or WebP.');
      return;
    }
    if (file.size > MAX_ICON_BYTES) {
      setImageError('Icon must be 1.5 MB or smaller.');
      return;
    }
    const reader = new FileReader();
    reader.onload = () => setImageDataUrl(typeof reader.result === 'string' ? reader.result : undefined);
    reader.onerror = () => setImageError('Could not read that image.');
    reader.readAsDataURL(file);
  };

  const onPaste = (e: ClipboardEvent) => {
    const item = Array.from(e.clipboardData.items).find((i) => i.type.startsWith('image/'));
    if (item) readImage(item.getAsFile() ?? undefined);
  };

  const submit = () => {
    if (!trimmed) return;
    haptic();
    const tool = addTool({ text: trimmed, imageDataUrl });
    setText('');
    setImageDataUrl(undefined);
    setImageError(null);
    onAdded?.(tool.id);
    closeWithExit();
  };

  // --- Swipe-to-dismiss (drag the panel down) ---
  const onHandlePointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (reduced) return;
    dragStart.current = { y: e.clientY, id: e.pointerId };
    setDragging(true);
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const onHandlePointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    // Resist upward drag, follow downward.
    setDrag(dy > 0 ? dy : dy * 0.25);
  };

  const onHandlePointerUp = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    dragStart.current = null;
    setDragging(false);
    if (dy > DISMISS_THRESHOLD) {
      haptic();
      setDrag(window.innerHeight);
      closeWithExit();
    } else {
      setDrag(0);
    }
  };

  // --- Long-press peek on a match chip ---
  const clearLongPress = () => {
    if (longPressTimer.current !== null) {
      window.clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  const onChipPressStart = (id: string) => {
    clearLongPress();
    longPressTimer.current = window.setTimeout(() => {
      haptic();
      setPeekId((cur) => (cur === id ? null : id));
    }, 420);
  };

  const panelTransform = visible
    ? `translateY(${drag}px) scale(1)`
    : 'translateY(24px) scale(0.94)';

  return (
    <div
      className="fixed inset-0 z-30 flex items-start justify-center px-4 pt-[12vh]"
      onClick={closeWithExit}
    >
      {/* Scrim — fades independently of the panel. */}
      <div
        aria-hidden
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        style={{
          opacity: visible ? Math.max(0, 1 - drag / 520) : 0,
          transition: reduced ? 'none' : 'opacity 300ms cubic-bezier(0.22,1,0.36,1)',
        }}
      />

      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        tabIndex={-1}
        className="relative w-full max-w-md overflow-hidden rounded-3xl border border-white/10 bg-white/[0.07] p-5 backdrop-blur-2xl"
        style={{
          transform: panelTransform,
          opacity: visible ? 1 : 0,
          transition: dragging
            ? 'none'
            : reduced
              ? 'none'
              : 'transform 320ms cubic-bezier(0.16,1,0.3,1), opacity 240ms ease-out',
          // Layered liquid glass: soft outer shadow + hairline inner top-highlight.
          boxShadow:
            '0 24px 80px rgba(0,0,0,0.55), inset 0 1px 0 rgba(255,255,255,0.18), inset 0 0 0 1px rgba(255,255,255,0.04)',
          willChange: 'transform, opacity',
        }}
        onClick={(e) => e.stopPropagation()}
        onPaste={onPaste}
      >
        {/* Grab handle — swipe down to dismiss. */}
        <div
          className="mx-auto -mt-1 mb-3 flex h-6 w-full cursor-grab touch-none items-center justify-center active:cursor-grabbing"
          onPointerDown={onHandlePointerDown}
          onPointerMove={onHandlePointerMove}
          onPointerUp={onHandlePointerUp}
          onPointerCancel={onHandlePointerUp}
        >
          <div className="h-1.5 w-10 rounded-full bg-white/25 transition-colors duration-200 group-active:bg-white/40" />
        </div>

        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-white">Add a tool to the universe</h2>
          <button
            type="button"
            onClick={closeWithExit}
            onPointerDown={haptic}
            aria-label="Close"
            className="flex h-10 w-10 items-center justify-center rounded-xl text-white/50 transition-all duration-150 hover:bg-white/10 hover:text-white active:scale-[0.9] active:bg-white/15"
          >
            ✕
          </button>
        </div>

        <input
          autoFocus
          value={text}
          onChange={(e: ChangeEvent<HTMLInputElement>) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') submit(); }}
          placeholder="Paste a tool name or URL — e.g. Perplexity or perplexity.ai"
          className="w-full rounded-xl border border-white/10 bg-white/[0.06] px-3 py-2.5 text-sm text-white placeholder-white/35 outline-none transition-all duration-200 focus:border-white/30 focus:bg-white/[0.08] focus:shadow-[0_0_0_4px_rgba(255,255,255,0.06)]"
        />

        {preview ? (
          <div
            key={preview.name}
            className="mt-3 flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.05] p-3"
            style={{
              animation: reduced ? undefined : 'atm-rise 360ms cubic-bezier(0.16,1,0.3,1) both',
              boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.08)',
            }}
          >
            <div
              className="flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden rounded-xl text-sm font-semibold text-white"
              style={{ background: preview.cat?.color ?? '#3a3f55' }}
            >
              {preview.logo ? (
                <img src={preview.logo} alt="" className="h-full w-full object-cover" />
              ) : (
                initials(preview.name)
              )}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-medium text-white">{preview.name}</div>
              <div className="mt-0.5 flex items-center gap-1.5 text-[11px] text-white/55">
                <span
                  className="rounded-full px-2 py-0.5 font-medium text-white"
                  style={{ background: `${preview.cat?.color ?? '#666'}33`, color: preview.cat?.color ?? '#fff' }}
                >
                  {preview.cat?.name ?? 'Unclassified'}
                </span>
                <span className="capitalize">· {preview.stage}</span>
                <span
                  key={Math.round(preview.confidence * 100)}
                  className="inline-block"
                  style={{ animation: reduced ? undefined : 'atm-bump 320ms cubic-bezier(0.34,1.56,0.64,1) both' }}
                >
                  · {Math.round(preview.confidence * 100)}% match
                </span>
              </div>
            </div>
          </div>
        ) : (
          <p className="mt-3 text-xs text-white/40">
            The classifier reads what you paste and drops it into the right category & workflow stage. Paste or upload an image to set its icon — otherwise the brand logo is pulled from logo.dev.
          </p>
        )}

        {matches.length > 0 ? (
          <div className="mt-3">
            <div className="mb-1 text-[10px] uppercase tracking-wider text-white/35">Already on the map</div>
            <div className="flex flex-wrap gap-1.5">
              {matches.map((m, i) => (
                <span
                  key={m.id}
                  className="relative inline-flex min-h-[40px] cursor-default touch-none select-none items-center rounded-lg border border-white/10 bg-white/[0.05] px-2 py-1 text-xs text-white/70 transition-all duration-150 hover:bg-white/[0.09] active:scale-[0.96] active:bg-white/[0.12]"
                  style={{
                    animation: reduced ? undefined : `atm-rise 340ms cubic-bezier(0.16,1,0.3,1) both`,
                    animationDelay: reduced ? undefined : `${40 + i * 55}ms`,
                    outline: peekId === m.id ? '1px solid rgba(255,255,255,0.35)' : undefined,
                    boxShadow: peekId === m.id ? '0 8px 24px rgba(0,0,0,0.45)' : undefined,
                    transform: peekId === m.id ? 'scale(1.06)' : undefined,
                  }}
                  onPointerDown={() => onChipPressStart(m.id)}
                  onPointerUp={clearLongPress}
                  onPointerLeave={clearLongPress}
                  onPointerCancel={clearLongPress}
                >
                  {m.name}
                  {peekId === m.id ? (
                    <span className="ml-1.5 text-[10px] text-white/40">· already added</span>
                  ) : null}
                </span>
              ))}
            </div>
          </div>
        ) : null}

        {imageError ? (
          <p
            className="mt-3 rounded-xl border border-red-300/20 bg-red-500/10 px-3 py-2 text-xs text-red-100/80"
            style={{ animation: reduced ? undefined : 'atm-rise 300ms cubic-bezier(0.16,1,0.3,1) both' }}
          >
            {imageError}
          </p>
        ) : null}

        <div className="mt-4 flex items-center gap-2">
          <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={(e) => readImage(e.target.files?.[0])} />
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            onPointerDown={haptic}
            className="min-h-[40px] rounded-xl border border-white/10 bg-white/[0.05] px-3 py-2 text-xs text-white/70 transition-all duration-150 hover:bg-white/10 active:scale-[0.96] active:bg-white/15"
          >
            {imageDataUrl ? 'Image set ✓' : 'Upload icon'}
          </button>
          <div className="flex-1" />
          <button
            type="button"
            onClick={submit}
            onPointerDown={() => { if (trimmed) haptic(); }}
            disabled={!trimmed}
            className="min-h-[40px] rounded-xl bg-white/90 px-4 py-2 text-xs font-semibold text-black shadow-[0_4px_16px_rgba(0,0,0,0.25)] transition-all duration-150 hover:bg-white hover:shadow-[0_6px_20px_rgba(0,0,0,0.3)] active:scale-[0.96] disabled:scale-100 disabled:opacity-40 disabled:shadow-none"
          >
            Add to map
          </button>
        </div>
      </div>

      <style>{`
        @keyframes atm-rise {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes atm-bump {
          0% { transform: scale(0.82); opacity: 0.4; }
          60% { transform: scale(1.08); }
          100% { transform: scale(1); opacity: 1; }
        }
      `}</style>
    </div>
  );
}
