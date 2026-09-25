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
├── Makefile             # pi-install / pi-settings / pi-status / pi-unlink
├── scripts/             # Makefile helpers (settings-missing-keys.jq, apply-package-filter.jq, mcp-*.jq)
├── pi-packages.txt      # Pi package manifest, installed by `make pi-install`
├── keybindings.json     # linked into ~/.pi/agent/ by `make pi-install`
├── prompts/             # prompt templates (planned)
├── themes/              # (planned)
├── settings.json        # default Pi preferences — merged under ~/.pi/agent/settings.json (live values win)
├── mcp.json             # default MCP servers — seeded into ~/.pi/agent/mcp.json by server name
└── <global AGENTS.md>   # (location TBD) personal rules, linked into each harness home by hand
```

## Applying the config

```sh
git clone git@github.com:andresbott/agents-config.git && cd agents-config
make pi-install    # tokensave check, npm tools (qmd), pi-packages.txt, settings defaults, MCP servers, link keybindings.json, register tokensave
```

`pi-install` re-points its own stale links and never clobbers a real file it did not
create. Before the Pi packages it runs `npm install -g` for each tool in
`PI_NPM_GLOBALS` (a Makefile variable) that is missing — e.g. `@tobilu/qmd`, the
`qmd` backend `npm:pi-memory` shells out to. Add new global npm dependencies of Pi
packages there, not in `pi-packages.txt` (which `pi install` consumes). `pi-install`
first checks that `tokensave` is on `PATH` and fails with install hints if not (it is a
Rust binary, so it is not auto-installed); at the end it runs `tokensave install
--agent pi --git-hook $(TOKENSAVE_GIT_HOOK)` (default `yes`) to register the MCP
server in `<agent-dir>/mcp.json`. `pi-unlink` removes only the symlinks that point back into this repo, and
`pi-status` shows installed packages, missing settings defaults, missing MCP servers, and linked config.
Override `PI_CODING_AGENT_DIR` (and `PI=echo NPM=echo TOKENSAVE=echo`) on the command line to test against
a scratch dir.

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
