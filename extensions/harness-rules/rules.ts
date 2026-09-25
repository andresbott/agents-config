// Pure assembly for the harness-rules injector — no I/O, so it is unit-testable.
// index.ts reads the rules.d drop-in dir and does the event wiring; this file
// only turns those file contents into the single block appended to the prompt.

export interface RuleFile {
  /** File name, e.g. "30-git.md". Used only for deterministic ordering. */
  name: string;
  /** Raw markdown contents of the rule file. */
  content: string;
}

/** Sentinel wrapping the injected block; also used to avoid double-injection. */
export const MARKER = "<!-- harness-rules -->";

/**
 * Join rule files into one block, ordered by file name so a numeric prefix
 * (10-, 20-, …) controls sequence. Blank files are dropped. Returns "" when
 * there is nothing to inject.
 */
export function buildRulesBlock(files: RuleFile[]): string {
  const parts = files
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((f) => f.content.trim())
    .filter((c) => c.length > 0);

  if (parts.length === 0) return "";
  return `${MARKER}\n${parts.join("\n\n")}`;
}

/**
 * Append the rules block to a base system prompt, unless it is already present
 * (idempotent — safe even if Pi ever hands us a prompt that already carries it).
 */
export function appendRules(systemPrompt: string, block: string): string {
  if (block === "" || systemPrompt.includes(MARKER)) return systemPrompt;
  return `${systemPrompt}\n\n${block}`;
}
