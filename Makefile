# agents-config — Pi dotfiles installer
#
# Pi setup:   make pi-install   installs the packages in pi-packages.txt, then
#             symlinks home config (keybindings.json) into ~/.pi/agent.
#
# Skills, rules and gitauto workflows now ship from the ai-extension-collection
# package (listed in pi-packages.txt), not from this repo.
#
# Config files are linked, not copied, so edits take effect live.
# Override the target dir / installer to test against a scratch dir, e.g.:
#   make pi-install PI=echo PI_CODING_AGENT_DIR=/tmp/t/pi
# shellcheck disable=SC1089,SC2034,SC2157,SC2170  # Make expands $$ and strips recipe @ prefixes before /bin/sh.

SHELL := /bin/sh

PI_CODING_AGENT_DIR ?= $(HOME)/.pi/agent
PI_PACKAGES         ?= $(CURDIR)/pi-packages.txt
PI_HOME_FILES       := keybindings.json
PI_SETTINGS_DEFAULTS ?= $(CURDIR)/settings.json
PI_SETTINGS         ?= $(PI_CODING_AGENT_DIR)/settings.json
PI                  ?= pi
# jq filter listing repo defaults the live settings file lacks.
JQ_MISSING_DEFAULTS := $(CURDIR)/scripts/settings-missing-keys.jq

default: help

.PHONY: pi-install pi-settings pi-status pi-unlink help

#==========================================================================================
##@ Pi
#==========================================================================================
pi-install: ## install packages, merge settings defaults, link config into Pi
	@[ -f "$(PI_PACKAGES)" ] || echo "no manifest at $(PI_PACKAGES) — skipping package install"
	@[ ! -f "$(PI_PACKAGES)" ] || { \
		fail=0; \
		while IFS= read -r line || [ -n "$$line" ]; do \
			case "$$line" in ''|\#*) continue;; esac; \
			echo ">> installing $$line"; \
			$(PI) install "$$line" </dev/null || fail=1; \
		done < "$(PI_PACKAGES)"; \
		[ $$fail -eq 0 ] || { echo "!! some installs failed" >&2; exit 1; }; \
	}
	@$(MAKE) --no-print-directory pi-settings
	@mkdir -p "$(PI_CODING_AGENT_DIR)"
	@for f in $(PI_HOME_FILES); do \
		src="$(CURDIR)/$$f"; dest="$(PI_CODING_AGENT_DIR)/$$f"; \
		[ -f "$$src" ] || continue; \
		if [ -L "$$dest" ]; then ln -sfn "$$src" "$$dest"; echo "relink  $$dest"; \
		elif [ -e "$$dest" ]; then echo "SKIP    $$dest (real file, left untouched)"; \
		else ln -s "$$src" "$$dest"; echo "link    $$dest"; fi; \
	done

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

pi-status: ## show Pi state — packages, settings defaults, config linked
	@echo "Packages (pi-packages.txt vs installed):"
	@installed=$$($(PI) list </dev/null 2>/dev/null); \
	if [ -f "$(PI_PACKAGES)" ]; then \
		while IFS= read -r line || [ -n "$$line" ]; do \
			case "$$line" in ''|\#*) continue;; esac; \
			if printf '%s\n' "$$installed" | grep -qF "$$line"; then \
				echo "  installed  $$line"; \
			else \
				echo "  MISSING    $$line"; \
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
