import { createContext } from 'react';
import type { AITool, ToolCategory } from '../data/ai-tool-universe';
import type { IntakeOutcome } from '../lib/intake';
import type { InferredEdge } from '../lib/relationship-intelligence.types';

export interface AddToolInput {
  /** Raw text: a tool name or URL. */
  text: string;
  /** Optional data-URL of a pasted/uploaded image to use as the icon. */
  imageDataUrl?: string;
  /** Optional already-resolved intake outcome (e.g. URL fallback, confirm). */
  outcome?: IntakeOutcome;
}

export interface AddedTool extends AITool {
  /** True for user-added tools (so variants can badge them as "new"). */
  userAdded?: boolean;
  /**
   * Typed, explained, confidence-scored relationship edges inferred at
   * intake time (P9). Additive to `relationIds`; never persisted.
   */
  inferredEdges?: InferredEdge[];
}

export type Language = 'en' | 'ru';

export interface PlaygroundSettings {
  language: Language;
  /** Active visualization variant id (e.g. 'A'). */
  variantId: string;
}

export interface ToolStore {
  tools: AddedTool[];
  toolById: Map<string, AddedTool>;
  /** Seed categories plus any user-created dynamic branches. */
  allCategories: ToolCategory[];
  /** Runtime-only categories minted for tools that fit no seed branch. */
  dynamicCategories: ToolCategory[];
  /** Classify + place a new tool. Returns it (or an existing match). */
  addTool: (input: AddToolInput) => AddedTool;
  /** Remove a user-added tool (seed tools are ignored). */
  removeTool: (id: string) => void;
  /** Inferred relationship edges for a tool id (empty if none). */
  edgesFor: (id: string) => InferredEdge[];
  /** Best icon URL for a tool: user image override, else logo.dev. */
  iconUrlFor: (tool: AITool, size?: number) => string | undefined;
  /** Persisted UI settings (language + active visualization). */
  settings: PlaygroundSettings;
  /** Patch persisted settings. */
  setSettings: (patch: Partial<PlaygroundSettings>) => void;
  /** Wipe added tools, icon overrides, settings, and the chat thread. */
  resetData: () => void;
  /** JSON snapshot of the user's added tools + settings. */
  exportData: () => string;
}

export const ToolStoreContext = createContext<ToolStore | null>(null);
