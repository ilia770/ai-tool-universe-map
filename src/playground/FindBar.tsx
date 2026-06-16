import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type FormEvent,
  type KeyboardEvent as ReactKeyboardEvent,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import { ArrowUp, Mic, Square } from 'lucide-react';
import { useToolStore } from './useToolStore';
import { runQuery } from './query';
import { categoryById } from '../data/ai-tool-universe';
import type { AITool } from '../data/ai-tool-universe';
import {
  ACCENT,
  cx,
  DISMISS,
  DURATION,
  EASE,
  FOCUS_RING,
  GLASS,
  HOVER_LIFT,
  STAGGER,
  TEXT,
  TYPE,
} from './designSystem';
import {
  fireHaptic,
  LONG_PRESS_MS,
  LONG_PRESS_SLOP_PX,
  shouldDismiss,
  useReducedMotion,
} from './interactions';

interface Turn {
  id: number;
  q: string;
  answer: string;
  matchIds: string[];
}

interface Props {
  onOpenTool: (id: string) => void;
  onAddToolQuery: (query: string) => void;
}

/** Persist the thread across FindBar unmounts (it is hidden when a tool opens). */
const STORAGE_KEY = 'playground.findbar.turns.v1';
const MAX_STORED_TURNS = 20;
const MAX_STORED_BYTES = 80_000;
const MAX_QUERY_CHARS = 500;
const MAX_ANSWER_CHARS = 900;
const MAX_MATCH_IDS = 8;

/** Seed example queries surfaced in the empty state (pre-fill the composer). */
const EXAMPLE_QUERIES = ['build a database fast', 'edit video', 'research tool'] as const;

/** Reduce-aware tick: gate on the caller's reduce flag, then fire shared. */
const haptic = (ms = 8, reduce = false) => {
  if (reduce) return;
  fireHaptic(ms);
};

function loadTurns(tools: AITool[]): Turn[] {
  if (typeof window === 'undefined') return [];
  const liveIds = new Set(tools.map((t) => t.id));
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    if (raw.length > MAX_STORED_BYTES) {
      window.localStorage.removeItem(STORAGE_KEY);
      return [];
    }
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed.slice(-MAX_STORED_TURNS).flatMap((item) => {
      if (!item || typeof item !== 'object') return [];
      const candidate = item as {
        id?: unknown;
        q?: unknown;
        answer?: unknown;
        matchIds?: unknown;
        matches?: unknown;
      };
      if (
        typeof candidate.id !== 'number' ||
        typeof candidate.q !== 'string' ||
        typeof candidate.answer !== 'string'
      ) {
        return [];
      }
      if (candidate.q.length > MAX_QUERY_CHARS || candidate.answer.length > MAX_ANSWER_CHARS) {
        return [];
      }
      const rawIds = Array.isArray(candidate.matchIds)
        ? candidate.matchIds
        : Array.isArray(candidate.matches)
          ? candidate.matches.map((match) =>
              match && typeof match === 'object' ? (match as { id?: unknown }).id : null,
            )
          : [];
      const matchIds = rawIds
        .filter((id): id is string => typeof id === 'string' && liveIds.has(id))
        .slice(0, MAX_MATCH_IDS);
      return [{ id: candidate.id, q: candidate.q, answer: candidate.answer, matchIds }];
    });
  } catch {
    return [];
  }
}

function persistTurns(turns: Turn[]) {
  if (typeof window === 'undefined') return;
  try {
    if (turns.length === 0) {
      window.localStorage.removeItem(STORAGE_KEY);
      return;
    }
    const capped = turns.slice(-MAX_STORED_TURNS).map((turn) => ({
      id: turn.id,
      q: turn.q.slice(0, MAX_QUERY_CHARS),
      answer: turn.answer.slice(0, MAX_ANSWER_CHARS),
      matchIds: turn.matchIds.slice(0, MAX_MATCH_IDS),
    }));
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(capped));
  } catch {
    /* storage unavailable — keep in-memory only */
  }
}

/**
 * ChatGPT-style "ask the map" composer pinned to the bottom in thumb reach.
 * Type a need ("find me something to build a database fast") and the on-device
 * query engine answers in a thread (capped to a third of the screen) with the
 * matched tools as scannable cards you tap to open their brand window. The
 * thread persists across tool-opens via localStorage; dismiss is non-destructive
 * (collapse + Undo, never a silent wipe). Empty state seeds example prompts and
 * recently-added history.
 */
