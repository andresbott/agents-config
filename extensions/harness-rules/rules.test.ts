import { test } from "node:test";
import assert from "node:assert/strict";

import { appendRules, buildRulesBlock, MARKER } from "./rules.ts";

test("orders rule files by name and joins them", () => {
  const block = buildRulesBlock([
    { name: "20-b.md", content: "SECOND" },
    { name: "10-a.md", content: "FIRST" },
  ]);
  assert.ok(block.startsWith(MARKER), "block is marked");
  assert.match(block, /FIRST[\s\S]*SECOND/, "10- precedes 20-");
});

test("skips blank files and returns '' when nothing remains", () => {
  assert.equal(buildRulesBlock([{ name: "x.md", content: "  \n" }]), "");
  assert.equal(buildRulesBlock([]), "");
});

test("appendRules adds the block once and is idempotent via the marker", () => {
  const block = buildRulesBlock([{ name: "a.md", content: "R" }]);
  const once = appendRules("BASE", block);
  assert.equal(once, `BASE\n\n${block}`);
  assert.equal(appendRules(once, block), once, "no double-append");
});

test("appendRules with an empty block is a no-op", () => {
  assert.equal(appendRules("BASE", ""), "BASE");
});
