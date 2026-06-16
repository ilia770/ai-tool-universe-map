/**
 * Minimal in-memory `localStorage` polyfill for the Node-based Vitest run
 * (`vitest run src`). The store/persistence helpers and tests reference the
 * global `localStorage`, which Node does not provide. This mirrors the small
 * surface the helpers use (getItem/setItem/removeItem/clear) so persistence
 * round-trips can be exercised without pulling in jsdom.
 */
class MemoryStorage {
  private store = new Map<string, string>();

  getItem(key: string): string | null {
    return this.store.has(key) ? (this.store.get(key) as string) : null;
  }

  setItem(key: string, value: string): void {
    this.store.set(key, String(value));
  }

  removeItem(key: string): void {
    this.store.delete(key);
  }

  clear(): void {
    this.store.clear();
  }
}

if (typeof globalThis.localStorage === 'undefined') {
  Object.defineProperty(globalThis, 'localStorage', {
    value: new MemoryStorage(),
    writable: true,
    configurable: true,
  });
}
