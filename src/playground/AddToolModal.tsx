import { useEffect, useMemo, useRef, useState, type ChangeEvent, type ClipboardEvent } from 'react';
import { useToolStore } from './useToolStore';
import { categoryById } from '../data/ai-tool-universe';
import { classifyToolDetailed, getDisplayName } from '../lib/classify-ai-tool';
import { getToolLogoUrl } from '../lib/tool-logos';

const MAX_ICON_BYTES = 1_500_000;
const ALLOWED_ICON_TYPES = new Set(['image/png', 'image/jpeg', 'image/webp']);

function initials(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
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
    if (!open) return;

    const previousActiveElement = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        onClose();
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
  }, [open, onClose]);

  if (!open) return null;

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
    const tool = addTool({ text: trimmed, imageDataUrl });
    setText('');
    setImageDataUrl(undefined);
    setImageError(null);
    onAdded?.(tool.id);
    onClose();
  };

  return (
    <div
      className="fixed inset-0 z-30 flex items-start justify-center bg-black/50 px-4 pt-[12vh] backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        tabIndex={-1}
        className="w-full max-w-md rounded-3xl border border-white/10 bg-white/[0.07] p-5 shadow-[0_24px_80px_rgba(0,0,0,0.55)] backdrop-blur-2xl"
        onClick={(e) => e.stopPropagation()}
        onPaste={onPaste}
      >
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-white">Add a tool to the universe</h2>
          <button type="button" onClick={onClose} className="rounded-lg px-2 py-1 text-white/50 hover:bg-white/10 hover:text-white">✕</button>
        </div>

        <input
          autoFocus
          value={text}
          onChange={(e: ChangeEvent<HTMLInputElement>) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') submit(); }}
          placeholder="Paste a tool name or URL — e.g. Perplexity or perplexity.ai"
          className="w-full rounded-xl border border-white/10 bg-white/[0.06] px-3 py-2.5 text-sm text-white placeholder-white/35 outline-none focus:border-white/25"
        />

        {preview ? (
          <div className="mt-3 flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.05] p-3">
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
                <span>· {Math.round(preview.confidence * 100)}% match</span>
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
              {matches.map((m) => (
                <span key={m.id} className="rounded-lg border border-white/10 bg-white/[0.05] px-2 py-1 text-xs text-white/70">{m.name}</span>
              ))}
            </div>
          </div>
        ) : null}

        {imageError ? (
          <p className="mt-3 rounded-xl border border-red-300/20 bg-red-500/10 px-3 py-2 text-xs text-red-100/80">
            {imageError}
          </p>
        ) : null}

        <div className="mt-4 flex items-center gap-2">
          <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={(e) => readImage(e.target.files?.[0])} />
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            className="rounded-xl border border-white/10 bg-white/[0.05] px-3 py-2 text-xs text-white/70 hover:bg-white/10"
          >
            {imageDataUrl ? 'Image set ✓' : 'Upload icon'}
          </button>
          <div className="flex-1" />
          <button
            type="button"
            onClick={submit}
            disabled={!trimmed}
            className="rounded-xl bg-white/90 px-4 py-2 text-xs font-semibold text-black transition hover:bg-white disabled:opacity-40"
          >
            Add to map
          </button>
        </div>
      </div>
    </div>
  );
}
