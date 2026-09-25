import { readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { appendRules, buildRulesBlock, type RuleFile } from "./rules.ts";

// Pi extension: inject the user's standing "harness rules" into the system
// prompt every session. The rules are NOT bundled here — they are read from a
// drop-in dir (`<pi-agent-dir>/rules.d/*.md`) that this repo symlinks its
// rules/ into via `make pi-install`. So content lives in git and this extension
// is pure mechanism. Ports the Claude coding-guides SessionStart hook to Pi's
// `before_agent_start` event.
//
// Pi rebuilds the system prompt each turn (before_agent_start chaining is across
// extensions within a turn, not across turns), so appending every turn does not
// accumulate; the MARKER guard in appendRules makes it idempotent regardless.
export default function harnessRules(pi: ExtensionAPI): void {
  const block = loadRulesBlock(resolveRulesDir());

  pi.on("before_agent_start", (event) => {
    const systemPrompt = appendRules(event.systemPrompt, block);
    if (systemPrompt === event.systemPrompt) return undefined;
    return { systemPrompt };
  });
}

/**
 * Directory the rule files are read from, in priority order:
 *   1. $PI_HARNESS_RULES_DIR        — explicit override (also used by tests)
 *   2. $PI_CODING_AGENT_DIR/rules.d — respects a customised Pi home
 *   3. ~/.pi/agent/rules.d          — the default Pi home
 */
export function resolveRulesDir(): string {
  const override = process.env.PI_HARNESS_RULES_DIR;
  if (override) return override;
  const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
  return join(agentDir, "rules.d");
}

/** Read <dir>/*.md and assemble the injected block; inject nothing on error. */
function loadRulesBlock(dir: string): string {
  try {
    const files: RuleFile[] = readdirSync(dir)
      .filter((name) => name.endsWith(".md"))
      .map((name) => ({ name, content: readFileSync(join(dir, name), "utf8") }));
    return buildRulesBlock(files);
  } catch {
    // Missing / unreadable rules.d → inject nothing rather than break startup.
    return "";
  }
}
