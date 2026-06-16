import {
  useEffect,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import { Check, Download, Trash2, X } from 'lucide-react';
import { useToolStore } from './useToolStore';
import { t } from './i18n';
import type { Language } from './toolStoreContext';
import {
  ACCENT,
  cx,
  DURATION,
  EASE,
  FOCUS_RING,
  GLASS,
  TEXT,
  TYPE,
} from './designSystem';
import {
  fireHaptic,
  prefersReducedMotion,
  rubberBand,
  shouldDismiss,
} from './interactions';

export interface VariantOption {
  id: string;
  ship: string;
}

interface Props {
  open: boolean;
  onClose: () => void;
  variants: VariantOption[];
  activeVariantId: string;
  onSelectVariant: (id: string) => void;
}

/** Reduce-aware tick — skip when the user asked for reduced motion. */
function haptic(ms = 8): void {
  if (prefersReducedMotion()) return;
  fireHaptic(ms);
}

export function SettingsPanel({ open, onClose, variants, activeVariantId, onSelectVariant }: Props) {
  const { settings, setSettings, resetData, exportData } = useToolStore();
  const lang = settings.language;
  const reduced = prefersReducedMotion();

  const [visible, setVisible] = useState(false);
  const [drag, setDrag] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ y: number; t: number; id: number } | null>(null);
  const dialogRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const r = requestAnimationFrame(() => {
      if (open) {
        setDrag(0);
        setVisible(true);
      } else {
        setVisible(false);
      }
    });
    return () => cancelAnimationFrame(r);
  }, [open]);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  const onHandlePointerDown = (e: ReactPointerEvent) => {
    dragStart.current = { y: e.clientY, t: e.timeStamp, id: e.pointerId };
    setDragging(true);
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };
  const onHandlePointerMove = (e: ReactPointerEvent) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    setDrag(rubberBand(dy));
  };
  const onHandlePointerUp = (e: ReactPointerEvent) => {
    if (!dragStart.current || dragStart.current.id !== e.pointerId) return;
    const dy = e.clientY - dragStart.current.y;
    const dt = e.timeStamp - dragStart.current.t;
    const v = dt > 0 ? dy / dt : 0;
    dragStart.current = null;
    setDragging(false);
    if (shouldDismiss(dy, v)) {
      haptic();
      onClose();
    } else {
      setDrag(0);
    }
  };

  const exportNow = () => {
    haptic();
    const blob = new Blob([exportData()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'my-ai-universe.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  const resetNow = () => {
    if (typeof window !== 'undefined' && !window.confirm(t('settings.reset.confirm', lang))) return;
    haptic(16);
    resetData();
    onClose();
  };

  const setLang = (next: Language) => {
    if (next === lang) return;
    haptic();
    setSettings({ language: next });
  };

  const panelTransform = visible
    ? `translateY(${drag}px) scale(1)`
    : 'translateY(24px) scale(0.94)';

  return (
    <div
      className="fixed inset-0 z-40 flex items-end justify-center px-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:items-center"
      onClick={onClose}
    >
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
        aria-label={t('settings.title', lang)}
        className={cx('relative w-full max-w-md overflow-hidden', GLASS.panel, 'p-5 select-none')}
        style={{
          transform: panelTransform,
          opacity: visible ? 1 : 0,
          transition:
            dragging || reduced
              ? 'none'
              : `transform ${DURATION.sheet}ms ${EASE.sheet}, opacity ${DURATION.exit}ms ${EASE.out}`,
          willChange: 'transform, opacity',
        }}
        onClick={(e) => e.stopPropagation()}
      >
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
          <h2 className={cx(TYPE.title, TEXT.primary)}>{t('settings.title', lang)}</h2>
          <button
            type="button"
            onClick={onClose}
            onPointerDown={() => haptic()}
            aria-label={t('settings.close', lang)}
            className={cx(
              'flex h-11 w-11 items-center justify-center rounded-2xl transition active:scale-[0.96]',
              '[@media(hover:hover)]:hover:bg-white/10',
              FOCUS_RING,
            )}
          >
            <X className="h-5 w-5 text-white/70" aria-hidden />
          </button>
        </div>

        <div className="flex max-h-[60vh] flex-col gap-5 overflow-y-auto">
          {/* Visualization */}
          <section>
            <h3 className={cx(TYPE.eyebrow, TEXT.meta, 'mb-2')}>
              {t('settings.visualization', lang)}
            </h3>
            <div
              className="grid grid-cols-2 gap-1"
              role="radiogroup"
              aria-label={t('settings.visualization', lang)}
            >
              {variants.map((v) => {
                const active = v.id === activeVariantId;
                return (
                  <button
                    key={v.id}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => {
                      haptic();
                      onSelectVariant(v.id);
                    }}
                    className={cx(
                      'flex min-h-[44px] items-center justify-between rounded-xl px-3 py-2 text-left transition-[background-color,transform] duration-200 active:scale-[0.97]',
                      active
                        ? cx(ACCENT.fill, ACCENT.text)
                        : cx(TEXT.body, '[@media(hover:hover)]:hover:bg-white/10'),
                      FOCUS_RING,
                    )}
                    style={{ transitionTimingFunction: EASE.out }}
                  >
                    <span className={cx(TYPE.body, 'font-medium leading-tight')}>{v.ship}</span>
                    {active && <Check className="h-4 w-4 shrink-0" aria-hidden />}
                  </button>
                );
              })}
            </div>
          </section>

          {/* Language */}
          <section>
            <h3 className={cx(TYPE.eyebrow, TEXT.meta, 'mb-2')}>{t('settings.language', lang)}</h3>
            <div
              className={cx('flex gap-1 p-1', GLASS.chip)}
              role="radiogroup"
              aria-label={t('settings.language', lang)}
            >
              {(['en', 'ru'] as const).map((code) => {
                const active = lang === code;
                return (
                  <button
                    key={code}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => setLang(code)}
                    className={cx(
                      'min-h-[44px] flex-1 rounded-lg px-3 py-2 text-center font-medium transition-[background-color,transform] duration-200 active:scale-[0.97]',
                      TYPE.body,
                      active
                        ? cx(ACCENT.fill, ACCENT.text)
                        : cx(TEXT.secondary, '[@media(hover:hover)]:hover:bg-white/10'),
                      FOCUS_RING,
                    )}
                    style={{ transitionTimingFunction: EASE.out }}
                  >
                    {code === 'en' ? 'English' : 'Русский'}
                  </button>
                );
              })}
            </div>
          </section>

          {/* Data */}
          <section className="flex flex-col gap-2">
            <h3 className={cx(TYPE.eyebrow, TEXT.meta)}>{t('settings.data', lang)}</h3>
            <button
              type="button"
              onClick={exportNow}
              className={cx(
                'flex min-h-[44px] items-center gap-2 rounded-xl px-3 py-2 transition active:scale-[0.97]',
                TEXT.body,
                '[@media(hover:hover)]:hover:bg-white/10',
                FOCUS_RING,
              )}
            >
              <Download className="h-4 w-4" aria-hidden />
              <span className={TYPE.body}>{t('settings.export', lang)}</span>
            </button>
            <button
              type="button"
              onClick={resetNow}
              className={cx(
                'flex min-h-[44px] items-center gap-2 rounded-xl px-3 py-2 transition active:scale-[0.97]',
                'text-red-200/90 [@media(hover:hover)]:hover:bg-red-400/10',
                FOCUS_RING,
              )}
            >
              <Trash2 className="h-4 w-4" aria-hidden />
              <span className={TYPE.body}>{t('settings.reset', lang)}</span>
            </button>
          </section>

          {/* About */}
          <section>
            <h3 className={cx(TYPE.eyebrow, TEXT.meta, 'mb-1')}>{t('settings.about', lang)}</h3>
            <p className={cx(TYPE.chip, TEXT.secondary)}>{t('about.body', lang)}</p>
          </section>
        </div>
      </div>
    </div>
  );
}
