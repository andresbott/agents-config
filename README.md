# agents-config

Personal coding-agent configuration for **Pi**. Pi packages are declared in
`pi-packages.txt` and installed by `make pi-install`; local config files are
linked into the Pi home.

> **Current status:** skills, standing rules, and the gitauto workflows have moved
> to [`ai-extension-collection`](https://github.com/andresbott/ai-extension-collection),
> which serves both Pi and Claude Code. This repository no longer manages anything
> for Claude Code.

## Capability matrix

| Area | What this repository contains | Pi | Claude Code |
|---|---|---|---|
| Installer | `Makefile` with install, unlink, and status targets | **Ready:** `make pi-install`, `pi-status`, `pi-unlink` | — |
| Named agents | Not managed here — distributed as a separate plugin | — | — |
| Skills, standing rules, gitauto | Moved to `ai-extension-collection` | Via that package (in progress) | Via that marketplace |
| Third-party packages | Reproducible package list in `pi-packages.txt` | **Ready:** installed by `make pi-install` | **Pending:** Claude marketplace/plugin state is not declared here |
| Superpowers | `obra/superpowers` development-process skills and session bootstrap | **Ready:** installed as a Git Pi package | **Pending:** install separately through Claude's official plugin marketplace |
| Local extensions | None — every Pi extension (coding-guides standing rules, startup splash, statusline, `/clear`, `/context`, clear-on-exit) comes from `ai-extension-collection` | Via that package | — |
| Preferences | `settings.json`: default Pi preferences (theme, startup, TUI, models, thinking level, autocomplete, terminal, telemetry, warnings) | **Ready:** merged under the live settings by `make pi-install` (live values win) | **Pending** |
| MCP servers | `mcp.json`: default MCP servers (Context7, keyless) | **Ready:** seeded into the live `mcp.json` by `make pi-install` (existing entries win) | **Pending** |
| Keybindings | `keybindings.json` with follow-up, thinking, and newline bindings | **Ready:** linked into the Pi home by `make pi-install` | **Pending** |
| Prompts and themes | Reserved in the target layout | **Pending** | **Pending** |

## Pi extensions

This repository ships no Pi extensions of its own. The coding-guides standing
rules, startup splash, statusline, `/clear`, `/context`, and clear-on-exit
extensions live in [`ai-extension-collection`](https://github.com/andresbott/ai-extension-collection)
and are installed from `pi-packages.txt`.

## Pi package inventory

`pi-packages.txt` is the reproducible package manifest consumed by
`make pi-install`.

| Package | Capability |
|---|---|
| `npm:pi-subagents` | Native subagent engine and supervisor tooling |
| `npm:pi-mcp-adapter` | Low-context MCP client and server configuration bridge |
| `npm:pi-web-access` | Web search, URL fetching, GitHub, PDF, and video access |
| `npm:pi-memory` | Persistent memory across Pi sessions |
| `npm:pi-lens` | LSP, diagnostics, and code-intelligence tooling |
| `npm:@ff-labs/pi-fff` | Fast fuzzy file and content search |
| `npm:@quintinshaw/pi-dynamic-workflows` | Multi-agent workflows, model routing, accounting, and worktree isolation |
| `npm:pi-agent-browser-native` | Browser automation via a native `agent_browser` tool over the `agent-browser` CLI |
| `git:github.com/obra/superpowers` | Brainstorming, planning, TDD, debugging, review, worktree, and completion skills with a Pi bootstrap extension |
| `git:github.com/andresbott/ai-extension-collection` | Personal extensions: coding-guides standing rules, startup splash, statusline, `/clear`, `/context`, clear-on-exit, gitauto adapter |
| `git:github.com/anthropics/skills` (filtered) | Only the `frontend-design` skill; the rest of Anthropic's skills repo is cloned but not loaded |

Pi packages and extensions execute code with the user's permissions. Review new
third-party sources before adding them to `pi-packages.txt`.

## Install

### Pi

Prerequisites:

- Pi installed and available as `pi`
- Git and Make
- [tokensave](https://github.com/aovestdipaperino/tokensave) on `PATH`
  (`brew install aovestdipaperino/tap/tokensave` or `cargo binstall tokensave`);
  `make pi-install` fails early if it is missing
- A Nerd Font if you want the statusline icons

```sh
git clone git@github.com:andresbott/agents-config.git
cd agents-config
make pi-install
```

`make pi-install`:

1. runs `npm install -g` for each tool in `PI_NPM_GLOBALS` that is not already
   installed — currently `@tobilu/qmd`, the `qmd` search backend `npm:pi-memory`
   needs, and `agent-browser`, the browser engine `npm:pi-agent-browser-native`
   drives (it uses system Chrome if found; otherwise run `agent-browser install`);
2. installs every non-comment entry from `pi-packages.txt` (needs `jq`). A JSON-object
   line installs its `source`, then seeds that object's resource filter into
   `~/.pi/agent/settings.json`, replacing the plain-string entry once and never
   overwriting an entry that is already an object;
3. merges `settings.json` defaults under `~/.pi/agent/settings.json` (needs `jq`):
   keys missing from the live file are added, keys already set live are kept, and
   arrays such as `enabledModels` are replaced whole rather than merged. It never
   touches a symlinked or invalid live file. Run only this step with
   `make pi-settings`;
4. adds every server in the repo `mcp.json` whose name is missing from
   `~/.pi/agent/mcp.json` (needs `jq`) — currently Context7
   (`https://mcp.context7.com/mcp`, no API key: public docs at anonymous rate
   limits). Servers are added whole, by name: an existing live entry with the same
   name (e.g. one you gave an API key) is never touched, and other live keys are
   kept. A removed default comes back on the next run — set `"disabled": true` on
   it instead;
5. links `keybindings.json` into the Pi home without replacing an unrelated real file;
6. runs `tokensave install --agent pi --git-hook yes`, which registers the tokensave
   MCP server in `~/.pi/agent/mcp.json` and installs its git sync hooks (override
   with `TOKENSAVE_GIT_HOOK=no`). Run `tokensave init` in each project to index it.

Restart Pi after the first installation so all packages and bootstrap extensions
load. Re-run `make pi-install` after changing the package manifest.

Inspect or remove the managed links with:

```sh
make pi-status
make pi-unlink   # leaves installed Pi packages in place
```

To target another Pi home:

```sh
make pi-install PI_CODING_AGENT_DIR=/path/to/pi-home
make pi-install PI=echo NPM=echo TOKENSAVE=echo PI_CODING_AGENT_DIR=/tmp/t/pi   # dry run
```

### Claude Code

Not managed here. Install the `ai-extension-collection` marketplace in Claude Code
for skills, rules, and gitauto.

## Linking behavior

- Linked config files remain the source of truth; `keybindings.json` edits take
  effect from this checkout.
- Existing real files in the Pi home are never overwritten.
- Stale symlinks previously created for the same file are safely repointed.
- `make pi-unlink` removes only links that point back into this repository.
- Override `PI_CODING_AGENT_DIR` to test against a scratch location.

## Repository layout

```text
Makefile              installation and link management
pi-packages.txt       reproducible Pi package manifest
keybindings.json      linked Pi keybindings
settings.json         default Pi preferences, merged under the live settings
mcp.json              default MCP servers, seeded into the live mcp.json by name
scripts/              Makefile helpers (settings-merge, package-filter and MCP-seed jq filters)
TODO.md               remaining setup and porting work
AGENTS.md             instructions for agents working on this repository
```

## Development notes

- Use Conventional Commit subjects when committing changes.
- Do not edit the legacy `odo-ai-marketplace` repository from this project; it is
  reference material only while remaining capabilities are ported.
