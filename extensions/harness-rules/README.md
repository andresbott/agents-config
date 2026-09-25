# harness-rules

A Pi extension that injects the user's **standing harness rules** into every
session — the Pi port of the Claude `coding-guides` plugin, whose SessionStart
hook did the same thing.

## What it does

On every turn it reads the drop-in dir **`<pi-agent-dir>/rules.d/*.md`**,
concatenates the files (ordered by file name), and appends the result to Pi's
system prompt — so the rules are always loaded.

The extension is pure **mechanism**: it carries no rules of its own. The rule
files live in this repo's top-level [`rules/`](../../rules) and are symlinked
into `~/.pi/agent/rules.d/` by `make pi-install`. Editing a rule in the repo is
therefore live (it's a symlink) — run `/reload` to pick it up.

## Where it reads from

Resolved in priority order:

1. `$PI_HARNESS_RULES_DIR` — explicit override (also used by the tests)
2. `$PI_CODING_AGENT_DIR/rules.d` — respects a customised Pi home
3. `~/.pi/agent/rules.d` — the default

## How it works

Pi has no plugin-style SessionStart injection, but its extension API does: the
`before_agent_start` event can modify the system prompt. So `index.ts` reads
`rules.d` on load and `on("before_agent_start")` appends the block.

Pi rebuilds the prompt each turn, so appending every turn does not accumulate; a
marker guard makes re-appending idempotent regardless. The assembly logic lives
in [`rules.ts`](./rules.ts) as a pure, dependency-free function; `index.ts` is
the I/O + wiring. Both are unit-tested.

## Install

From this repo it's listed in `../../pi-packages.txt`, so:

```sh
make pi-install        # installs the extension AND symlinks rules/ into rules.d
```

Standalone (extension only — you must populate `rules.d` yourself):

```sh
pi install ./extensions/harness-rules
```

## Test

```sh
npm test
# node --experimental-strip-types --test ./rules.test.ts ./index.test.ts
```

## Notes

- **Adding/removing a rule file** needs the symlink in place (`make pi-install`)
  and a `/reload` (the block is read on extension load).
- **Content is Claude-flavoured in places.** `20-tool-execution.md` names
  Claude's tools and `60-skills-and-exploration.md` is about superpowers /
  Explore agents / tokensave — most of which does not apply under Pi. Trim or
  Pi-adapt those files in `rules/` as needed.
