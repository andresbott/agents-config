import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import harnessRules from "./index.ts";

// Minimal stand-in for the slice of Pi's ExtensionAPI this extension uses.
function makeFakePi() {
  const handlers = new Map<string, (event: any) => any>();
  const pi = { on: (event: string, handler: any) => handlers.set(event, handler) };
  return { pi, handlers };
}

// Point the extension at a throwaway rules.d via the env override.
function withRulesDir(files: Record<string, string>): string {
  const dir = mkdtempSync(join(tmpdir(), "harness-rules-"));
  for (const [name, content] of Object.entries(files)) {
    writeFileSync(join(dir, name), content);
  }
  process.env.PI_HARNESS_RULES_DIR = dir;
  return dir;
}

test("registers a before_agent_start handler", () => {
  withRulesDir({ "10-x.md": "RULE X" });
  const { pi, handlers } = makeFakePi();
  harnessRules(pi as any);
  assert.ok(handlers.has("before_agent_start"));
  delete process.env.PI_HARNESS_RULES_DIR;
});

test("injects rules.d/*.md into the system prompt, ordered by name", () => {
  withRulesDir({ "10-a.md": "FIRST RULE", "20-b.md": "SECOND RULE" });
  const { pi, handlers } = makeFakePi();
  harnessRules(pi as any);
  const result = handlers.get("before_agent_start")!({ systemPrompt: "BASE" });
  assert.ok(result?.systemPrompt.startsWith("BASE\n\n"), "kept the base prompt");
  assert.match(result.systemPrompt, /FIRST RULE[\s\S]*SECOND RULE/);
  delete process.env.PI_HARNESS_RULES_DIR;
});

test("injects nothing when the rules dir is absent", () => {
  process.env.PI_HARNESS_RULES_DIR = join(tmpdir(), `absent-${Date.now()}`);
  const { pi, handlers } = makeFakePi();
  harnessRules(pi as any);
  const onStart = handlers.get("before_agent_start")!;
  assert.equal(onStart({ systemPrompt: "BASE" }), undefined);
  delete process.env.PI_HARNESS_RULES_DIR;
});

test("does not double-inject when the block is already present", () => {
  withRulesDir({ "10-a.md": "RULE" });
  const { pi, handlers } = makeFakePi();
  harnessRules(pi as any);
  const onStart = handlers.get("before_agent_start")!;
  const once = onStart({ systemPrompt: "BASE" }).systemPrompt;
  assert.equal(onStart({ systemPrompt: once }), undefined, "second pass is a no-op");
  delete process.env.PI_HARNESS_RULES_DIR;
});
