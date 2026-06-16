import { useCallback, useEffect, useRef, useState } from 'react';
import { useToolStore } from './useToolStore';
import { categoryById } from '../data/ai-tool-universe';
import { knowledgeFor } from './knowledge';
import { useInAppBrowser } from '../components/useInAppBrowser';

function initials(name: string): string {
  return name.split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('');
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function tap(): void {
  if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(8);
}

interface Props {
  toolId: string | null;
  onClose: () => void;
  onSelect: (id: string) => void;
}

/**
 * The rich "brand window": everything the hyperbrain knows about a tool —
 * killer features, what it's for, advantages, weaknesses, who uses it, and
 * pricing — plus connections and an in-app Open. Liquid glass, ≤ a third of
 * the screen on desktop, full-width sheet on phones.
 */
export function ToolDetail({ toolId, onClose, onSelect }: Props) {
  const { toolById, iconUrlFor } = useToolStore();
  const { openInApp } = useInAppBrowser();

  // mounted + visible state so the panel animates IN, and animates OUT
  // before it leaves the tree instead of popping.
  const [mountedId, setMountedId] = useState<string | null>(toolId);
  const [visible, setVisible] = useState(false);
  // live drag offset (px) while swiping to dismiss; null when idle.
  const [drag, setDrag] = useState<{ x: number; y: number } | null>(null);
  const [dragging, setDragging] = useState(false);
  // long-press "peek" on a connected tool chip.
  const [peekId, setPeekId] = useState<string | null>(null);
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
      setPeekId(null);
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
    closeTimer.current = window.setTimeout(() => setMountedId(null), reduce ? 0 : 280);
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
  const connections = tool.relationIds
    .map((id) => toolById.get(id))
    .filter((t): t is NonNullable<typeof t> => Boolean(t));

  const peekTool = peekId ? toolById.get(peekId) ?? null : null;

  return (
    <ToolDetailView
      key={mountedId}
      tool={tool}
      cat={cat}
      k={k}
      icon={icon}
      connections={connections}
      visible={visible}
      reduce={reduce}
      drag={drag}
      dragging={dragging}
      peekTool={peekTool}
      iconUrlFor={iconUrlFor}
      setDrag={setDrag}
      setDragging={setDragging}
      setPeekId={setPeekId}
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
  visible: boolean;
  reduce: boolean;
  drag: { x: number; y: number } | null;
  dragging: boolean;
  peekTool: Tool | null;
  iconUrlFor: ReturnType<typeof useToolStore>['iconUrlFor'];
  setDrag: (d: { x: number; y: number } | null) => void;
  setDragging: (d: boolean) => void;
  setPeekId: (id: string | null) => void;
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
  visible,
  reduce,
  drag,
  dragging,
  peekTool,
  iconUrlFor,
  setDrag,
  setDragging,
  setPeekId,
  onSelect,
  openInApp,
  requestClose,
}: ViewProps) {
  // Pointer drag-to-dismiss: follow the finger to the right / down, release
  // past a threshold to close, else spring back.
  const startRef = useRef<{ x: number; y: number } | null>(null);
  const dragRef = useRef<{ x: number; y: number } | null>(null);
  const movedRef = useRef(false);

  const onPointerDown = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      // ignore drags that begin on interactive controls or the scroll body.
      const el = e.target as HTMLElement;
      if (el.closest('[data-no-drag]')) return;
      if (e.pointerType === 'mouse') return; // touch / pen only — desktop uses hover
      startRef.current = { x: e.clientX, y: e.clientY };
      movedRef.current = false;
      (e.currentTarget as HTMLElement).setPointerCapture?.(e.pointerId);
    },
    [],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      const start = startRef.current;
      if (!start) return;
      const dx = e.clientX - start.x;
      const dy = e.clientY - start.y;
      // resist upward / leftward pulls — only dismiss toward right / down.
      const rx = dx > 0 ? dx : dx * 0.18;
      const ry = dy > 0 ? dy : dy * 0.18;
      if (!movedRef.current && Math.hypot(dx, dy) > 6) {
        movedRef.current = true;
        setDragging(true);
      }
      if (movedRef.current) {
        const next = { x: rx, y: ry };
        dragRef.current = next;
        setDrag(next);
      }
    },
    [setDrag, setDragging],
  );

  const endDrag = useCallback(() => {
    const d = dragRef.current;
    startRef.current = null;
    dragRef.current = null;
    setDragging(false);
    if (d && (d.x > 120 || d.y > 140)) {
      requestClose();
    } else {
      setDrag(null);
    }
    // small delay so the "released" flag clears after the spring-back tick.
    movedRef.current = false;
  }, [requestClose, setDrag, setDragging]);

  // panel transform: combine enter/exit state with live drag.
  const dist = drag ? Math.hypot(drag.x, drag.y) : 0;
  const dragOpacity = drag ? Math.max(0.35, 1 - dist / 520) : 1;
  const transform = drag
    ? `translate3d(${drag.x}px, ${drag.y}px, 0) scale(${Math.max(0.94, 1 - dist / 2600)})`
    : visible
      ? 'translate3d(0,0,0) scale(1)'
      : 'translate3d(16px, 8px, 0) scale(0.96)';

  const transition = dragging
    ? 'none'
    : reduce
      ? 'opacity 90ms linear'
      : 'transform 420ms cubic-bezier(0.22, 1, 0.36, 1), opacity 300ms ease';

  // stagger helper for sections / chips.
  const stagger = (i: number): React.CSSProperties =>
    reduce
      ? {}
      : {
          transition: 'opacity 360ms ease, transform 460ms cubic-bezier(0.22, 1, 0.36, 1)',
          transitionDelay: `${visible ? 70 + i * 42 : 0}ms`,
          opacity: visible ? 1 : 0,
          transform: visible ? 'translateY(0)' : 'translateY(10px)',
        };

  let sectionIndex = 0;
  const next = () => sectionIndex++;

  return (
    <div
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
      className="pointer-events-auto absolute right-4 top-20 bottom-4 z-20 flex w-[min(380px,calc(100vw-2rem))] flex-col overflow-hidden rounded-3xl border border-white/10 bg-white/[0.07] shadow-[0_24px_80px_rgba(0,0,0,0.55)] backdrop-blur-2xl ring-1 ring-inset ring-white/[0.08] [box-shadow:0_24px_80px_rgba(0,0,0,0.55),inset_0_1px_0_0_rgba(255,255,255,0.14)] [will-change:transform]"
    >
      {/* grab affordance for swipe-to-dismiss on touch */}
      <div className="pointer-events-none absolute left-1/2 top-1.5 h-1 w-9 -translate-x-1/2 rounded-full bg-white/20 lg:hidden" />

      <div className="flex items-center gap-3 border-b border-white/10 p-4">
        <div
          className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-2xl text-sm font-semibold text-white shadow-[inset_0_1px_0_0_rgba(255,255,255,0.18)] transition-transform duration-500"
          style={{
            background: cat?.color ?? '#3a3f55',
            transform: visible ? 'scale(1)' : 'scale(0.8)',
            transitionTimingFunction: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
          }}
        >
          {icon ? <img src={icon} alt="" className="h-full w-full object-cover" /> : initials(tool.name)}
        </div>
        <div className="min-w-0 flex-1" style={stagger(next())}>
          <div className="truncate text-base font-semibold text-white">{tool.name}</div>
          <div className="mt-0.5 flex items-center gap-1.5 text-[11px] text-white/55">
            <span className="rounded-full px-2 py-0.5 font-medium" style={{ background: `${cat?.color ?? '#666'}33`, color: cat?.color ?? '#fff' }}>{cat?.name ?? tool.category}</span>
            <span className="capitalize">· {tool.stage}</span>
          </div>
        </div>
        <button
          type="button"
          data-no-drag
          onClick={requestClose}
          aria-label="Close"
          className="flex h-10 w-10 items-center justify-center rounded-xl text-white/50 transition duration-150 hover:bg-white/10 hover:text-white active:scale-90 active:bg-white/15"
        >
          ✕
        </button>
      </div>

      <div data-no-drag className="flex-1 space-y-4 overflow-y-auto p-4 text-sm [scrollbar-width:thin]">
        <div style={stagger(next())}>
          <Section title="What it does">
            <p className="text-white/75">{k?.whatFor || tool.summary}</p>
          </Section>
        </div>

        {k?.enriched && k.killerFeatures.length > 0 ? (
          <div style={stagger(next())}>
            <Section title="Killer features">
              <ul className="space-y-1">
                {k.killerFeatures.map((f, i) => (
                  <li
                    key={f}
                    className="flex gap-2 text-white/75"
                    style={
                      reduce
                        ? undefined
                        : {
                            transition: 'opacity 320ms ease, transform 380ms cubic-bezier(0.22,1,0.36,1)',
                            transitionDelay: `${visible ? 180 + i * 32 : 0}ms`,
                            opacity: visible ? 1 : 0,
                            transform: visible ? 'translateX(0)' : 'translateX(-6px)',
                          }
                    }
                  >
                    <span className="text-white/40">▸</span>{f}
                  </li>
                ))}
              </ul>
            </Section>
          </div>
        ) : null}

        {k?.enriched && (k.advantages.length > 0 || k.weaknesses.length > 0) ? (
          <div className="grid grid-cols-2 gap-3" style={stagger(next())}>
            {k.advantages.length > 0 ? (
              <Section title="Strengths"><ul className="space-y-1">{k.advantages.map((a) => <li key={a} className="text-emerald-300/80">+ {a}</li>)}</ul></Section>
            ) : null}
            {k.weaknesses.length > 0 ? (
              <Section title="Watch-outs"><ul className="space-y-1">{k.weaknesses.map((w) => <li key={w} className="text-amber-300/75">– {w}</li>)}</ul></Section>
            ) : null}
          </div>
        ) : null}

        {k?.enriched && k.whoUses ? (
          <div style={stagger(next())}>
            <Section title="Who uses it"><p className="text-white/75">{k.whoUses}</p></Section>
          </div>
        ) : null}

        <div style={stagger(next())}>
          <Section title="Pricing">
            <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-3 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.06)]">
              <div className="text-xs font-medium uppercase tracking-wide text-white/45">{k?.pricing.model ?? 'unknown'}</div>
              <div className="mt-0.5 text-white/80">{k?.pricing.summary ?? 'Pricing not yet researched.'}</div>
            </div>
          </Section>
        </div>

        {connections.length > 0 ? (
          <div style={stagger(next())}>
            <Section title={`Connected to · ${connections.length}`}>
              <div className="flex flex-wrap gap-1.5">
                {connections.map((c, i) => (
                  <ConnectionChip
                    key={c.id}
                    tool={c}
                    index={i}
                    visible={visible}
                    reduce={reduce}
                    onSelect={onSelect}
                    onPeek={setPeekId}
                  />
                ))}
              </div>
            </Section>
          </div>
        ) : null}
      </div>

      {tool.url ? (
        <div className="border-t border-white/10 p-3" style={stagger(next())}>
          <button
            type="button"
            data-no-drag
            onClick={() => {
              tap();
              openInApp(tool.url as string, tool.name);
            }}
            className="group relative w-full overflow-hidden rounded-2xl bg-white/90 py-2.5 text-sm font-semibold text-black shadow-[0_8px_24px_rgba(0,0,0,0.35)] transition duration-150 hover:bg-white active:scale-[0.98] active:brightness-95"
          >
            <span className="pointer-events-none absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-black/[0.06] to-transparent transition-transform duration-700 group-hover:translate-x-full" />
            Open {tool.name} ↗
          </button>
        </div>
      ) : null}

      {/* long-press peek bubble */}
      <PeekBubble tool={peekTool} icon={peekTool ? iconUrlFor(peekTool, 96) : undefined} reduce={reduce} onClose={() => setPeekId(null)} />
    </div>
  );
}

