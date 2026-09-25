# agents-config — Pi dotfiles installer
#
# Pi setup:   make pi-install   installs the packages in pi-packages.txt, seeds
#             settings and MCP server defaults, then symlinks home config
#             (keybindings.json) into ~/.pi/agent.
#
# Skills, rules and gitauto workflows now ship from the ai-extension-collection
# package (listed in pi-packages.txt), not from this repo.
#
# Config files are linked, not copied, so edits take effect live.
# Override the target dir / installers to test against a scratch dir, e.g.:
#   make pi-install PI=echo NPM=echo TOKENSAVE=echo PI_CODING_AGENT_DIR=/tmp/t/pi
# shellcheck disable=SC1089,SC2034,SC2157,SC2170  # Make expands $$ and strips recipe @ prefixes before /bin/sh.

SHELL := /bin/sh

PI_CODING_AGENT_DIR ?= $(HOME)/.pi/agent
PI_PACKAGES         ?= $(CURDIR)/pi-packages.txt
PI_HOME_FILES       := keybindings.json
PI_SETTINGS_DEFAULTS ?= $(CURDIR)/settings.json
PI_SETTINGS         ?= $(PI_CODING_AGENT_DIR)/settings.json
PI                  ?= pi
# Default MCP servers (repo mcp.json), seeded into the live <agent-dir>/mcp.json by
# server name; a live entry with the same name is never touched.
PI_MCP_DEFAULTS     ?= $(CURDIR)/mcp.json
PI_MCP_CONFIG       ?= $(PI_CODING_AGENT_DIR)/mcp.json
# Starter policy for npm:@gotgenes/pi-permission-system, copied only when the live
# file is missing. Never linked or merged: the extension rewrites that file itself.
PI_PERMISSION_DEFAULTS ?= $(CURDIR)/pi-permission-system.json
PI_PERMISSION_CONFIG   ?= $(PI_CODING_AGENT_DIR)/extensions/pi-permission-system/config.json
# Global npm tools that Pi packages shell out to (installed before the packages).
#   @tobilu/qmd   — `qmd` search backend required by npm:pi-memory
#   agent-browser — browser engine CLI required by npm:pi-agent-browser-native
PI_NPM_GLOBALS      ?= @tobilu/qmd agent-browser
NPM                 ?= npm
# tokensave — code-graph MCP server, registered in <agent-dir>/mcp.json (read by
# npm:pi-mcp-adapter) by the pi-tokensave target, a prerequisite of pi-install.
# Required but not auto-installed: pi-tokensave fails if missing.
TOKENSAVE           ?= tokensave
TOKENSAVE_GIT_HOOK  ?= yes
# Its per-project .tokensave/ index is added to the user's global gitignore
# (git config --global core.excludesFile, else git's default ~/.config/git/ignore).
GIT                 ?= git
# jq filter listing repo defaults the live settings file lacks.
JQ_MISSING_DEFAULTS := $(CURDIR)/scripts/settings-missing-keys.jq
# jq filter seeding a manifest JSON line's resource filter into the live settings.
JQ_PACKAGE_FILTER   := $(CURDIR)/scripts/apply-package-filter.jq
# jq filters listing / seeding repo MCP servers the live mcp.json lacks.
JQ_MCP_MISSING      := $(CURDIR)/scripts/mcp-missing-servers.jq
JQ_MCP_SEED         := $(CURDIR)/scripts/mcp-seed-servers.jq

default: help

.PHONY: pi-install pi-tokensave pi-settings pi-status pi-unlink help

