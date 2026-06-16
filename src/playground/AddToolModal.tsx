import {
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  type ChangeEvent,
  type ClipboardEvent,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import { ImagePlus, Loader2, X } from 'lucide-react';
import { useToolStore } from './useToolStore';
import { categoryById } from '../data/ai-tool-universe';
import { classifyToolDetailed, getDisplayName } from '../lib/classify-ai-tool';
import { getToolLogoUrl } from '../lib/tool-logos';
import {
  ACCENT,
  DISMISS,
  DURATION,
  EASE,
  FOCUS_RING,
  GLASS,
  HOVER_LIFT,
  RADIUS,
  SHADOW,
  STAGGER,
  TEXT,
  TYPE,
  cx,
} from './designSystem';

const MAX_ICON_BYTES = 1_500_000;
const ALLOWED_ICON_TYPES = new Set(['image/png', 'image/jpeg', 'image/webp']);

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
  if (prefersReducedMotion()) return;
  if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(8);
}

interface Props {
  open: boolean;
  initialText?: string;
  onClose: () => void;
  onAdded?: (id: string) => void;
}

export function AddToolModal({ open, initialText, onClose, onAdded }: Props) {
  const { tools, addTool } = useToolStore();
  const [text, setText] = useState('');
  const [imageDataUrl, setImageDataUrl] = useState<string | undefined>(undefined);
  const [imageError, setImageError] = useState<string | null>(null);
  const [imageLoading, setImageLoading] = useState(false);
  const dialogRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const celebrationTimerRef = useRef<number | null>(null);
  const titleId = useId();
  const inputId = useId();
  const inputDescriptionId = useId();
  const imageErrorId = useId();

  // Mount/visibility lifecycle so the panel animates IN and OUT (not pop).
  const [mounted, setMounted] = useState(open);
  const [visible, setVisible] = useState(false);
  const [reduced, setReduced] = useState(prefersReducedMotion);

  // Celebration bloom flare fired at submit (the milestone delight moment).
  const [celebrating, setCelebrating] = useState(false);

  // Swipe-to-dismiss drag state (follows the pointer, springs back under threshold).
  const [drag, setDrag] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ y: number; t: number; id: number } | null>(null);
  const lastMove = useRef<{ y: number; t: number } | null>(null);

  const trimmed = text.trim();
  const dirty = trimmed.length > 0 || imageDataUrl !== undefined;

  const closeWithExit = useCallback(() => {
    if (prefersReducedMotion()) {
      onClose();
      return;
    }
    setVisible(false);
    window.setTimeout(onClose, DURATION.exit);
  }, [onClose]);

  const clearCelebrationTimer = useCallback(() => {
    if (celebrationTimerRef.current !== null) {
      window.clearTimeout(celebrationTimerRef.current);
      celebrationTimerRef.current = null;
    }
  }, []);

  // Dismiss guard: if the user typed something, confirm before discarding.
  const requestClose = useCallback(() => {
    if (dirty && typeof window !== 'undefined') {
      const ok = window.confirm('Discard this tool? Your entry will be lost.');
      if (!ok) return;
    }
    clearCelebrationTimer();
    setCelebrating(false);
    closeWithExit();
  }, [dirty, clearCelebrationTimer, closeWithExit]);

  useEffect(() => () => clearCelebrationTimer(), [clearCelebrationTimer]);

  useEffect(() => {
    const timer = window.setTimeout(() => setCelebrating(false), 0);
    return () => window.clearTimeout(timer);
  }, [open]);

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
    clearCelebrationTimer();
    if (open) {
      let raf2 = 0;
      const raf1 = requestAnimationFrame(() => {
        setMounted(true);
        setDrag(0);
        setText(initialText ?? '');
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
      timer = window.setTimeout(() => setMounted(false), reduced ? 0 : DURATION.exit);
    });
    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(timer);
    };
  }, [open, reduced, clearCelebrationTimer, initialText]);

  const preview = useMemo(() => {
    if (!trimmed) return null;
    const result = classifyToolDetailed(trimmed);
    const name = getDisplayName(trimmed);
    const cat = categoryById.get(result.category);
    const domainMatch = trimmed.match(/([a-z0-9-]+\.[a-z]{2,})/i)?.[1]?.toLowerCase();
    const logo =
      imageDataUrl ??
      getToolLogoUrl({ id: name.toLowerCase(), url: domainMatch ? `https://${domainMatch}` : undefined, logoDomain: domainMatch }, 96);
    return { name, cat, stage: result.stage, logo };
  }, [trimmed, imageDataUrl]);

  const matches = useMemo(() => {
    if (!trimmed) return [];
    const q = trimmed.toLowerCase();
    return tools.filter((t) => t.name.toLowerCase().includes(q)).slice(0, 4);
  }, [trimmed, tools]);

  // An exact identity match means we should "Open" the existing tool, not re-add.
  const exactMatch = useMemo(() => {
    if (!preview) return null;
    const q = preview.name.toLowerCase();
    return tools.find((t) => t.name.toLowerCase() === q) ?? null;
  }, [preview, tools]);

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
        requestClose();
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
  }, [mounted, requestClose]);

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
    setImageLoading(true);
    const reader = new FileReader();
    reader.onload = () => {
      setImageDataUrl(typeof reader.result === 'string' ? reader.result : undefined);
      setImageLoading(false);
    };
    reader.onerror = () => {
      setImageError('Could not read that image.');
      setImageLoading(false);
    };
    reader.readAsDataURL(file);
  };

  const clearImage = () => {
    setImageDataUrl(undefined);
    setImageError(null);
    setImageLoading(false);
    if (fileRef.current) fileRef.current.value = '';
  };

  const resetDraft = () => {
    setText('');
    clearImage();
    setCelebrating(false);
  };

  const onPaste = (e: ClipboardEvent) => {
    const item = Array.from(e.clipboardData.items).find((i) => i.type.startsWith('image/'));
    if (item) readImage(item.getAsFile() ?? undefined);
  };

  // Open an existing tool (dedupe path + tappable match chips).
  const openExisting = (id: string) => {
    haptic();
    clearCelebrationTimer();
    resetDraft();
    onAdded?.(id);
    closeWithExit();
  };

  const submit = () => {
    if (!trimmed || celebrating) return;
    if (exactMatch) {
      openExisting(exactMatch.id);
      return;
    }
    haptic();
    const tool = addTool({ text: trimmed, imageDataUrl });
    // Celebration: bloom flare at the CTA, then hand off to the brand window.
    if (reduced) {
      resetDraft();
      onAdded?.(tool.id);
      closeWithExit();
      return;
    }
    clearCelebrationTimer();
    setCelebrating(true);
    celebrationTimerRef.current = window.setTimeout(() => {
      celebrationTimerRef.current = null;
      resetDraft();
      onAdded?.(tool.id);
      closeWithExit();
    }, DURATION.celebrate);
  };

  // --- Swipe-to-dismiss (drag the panel down) — unified DISMISS contract ---
  const onHandlePointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (reduced) return;
    dragStart.current = { y: e.clientY, t: e.timeStamp, id: e.pointerId };
    lastMove.current = { y: e.clientY, t: e.timeStamp };
    setDragging(true);
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const onHandlePointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    lastMove.current = { y: e.clientY, t: e.timeStamp };
    // Follow downward 1:1; rubber-band any upward over-drag.
    setDrag(dy > 0 ? dy : dy * DISMISS.resistance);
  };

  const onHandlePointerUp = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    const prev = lastMove.current;
    const velocity = prev && e.timeStamp > prev.t ? (e.clientY - prev.y) / (e.timeStamp - prev.t) : 0;
    dragStart.current = null;
    lastMove.current = null;
    setDragging(false);
    // Dismiss if dragged down past distance OR a downward flick over velocity.
    if (dy > DISMISS.distancePx || velocity > DISMISS.velocity) {
      haptic();
      setDrag(window.innerHeight);
      requestClose();
      if (dirty) setDrag(0); // guard may cancel — snap back if so
    } else {
      setDrag(0);
    }
  };

  const panelTransform = visible
    ? `translateY(${drag}px) scale(1)`
    : 'translateY(24px) scale(0.94)';

  const plateBg = preview?.cat?.color ?? '#3a3f55';

  return (
    <div
      className="fixed inset-0 z-30 flex items-start justify-center px-4 pt-[max(12vh,calc(env(safe-area-inset-top)+1rem))]"
      onClick={requestClose}
    >
      {/* Scrim — fades independently of the panel. */}
      <div
        aria-hidden
        className={GLASS.scrim + ' absolute inset-0'}
        style={{
          opacity: visible ? Math.max(0, 1 - drag / 520) : 0,
          transition: reduced ? 'none' : `opacity ${DURATION.enter}ms ${EASE.out}`,
        }}
      />

      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        className={cx(
          'relative w-full max-w-md overflow-hidden',
          GLASS.panel,
          'p-5',
          'select-none [-webkit-touch-callout:none]',
        )}
        style={{
          transform: panelTransform,
          opacity: visible ? 1 : 0,
          transition: dragging || reduced
            ? 'none'
            : `transform ${DURATION.sheet}ms ${EASE.sheet}, opacity ${DURATION.exit}ms ${EASE.out}`,
          willChange: 'transform, opacity',
          marginBottom: 'env(safe-area-inset-bottom)',
        }}
        onClick={(e) => e.stopPropagation()}
        onPaste={onPaste}
      >
        {/* Grab handle — swipe down to dismiss (unified h-1 w-9 token). */}
        <div
          className="group/handle mx-auto -mt-1 mb-3 flex h-6 w-full cursor-grab touch-none items-center justify-center active:cursor-grabbing"
          onPointerDown={onHandlePointerDown}
          onPointerMove={onHandlePointerMove}
          onPointerUp={onHandlePointerUp}
          onPointerCancel={onHandlePointerUp}
        >
          <div className="h-1 w-9 rounded-full bg-white/20 transition-colors duration-200 group-active/handle:bg-white/40" />
        </div>

        <div className="mb-4 flex items-center justify-between">
          <h2 id={titleId} className={cx(TYPE.title, TEXT.primary)}>
            Add a tool to the universe
          </h2>
          <button
            type="button"
            onClick={requestClose}
            onPointerDown={haptic}
            aria-label="Close"
            className={cx(
              'flex h-11 w-11 items-center justify-center',
              RADIUS.control,
              TEXT.secondary,
              'transition-all duration-150 [@media(hover:hover)]:hover:bg-white/10 [@media(hover:hover)]:hover:text-white active:scale-[0.92] active:bg-white/15',
              FOCUS_RING,
            )}
          >
            <X aria-hidden size={18} strokeWidth={2.25} />
          </button>
        </div>

        <label htmlFor={inputId} className="sr-only">
          Tool name or URL
        </label>
        <p id={inputDescriptionId} className="sr-only">
          Paste a tool name or URL, then press Enter or add it to the map.
        </p>
        <input
          id={inputId}
          type="text"
          value={text}
          onChange={(e: ChangeEvent<HTMLInputElement>) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') submit(); }}
          enterKeyHint="done"
          aria-describedby={inputDescriptionId}
          placeholder="Paste a tool name or URL — e.g. Perplexity or perplexity.ai"
          className={cx(
            'w-full',
            GLASS.chip,
            'px-3 py-2.5',
            TYPE.body,
            'text-white/85',
            TEXT.placeholder,
            'outline-none transition-all duration-200',
            'focus:border-cyan-300/40 focus:bg-white/[0.08] focus:shadow-[0_0_0_4px_rgba(125,211,252,0.12)]',
            FOCUS_RING,
          )}
        />

        {preview ? (
          <div
            key={preview.name}
            className="mt-3 flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.05] p-3"
            style={{
              animation: reduced ? undefined : `atm-rise ${DURATION.sheet}ms ${EASE.out} both`,
              boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.08)',
            }}
          >
            {/* Brand plate — also the icon-upload affordance (tap to replace). */}
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              onPointerDown={haptic}
              aria-label={imageDataUrl ? 'Replace icon' : 'Upload icon'}
              className={cx(
                'group/plate relative flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden',
                RADIUS.panel,
                'text-sm font-semibold text-white',
                FOCUS_RING,
              )}
              style={{
                background: plateBg,
                animation: reduced ? undefined : `atm-plate-pop ${DURATION.state}ms ${EASE.back} both`,
              }}
            >
              {imageLoading ? (
                <Loader2 aria-hidden className={cx(!reduced && 'animate-spin', 'text-white/90')} size={18} />
              ) : preview.logo ? (
                <img src={preview.logo} alt="" className="h-full w-full object-cover" />
              ) : (
                initials(preview.name)
              )}
              {/* Hover/focus hint that the plate is tappable. */}
              <span
                aria-hidden
                className="absolute inset-0 flex items-center justify-center bg-black/45 opacity-0 transition-opacity duration-150 [@media(hover:hover)]:group-hover/plate:opacity-100 group-focus-visible/plate:opacity-100"
              >
                <ImagePlus size={16} className="text-white" />
              </span>
            </button>

            <div className="min-w-0 flex-1">
              <div className={cx('truncate', TYPE.body, 'font-medium text-white/85')}>{preview.name}</div>
              <div className={cx('mt-1 flex items-center gap-1.5', TYPE.chip, TEXT.meta)}>
                <span
                  className="rounded-full px-2 py-0.5 font-medium"
                  style={{ background: `${preview.cat?.color ?? '#666'}33`, color: preview.cat?.color ?? '#fff' }}
                >
                  {preview.cat?.name ?? 'Unclassified'}
                </span>
                <span className="capitalize">· {preview.stage}</span>
              </div>
            </div>

            {imageDataUrl ? (
              <button
                type="button"
                onClick={clearImage}
                onPointerDown={haptic}
                aria-label="Remove uploaded icon"
                className={cx(
                  'flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-white/55',
                  'transition-all duration-150 [@media(hover:hover)]:hover:bg-white/10 [@media(hover:hover)]:hover:text-white active:scale-[0.9]',
                  FOCUS_RING,
                )}
              >
                <X aria-hidden size={14} strokeWidth={2.25} />
              </button>
            ) : null}
          </div>
        ) : (
          <p className={cx('mt-3', TYPE.chip, TEXT.meta)}>
            The classifier reads what you paste and drops it into the right category & workflow stage. Tap the icon to upload your own — otherwise the brand logo is pulled from logo.dev.
          </p>
        )}

        {matches.length > 0 ? (
          <div className="mt-4">
            <div className={cx('mb-1.5', TYPE.eyebrow, TEXT.meta)}>Already on the map</div>
            <div className="flex flex-wrap gap-1.5">
              {matches.map((m, i) => (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => openExisting(m.id)}
                  onPointerDown={haptic}
                  aria-label={`Open ${m.name}`}
                  className={cx(
                    'inline-flex min-h-[44px] items-center gap-1.5',
                    GLASS.chip,
                    'px-3 py-1.5',
                    TYPE.chip,
                    TEXT.body,
                    'transition-all duration-150 [@media(hover:hover)]:hover:bg-white/[0.10] active:scale-[0.96]',
                    HOVER_LIFT,
                    FOCUS_RING,
                  )}
                  style={{
                    animation: reduced ? undefined : `atm-rise ${DURATION.peek}ms ${EASE.out} both`,
                    animationDelay: reduced ? undefined : `${40 + Math.min(i, 5) * STAGGER.chip}ms`,
                  }}
                >
                  {m.name}
                  <span className={cx(TYPE.eyebrow, ACCENT.text)}>Open</span>
                </button>
              ))}
            </div>
          </div>
        ) : null}

        {imageError ? (
          <p
            id={imageErrorId}
            role="alert"
            aria-live="assertive"
            className="mt-3 rounded-xl border border-red-300/20 bg-red-500/10 px-3 py-2 text-xs text-red-100/85"
            style={{ animation: reduced ? undefined : `atm-rise ${DURATION.enter}ms ${EASE.out} both` }}
          >
            {imageError}
          </p>
        ) : null}

        {/* Hidden file input drives the plate upload affordance. */}
        <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={(e) => readImage(e.target.files?.[0])} />

        <div className="mt-5">
          <button
            type="button"
            onClick={submit}
            onPointerDown={() => { if (trimmed) haptic(); }}
            disabled={!trimmed || celebrating}
            className={cx(
              'relative w-full min-h-[44px] overflow-hidden',
              RADIUS.control,
              'bg-white/90 px-4 py-2.5',
              TYPE.body,
              'font-semibold text-black',
              SHADOW.floating,
              'transition-all duration-150 [@media(hover:hover)]:hover:bg-white active:scale-[0.98]',
              'disabled:scale-100 disabled:opacity-40 disabled:shadow-none',
              FOCUS_RING,
            )}
          >
            {exactMatch ? `Open ${exactMatch.name}` : 'Add to map'}
            {/* Celebration bloom flare — fires once at submit. */}
            {celebrating ? (
              <span
                aria-hidden
                className="pointer-events-none absolute left-1/2 top-1/2 h-16 w-16 -translate-x-1/2 -translate-y-1/2 rounded-full"
                style={{
                  background: `radial-gradient(circle, ${plateBg}cc 0%, transparent 70%)`,
                  animation: `atm-bloom ${DURATION.celebrate}ms ${EASE.out} forwards`,
                }}
              />
            ) : null}
          </button>
        </div>
      </div>
    </div>
  );
}
