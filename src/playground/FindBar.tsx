import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type FormEvent,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import { useToolStore } from './useToolStore';
import { runQuery } from './query';
import type { AITool } from '../data/ai-tool-universe';

interface Turn {
  id: number;
  q: string;
  answer: string;
  matches: AITool[];
}

interface Props {
  onOpenTool: (id: string) => void;
}

const haptic = (ms = 8) => {
  if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
    navigator.vibrate(ms);
  }
};

const usePrefersReducedMotion = (): boolean => {
  const [reduced, setReduced] = useState(
    () => typeof window !== 'undefined' && !!window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  );
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = (e: MediaQueryListEvent) => setReduced(e.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);
  return reduced;
};

/**
 * ChatGPT-style "ask the hyperbrain" bar pinned to the bottom. Type a need
 * ("find me something to build a database fast") and the on-device query
 * engine answers in a thread (capped to a third of the screen), with the
 * matched tools as chips you tap to open their brand window. The empty
 * state surfaces recently-added tools as quick history.
 */
export function FindBar({ onOpenTool }: Props) {
  const { tools } = useToolStore();
  const [text, setText] = useState('');
  const [turns, setTurns] = useState<Turn[]>([]);
  const [focused, setFocused] = useState(false);
  const [peekId, setPeekId] = useState<string | null>(null);
  const nextId = useRef(1);
  const reduce = usePrefersReducedMotion();

  // Swipe-to-dismiss drag state for the conversation thread.
  const [dragY, setDragY] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ y: number; active: boolean } | null>(null);
  const scrollRef = useRef<HTMLDivElement | null>(null);

  // Long-press handling for chips (quick peek / secondary action).
  const pressTimer = useRef<number | null>(null);
  const longFired = useRef(false);

  const history = useMemo(() => tools.filter((t) => t.userAdded).slice(-6).reverse(), [tools]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const q = text.trim();
    if (!q) return;
    haptic(10);
    const { answer, matches } = runQuery(q, tools);
    setTurns((prev) => [...prev, { id: nextId.current++, q, answer, matches }]);
    setText('');
  };

  const openTool = useCallback(
    (id: string) => {
      if (longFired.current) {
        longFired.current = false;
        return;
      }
      haptic(8);
      onOpenTool(id);
    },
    [onOpenTool],
  );

  const clearPress = useCallback(() => {
    if (pressTimer.current !== null) {
      window.clearTimeout(pressTimer.current);
      pressTimer.current = null;
    }
  }, []);

  const startPress = useCallback(
    (id: string) => {
      longFired.current = false;
      clearPress();
      pressTimer.current = window.setTimeout(() => {
        longFired.current = true;
        haptic(16);
        setPeekId(id);
      }, 420);
    },
    [clearPress],
  );

  useEffect(() => () => clearPress(), [clearPress]);

  // Auto-scroll thread to the latest turn when one is added.
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: reduce ? 'auto' : 'smooth' });
  }, [turns, reduce]);

  // --- swipe-down-to-dismiss the conversation thread ---
  const onThreadPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (e.pointerType === 'mouse') return;
    const el = scrollRef.current;
    // Only start a dismiss drag when the thread is scrolled to the top.
    if (el && el.scrollTop > 2) return;
    dragStart.current = { y: e.clientY, active: true };
    setDragging(true);
  };

  const onThreadPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragStart.current?.active) return;
    const dy = e.clientY - dragStart.current.y;
    if (dy <= 0) {
      setDragY(0);
      return;
    }
    setDragY(dy);
  };

  const endThreadDrag = () => {
    if (!dragStart.current?.active) return;
    dragStart.current = null;
    setDragging(false);
    if (dragY > 90) {
      haptic(12);
      setTurns([]);
    }
    setDragY(0);
  };

  const peekTool = peekId ? tools.find((t) => t.id === peekId) ?? null : null;

  const threadStyle: CSSProperties = {
    transform: dragY > 0 ? `translateY(${dragY}px)` : undefined,
    opacity: dragY > 0 ? Math.max(0.35, 1 - dragY / 260) : undefined,
    transition: dragging ? 'none' : reduce ? 'none' : 'transform 0.42s cubic-bezier(0.22,1,0.36,1), opacity 0.42s ease',
    touchAction: 'pan-y',
  };

  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 flex justify-center px-4 pb-5">
      <div
        className={[
          'group pointer-events-auto w-full max-w-xl overflow-hidden rounded-3xl border border-white/10',
          'bg-white/[0.07] p-2 backdrop-blur-2xl',
          'shadow-[0_20px_70px_rgba(0,0,0,0.5),inset_0_1px_0_0_rgba(255,255,255,0.16)]',
          reduce ? '' : 'transition-[box-shadow,transform,background-color] duration-500 ease-out',
          focused ? 'bg-white/[0.085] shadow-[0_28px_90px_rgba(0,0,0,0.6),inset_0_1px_0_0_rgba(255,255,255,0.22)]' : '',
          reduce ? '' : 'motion-safe:animate-[findbar-rise_0.5s_cubic-bezier(0.22,1,0.36,1)]',
        ].join(' ')}
      >
        {turns.length > 0 ? (
          <div
            ref={scrollRef}
            onPointerDown={onThreadPointerDown}
            onPointerMove={onThreadPointerMove}
            onPointerUp={endThreadDrag}
            onPointerCancel={endThreadDrag}
            style={threadStyle}
            className="relative max-h-[33vh] space-y-3 overflow-y-auto px-2 pt-2 pb-1"
          >
            <div className="pointer-events-none sticky top-0 z-10 -mt-2 mb-1 flex justify-center pt-1">
              <span className="h-1 w-9 rounded-full bg-white/20" aria-hidden />
            </div>
            {turns.map((t, ti) => (
              <div
                key={t.id}
                className="space-y-1.5"
                style={
                  reduce
                    ? undefined
                    : {
                        animation: `findbar-turn 0.46s cubic-bezier(0.22,1,0.36,1) both`,
                        animationDelay: `${Math.min(ti, 6) * 40}ms`,
                      }
                }
              >
                <div className="ml-auto w-fit max-w-[85%] rounded-2xl rounded-br-md bg-white/[0.12] px-3 py-1.5 text-sm text-white shadow-[inset_0_1px_0_0_rgba(255,255,255,0.12)]">
                  {t.q}
                </div>
                <div className="w-fit max-w-[90%] rounded-2xl rounded-bl-md bg-white/[0.05] px-3 py-2 text-sm text-white/85 shadow-[inset_0_1px_0_0_rgba(255,255,255,0.07)]">
                  <p>{t.answer}</p>
                  {t.matches.length > 0 ? (
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {t.matches.map((m, mi) => (
                        <button
                          key={m.id}
                          type="button"
                          onClick={() => openTool(m.id)}
                          onPointerDown={() => startPress(m.id)}
                          onPointerUp={clearPress}
                          onPointerLeave={clearPress}
                          onPointerCancel={clearPress}
                          onContextMenu={(e) => e.preventDefault()}
                          style={
                            reduce
                              ? undefined
                              : {
                                  animation: `findbar-chip 0.4s cubic-bezier(0.22,1,0.36,1) both`,
                                  animationDelay: `${120 + mi * 45}ms`,
                                }
                          }
                          className={[
                            'min-h-[40px] select-none rounded-lg border border-white/10 bg-white/[0.06]',
                            'px-2.5 py-1 text-xs text-white/80',
                            reduce ? '' : 'transition duration-200 ease-out',
                            'hover:-translate-y-0.5 hover:bg-white/15 hover:text-white',
                            'active:scale-[0.96] active:bg-white/20',
                          ].join(' ')}
                        >
                          {m.name}
                        </button>
                      ))}
                    </div>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        ) : history.length > 0 ? (
          <div className="flex flex-wrap items-center gap-1.5 px-2 pt-2 pb-1">
            <span className="text-[10px] uppercase tracking-wider text-white/35">Recently added</span>
            {history.map((m, mi) => (
              <button
                key={m.id}
                type="button"
                onClick={() => openTool(m.id)}
                onPointerDown={() => startPress(m.id)}
                onPointerUp={clearPress}
                onPointerLeave={clearPress}
                onPointerCancel={clearPress}
                onContextMenu={(e) => e.preventDefault()}
                style={
                  reduce
                    ? undefined
                    : {
                        animation: `findbar-chip 0.42s cubic-bezier(0.22,1,0.36,1) both`,
                        animationDelay: `${mi * 50}ms`,
                      }
                }
                className={[
                  'min-h-[40px] select-none rounded-lg border border-white/10 bg-white/[0.06]',
                  'px-2.5 py-1 text-xs text-white/75',
                  reduce ? '' : 'transition duration-200 ease-out',
                  'hover:-translate-y-0.5 hover:bg-white/15 hover:text-white',
                  'active:scale-[0.96] active:bg-white/20',
                ].join(' ')}
              >
                {m.name}
              </button>
            ))}
          </div>
        ) : null}

        <form onSubmit={submit} className="flex items-center gap-2 p-1">
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            placeholder="Ask the map — e.g. find me a tool to build a database fast"
            className={[
              'flex-1 rounded-2xl border border-white/10 bg-white/[0.05]',
              'px-3.5 py-2.5 text-sm text-white placeholder-white/35 outline-none',
              reduce ? '' : 'transition duration-300 ease-out',
              'focus:border-white/25 focus:bg-white/[0.08]',
              'focus:shadow-[0_0_0_3px_rgba(255,255,255,0.08),inset_0_1px_0_0_rgba(255,255,255,0.06)]',
            ].join(' ')}
          />
          <button
            type="submit"
            disabled={!text.trim()}
            className={[
              'flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-white/90 text-black',
              reduce ? '' : 'transition duration-200 ease-out',
              'hover:scale-105 hover:bg-white',
              'active:scale-[0.88] active:bg-white/80',
              'disabled:scale-100 disabled:opacity-40',
              text.trim() && !reduce ? 'shadow-[0_4px_16px_rgba(255,255,255,0.25)]' : '',
            ].join(' ')}
            aria-label="Ask"
          >
            <span className={text.trim() && !reduce ? 'inline-block motion-safe:animate-[findbar-bump_0.3s_ease-out]' : 'inline-block'}>
              ↑
            </span>
          </button>
        </form>
      </div>

      {/* Long-press quick peek */}
      {peekTool ? (
        <button
          type="button"
          aria-label={`Close preview of ${peekTool.name}`}
          onClick={() => setPeekId(null)}
          className="pointer-events-auto fixed inset-0 z-30 flex items-end justify-center bg-black/40 px-4 pb-28 backdrop-blur-sm motion-safe:animate-[findbar-fade_0.2s_ease-out]"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={
              reduce
                ? undefined
                : { animation: 'findbar-peek 0.4s cubic-bezier(0.22,1,0.36,1) both' }
            }
            className="w-full max-w-xs cursor-default rounded-3xl border border-white/10 bg-white/[0.09] p-4 text-left shadow-[0_30px_90px_rgba(0,0,0,0.6),inset_0_1px_0_0_rgba(255,255,255,0.2)] backdrop-blur-2xl"
          >
            <div className="text-sm font-medium text-white">{peekTool.name}</div>
            {peekTool.summary ? (
              <p className="mt-1 line-clamp-3 text-xs leading-relaxed text-white/70">{peekTool.summary}</p>
            ) : null}
            <div
              role="button"
              tabIndex={0}
              onClick={() => {
                const id = peekTool.id;
                setPeekId(null);
                haptic(8);
                onOpenTool(id);
              }}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  const id = peekTool.id;
                  setPeekId(null);
                  onOpenTool(id);
                }
              }}
              className={[
                'mt-3 flex min-h-[40px] items-center justify-center rounded-2xl bg-white/90 text-sm font-medium text-black',
                reduce ? '' : 'transition duration-200 ease-out',
                'hover:bg-white active:scale-[0.96]',
              ].join(' ')}
            >
              Open
            </div>
          </div>
        </button>
      ) : null}

      <style>{`
        @keyframes findbar-rise {
          from { transform: translateY(16px) scale(0.985); opacity: 0; }
          to { transform: translateY(0) scale(1); opacity: 1; }
        }
        @keyframes findbar-turn {
          from { transform: translateY(10px); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
        @keyframes findbar-chip {
          from { transform: translateY(6px) scale(0.94); opacity: 0; }
          to { transform: translateY(0) scale(1); opacity: 1; }
        }
        @keyframes findbar-bump {
          0% { transform: translateY(0); }
          45% { transform: translateY(-2px); }
          100% { transform: translateY(0); }
        }
        @keyframes findbar-peek {
          from { transform: translateY(24px) scale(0.96); opacity: 0; }
          to { transform: translateY(0) scale(1); opacity: 1; }
        }
        @keyframes findbar-fade {
          from { opacity: 0; }
          to { opacity: 1; }
        }
      `}</style>
    </div>
  );
}
