import { useCallback, useEffect, useId, useRef, useState } from 'react';
import { ArrowUpRight, X } from 'lucide-react';
import { useToolStore } from './useToolStore';
import { categoryById } from '../data/ai-tool-universe';
import { knowledgeFor } from './knowledge';
import type { InferredEdge } from '../lib/relationship-intelligence.types';
import { connectedBecause } from './relationshipReason';
import { useInAppBrowser } from '../components/useInAppBrowser';
import {
  ACCENT,
  cx,
  DISMISS,
  DURATION,
  EASE,
  FOCUS_RING,
  GLASS,
  HOVER_LIFT,
  RADIUS,
  SEMANTIC,
  STAGGER,
  TEXT,
  TYPE,
  categoryColor,
  categoryTint,
} from './designSystem';

function initials(name: string): string {
  return name.split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('');
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function tap(): void {
  if (prefersReducedMotion()) return;
  if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(8);
}

const FOCUSABLE_SELECTOR = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[contenteditable="true"]',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

function focusableElements(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter((el) => {
    if (el.closest('[inert]')) return false;
    const style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden' && el.getClientRects().length > 0;
  });
}

/** Derive a best-effort destination for url-less seed tools (logoDomain → name). */
function derivedUrl(tool: Tool): string | null {
  if (tool.url) return tool.url;
  if (tool.logoDomain) return `https://${tool.logoDomain}`;
  return null;
}

interface Props {
  toolId: string | null;
  onClose: () => void;
  onSelect: (id: string) => void;
}

/**
 * The rich "brand window": everything the hyperbrain knows about a tool —
 * killer features, what it's for, advantages, weaknesses, who uses it, and
 * pricing — plus connections and an in-app Open. A floating glass bottom-sheet
 * on phones, right column on desktop. Liquid glass, App-Store-grade.
 */
export function ToolDetail({ toolId, onClose, onSelect }: Props) {
  const { toolById, iconUrlFor, edgesFor } = useToolStore();
  const { openInApp } = useInAppBrowser();

  // mounted + visible state so the panel animates IN, and animates OUT
  // before it leaves the tree instead of popping.
  const [mountedId, setMountedId] = useState<string | null>(toolId);
  const [visible, setVisible] = useState(false);
  // live drag offset (px) while swiping to dismiss; null when idle.
  const [drag, setDrag] = useState<{ y: number; t: number } | null>(null);
  const [dragging, setDragging] = useState(false);
  // track the last toolId we reacted to, so we can adjust state during render
  // (React's "store info from previous render" pattern) instead of in an effect.
  const [prevToolId, setPrevToolId] = useState<string | null>(toolId);

  const closeTimer = useRef<number | null>(null);
  const reduce = prefersReducedMotion();

  // Adopt a newly opened tool synchronously during render so the panel is
  // mounted (invisible) on this pass and animates in on the next frame.
  if (toolId !== prevToolId) {
    setPrevToolId(toolId);
    if (toolId) {
      setMountedId(toolId);
      setVisible(false);
      setDrag(null);
    } else {
      // close requested — play the exit, the effect schedules unmount.
      setVisible(false);
    }
  }

  // Flip to visible after mount (enter), or schedule unmount after exit.
  useEffect(() => {
    if (toolId) {
      if (closeTimer.current) {
        window.clearTimeout(closeTimer.current);
        closeTimer.current = null;
      }
      const raf = requestAnimationFrame(() => setVisible(true));
      return () => cancelAnimationFrame(raf);
    }
    closeTimer.current = window.setTimeout(() => setMountedId(null), reduce ? 0 : DURATION.exit);
    return () => {
      if (closeTimer.current) window.clearTimeout(closeTimer.current);
    };
  }, [toolId, reduce]);

  const requestClose = useCallback(() => {
    tap();
    onClose();
  }, [onClose]);

  if (!mountedId) return null;
  const tool = toolById.get(mountedId);
  if (!tool) return null;

  const cat = categoryById.get(tool.category);
  const k = knowledgeFor(tool.id);
  const icon = iconUrlFor(tool, 96);
  const inferredEdges = edgesFor(tool.id);
  const edgeByToId = new Map(inferredEdges.map((e) => [e.toId, e]));
  // Inferred edges may point at tools not in the curated relationIds list —
  // surface them too so "Connected because …" reasons aren't hidden.
  const connectionIds = Array.from(new Set([...tool.relationIds, ...inferredEdges.map((e) => e.toId)]));
  const connections = connectionIds
    .map((id) => toolById.get(id))
    .filter((t): t is NonNullable<typeof t> => Boolean(t));

  return (
    <ToolDetailView
      key={mountedId}
      tool={tool}
      cat={cat}
      k={k}
      icon={icon}
      connections={connections}
      edgeByToId={edgeByToId}
      visible={visible}
      reduce={reduce}
      drag={drag}
      dragging={dragging}
      iconUrlFor={iconUrlFor}
      setDrag={setDrag}
      setDragging={setDragging}
      onSelect={onSelect}
      openInApp={openInApp}
      requestClose={requestClose}
    />
  );
}

type Tool = NonNullable<ReturnType<ReturnType<typeof useToolStore>['toolById']['get']>>;
type Cat = ReturnType<typeof categoryById.get>;
type Knowledge = ReturnType<typeof knowledgeFor>;

interface ViewProps {
  tool: Tool;
  cat: Cat;
  k: Knowledge;
  icon: string | undefined;
  connections: Tool[];
  edgeByToId: Map<string, InferredEdge>;
  visible: boolean;
  reduce: boolean;
  drag: { y: number; t: number } | null;
  dragging: boolean;
  iconUrlFor: ReturnType<typeof useToolStore>['iconUrlFor'];
  setDrag: (d: { y: number; t: number } | null) => void;
  setDragging: (d: boolean) => void;
  onSelect: (id: string) => void;
  openInApp: (url: string, name: string) => void;
  requestClose: () => void;
}

function ToolDetailView({
  tool,
  cat,
  k,
  icon,
  connections,
  edgeByToId,
  visible,
  reduce,
  drag,
  dragging,
  iconUrlFor,
  setDrag,
  setDragging,
  onSelect,
  openInApp,
  requestClose,
}: ViewProps) {
  const panelRef = useRef<HTMLDivElement | null>(null);
  const titleId = useId();

  // Down-only drag-to-dismiss (unified DISMISS contract): follow the finger
  // down, release past a distance OR a downward flick velocity to close.
  const startRef = useRef<{ y: number; t: number } | null>(null);
  const lastRef = useRef<{ y: number; t: number } | null>(null);
  const dragRef = useRef<{ y: number; t: number } | null>(null);
  const velRef = useRef(0);
  const movedRef = useRef(false);

  // Dialog semantics: focus the panel on mount, trap keyboard focus, restore focus.
  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null;
    const raf = requestAnimationFrame(() => panelRef.current?.focus());
    const focusFirst = () => {
      const panel = panelRef.current;
      if (!panel) return;
      (focusableElements(panel)[0] ?? panel).focus({ preventScroll: true });
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        requestClose();
        return;
      }

      if (e.key !== 'Tab') return;
      const panel = panelRef.current;
      if (!panel) return;

      const focusable = focusableElements(panel);
      if (focusable.length === 0) {
        e.preventDefault();
        panel.focus({ preventScroll: true });
        return;
      }

      const active = document.activeElement;
      if (!(active instanceof HTMLElement) || !panel.contains(active)) {
        e.preventDefault();
        focusable[0].focus({ preventScroll: true });
        return;
      }

      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey && (active === first || active === panel)) {
        e.preventDefault();
        last.focus({ preventScroll: true });
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus({ preventScroll: true });
      }
    };
    const onFocusIn = (e: FocusEvent) => {
      const panel = panelRef.current;
      if (!panel) return;
      if (e.target instanceof Node && panel.contains(e.target)) return;
      focusFirst();
    };
    document.addEventListener('keydown', onKey, true);
    document.addEventListener('focusin', onFocusIn, true);
    return () => {
      cancelAnimationFrame(raf);
      document.removeEventListener('keydown', onKey, true);
      document.removeEventListener('focusin', onFocusIn, true);
      if (opener?.isConnected) opener.focus({ preventScroll: true });
    };
  }, [requestClose]);

  const onPointerDown = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      // ignore drags that begin on interactive controls or the scroll body.
      const el = e.target as HTMLElement;
      if (el.closest('[data-no-drag]')) return;
      if (e.pointerType === 'mouse') return; // touch / pen only — desktop uses hover
      startRef.current = { y: e.clientY, t: e.timeStamp };
      lastRef.current = startRef.current;
      velRef.current = 0;
      movedRef.current = false;
      (e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
    },
    [],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      const start = startRef.current;
      if (!start) return;
      const dy = e.clientY - start.y;
      // down-only: resist (rubber-band) any upward pull.
      const ry = dy > 0 ? dy : dy * DISMISS.resistance;
      const last = lastRef.current;
      if (last) {
        const dt = e.timeStamp - last.t;
        if (dt > 0) velRef.current = (e.clientY - last.y) / dt;
      }
      lastRef.current = { y: e.clientY, t: e.timeStamp };
      if (!movedRef.current && Math.abs(dy) > 6) {
        movedRef.current = true;
        setDragging(true);
      }
      if (movedRef.current) {
        const nextDrag = { y: ry, t: e.timeStamp };
        dragRef.current = nextDrag;
        setDrag(nextDrag);
      }
    },
    [setDrag, setDragging],
  );

  const endDrag = useCallback(() => {
    const d = dragRef.current;
    const v = velRef.current;
    startRef.current = null;
    lastRef.current = null;
    dragRef.current = null;
    setDragging(false);
    // commit on distance OR a downward flick velocity (unified contract).
    if (d && (d.y > DISMISS.distancePx || (v > DISMISS.velocity && d.y > 24))) {
      requestClose();
    } else {
      setDrag(null);
    }
    movedRef.current = false;
  }, [requestClose, setDrag, setDragging]);

  // panel transform: combine enter/exit state with live downward drag.
  const dy = drag ? Math.max(0, drag.y) : 0;
  const dragOpacity = drag ? Math.max(0.4, 1 - dy / 480) : 1;
  const transform = drag
    ? `translate3d(0, ${drag.y}px, 0) scale(${Math.max(0.94, 1 - dy / 2600)})`
    : visible
      ? 'translate3d(0,0,0) scale(1)'
      : 'translate3d(0, 16px, 0) scale(0.96)';

  const transition = dragging
    ? 'none'
    : reduce
      ? `opacity ${DURATION.press}ms linear`
      : `transform ${DURATION.sheet}ms ${EASE.sheet}, opacity ${DURATION.enter}ms ease`;

  const accent = categoryColor(tool.category);

  // stagger helper for sections (cap stagger count at 6 per the spec).
  const stagger = (i: number): React.CSSProperties =>
    reduce
      ? {}
      : {
          transition: `opacity ${DURATION.enter}ms ease, transform ${DURATION.turn}ms ${EASE.out}`,
          transitionDelay: `${visible ? 70 + Math.min(i, 6) * STAGGER.section : 0}ms`,
          opacity: visible ? 1 : 0,
          transform: visible ? 'translateY(0)' : 'translateY(10px)',
        };

  let sectionIndex = 0;
  const next = () => sectionIndex++;

  const open = derivedUrl(tool);

  return (
    <div
      ref={panelRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      tabIndex={-1}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={endDrag}
      onPointerCancel={endDrag}
      style={{
        transform,
        opacity: (visible ? 1 : 0) * dragOpacity,
        transition,
        touchAction: 'pan-y',
      }}
      className={cx(
        GLASS.panel,
        FOCUS_RING,
        'pointer-events-auto absolute z-20 flex flex-col overflow-hidden outline-none',
        'right-[max(1rem,env(safe-area-inset-right))] top-20',
        'bottom-[max(1rem,env(safe-area-inset-bottom))]',
        'w-[min(380px,calc(100vw-2rem))] select-none [-webkit-touch-callout:none] [will-change:transform]',
      )}
    >
      {/* grab affordance for swipe-to-dismiss on touch */}
      <div className="pointer-events-none absolute left-1/2 top-1.5 h-1 w-9 -translate-x-1/2 rounded-full bg-white/20 lg:hidden" />

      {/* Hero — plate + name + category pill + close (no divider, whitespace) */}
      <div className="flex items-center gap-3 px-4 pb-3 pt-5">
        <div
          className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-2xl text-sm font-semibold text-white"
          style={{
            background: accent,
            boxShadow: `inset 0 1px 0 0 rgba(255,255,255,0.18), 0 10px 26px -8px ${categoryTint(tool.category, '99')}`,
            transform: visible ? 'scale(1)' : 'scale(0.8)',
            transition: reduce ? 'none' : `transform ${DURATION.sheet}ms ${EASE.back}`,
          }}
        >
          {icon ? <img src={icon} alt="" className="h-full w-full object-cover" /> : initials(tool.name)}
        </div>
        <div className="min-w-0 flex-1" style={stagger(next())}>
          <div id={titleId} className={cx('truncate', TYPE.title, TEXT.primary)}>{tool.name}</div>
          <div className={cx('mt-1 flex items-center gap-1.5', TYPE.chip, TEXT.meta)}>
            <span
              className="rounded-full px-2 py-0.5 font-medium"
              style={{ background: categoryTint(tool.category, '33'), color: accent }}
            >
              {cat?.name ?? tool.category}
            </span>
            <span className="capitalize">· {tool.stage}</span>
          </div>
        </div>
        <button
          type="button"
          data-no-drag
          onClick={requestClose}
          aria-label="Close"
          className={cx(
            'flex h-11 w-11 items-center justify-center text-white/55',
            RADIUS.control, FOCUS_RING,
            'transition duration-150 hover:bg-white/10 hover:text-white active:scale-90 active:bg-white/15',
          )}
        >
          <X className="h-5 w-5" aria-hidden="true" />
        </button>
      </div>

      <div
        data-no-drag
        className={cx('flex-1 space-y-6 overflow-y-auto overscroll-contain px-4 pb-5 pt-1', TYPE.body, '[scrollbar-width:thin]')}
      >
        <div style={stagger(next())}>
          <Section title="What it does">
            <ClampText text={k?.whatFor || tool.summary} reduce={reduce} />
          </Section>
        </div>

        {k?.enriched && k.killerFeatures.length > 0 ? (
          <div style={stagger(next())}>
            <Section title="Killer features">
              <ul className="space-y-1.5">
                {k.killerFeatures.map((f, i) => (
                  <li
                    key={f}
                    className={cx('flex gap-2', TEXT.body)}
                    style={
                      reduce
                        ? undefined
                        : {
                            transition: `opacity ${DURATION.enter}ms ease, transform ${DURATION.turn}ms ${EASE.out}`,
                            transitionDelay: `${visible ? 180 + Math.min(i, 6) * 32 : 0}ms`,
                            opacity: visible ? 1 : 0,
                            transform: visible ? 'translateX(0)' : 'translateX(-6px)',
                          }
                    }
                  >
                    <span aria-hidden="true" style={{ color: accent }} className="mt-0.5 shrink-0">▸</span>
                    <span>{f}</span>
                  </li>
                ))}
              </ul>
            </Section>
          </div>
        ) : null}

        {k?.enriched && (k.advantages.length > 0 || k.weaknesses.length > 0) ? (
          <div className="grid grid-cols-2 gap-4" style={stagger(next())}>
            {k.advantages.length > 0 ? (
              <Section title="Strengths">
                <ul className="space-y-1">
                  {k.advantages.map((a) => (
                    <li key={a} className={cx('flex gap-1.5', SEMANTIC.positive)}>
                      <span aria-hidden="true">+</span>
                      <span>{a}</span>
                    </li>
                  ))}
                </ul>
              </Section>
            ) : null}
            {k.weaknesses.length > 0 ? (
              <Section title="Watch-outs">
                <ul className="space-y-1">
                  {k.weaknesses.map((w) => (
                    <li key={w} className={cx('flex gap-1.5', SEMANTIC.caution)}>
                      <span aria-hidden="true">–</span>
                      <span>{w}</span>
                    </li>
                  ))}
                </ul>
              </Section>
            ) : null}
          </div>
        ) : null}

        {k?.enriched && k.whoUses ? (
          <div style={stagger(next())}>
            <Section title="Who uses it"><p className={TEXT.body}>{k.whoUses}</p></Section>
          </div>
        ) : null}

        {/* Pricing — hidden when un-enriched (no empty "not researched" stub). */}
        {k?.enriched && k.pricing.model !== 'unknown' ? (
          <div style={stagger(next())}>
            <Section title="Pricing">
              <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-3 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.06)]">
                <div className={cx(TYPE.eyebrow, TEXT.meta)}>{k.pricing.model}</div>
                <div className={cx('mt-1', TEXT.body)}>{k.pricing.summary}</div>
              </div>
            </Section>
          </div>
        ) : null}

        {connections.length > 0 ? (
          <div style={stagger(next())}>
            <Section title={`Connected to · ${connections.length}`}>
              <div className="flex flex-wrap gap-2">
                {connections.map((c, i) => (
                  <ConnectionChip
                    key={c.id}
                    tool={c}
                    icon={iconUrlFor(c, 48)}
                    edge={edgeByToId.get(c.id)}
                    index={i}
                    visible={visible}
                    reduce={reduce}
                    onSelect={onSelect}
                  />
                ))}
              </div>
            </Section>
          </div>
        ) : null}
      </div>

      {/* Primary CTA — bottom-pinned; derived URL for url-less seed tools. */}
      <div className="px-4 pb-[max(1rem,env(safe-area-inset-bottom))] pt-3" style={stagger(next())}>
        {open ? (
          <button
            type="button"
            data-no-drag
            onClick={() => {
              tap();
              openInApp(open, tool.name);
            }}
            className={cx(
              'group relative flex w-full items-center justify-center gap-1.5 overflow-hidden bg-white/90 py-2.5',
              RADIUS.control, TYPE.body, FOCUS_RING,
              'font-semibold text-black shadow-[0_8px_24px_rgba(0,0,0,0.35)]',
              'transition duration-150 hover:bg-white active:scale-[0.98] active:brightness-95',
            )}
          >
            <span className="pointer-events-none absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-black/[0.06] to-transparent transition-transform duration-700 group-hover:translate-x-full" />
            <span>Open {tool.name}</span>
            <ArrowUpRight className="h-4 w-4" aria-hidden="true" />
          </button>
        ) : (
          <div
            className={cx(
              'flex w-full items-center justify-center py-2.5',
              RADIUS.control, TYPE.body, TEXT.meta,
              'cursor-default border border-white/10 bg-white/[0.04]',
            )}
          >
            Link coming soon
          </div>
        )}
      </div>
    </div>
  );
}

