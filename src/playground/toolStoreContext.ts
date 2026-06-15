import { createContext } from 'react';
import type { AITool } from '../data/ai-tool-universe';

export interface AddToolInput {
  /** Raw text: a tool name or URL. */
  text: string;
  /** Optional data-URL of a pasted/uploaded image to use as the icon. */
  imageDataUrl?: string;
}

export interface AddedTool extends AITool {
  /** True for user-added tools (so variants can badge them as "new"). */
  userAdded?: boolean;
}

export interface ToolStore {
  tools: AddedTool[];
  toolById: Map<string, AddedTool>;
  /** Classify + place a new tool. Returns it (or an existing match). */
  addTool: (input: AddToolInput) => AddedTool;
  /** Best icon URL for a tool: user image override, else logo.dev. */
  iconUrlFor: (tool: AITool, size?: number) => string | undefined;
}

export const ToolStoreContext = createContext<ToolStore | null>(null);