#==========================================================================================
##@ Pi
#==========================================================================================
pi-install: pi-tokensave ## full Pi setup (tokensave, packages, settings, MCP, permissions, links)
	@for p in $(PI_NPM_GLOBALS); do \
		if $(NPM) ls -g --depth=0 "$$p" >/dev/null 2>&1; then echo "ok      $$p (npm global already installed)"; \
		else echo ">> npm install -g $$p"; $(NPM) install -g "$$p" </dev/null || { echo "!! npm install -g $$p failed" >&2; exit 1; }; fi; \
	done
	@# Before the packages, so the permission extension never loads without a policy
	@# (with none, every tool call asks).
	@src="$(PI_PERMISSION_DEFAULTS)"; dest="$(PI_PERMISSION_CONFIG)"; \
	if [ ! -f "$$src" ]; then echo "no permission policy at $$src — skipping"; \
	elif [ -e "$$dest" ] || [ -L "$$dest" ]; then echo "ok      $$dest (permission policy exists, left untouched)"; \
	else mkdir -p "$$(dirname "$$dest")" && cp "$$src" "$$dest" && echo "create  $$dest (starter permission policy)"; fi
	@[ -f "$(PI_PACKAGES)" ] || echo "no manifest at $(PI_PACKAGES) — skipping package install"
	@[ ! -f "$(PI_PACKAGES)" ] || { \
		command -v jq >/dev/null 2>&1 || { echo "pi-install: jq is required" >&2; exit 1; }; \
		fail=0; dest="$(PI_SETTINGS)"; \
		while IFS= read -r line || [ -n "$$line" ]; do \
			case "$$line" in ''|\#*) continue;; esac; \
			entry=; src=$$line; \
			case "$$line" in '{'*) \
				entry=$$line; \
				src=$$(printf '%s\n' "$$entry" | jq -er '.source | strings') \
					|| { echo "!! bad manifest entry (need a JSON object with a string .source): $$entry" >&2; fail=1; continue; };; \
			esac; \
			echo ">> installing $$src"; \
			$(PI) install "$$src" </dev/null || { fail=1; continue; }; \
			[ -n "$$entry" ] || continue; \
			if [ -L "$$dest" ]; then echo "SKIP    filter for $$src ($$dest is a symlink)"; \
			elif [ ! -f "$$dest" ]; then echo "SKIP    filter for $$src (no $$dest)"; \
			elif ! jq -e --arg src "$$src" 'any(.packages[]?; . == $$src)' "$$dest" >/dev/null; then \
				echo "ok      filter for $$src (no plain-string entry; live settings kept)"; \
			else \
				tmp=$$(mktemp) || { fail=1; continue; }; \
				if jq --argjson entry "$$entry" -f "$(JQ_PACKAGE_FILTER)" "$$dest" > "$$tmp"; then \
					cp "$$tmp" "$$dest"; echo "filter  $$src (seeded resource filter into $$dest)"; \
				else echo "!! seeding filter for $$src failed" >&2; fail=1; fi; \
				rm -f "$$tmp"; \
			fi; \
		done < "$(PI_PACKAGES)"; \
		[ $$fail -eq 0 ] || { echo "!! some installs failed" >&2; exit 1; }; \
	}
	@$(MAKE) --no-print-directory pi-settings
	@command -v jq >/dev/null 2>&1 || { echo "pi-install: jq is required" >&2; exit 1; }
	@src="$(PI_MCP_DEFAULTS)"; dest="$(PI_MCP_CONFIG)"; \
	[ -f "$$src" ] || { echo "no MCP defaults at $$src — skipping MCP seeding"; exit 0; }; \
	jq -e '.mcpServers | type == "object"' "$$src" >/dev/null 2>&1 || { echo "pi-install: $$src needs an .mcpServers object" >&2; exit 1; }; \
	if [ -L "$$dest" ]; then echo "SKIP    $$dest (symlink, left untouched)"; exit 0; fi; \
	if [ ! -e "$$dest" ]; then \
		mkdir -p "$$(dirname "$$dest")" && cp "$$src" "$$dest" && echo "create  $$dest (from defaults)"; exit $$?; \
	fi; \
	jq -e 'type == "object" and ((.mcpServers // {}) | type == "object")' "$$dest" >/dev/null 2>&1 \
		|| { echo "pi-install: $$dest is not an MCP config object" >&2; exit 1; }; \
	missing=$$(jq -r -s -f "$(JQ_MCP_MISSING)" "$$src" "$$dest") || exit 1; \
	if [ -z "$$missing" ]; then echo "ok      $$dest (all default MCP servers present)"; exit 0; fi; \
	tmp=$$(mktemp) || exit 1; \
	if jq -s -f "$(JQ_MCP_SEED)" "$$src" "$$dest" > "$$tmp"; then \
		cp "$$tmp" "$$dest"; rm -f "$$tmp"; echo "mcp     $$dest (added: $$missing)"; \
	else rm -f "$$tmp"; echo "pi-install: MCP seeding failed" >&2; exit 1; fi
	@mkdir -p "$(PI_CODING_AGENT_DIR)"
	@for f in $(PI_HOME_FILES); do \
		src="$(CURDIR)/$$f"; dest="$(PI_CODING_AGENT_DIR)/$$f"; \
		[ -f "$$src" ] || continue; \
		if [ -L "$$dest" ]; then ln -sfn "$$src" "$$dest"; echo "relink  $$dest"; \
		elif [ -e "$$dest" ]; then echo "SKIP    $$dest (real file, left untouched)"; \
		else ln -s "$$src" "$$dest"; echo "link    $$dest"; fi; \
	done

