import { classifyToolDetailed, getDisplayName, type ClassificationResult } from './classify-ai-tool';

export const UNSURE_PROMPT =
  'Не нашёл такой сервис — скинь ссылку на сайт, определю что это и добавлю.';

/** Below this confidence we do NOT auto-place a tool. */
export const CONFIDENCE_FLOOR = 0.45;

export type IntakeOutcome =
  | { kind: 'classified'; result: ClassificationResult; name: string }
  | { kind: 'unsure'; prompt: string; query: string }
  | { kind: 'ambiguous'; result: ClassificationResult; name: string; question: string }
  | { kind: 'newCategory'; suggestedName: string; result: ClassificationResult; name: string };

export interface IntakeOptions {
  url?: string;
  confirmed?: boolean;
}

const hasUrlLike = (value: string) => /\.[a-z]{2,}/i.test(value) || value.startsWith('http');

export function classifyIntake(text: string, opts: IntakeOptions = {}): IntakeOutcome {
  const source = (opts.url ?? text).trim();
  const result = classifyToolDetailed(source);
  const hasUrl = hasUrlLike(source);

  const name = getDisplayName(source);

  // Unknown AND no URL to reason from → ask, do not guess.
  if (result.category === 'core' && result.confidence <= CONFIDENCE_FLOOR && !hasUrl) {
    return { kind: 'unsure', prompt: UNSURE_PROMPT, query: text.trim() };
  }

  // No rule fit even with a URL → mint a fresh branch instead of dumping
  // the tool into the catch-all `core` bucket.
  if (result.category === 'core' && result.confidence <= CONFIDENCE_FLOOR) {
    return { kind: 'newCategory', suggestedName: name, result, name };
  }

  return { kind: 'classified', result, name };
}