function ConnectionChip({
  tool,
  index,
  visible,
  reduce,
  onSelect,
  onPeek,
}: {
  tool: Tool;
  index: number;
  visible: boolean;
  reduce: boolean;
  onSelect: (id: string) => void;
  onPeek: (id: string | null) => void;
}) {
  const pressTimer = useRef<number | null>(null);
  const longFired = useRef(false);

  const clearPress = useCallback(() => {
    if (pressTimer.current) {
      window.clearTimeout(pressTimer.current);
      pressTimer.current = null;
    }
  }, []);

  const onPressStart = useCallback(() => {
    longFired.current = false;
    pressTimer.current = window.setTimeout(() => {
      longFired.current = true;
      tap();
      onPeek(tool.id);
    }, 420);
  }, [onPeek, tool.id]);

  const onClick = useCallback(() => {
    if (longFired.current) {
      longFired.current = false;
      return; // long-press already handled — don't also navigate
    }
    tap();
    onSelect(tool.id);
  }, [onSelect, tool.id]);

  return (
    <button
      type="button"
      data-no-drag
      onClick={onClick}
      onPointerDown={onPressStart}
      onPointerUp={clearPress}
      onPointerLeave={clearPress}
      onPointerCancel={clearPress}
      onContextMenu={(e) => e.preventDefault()}
      style={
        reduce
          ? undefined
          : {
              transition: 'opacity 320ms ease, transform 420ms cubic-bezier(0.22,1,0.36,1)',
              transitionDelay: `${visible ? 200 + index * 28 : 0}ms`,
              opacity: visible ? 1 : 0,
              transform: visible ? 'scale(1)' : 'scale(0.85)',
            }
      }
      className="min-h-[40px] select-none rounded-xl border border-white/10 bg-white/[0.05] px-2.5 py-1 text-xs text-white/75 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.07)] transition-[background,transform,color] duration-150 hover:-translate-y-0.5 hover:bg-white/[0.12] hover:text-white active:scale-95 active:bg-white/20"
    >
      {tool.name}
    </button>
  );
}