pi-tokensave: ## check tokensave is installed, register its MCP server in Pi, git-ignore .tokensave/ globally
	@command -v "$(TOKENSAVE)" >/dev/null 2>&1 || { \
		echo "!! tokensave is required but '$(TOKENSAVE)' is not on PATH. Install it, then re-run make pi-install:" >&2; \
		echo "     brew install aovestdipaperino/tap/tokensave   # or: cargo binstall tokensave" >&2; \
		echo "     prebuilt binaries: https://github.com/aovestdipaperino/tokensave/releases/latest" >&2; \
		exit 1; }
	@echo ">> tokensave install --agent pi --git-hook $(TOKENSAVE_GIT_HOOK)"
	@PI_CODING_AGENT_DIR="$(PI_CODING_AGENT_DIR)" $(TOKENSAVE) install --agent pi --git-hook "$(TOKENSAVE_GIT_HOOK)" </dev/null \
		|| { echo "!! tokensave install failed" >&2; exit 1; }
	@f=$$($(GIT) config --global --get core.excludesFile); \
	[ -n "$$f" ] || f="$${XDG_CONFIG_HOME:-$$HOME/.config}/git/ignore"; \
	case "$$f" in "~/"*) f="$$HOME/$${f#??}";; esac; \
	if [ -f "$$f" ] && grep -qxE '(\*\*/|/)?\.tokensave/?' "$$f"; then \
		echo "ok      $$f (.tokensave/ already git-ignored)"; \
	else \
		mkdir -p "$$(dirname "$$f")" || exit 1; \
		if [ -s "$$f" ] && [ -n "$$(tail -c1 "$$f")" ]; then echo >> "$$f"; fi; \
		printf '%s\n' "# tokensave per-project index (added by agents-config make pi-tokensave)" ".tokensave/" >> "$$f" \
			|| { echo "!! could not update global gitignore $$f" >&2; exit 1; }; \
		echo "ignore  $$f (added .tokensave/)"; \
	fi

pi-settings: ## merge repo settings.json defaults under the live Pi settings (live values win)
	@command -v jq >/dev/null 2>&1 || { echo "pi-settings: jq is required" >&2; exit 1; }
	@src="$(PI_SETTINGS_DEFAULTS)"; dest="$(PI_SETTINGS)"; \
	[ -f "$$src" ] || { echo "no defaults at $$src — skipping settings merge"; exit 0; }; \
	jq -e 'type == "object"' "$$src" >/dev/null 2>&1 || { echo "pi-settings: $$src is not a JSON object" >&2; exit 1; }; \
	if [ -L "$$dest" ]; then echo "SKIP    $$dest (symlink, left untouched)"; exit 0; fi; \
	if [ ! -e "$$dest" ]; then \
		mkdir -p "$$(dirname "$$dest")" && cp "$$src" "$$dest" && echo "create  $$dest (from defaults)"; exit $$?; \
	fi; \
	jq -e 'type == "object"' "$$dest" >/dev/null 2>&1 || { echo "pi-settings: $$dest is not a JSON object" >&2; exit 1; }; \
	missing=$$(jq -r -s -f "$(JQ_MISSING_DEFAULTS)" "$$src" "$$dest") || exit 1; \
	if [ -z "$$missing" ]; then echo "ok      $$dest (all defaults already set)"; exit 0; fi; \
	tmp=$$(mktemp) || exit 1; \
	if jq -s '.[0] * .[1]' "$$src" "$$dest" > "$$tmp"; then \
		cp "$$tmp" "$$dest"; rm -f "$$tmp"; echo "merge   $$dest (added: $$missing)"; \
	else rm -f "$$tmp"; echo "pi-settings: merge failed" >&2; exit 1; fi

