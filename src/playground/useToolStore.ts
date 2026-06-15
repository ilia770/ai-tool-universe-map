import { useContext } from 'react';
import { ToolStoreContext, type ToolStore } from './toolStoreContext';

export function useToolStore(): ToolStore {
  const ctx = useContext(ToolStoreContext);
  if (!ctx) throw new Error('useToolStore must be used within ToolStoreProvider');
  return ctx;
}
