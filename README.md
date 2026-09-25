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
| Permissions | `pi-permission-system.json`: restrictive starter allow / ask / deny policy | **Ready:** copied by `make pi-install` only when no live policy exists | — |
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
| `npm:@gotgenes/pi-permission-system` | allow / ask / deny policy for tools, bash commands, paths, MCP, and skills (with no policy file, every tool call asks) |
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
  `make pi-install` (via `pi-tokensave`) fails early if it is missing
- A Nerd Font if you want the statusline icons

```sh
git clone git@github.com:andresbott/agents-config.git
cd agents-config
make pi-install
```

`make pi-install`:

1. first runs its prerequisite `make pi-tokensave` (also runnable on its own), which:
   - fails early, with install hints, if `tokensave` is not on `PATH`;
   - runs `tokensave install --agent pi --git-hook yes`, which registers the
     tokensave MCP server in `~/.pi/agent/mcp.json` and installs its git sync hooks
     (override with `TOKENSAVE_GIT_HOOK=no`). Run `tokensave init` in each project
     to index it;
   - adds `.tokensave/` (that per-project index) to your global gitignore, so no
     project needs its own entry: the file named by `git config --global
     core.excludesFile`, or git's default `~/.config/git/ignore` when unset. It is
     appended once and skipped if an equivalent line is already there;
2. runs `npm install -g` for each tool in `PI_NPM_GLOBALS` that is not already
   installed — currently `@tobilu/qmd`, the `qmd` search backend `npm:pi-memory`
   needs, and `agent-browser`, the browser engine `npm:pi-agent-browser-native`
   drives (it uses system Chrome if found; otherwise run `agent-browser install`);
3. copies the starter permission policy `pi-permission-system.json` to
   `~/.pi/agent/extensions/pi-permission-system/config.json`, only if no file is
   there yet. Without it `npm:@gotgenes/pi-permission-system` makes every tool call
   ask, so this runs before the packages. The policy is deliberately restrictive,
   to be relaxed as needed: reading files anywhere, file edits inside the working
   directory, and read-only tools / bash commands (`ls`, `cat`, `grep`, `ffgrep`,
   `git status|diff|log|show`, …) run freely; every other command or tool, and any
   write outside the working directory, asks (so do path-taking extension tools
   such as `ffgrep` pointed outside it); secrets (`.env*`, `~/.ssh`, `~/.aws`,
   `~/.gnupg`, gh and git credentials, Pi's `auth.json`), `sudo`, force-push, and
   edits to the policy itself are denied.
   Inside `npm:pi-subagents` subagents an `ask` cannot reach you and is denied, so
   under this policy subagents can read and edit files but not run other commands.
   Edit the live file to change the policy — it is never overwritten, and the
   extension rewrites it itself, so it is copied rather than linked;
4. installs every non-comment entry from `pi-packages.txt` (needs `jq`). A JSON-object
   line installs its `source`, then seeds that object's resource filter into
   `~/.pi/agent/settings.json`, replacing the plain-string entry once and never
   overwriting an entry that is already an object;
5. merges `settings.json` defaults under `~/.pi/agent/settings.json` (needs `jq`):
   keys missing from the live file are added, keys already set live are kept, and
   arrays such as `enabledModels` are replaced whole rather than merged. It never
   touches a symlinked or invalid live file. Run only this step with
   `make pi-settings`;
6. adds every server in the repo `mcp.json` whose name is missing from
   `~/.pi/agent/mcp.json` (needs `jq`) — currently Context7
   (`https://mcp.context7.com/mcp`, no API key: public docs at anonymous rate
   limits). Servers are added whole, by name: an existing live entry with the same
   name (e.g. one you gave an API key) is never touched, and other live keys are
   kept. A removed default comes back on the next run — set `"disabled": true` on
   it instead;
7. links `keybindings.json` into the Pi home without replacing an unrelated real file.

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
HOME=/tmp/t make pi-install PI=echo NPM=echo TOKENSAVE=echo   # dry run that also spares your global gitignore
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
pi-permission-system.json  starter permission policy, copied when none exists
scripts/              Makefile helpers (settings-merge, package-filter and MCP-seed jq filters)
TODO.md               remaining setup and porting work
AGENTS.md             instructions for agents working on this repository
```

## Development notes

- Use Conventional Commit subjects when committing changes.
- Do not edit the legacy `odo-ai-marketplace` repository from this project; it is
  reference material only while remaining capabilities are ported.