pi-status: ## show Pi state — npm tools, packages, settings defaults, MCP servers, permission policy, config linked
	@echo "npm globals (PI_NPM_GLOBALS):"
	@for p in $(PI_NPM_GLOBALS); do \
		if $(NPM) ls -g --depth=0 "$$p" >/dev/null 2>&1; then echo "  installed  $$p"; \
		else echo "  MISSING    $$p"; fi; \
	done
	@echo "Packages (pi-packages.txt vs installed):"
	@installed=$$($(PI) list </dev/null 2>/dev/null); \
	if [ -f "$(PI_PACKAGES)" ]; then \
		while IFS= read -r line || [ -n "$$line" ]; do \
			case "$$line" in ''|\#*) continue;; esac; \
			src=$$line; want=; \
			case "$$line" in '{'*) \
				src=$$(printf '%s\n' "$$line" | jq -r '.source // empty' 2>/dev/null); \
				[ -n "$$src" ] || src=$$line; want=" (filtered)";; \
			esac; \
			if ! printf '%s\n' "$$installed" | grep -qF "$$src"; then \
				echo "  MISSING    $$src"; \
			elif [ -n "$$want" ] && ! printf '%s\n' "$$installed" | grep -qF "$$src$$want"; then \
				echo "  UNFILTERED $$src (make pi-install seeds the filter)"; \
			else \
				echo "  installed  $$src$$want"; \
			fi; \
		done < "$(PI_PACKAGES)"; \
	else echo "  (no manifest)"; fi
	@echo "Settings defaults (settings.json vs live):"
	@src="$(PI_SETTINGS_DEFAULTS)"; dest="$(PI_SETTINGS)"; \
	if ! command -v jq >/dev/null 2>&1; then echo "  (jq not installed)"; \
	elif [ ! -f "$$src" ]; then echo "  (no defaults)"; \
	elif [ ! -f "$$dest" ]; then echo "  absent     $$dest"; \
	else \
		missing=$$(jq -r -s -f "$(JQ_MISSING_DEFAULTS)" "$$src" "$$dest" 2>/dev/null); \
		if [ -z "$$missing" ]; then echo "  applied    all defaults set"; \
		else echo "  MISSING    $$missing"; fi; \
	fi
	@echo "MCP servers (mcp.json vs live):"
	@src="$(PI_MCP_DEFAULTS)"; dest="$(PI_MCP_CONFIG)"; \
	if ! command -v jq >/dev/null 2>&1; then echo "  (jq not installed)"; \
	elif [ ! -f "$$src" ]; then echo "  (no defaults)"; \
	elif [ ! -f "$$dest" ]; then echo "  absent     $$dest"; \
	elif ! missing=$$(jq -r -s -f "$(JQ_MCP_MISSING)" "$$src" "$$dest" 2>/dev/null); then echo "  INVALID    $$dest"; \
	elif [ -z "$$missing" ]; then echo "  applied    all default servers present"; \
	else echo "  MISSING    $$missing"; fi
	@echo "Permission policy (pi-permission-system):"
	@dest="$(PI_PERMISSION_CONFIG)"; \
	if [ -f "$$dest" ]; then echo "  present    $$dest"; \
	else echo "  MISSING    $$dest (with none, every tool call asks)"; fi
	@echo "Config files (~/.pi/agent):"
	@for f in $(PI_HOME_FILES); do \
		dest="$(PI_CODING_AGENT_DIR)/$$f"; \
		if [ -L "$$dest" ]; then \
			case "$$(readlink "$$dest")" in \
				"$(CURDIR)"/*) echo "  linked     $$f";; \
				*) echo "  foreign    $$f -> $$(readlink "$$dest")";; \
			esac; \
		elif [ -e "$$dest" ]; then echo "  real file  $$f"; \
		else echo "  absent     $$f"; fi; \
	done

pi-unlink: ## remove this repo's config symlinks from Pi (leaves packages installed)
	@for f in $(PI_HOME_FILES); do \
		dest="$(PI_CODING_AGENT_DIR)/$$f"; \
		if [ -L "$$dest" ]; then \
			case "$$(readlink "$$dest")" in \
				"$(CURDIR)"/*) rm "$$dest"; echo "unlink  $$dest";; \
				*) echo "keep    $$dest (points outside this repo)";; \
			esac; \
		fi; \
	done

#==========================================================================================
#  Help
#==========================================================================================
help: # Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
