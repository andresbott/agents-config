# AGENTS.md

Guidance for AI agents working in this repository.

## What this repo is

Andrés's personal **Pi** configuration — a "pi-dotfiles" repo: the agent's
settings, context, skills, and extensions, versioned in git so the same setup is
reproducible across machines. The config is *applied* by installing this repo
as a Pi package (see [Applying the config](#applying-the-config)) — `pi` reads
`skills/`, `extensions/`, `prompts/`, and `themes/` straight from the package
source (no copy step), so edits here take effect immediately.

Pi is a terminal coding agent in the same family as Claude Code and omp; each
keeps its config under a home directory (`~/.pi/`, `~/.claude/`, `~/.omp/`). This
repo is the source of truth for the Pi side.

> **This `AGENTS.md` is the guide to working *on this repo*.** It is distinct
> from the **global-context** `AGENTS.md` that Pi loads for every project (your
> personal rules) — that payload lives separately in the tree. Unlike
> `skills/`/`extensions/`/`prompts/`/`themes/`, it is **not** a package resource
> kind `pi install` can place; it's a context file Pi discovers directly, so it
> still needs a manual link to `~/.pi/agent/AGENTS.md` (see
> [Applying the config](#applying-the-config)). Keep personal global rules out
> of this file.

## Status — migration in progress

This repo replaces the **`odo-private-config` Claude Code plugin marketplace**.
That marketplace's source lives in a separate repo, at
`/home/bott/.datos/edit/programacion-privado/odo-ai-marketplace`, and is being
ported into the Pi layout here.

- **`odo-ai-marketplace` is read-only legacy from this repo's perspective.**
  Don't edit it from here. Treat it as a reference to *mine* when porting a
  capability into the Pi structure.
- **New work goes at the repo root**, in the Pi layout below.

Worth porting from `odo-ai-marketplace` (see its `plugins/` directory): the
`coding-guides`, `land`, `architects`, `doc-authoring`, `go-idioms`,
`odo-repo`, and `session-sounds` plugins. For how the legacy marketplace
worked, see its `README.md`.

## Target layout

The Pi config follows the "pi-dotfiles" convention. **This is the target** — most
of it does not exist yet; the repo currently holds only `OLD_CONTENT/` and this
file. Build it out incrementally, and keep this list in sync as it fills in.

```
.
├── AGENTS.md            # this file — guide to working ON this repo
├── settings.json        # reference preferences (copied by hand — not part of `pi install`)
├── skills/              # SKILL.md skills
├── extensions/          # TypeScript extensions
├── prompts/             # prompt templates
├── themes/
└── <global AGENTS.md>   # (location TBD) personal rules linked to ~/.pi/agent/AGENTS.md
```

## Applying the config

```
git clone git@github.com:andresbott/agents-config.git && cd agents-config
pi install .            # registers this repo as a Pi package (user scope)
```

`pi install <path>` auto-discovers `skills/`, `extensions/`, `prompts/`, and
`themes/` at the package root and adds the source to
`~/.pi/agent/settings.json`'s `packages` list. For a **local path**, `pi` reads
the files in place (not copied), so edits here take effect live — no build or
reload step. From a different machine, the same command works against a git
source instead: `pi install git:github.com/andresbott/agents-config` (that
variant *is* cloned into a managed cache, so re-run `pi update <source>` to
pick up changes there). Use `pi install -l .` instead of `pi install .` to
install project-locally (`.pi/settings.json`) rather than for the current
user.

Two things `pi install` does **not** cover, both because they aren't a package
resource kind:

- **`settings.json` preferences** (`defaultProvider`, `defaultModel`, active
  `theme`, etc.) — copy the relevant keys from this repo's `settings.json` into
  `~/.pi/agent/settings.json` by hand, per machine. Some of these
  (provider/model choice) may legitimately differ per machine anyway.
- **The global-context `AGENTS.md` payload** — link or copy it directly to
  `~/.pi/agent/AGENTS.md` (**not** this repo-guide file).

> **Confirm before relying on this:** if the daily driver is `omp` rather than
> vanilla Pi, the target is `~/.omp/` (with `config.yml`) instead of `~/.pi/`,
> and it isn't yet confirmed whether `omp` has the same package-install
> mechanism. Decide which harness this repo standardizes on and update this
> section.

## Conventions for agents

- **Where work goes:** the repo root, in the Pi layout above. Never modify
  `odo-ai-marketplace` — it's a separate repo, kept read-only from here.
- **Keep the layout honest:** add a directory/file to *Target layout* only when
  it actually exists.
- **Commits:** Conventional Commits (`feat(scope): …`, `docs: …`, `ci: …`),
  matching the existing history.
- **No version-bump rule.** The old marketplace required bumping
  `.claude-plugin/marketplace.json` on every commit; that mechanism lives only in
  legacy `OLD_CONTENT/` and does **not** apply to new work here.