/** Description with a 3-line clamp + inline "more" that animates open. */
function ClampText({ text, reduce }: { text: string; reduce: boolean }) {
  const [expanded, setExpanded] = useState(false);
  const [clampable, setClampable] = useState(false);
  const ref = useRef<HTMLParagraphElement | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setClampable(el.scrollHeight - el.clientHeight > 4);
  }, [text]);

  return (
    <div>
      <p
        ref={ref}
        className={cx(TEXT.body, !expanded && 'line-clamp-3')}
        style={reduce ? undefined : { transition: `max-height ${DURATION.enter}ms ${EASE.out}` }}
      >
        {text}
      </p>
      {clampable ? (
        <button
          type="button"
          data-no-drag
          onClick={() => setExpanded((v) => !v)}
          className={cx('mt-1', TYPE.chip, ACCENT.text, FOCUS_RING, 'rounded font-medium active:scale-[0.96]')}
        >
          {expanded ? 'Less' : 'More'}
        </button>
      ) : null}
    </div>
  );
}

function ConnectionChip({
  tool,
  icon,
  edge,
  index,
  visible,
  reduce,
  onSelect,
}: {
  tool: Tool;
  icon: string | undefined;
  edge: InferredEdge | undefined;
  index: number;
  visible: boolean;
  reduce: boolean;
  onSelect: (id: string) => void;
}) {
  const [revealed, setRevealed] = useState(false);
  const captionId = useId();

  const onClick = useCallback(() => {
    tap();
    onSelect(tool.id);
  }, [onSelect, tool.id]);

  const onToggle = useCallback(() => {
    tap();
    setRevealed((v) => !v);
  }, []);

  return (
    <div
      className="flex min-w-0 flex-col gap-1"
      style={
        reduce
          ? undefined
          : {
              transition: `opacity ${DURATION.enter}ms ease, transform ${DURATION.peek}ms ${EASE.out}`,
              transitionDelay: `${visible ? 200 + Math.min(index, 6) * STAGGER.chip : 0}ms`,
              opacity: visible ? 1 : 0,
              transform: visible ? 'scale(1)' : 'scale(0.9)',
            }
      }
    >
      <div className="flex items-center gap-1">
        <button
          type="button"
          data-no-drag
          onClick={onClick}
          className={cx(
            'flex min-h-[44px] select-none items-center gap-2 px-2.5 py-1.5',
            GLASS.chip, TYPE.chip, TEXT.body, FOCUS_RING, HOVER_LIFT,
            'shadow-[inset_0_1px_0_0_rgba(255,255,255,0.07)]',
            'transition-[background,transform,color] duration-150 hover:bg-white/[0.12] hover:text-white active:scale-95 active:bg-white/20',
          )}
        >
          {icon ? (
            <img src={icon} alt="" className="h-4 w-4 shrink-0 rounded" />
          ) : (
            <span
              aria-hidden="true"
              className="flex h-4 w-4 shrink-0 items-center justify-center rounded text-[8px] font-semibold text-white"
              style={{ background: categoryColor(tool.category) }}
            >
              {initials(tool.name)[0] ?? '?'}
            </span>
          )}
          <span className="truncate">{tool.name}</span>
        </button>
        {edge ? (
          <button
            type="button"
            data-no-drag
            onClick={onToggle}
            aria-expanded={revealed}
            aria-controls={captionId}
            aria-label={`Why connected to ${tool.name}`}
            className={cx(
              'flex h-11 w-7 shrink-0 items-center justify-center text-white/45',
              RADIUS.control, FOCUS_RING,
              'transition duration-150 hover:bg-white/10 hover:text-white active:scale-90',
            )}
          >
            <span aria-hidden="true" className={cx(TYPE.chip)}>{revealed ? '×' : '?'}</span>
          </button>
        ) : null}
      </div>
      {edge ? (
        <div
          id={captionId}
          className="overflow-hidden"
          style={
            reduce
              ? { maxHeight: revealed ? '64px' : '0px' }
              : {
                  maxHeight: revealed ? '64px' : '0px',
                  transition: `max-height ${DURATION.enter}ms ${EASE.out}`,
                }
          }
        >
          <p className={cx('px-1 pt-0.5', TYPE.chip, TEXT.meta)}>{connectedBecause(edge)}</p>
        </div>
      ) : null}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <div className={cx('mb-2', TYPE.eyebrow, TEXT.meta)}>{title}</div>
      {children}
    </div>
  );
}
