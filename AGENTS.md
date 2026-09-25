# AGENTS.md

Guidance for AI agents working in this repository.

## What this repo is

Andrés's personal **Pi** configuration, kept as a dotfiles repo: the Pi package
manifest, keybindings, and default settings versioned in git so the same setup is
reproducible across machines. It targets **Pi** (`~/.pi/agent/`, overridable via
`$PI_CODING_AGENT_DIR`).

`make pi-install` installs the packages and symlinks config files into the Pi home,
so edits here take effect live (see [Applying the config](#applying-the-config)).

**Skills, standing rules, and the gitauto workflows are not managed here.** They
live in [`ai-extension-collection`](https://github.com/andresbott/ai-extension-collection)
(a Claude marketplace + Pi package), which is installed from `pi-packages.txt`.
Do not re-add `skills/`, `rules/`, or `workflows/` directories.

> **This `AGENTS.md` is the guide to working *on this repo*.** It is distinct from
> the **global-context** `AGENTS.md` / `CLAUDE.md` that a harness loads for every
> project (your personal rules); that payload lives separately and is linked into
> each harness home by hand. Keep personal global rules out of this file.

## Why dotfiles, not a plugin

A Pi package (`pi install`) distributes only `skills` / `extensions` / `prompts` /
`themes`, never settings or keybindings. Those per-machine files are what this repo
links; everything distributable belongs in a package.

**Named agents are not managed here** — they are distributed as a plugin. Do not
re-add an `agents/` directory.

## Status — porting from the old marketplace

This repo replaces the **`odo-private-config` Claude Code plugin marketplace**. That
marketplace's source lives in a separate repo, at
`/home/bott/.datos/edit/programacion-privado/odo-ai-marketplace`, and its capabilities
are being ported into this dotfiles layout.

- **`odo-ai-marketplace` is read-only legacy from this repo's perspective.** Don't
  edit it from here — mine it as a reference when porting a capability.
- **New work goes at the repo root**, in the dotfiles layout below.

Worth porting from `odo-ai-marketplace` (see its `plugins/` directory): the
`coding-guides`, `land`, `architects`, `doc-authoring`, `go-idioms`, `odo-repo`,
and `session-sounds` plugins.

> **Skills, rules, extensions, and gitauto moved out.** `go-idioms`, `doc-authoring`,
> `coding-guides` (rule content plus the Pi extension that injects it), the Pi
> extensions, and the gitauto workflows now live in `ai-extension-collection`. This
> repo ships no local extensions.

## Target layout

**This is the target** — some of it does not exist yet. Build it out incrementally
and keep this list in sync. Items marked *(planned)* have no files.

```
.
├── AGENTS.md            # this file — guide to working ON this repo
├── Makefile             # pi-install (needs pi-tokensave) / pi-tokensave / pi-settings / pi-status / pi-unlink
├── scripts/             # Makefile helpers (settings-missing-keys.jq, apply-package-filter.jq, mcp-*.jq)
├── pi-packages.txt      # Pi package manifest, installed by `make pi-install`
├── keybindings.json     # linked into ~/.pi/agent/ by `make pi-install`
├── prompts/             # prompt templates (planned)
├── themes/              # (planned)
├── settings.json        # default Pi preferences — merged under ~/.pi/agent/settings.json (live values win)
├── mcp.json             # default MCP servers — seeded into ~/.pi/agent/mcp.json by server name
├── pi-permission-system.json # starter permission policy — copied to ~/.pi/agent/extensions/pi-permission-system/config.json if missing
└── <global AGENTS.md>   # (location TBD) personal rules, linked into each harness home by hand
```

## Applying the config

```sh
git clone git@github.com:andresbott/agents-config.git && cd agents-config
make pi-install    # pi-tokensave (check, register MCP, git-ignore .tokensave/), npm tools (qmd), permission policy, pi-packages.txt, settings defaults, MCP servers, link keybindings.json
```

`pi-install` re-points its own stale links and never clobbers a real file it did not
create. Before the Pi packages it runs `npm install -g` for each tool in
`PI_NPM_GLOBALS` (a Makefile variable) that is missing — e.g. `@tobilu/qmd`, the
`qmd` backend `npm:pi-memory` shells out to. Add new global npm dependencies of Pi
packages there, not in `pi-packages.txt` (which `pi install` consumes).

**tokensave setup is its own target.** `pi-install` depends on `pi-tokensave`, so
it runs first (and alone via `make pi-tokensave`). It checks that `tokensave` is on
`PATH` and fails with install hints if not (it is a Rust binary, so it is not
auto-installed) — before anything else is written. Then it runs `tokensave install
--agent pi --git-hook $(TOKENSAVE_GIT_HOOK)` (default `yes`) to register the MCP
server in `<agent-dir>/mcp.json` (it creates the agent dir if needed, and the MCP
seeding that runs later merges into its file). Last, it appends `.tokensave/` (the per-project
index `tokensave init` creates) to the user's global gitignore — `git config --global
core.excludesFile` if set, else git's default `${XDG_CONFIG_HOME:-~/.config}/git/ignore`
— unless an equivalent line (`.tokensave`, `/.tokensave/`, `**/.tokensave/`) is
already there; it never sets `core.excludesFile` itself. Keep tokensave-only steps in
`pi-tokensave`, not in `pi-install`.

`pi-unlink` removes only the symlinks that point back into this repo, and
`pi-status` shows installed packages, missing settings defaults, missing MCP servers, the permission policy, and linked config.
Override `PI_CODING_AGENT_DIR` (and `PI=echo NPM=echo TOKENSAVE=echo`) on the command line to test against
a scratch dir; the gitignore step follows `$HOME`, so prefix `HOME=/tmp/t` to keep it off the real one.

**Filtered packages.** A `pi-packages.txt` line starting with `{` is the JSON object
form Pi keeps in `settings.json` (`{"source":"git:…","skills":["skills/x"]}`).
`pi-install` installs its `source`, then `scripts/apply-package-filter.jq` swaps the
plain-string settings entry `pi install` wrote for that object. Like settings defaults it
only seeds: an entry that is already an object (e.g. edited in `pi config`) is kept, and
re-running `pi install` preserves object entries. Filters narrow what loads, not what is
cloned — git sources are full clones. `pi-status` reports such a package as
`UNFILTERED` if its live entry is still a plain string.

**Settings are defaults, not a mirror.** Pi has no defaults layer (it merges only
`~/.pi/agent/settings.json` and a project `.pi/settings.json`, project winning), so
`make pi-settings` (run by `pi-install`) deep-merges this repo's `settings.json`
*under* the live file with `jq -s '.[0] * .[1]'`: missing keys are added, live values
win, arrays are replaced whole. Do not symlink `settings.json` — Pi writes through
the link (`/settings`, `/model`, `pi install`, `lastChangelogVersion`). Keep
`packages` out of it (that is `pi-packages.txt`), and keep per-machine choices such
as `defaultProvider` / `defaultModel` out unless they should seed every machine.

**MCP servers are seeded by name.** `pi-install` adds each
server in this repo's `mcp.json` whose name is missing from
`<agent-dir>/mcp.json` (the file `npm:pi-mcp-adapter` reads), via
`scripts/mcp-seed-servers.jq`. Unlike settings, server definitions are atomic — a
live entry with the same name wins whole and is never deep-merged (a live stdio
`command` must not gain a default `url`); other live keys (`settings`, `imports`)
are kept. Keep the defaults keyless: no API keys or tokens in the repo. A key
goes in the live entry (`headers` / `bearerToken`, which support `${VAR}`), which
the seeding then leaves alone. The repo file is safe at the root: the adapter
loads project config only from `.mcp.json` and `.pi/mcp.json`. tokensave
registers itself in the same file and merges rather than overwrites, so it is
not listed here.

**The permission policy is copied once, never merged.** `npm:@gotgenes/pi-permission-system`
reads `<agent-dir>/extensions/pi-permission-system/config.json`; with no file,
every tool call asks. So `pi-install` copies `pi-permission-system.json` there
*before* installing packages, and only when nothing (not even a symlink) is at that
path. It is not linked — the extension rewrites the file (temp file + rename, which
would replace a link) — and not merged, because a merged-in rule could silently
loosen or tighten a policy the user has edited. Keep it plain JSON (a rewrite drops
comments) and valid against the package's `schemas/permissions.schema.json`.

The starter is **restrictive on purpose** and meant to be relaxed rule by rule as
prompts get in the way. Its shape, which a change should keep:

- `"*": "ask"` — any tool not listed prompts (network, subagents, workflows,
  browser, memory writes, `mcpScript`). Read-only tools are allowed by name; any
  registered tool name is a valid key.
- **Writes are gated in one place, `path_write`**, which covers the `write`/`edit`
  tools, bash redirects, `find -delete`, and path-bearing extension tools. Its
  `"*"` is `allow`: file edits inside the working tree need no approval, while
  `external_directory` still asks outside it and the secret and policy denies
  hold. To make writes ask again, set `path_write`'s `"*"` back to `ask` — not
  the `write`/`edit` tool keys: every gate that says `ask` prompts separately,
  so asking on both would double-prompt each write, and the bash allowlist does
  not stop writes by itself (`cat > f <<EOF` is an allowed `cat`; only
  `path_write` catches the redirect). With `ask` there, an extension tool with a
  `path` argument (e.g. `ffgrep`, `read_symbol`) prompts even when the tool is
  allowed, because extension tools consult both read and write surfaces.
- `path_read` / `path_write` are written out rather than as bare `path`, so
  either direction can be tightened on its own: sugar entries come first and
  explicit ones after, so a bare `path` deny would be overridden by a later
  `path_write` `"*"` (last match wins). Keep every secret deny in **both** maps,
  after their `"*"`.
- `external_directory` (the outside-the-working-tree gate) is split the same
  way: `_read` is `allow` (reading anywhere; the `path_read` secret denies still
  apply), `_write` is `ask`. Only the built-in `read` / `grep` / `find` / `ls` and
  the package's pure-reader bash words (`cat`, `grep`, `ls`, `find`, `head`, …)
  prove a read and get the free pass. Extension and MCP tools (`ffgrep`,
  `read_symbol`, …) prove no direction — hardcoded in the package
  (`effectProvenByTool`), no config key — so outside the tree they also consult
  `_write` and still prompt; inside it they are free because `path_write` allows.
  Making them silent outside would need `external_directory_write: allow`, which
  would let every tool write outside the tree — don't. If one external tree gets
  noisy, grant it on `_write` itself as a map —
  `"external_directory_write": {"*": "ask", "~/src/*": "allow"}` — knowing that
  lets every tool write there. (Not on bare `external_directory`: its entries
  expand first, so the explicit `_write` `"*"` after them would win.)
- `bash` is `"*": "ask"` plus read-only commands (exact forms for `git branch`,
  whose other forms mutate). Hard denies (`sudo`, `doas`, force-push) carry a
  `reason` so the agent learns what to do instead.

`npm:pi-subagents` runs subagents as subprocesses that cannot forward an `ask` to
the parent, so inside them every `ask` is a deny — under this policy subagents and
workflow workers can read and edit files in the working tree, but any command off
the bash allowlist (running tests, builds, `git commit`) is denied. Allowing those
commands is the next step to let them work unattended.

Only one Pi subagent engine is installed on purpose (`npm:pi-subagents`, listed in
`pi-packages.txt`): `@tintinweb/pi-subagents` was dropped because it loaded the same
named agents a second time via a parallel `Agent` tool.

One thing the Makefile does **not** cover:

- **The global-context `AGENTS.md` / `CLAUDE.md` payload** — link or copy it directly
  into each harness home (`~/.pi/agent/AGENTS.md`, `~/.claude/CLAUDE.md`), **not** this
  repo-guide file.

> **Confirm before relying on this:** if a machine's daily driver is `omp` rather than
> vanilla Pi, its home is `~/.omp/` (with `config.yml`); add it as a third link target
> once that's confirmed.

## Conventions

- **Keep the layout honest:** add a directory/file to *Target layout* only once it
  actually exists.
- **Commits:** Conventional Commits (`feat(scope): …`, `docs: …`, `ci: …`), matching
  the existing history.
- **No version-bump rule.** The old marketplace required bumping
  `.claude-plugin/marketplace.json` on every commit; there is no package or manifest
  here, so nothing like that applies.