function PeekBubble({
  tool,
  icon,
  reduce,
  onClose,
}: {
  tool: Tool | null;
  icon: string | undefined;
  reduce: boolean;
  onClose: () => void;
}) {
  const [mounted, setMounted] = useState<Tool | null>(tool);
  const [shown, setShown] = useState(false);
  const [prevTool, setPrevTool] = useState<Tool | null>(tool);

  // adopt / dismiss during render (avoids synchronous setState in an effect).
  if (tool !== prevTool) {
    setPrevTool(tool);
    if (tool) {
      setMounted(tool);
      setShown(false);
    } else {
      setShown(false);
    }
  }

  useEffect(() => {
    if (tool) {
      const raf = requestAnimationFrame(() => setShown(true));
      return () => cancelAnimationFrame(raf);
    }
    const t = window.setTimeout(() => setMounted(null), reduce ? 0 : 200);
    return () => window.clearTimeout(t);
  }, [tool, reduce]);

  // auto-dismiss the peek after a beat.
  useEffect(() => {
    if (!tool) return;
    const t = window.setTimeout(onClose, 2200);
    return () => window.clearTimeout(t);
  }, [tool, onClose]);

  if (!mounted) return null;
  const cat = categoryById.get(mounted.category);

  return (
    <button
      type="button"
      data-no-drag
      onClick={onClose}
      aria-label={`Peek ${mounted.name}`}
      className="absolute inset-x-3 bottom-3 z-30 flex cursor-pointer items-center gap-3 rounded-2xl border border-white/15 bg-white/[0.1] p-3 text-left shadow-[0_18px_50px_rgba(0,0,0,0.55),inset_0_1px_0_0_rgba(255,255,255,0.16)] backdrop-blur-2xl"
      style={{
        transition: reduce ? 'opacity 90ms linear' : 'transform 360ms cubic-bezier(0.34,1.56,0.64,1), opacity 240ms ease',
        opacity: shown ? 1 : 0,
        transform: shown ? 'translateY(0) scale(1)' : 'translateY(14px) scale(0.94)',
      }}
    >
      <div
        className="flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-xl text-xs font-semibold text-white shadow-[inset_0_1px_0_0_rgba(255,255,255,0.18)]"
        style={{ background: cat?.color ?? '#3a3f55' }}
      >
        {icon ? <img src={icon} alt="" className="h-full w-full object-cover" /> : initials(mounted.name)}
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-semibold text-white">{mounted.name}</div>
        <div className="truncate text-[11px] text-white/60">{mounted.summary}</div>
      </div>
    </button>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="mb-1.5 text-[10px] font-medium uppercase tracking-wider text-white/35">{title}</div>
      {children}
    </div>
  );
}
