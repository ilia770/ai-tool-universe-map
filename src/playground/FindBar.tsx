import { useMemo, useRef, useState, type FormEvent } from 'react';
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
  const nextId = useRef(1);

  const history = useMemo(() => tools.filter((t) => t.userAdded).slice(-6).reverse(), [tools]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const q = text.trim();
    if (!q) return;
    const { answer, matches } = runQuery(q, tools);
    setTurns((prev) => [...prev, { id: nextId.current++, q, answer, matches }]);
    setText('');
  };

  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 flex justify-center px-4 pb-5">
      <div className="pointer-events-auto w-full max-w-xl rounded-3xl border border-white/10 bg-white/[0.06] p-2 shadow-[0_20px_70px_rgba(0,0,0,0.5)] backdrop-blur-2xl">
        {turns.length > 0 ? (
          <div className="max-h-[33vh] space-y-3 overflow-y-auto px-2 pt-2 pb-1">
            {turns.map((t) => (
              <div key={t.id} className="space-y-1.5">
                <div className="ml-auto w-fit max-w-[85%] rounded-2xl rounded-br-md bg-white/[0.12] px-3 py-1.5 text-sm text-white">{t.q}</div>
                <div className="w-fit max-w-[90%] rounded-2xl rounded-bl-md bg-white/[0.05] px-3 py-2 text-sm text-white/85">
                  <p>{t.answer}</p>
                  {t.matches.length > 0 ? (
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {t.matches.map((m) => (
                        <button
                          key={m.id}
                          type="button"
                          onClick={() => onOpenTool(m.id)}
                          className="rounded-lg border border-white/10 bg-white/[0.06] px-2 py-1 text-xs text-white/80 transition hover:bg-white/15 hover:text-white active:scale-95"
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
            {history.map((m) => (
              <button
                key={m.id}
                type="button"
                onClick={() => onOpenTool(m.id)}
                className="rounded-lg border border-white/10 bg-white/[0.06] px-2 py-1 text-xs text-white/75 transition hover:bg-white/15 hover:text-white active:scale-95"
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
            placeholder="Ask the map — e.g. find me a tool to build a database fast"
            className="flex-1 rounded-2xl border border-white/10 bg-white/[0.05] px-3.5 py-2.5 text-sm text-white placeholder-white/35 outline-none transition focus:border-white/25"
          />
          <button
            type="submit"
            disabled={!text.trim()}
            className="flex h-10 w-10 items-center justify-center rounded-2xl bg-white/90 text-black transition hover:bg-white active:scale-90 disabled:opacity-40"
            aria-label="Ask"
          >
            ↑
          </button>
        </form>
      </div>
    </div>
  );
}