export function FindBar({ onOpenTool, onAddToolQuery }: Props) {
  const { tools, toolById, iconUrlFor } = useToolStore();
  const [text, setText] = useState('');
  const [turns, setTurns] = useState<Turn[]>(() => loadTurns(tools));
  const [focused, setFocused] = useState(false);
  const [peekId, setPeekId] = useState<string | null>(null);
  const [thinkingId, setThinkingId] = useState<number | null>(null);
  const [collapsed, setCollapsed] = useState(false);
  const [undo, setUndo] = useState<Turn[] | null>(null);
  const nextId = useRef(1);
  const reduce = useReducedMotion();

  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const undoTimer = useRef<number | null>(null);
  const thinkingTimer = useRef<number | null>(null);

  // Swipe-to-dismiss drag state for the conversation thread.
  const [dragY, setDragY] = useState(0);
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef<{ y: number; t: number; active: boolean } | null>(null);
  const lastMove = useRef<{ y: number; t: number } | null>(null);
  const scrollRef = useRef<HTMLDivElement | null>(null);

  // Long-press handling for chips (quick peek / secondary action).
  const pressTimer = useRef<number | null>(null);
  const pressOrigin = useRef<{ x: number; y: number } | null>(null);
  const longFired = useRef(false);

  // Seed the running id past any persisted turns.
  useEffect(() => {
    nextId.current = turns.reduce((max, t) => Math.max(max, t.id + 1), nextId.current);
    // run once on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Persist the thread so opening a tool window doesn't destroy the conversation.
  useEffect(() => {
    persistTurns(turns);
  }, [turns]);

  const history = useMemo(
    () => tools.filter((t) => t.userAdded).slice(-6).reverse(),
    [tools],
  );

  const hasText = text.trim().length > 0;
  const streaming = thinkingId !== null;
  const showThread = turns.length > 0 && !collapsed;

  const autoGrow = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    // 1 line → ~5-line cap (~120px), then inner scroll.
    el.style.height = `${Math.min(el.scrollHeight, 120)}px`;
  }, []);

  useEffect(() => {
    autoGrow();
  }, [text, autoGrow]);

  const runTurn = useCallback(
    (raw: string) => {
      const q = raw.trim().slice(0, MAX_QUERY_CHARS);
      if (!q) return;
      haptic(10, reduce);
      const { answer, matches } = runQuery(q, tools);
      const id = nextId.current++;
      setCollapsed(false);
      setTurns((prev) => [
        ...prev.slice(-(MAX_STORED_TURNS - 1)),
        {
          id,
          q,
          answer: answer.slice(0, MAX_ANSWER_CHARS),
          matchIds: matches.slice(0, MAX_MATCH_IDS).map((match) => match.id),
        },
      ]);
      setText('');
      // Brief thinking pulse before the answer "streams" in.
      if (thinkingTimer.current !== null) window.clearTimeout(thinkingTimer.current);
      setThinkingId(id);
      thinkingTimer.current = window.setTimeout(
        () => setThinkingId(null),
        reduce ? 0 : 420,
      );
    },
    [tools, reduce],
  );

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (streaming) {
      // ■ stop — cancel the in-flight stream.
      if (thinkingTimer.current !== null) window.clearTimeout(thinkingTimer.current);
      setThinkingId(null);
      haptic(6, reduce);
      return;
    }
    runTurn(text);
  };

  const onComposerKeyDown = (e: ReactKeyboardEvent<HTMLTextAreaElement>) => {
    // Enter submits; Shift+Enter inserts a newline.
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      if (!streaming) runTurn(text);
    }
  };

  const openTool = useCallback(
    (id: string) => {
      if (longFired.current) {
        longFired.current = false;
        return;
      }
      haptic(8, reduce);
      onOpenTool(id);
    },
    [onOpenTool, reduce],
  );

  const clearPress = useCallback(() => {
    if (pressTimer.current !== null) {
      window.clearTimeout(pressTimer.current);
      pressTimer.current = null;
    }
    pressOrigin.current = null;
  }, []);

  const startPress = useCallback(
    (id: string, e: ReactPointerEvent) => {
      longFired.current = false;
      clearPress();
      pressOrigin.current = { x: e.clientX, y: e.clientY };
      pressTimer.current = window.setTimeout(() => {
        longFired.current = true;
        haptic(16, reduce);
        setPeekId(id);
      }, LONG_PRESS_MS);
    },
    [clearPress, reduce],
  );

  // Cancel the long-press if the finger moves past the slop (a scroll, not a peek).
  const onChipMove = useCallback(
    (e: ReactPointerEvent) => {
      const o = pressOrigin.current;
      if (!o) return;
      if (Math.hypot(e.clientX - o.x, e.clientY - o.y) > LONG_PRESS_SLOP_PX) clearPress();
    },
    [clearPress],
  );

  useEffect(
    () => () => {
      clearPress();
      if (undoTimer.current !== null) window.clearTimeout(undoTimer.current);
      if (thinkingTimer.current !== null) window.clearTimeout(thinkingTimer.current);
    },
    [clearPress],
  );

  // Auto-scroll thread to the latest turn when one is added.
  useEffect(() => {
    const el = scrollRef.current;
    if (!el || collapsed) return;
    el.scrollTo({ top: el.scrollHeight, behavior: reduce ? 'auto' : 'smooth' });
  }, [turns, collapsed, thinkingId, reduce]);

  // --- non-destructive swipe-down-to-dismiss (unified DISMISS contract) ---
  const onThreadPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (e.pointerType === 'mouse') return;
    const el = scrollRef.current;
    // Only start a dismiss drag when the thread is scrolled to the top.
    if (el && el.scrollTop > 2) return;
    dragStart.current = { y: e.clientY, t: e.timeStamp, active: true };
    lastMove.current = { y: e.clientY, t: e.timeStamp };
    setDragging(true);
  };

  const onThreadPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragStart.current?.active) return;
    const dyRaw = e.clientY - dragStart.current.y;
    lastMove.current = { y: e.clientY, t: e.timeStamp };
    if (dyRaw <= 0) {
      setDragY(0);
      return;
    }
    // Rubber-band the over-drag for a tactile, iOS-feeling pull.
    const dy = dyRaw > DISMISS.distancePx
      ? DISMISS.distancePx + (dyRaw - DISMISS.distancePx) * DISMISS.resistance
      : dyRaw;
    setDragY(dy);
  };

  const collapseThread = useCallback(() => {
    haptic(12, reduce);
    setUndo(turns);
    setTurns([]);
    setCollapsed(false);
    persistTurns([]);
    if (undoTimer.current !== null) window.clearTimeout(undoTimer.current);
    undoTimer.current = window.setTimeout(() => setUndo(null), 4000);
  }, [reduce, turns]);

  const endThreadDrag = () => {
    if (!dragStart.current?.active) return;
    const start = dragStart.current;
    dragStart.current = null;
    setDragging(false);
    const last = lastMove.current;
    const velocity = last ? (last.y - start.y) / Math.max(1, last.t - start.t) : 0;
    // Commit on distance OR a downward flick velocity.
    if (shouldDismiss(dragY, velocity)) {
      collapseThread();
    }
    setDragY(0);
  };

  const restoreUndo = () => {
    if (undoTimer.current !== null) window.clearTimeout(undoTimer.current);
    if (undo) setTurns(undo);
    setUndo(null);
    setCollapsed(false);
    haptic(8, reduce);
  };

  const newChat = () => {
    if (turns.length === 0) return;
    collapseThread();
  };

  const peekTool = peekId ? tools.find((t) => t.id === peekId) ?? null : null;

  useEffect(() => {
    if (!peekTool) return;
    const closeOnEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPeekId(null);
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [peekTool]);

  const threadStyle: CSSProperties = {
    transform: dragY > 0 ? `translateY(${dragY}px)` : undefined,
    opacity: dragY > 0 ? Math.max(0.35, 1 - dragY / 260) : undefined,
    transition: dragging
      ? 'none'
      : reduce
        ? 'none'
        : `transform ${DURATION.exit}ms ${EASE.sheet}, opacity ${DURATION.exit}ms ease`,
    touchAction: 'pan-y',
  };

  const categoryName = (tool: AITool) => categoryById.get(tool.category)?.shortName ?? '';

  // ChatGPT-grade result card: favicon/logo + name + 1-line category.
  const renderResultChip = (m: AITool, delayMs: number) => {
    const icon = iconUrlFor(m, 48);
    return (
      <button
        key={m.id}
        type="button"
        onClick={() => openTool(m.id)}
        onPointerDown={(e) => startPress(m.id, e)}
        onPointerMove={onChipMove}
        onPointerUp={clearPress}
        onPointerLeave={clearPress}
        onPointerCancel={clearPress}
        onContextMenu={(e) => e.preventDefault()}
        style={
          reduce
            ? undefined
            : { animation: `findbar-chip ${DURATION.peek}ms ${EASE.out} both`, animationDelay: `${delayMs}ms` }
        }
        className={cx(
          'group/chip flex min-h-[44px] shrink-0 select-none items-center gap-2',
          GLASS.chip,
          'px-2.5 py-1.5 text-left',
          !reduce && 'transition duration-200 ease-out',
          HOVER_LIFT,
          '[@media(hover:hover)]:hover:bg-white/[0.1]',
          'active:scale-[0.96] active:bg-white/[0.12]',
          FOCUS_RING,
        )}
      >
        {icon ? (
          <img
            src={icon}
            alt=""
            aria-hidden
            className="h-5 w-5 shrink-0 rounded-md object-cover"
            loading="lazy"
          />
        ) : (
          <span
            aria-hidden
            className="grid h-5 w-5 shrink-0 place-items-center rounded-md bg-white/10 text-[10px] font-semibold text-white/70"
          >
            {m.name.slice(0, 1).toUpperCase()}
          </span>
        )}
        <span className="min-w-0">
          <span className={cx('block truncate', TYPE.chip, TEXT.body)}>{m.name}</span>
          {categoryName(m) ? (
            <span className={cx('block truncate text-[10px]', TEXT.secondary)}>{categoryName(m)}</span>
          ) : null}
        </span>
      </button>
    );
  };

  const matchesForTurn = (t: Turn): AITool[] =>
    t.matchIds
      .map((id) => toolById.get(id))
      .filter((tool): tool is AITool => Boolean(tool));

  // Follow-up pills revealed AFTER the answer paints.
  const followUps = (matches: AITool[]): string[] => {
    if (matches.length === 0) return [];
    const top = matches[0]?.name;
    const pills = ['Show alternatives'];
    if (top) pills.push(`What connects to ${top}`);
    pills.push('Cheaper options');
    return pills.slice(0, 3);
  };

  return (
    <div
      className="pointer-events-none absolute inset-x-0 bottom-0 z-20 flex justify-center px-4"
      style={{ paddingBottom: 'max(1.25rem, calc(env(safe-area-inset-bottom) + 0.25rem))' }}
    >
      <div
        className={cx(
          'group pointer-events-auto w-full max-w-xl overflow-hidden p-2',
          GLASS.panel,
          !reduce && 'transition-[box-shadow,transform,background-color] duration-300 ease-out',
          focused && 'bg-white/[0.085] shadow-[0_28px_90px_rgba(0,0,0,0.6),inset_0_1px_0_0_rgba(255,255,255,0.18)]',
          !reduce && 'motion-safe:animate-[findbar-rise_0.5s_cubic-bezier(0.22,1,0.36,1)]',
        )}
        style={{ touchAction: 'manipulation' }}
      >
        {showThread ? (
          <div
            ref={scrollRef}
            role="log"
            aria-live="polite"
            aria-label="Ask the map conversation"
            onPointerDown={onThreadPointerDown}
            onPointerMove={onThreadPointerMove}
            onPointerUp={endThreadDrag}
            onPointerCancel={endThreadDrag}
            style={threadStyle}
            className="relative max-h-[33vh] space-y-3 overflow-y-auto overscroll-contain px-2 pt-2 pb-1"
          >
            <div className="pointer-events-none sticky top-0 z-10 -mt-2 mb-1 grid grid-cols-[1fr_auto_1fr] items-center pt-1">
              <span aria-hidden />
              <span className="col-start-2 h-1 w-9 justify-self-center rounded-full bg-white/20" aria-hidden />
              <button
                type="button"
                onClick={newChat}
                className={cx(
                  'pointer-events-auto col-start-3 justify-self-end rounded-full px-2.5 py-1',
                  TYPE.chip,
                  TEXT.secondary,
                  !reduce && 'transition duration-200 ease-out',
                  '[@media(hover:hover)]:hover:bg-white/10 [@media(hover:hover)]:hover:text-white/85',
                  'active:scale-[0.96]',
                  FOCUS_RING,
                )}
              >
                New chat
              </button>
            </div>
            {turns.map((t, ti) => {
              const matches = matchesForTurn(t);
              return (
                <div
                  key={t.id}
                  className="space-y-1.5"
                  style={
                    reduce
                      ? undefined
                      : {
                          animation: `findbar-turn ${DURATION.turn}ms ${EASE.out} both`,
                          animationDelay: `${Math.min(ti, 6) * STAGGER.section}ms`,
                        }
                  }
                >
                  <div
                    className={cx(
                      'ml-auto w-fit max-w-[85%] rounded-2xl rounded-br-md bg-white/[0.12] px-3 py-1.5',
                      TYPE.body,
                      'text-white shadow-[inset_0_1px_0_0_rgba(255,255,255,0.12)]',
                    )}
                  >
                    {t.q}
                  </div>

                {thinkingId === t.id ? (
                  <div className="flex w-fit items-center gap-1 rounded-2xl rounded-bl-md bg-white/[0.05] px-3 py-2.5">
                    {[0, 1, 2].map((d) => (
                      <span
                        key={d}
                        aria-hidden
                        className="h-1.5 w-1.5 rounded-full bg-white/55"
                        style={
                          reduce
                            ? undefined
                            : { animation: 'findbar-think 1.4s ease-in-out infinite', animationDelay: `${d * 0.16}s` }
                        }
                      />
                    ))}
                    <span className="sr-only">Thinking</span>
                  </div>
                ) : (
                  <>
                    <div
                      className={cx(
                        'w-fit max-w-[95%] rounded-2xl rounded-bl-md bg-white/[0.05] px-3 py-2',
                        TYPE.body,
                        TEXT.primary,
                        'shadow-[inset_0_1px_0_0_rgba(255,255,255,0.07)]',
                      )}
                    >
                      <p>
                        {reduce
                          ? t.answer
                          : t.answer.split(' ').map((w, wi) => (
                              <span
                                key={wi}
                                style={{
                                  display: 'inline-block',
                                  animation: `findbar-word 0.24s ${EASE.out} both`,
                                  animationDelay: `${Math.min(wi, 24) * STAGGER.word}ms`,
                                }}
                              >
                                {w}
                                {wi < t.answer.split(' ').length - 1 ? ' ' : ''}
                              </span>
                            ))}
                      </p>
                    </div>

                    {matches.length > 0 ? (
                      matches.length > 3 ? (
                        <div className="-mx-1 flex snap-x gap-1.5 overflow-x-auto px-1 pb-0.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                          {matches.map((m, mi) => (
                            <span key={m.id} className="snap-start">
                              {renderResultChip(m, 120 + mi * STAGGER.chip)}
                            </span>
                          ))}
                        </div>
                      ) : (
                        <div className="flex flex-wrap gap-1.5">
                          {matches.map((m, mi) => renderResultChip(m, 120 + mi * STAGGER.chip))}
                        </div>
                      )
                    ) : (
                      // Zero-result → inline "Add it" that opens the add flow pre-filled.
                      <button
                        type="button"
                        onClick={() => {
                          haptic(8, reduce);
                          onAddToolQuery(t.q);
                        }}
                        className={cx(
                          'inline-flex min-h-[44px] items-center gap-1.5 rounded-xl px-3 py-1.5',
                          ACCENT.fill,
                          ACCENT.border,
                          'border',
                          TYPE.chip,
                          ACCENT.text,
                          !reduce && 'transition duration-200 ease-out',
                          'active:scale-[0.96]',
                          FOCUS_RING,
                        )}
                      >
                        Add it to the map
                      </button>
                    )}

                    {followUps(matches).length > 0 ? (
                      <div className="flex flex-wrap gap-1.5 pt-0.5">
                        {followUps(matches).map((f, fi) => (
                          <button
                            key={f}
                            type="button"
                            onClick={() => runTurn(f.replace(/^What connects to /, 'connections for '))}
                            style={
                              reduce
                                ? undefined
                                : {
                                    animation: `findbar-pill 0.32s ${EASE.out} both`,
                                    animationDelay: `${260 + fi * STAGGER.chip}ms`,
                                  }
                            }
                            className={cx(
                              'min-h-[36px] rounded-full border border-white/10 bg-white/[0.04] px-3 py-1',
                              TYPE.chip,
                              TEXT.secondary,
                              !reduce && 'transition duration-200 ease-out',
                              HOVER_LIFT,
                              '[@media(hover:hover)]:hover:bg-white/[0.08] [@media(hover:hover)]:hover:text-white/80',
                              'active:scale-[0.96]',
                              FOCUS_RING,
                            )}
                          >
                            {f}
                          </button>
                        ))}
                      </div>
                    ) : null}
                  </>
                )}
                </div>
              );
            })}
          </div>
        ) : (
          <div className="px-2 pt-2 pb-1">
            <span className={cx('block px-0.5', TYPE.eyebrow, TEXT.meta)}>
              {history.length > 0 ? 'Recently added' : 'Try'}
            </span>
            <div className="mt-2 flex flex-wrap items-center gap-1.5">
              {(history.length > 0 ? history : EXAMPLE_QUERIES).map((item, mi) => {
                const isTool = typeof item !== 'string';
                const key = isTool ? item.id : item;
                const label = isTool ? item.name : item;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => {
                      if (isTool) {
                        openTool(item.id);
                      } else {
                        setText(item);
                        textareaRef.current?.focus();
                        haptic(6, reduce);
                      }
                    }}
                    onPointerDown={isTool ? (e) => startPress(item.id, e) : undefined}
                    onPointerMove={isTool ? onChipMove : undefined}
                    onPointerUp={isTool ? clearPress : undefined}
                    onPointerLeave={isTool ? clearPress : undefined}
                    onPointerCancel={isTool ? clearPress : undefined}
                    onContextMenu={isTool ? (e) => e.preventDefault() : undefined}
                    style={
                      reduce
                        ? undefined
                        : {
                            animation: `findbar-chip ${DURATION.peek}ms ${EASE.out} both`,
                            animationDelay: `${mi * STAGGER.chip}ms`,
                          }
                    }
                    className={cx(
                      'min-h-[44px] select-none',
                      GLASS.chip,
                      'px-3 py-1.5',
                      TYPE.chip,
                      TEXT.body,
                      !reduce && 'transition duration-200 ease-out',
                      HOVER_LIFT,
                      '[@media(hover:hover)]:hover:bg-white/[0.1]',
                      'active:scale-[0.96] active:bg-white/[0.12]',
                      FOCUS_RING,
                    )}
                  >
                    {label}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        <form onSubmit={submit} className="flex items-end gap-2 p-1">
          <textarea
            ref={textareaRef}
            value={text}
            rows={1}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={onComposerKeyDown}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            placeholder="Ask the map…"
            enterKeyHint="search"
            inputMode="search"
            aria-label="Ask the map"
            className={cx(
              'flex-1 resize-none bg-white/[0.05]',
              'rounded-2xl border border-white/10',
              'px-3.5 py-2.5',
              TYPE.body,
              'text-white outline-none',
              TEXT.placeholder,
              'max-h-[120px] overflow-y-auto',
              !reduce && 'transition duration-300 ease-out',
              'focus:border-white/25 focus:bg-white/[0.08]',
              'focus:shadow-[0_0_0_3px_rgba(125,211,252,0.18),inset_0_1px_0_0_rgba(255,255,255,0.06)]',
              FOCUS_RING,
            )}
          />
          <button
            type="submit"
            disabled={!hasText && !streaming}
            aria-label={streaming ? 'Stop' : 'Ask'}
            className={cx(
              'flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl',
              !reduce && 'transition duration-200 ease-out',
              streaming
                ? 'bg-white/90 text-black'
                : hasText
                  ? 'bg-white/90 text-black shadow-[0_4px_16px_rgba(255,255,255,0.22)]'
                  : 'bg-white/10 text-white/55',
              hasText || streaming ? '[@media(hover:hover)]:hover:scale-105' : '',
              'active:scale-[0.88]',
              'disabled:scale-100 disabled:opacity-40',
              FOCUS_RING,
            )}
          >
            <span
              key={streaming ? 'stop' : hasText ? 'send' : 'mic'}
              aria-hidden
              className="inline-flex"
              style={reduce ? undefined : { animation: `findbar-icon-in ${DURATION.state}ms ${EASE.back} both` }}
            >
              {streaming ? (
                <Square className="h-4 w-4 fill-current" strokeWidth={0} />
              ) : hasText ? (
                <ArrowUp className="h-5 w-5" strokeWidth={2.5} />
              ) : (
                <Mic className="h-[18px] w-[18px]" strokeWidth={2} />
              )}
            </span>
          </button>
        </form>
      </div>

      {/* Non-destructive dismiss → "Cleared · Undo" toast (no silent wipe). */}
      {undo ? (
        <div
          className="pointer-events-none fixed inset-x-0 z-30 flex justify-center px-4"
          style={{ bottom: 'max(6.5rem, calc(env(safe-area-inset-bottom) + 6rem))' }}
        >
          <div
            style={reduce ? undefined : { animation: `findbar-toast 0.3s ${EASE.out} both` }}
            className={cx(
              'pointer-events-auto flex items-center gap-3 px-4 py-2.5',
              GLASS.floating,
            )}
          >
            <span className={cx(TYPE.chip, TEXT.body)}>Conversation cleared</span>
            <button
              type="button"
              onClick={restoreUndo}
              className={cx(
                'rounded-full px-2.5 py-1',
                TYPE.chip,
                ACCENT.text,
                'font-medium',
                !reduce && 'transition duration-200 ease-out',
                '[@media(hover:hover)]:hover:bg-white/10',
                'active:scale-[0.96]',
                FOCUS_RING,
              )}
            >
              Undo
            </button>
          </div>
        </div>
      ) : null}

      {/* Long-press quick peek */}
      {peekTool ? (
        <div
          role="presentation"
          onClick={() => setPeekId(null)}
          className={cx(
            'pointer-events-auto fixed inset-0 z-30 flex items-end justify-center px-4 pb-28',
            GLASS.scrim,
            !reduce && 'motion-safe:animate-[findbar-fade_0.2s_ease-out]',
          )}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-label={`Preview of ${peekTool.name}`}
            onClick={(e) => e.stopPropagation()}
            style={reduce ? undefined : { animation: `findbar-peek ${DURATION.peek}ms ${EASE.out} both` }}
            className={cx('w-full max-w-xs cursor-default p-4 text-left', GLASS.panel)}
          >
            <div className="flex items-center gap-2">
              {iconUrlFor(peekTool, 48) ? (
                <img
                  src={iconUrlFor(peekTool, 48)}
                  alt=""
                  aria-hidden
                  className="h-7 w-7 shrink-0 rounded-lg object-cover"
                />
              ) : null}
              <div className={cx(TYPE.title, 'text-white')}>{peekTool.name}</div>
            </div>
            {peekTool.summary ? (
              <p className={cx('mt-2 line-clamp-3 leading-relaxed', TYPE.chip, TEXT.secondary)}>
                {peekTool.summary}
              </p>
            ) : null}
            <button
              type="button"
              onClick={() => {
                const id = peekTool.id;
                setPeekId(null);
                haptic(8, reduce);
                onOpenTool(id);
              }}
              className={cx(
                'mt-3 flex min-h-[44px] w-full items-center justify-center rounded-2xl bg-white/90',
                TYPE.body,
                'font-medium text-black',
                !reduce && 'transition duration-200 ease-out',
                '[@media(hover:hover)]:hover:bg-white',
                'active:scale-[0.96]',
                FOCUS_RING,
              )}
            >
              Open
            </button>
          </div>
        </div>
      ) : null}

      <style>{`
        @keyframes findbar-peek {
          from { transform: translateY(24px) scale(0.96); opacity: 0; }
          to { transform: translateY(0) scale(1); opacity: 1; }
        }
      `}</style>
    </div>
  );
}
