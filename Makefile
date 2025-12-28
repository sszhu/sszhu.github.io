# Makefile: Micromamba + uv + VS Code "batteries-included" template
#
# Includes:
# - Tool bootstrapping (opt-in installers):
#     - micromamba: curl -L micro.mamba.pm/install.sh | bash (ALLOW_CURL_BASH=1)
#     - uv:        curl -fsSL https://astral.sh/uv/install.sh | bash (ALLOW_CURL_BASH=1)
#   Or install via Homebrew: brew install micromamba uv
# - Micromamba environment creation/update from environment.yml
# - Python dependency sync via uv inside micromamba env
# - VS Code generation:
#     - .vscode/settings.json (auto-detects env Python via micromamba run; no jq required)
#     - .vscode/tasks.json (tasks run inside env via micromamba run -n $(ENV_NAME))
#     - .vscode/launch.json
# - Project bootstrapping:
#     - pyproject.toml (if missing)
#     - .gitignore (if missing)
#     - .env from .env.example or placeholders
#     - src/<PACKAGE_NAME>/main.py + tests/test_smoke.py (if missing)
# - Aliases (opt-in): add/remove a marked micromamba alias block in ~/.bashrc and ~/.zshrc
# - Doctor checks: prerequisites, env Python, VS Code JSON validity, and pyproject.toml (TOML) validity
# - Dependency management: uv lock/update targets
# - Portability: OS-aware sed in-place; consistent task execution via micromamba
#
# Usage:
#   make init
#   make ensure-tools
#   make env sync vscode
#   make test lint typecheck
#   WITH_ALIASES=1 make aliases   # optional
#   make uninstall-aliases        # optional
#
# Configure:
#   make ENV_NAME=llm PACKAGE_NAME=your_project PYTHON_VERSION=3.11 init

SHELL := /bin/bash

.DEFAULT_GOAL := help

ENV_NAME ?= llm
PYTHON_VERSION ?= 3.11

PACKAGE_NAME ?= your_project
PROJECT_NAME ?= your-project
PROJECT_VERSION ?= 0.1.0

VSCODE_DIR := .vscode
SETTINGS_JSON := $(VSCODE_DIR)/settings.json
TASKS_JSON := $(VSCODE_DIR)/tasks.json
LAUNCH_JSON := $(VSCODE_DIR)/launch.json

ENV_FILE ?= .env
ENV_EXAMPLE ?= .env.example

# Install gating: disallow curl | bash unless explicitly opted-in
ALLOW_CURL_BASH ?= 0
WITH_ALIASES ?= 0

# OS detection for portable in-place editing
UNAME_S := $(shell uname -s)
SED_INPLACE := sed -i
ifeq ($(UNAME_S),Darwin)
	SED_INPLACE := sed -i ''
endif

.PHONY: help ensure-tools env sync vscode settings tasks launch \
	pyproject gitignore envfile init test lint typecheck clean \
	ensure-src-layout aliases uninstall-aliases doctor lock update \
	ci-setup lint-makefile

help:
	@echo "Targets:"
	@echo "  make init           One-shot setup (tools + env + deps + vscode + files + aliases)"
	@echo "  make ensure-tools   Install micromamba/uv if missing"
	@echo "  make doctor         Validate prerequisites, env and VS Code JSON"
	@echo "  make env            Create/update micromamba env from environment.yml"
	@echo "  make sync           uv sync --all-extras (inside micromamba env)"
	@echo "  make vscode         Generate .vscode/settings.json + tasks.json + launch.json"
	@echo "  make pyproject      Generate pyproject.toml if missing"
	@echo "  make gitignore      Generate .gitignore if missing"
	@echo "  make envfile        Create .env (from .env.example if exists)"
	@echo "  make aliases        Add common micromamba aliases to ~/.bashrc and ~/.zshrc (opt-in)"
	@echo "  make uninstall-aliases Remove installed alias block from shell rc files"
	@echo "  make test           Run pytest"
	@echo "  make lint           Run ruff check ."
	@echo "  make typecheck      Run mypy"
	@echo "  make clean          Remove caches"
	@echo "  make ci-setup       CI helper for preinstalled tools"
	@echo "  make lint-makefile  Detect space-indented recipe lines"
	@echo ""
	@echo "Options:"
	@echo "  ENV_NAME=$(ENV_NAME)"
	@echo "  PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "  PACKAGE_NAME=$(PACKAGE_NAME)"
	@echo "  PROJECT_NAME=$(PROJECT_NAME)"

# Install tools if not available
ensure-tools:
		@set -euo pipefail; \
		NEED_RESTART=0; \
		if ! command -v micromamba >/dev/null 2>&1; then \
			echo "==> micromamba not found."; \
			if [[ "$(ALLOW_CURL_BASH)" -eq 1 ]]; then \
				echo "Installing micromamba (opt-in via ALLOW_CURL_BASH=1)..."; \
				curl -L micro.mamba.pm/install.sh | bash; \
				NEED_RESTART=1; \
			else \
				echo "ERROR: micromamba missing. Set ALLOW_CURL_BASH=1 to auto-install, or install manually."; \
				echo "       Docs: https://mamba.readthedocs.io/ and Homebrew: brew install micromamba"; \
				exit 1; \
			fi; \
		else \
			echo "==> micromamba found: $$(command -v micromamba)"; \
		fi; \
		if ! command -v uv >/dev/null 2>&1; then \
			echo "==> uv not found."; \
			if [[ "$(ALLOW_CURL_BASH)" -eq 1 ]]; then \
				echo "Installing uv (opt-in via ALLOW_CURL_BASH=1)..."; \
				curl -fsSL https://astral.sh/uv/install.sh | bash; \
				NEED_RESTART=1; \
			else \
				echo "ERROR: uv missing. Set ALLOW_CURL_BASH=1 to auto-install, or install manually."; \
				echo "       Docs: https://docs.astral.sh/uv/ and Homebrew: brew install uv"; \
				exit 1; \
			fi; \
		else \
			echo "==> uv found: $$(command -v uv)"; \
		fi; \
		if [[ $$NEED_RESTART -eq 1 ]]; then \
			echo ""; \
			echo "⚠️  Tools were installed, but your current shell may not have updated PATH."; \
			echo "    Restart your terminal (or run: source ~/.zshrc or source ~/.bashrc),"; \
			echo "    then re-run: make init"; \
			echo ""; \
			exit 2; \
		fi

# (deprecated) jq previously used for env-path discovery; no longer required

# --- Micromamba environment ---------------------------------------------------

env: ensure-tools
	@test -f environment.yml || { echo "ERROR: environment.yml not found"; exit 1; }
	@echo "==> Creating/updating micromamba env: $(ENV_NAME)"
	@micromamba env create -f environment.yml -n "$(ENV_NAME)" >/dev/null 2>&1 || \
	  micromamba env update -f environment.yml -n "$(ENV_NAME)"

sync: ensure-tools
	@echo "==> uv sync (with extras) in env: $(ENV_NAME)"
	@micromamba run -n "$(ENV_NAME)" uv sync --all-extras

# --- Dependency management ---------------------------------------------------

lock:
	@echo "==> uv lock in env: $(ENV_NAME)"
	@micromamba run -n "$(ENV_NAME)" uv lock

update:
	@echo "==> uv sync --upgrade in env: $(ENV_NAME)"
	@micromamba run -n "$(ENV_NAME)" uv sync --upgrade

# --- VS Code generation -------------------------------------------------------

vscode: settings tasks launch
	@echo "==> VS Code files generated under $(VSCODE_DIR)/"

settings: ensure-tools
	@echo "==> Generating $(SETTINGS_JSON) for env: $(ENV_NAME)"
	@mkdir -p "$(VSCODE_DIR)"
	@PY_PATH="$$(micromamba run -n "$(ENV_NAME)" python -c 'import sys; print(sys.executable)' 2>/dev/null || command -v python3)"; \
	if [[ -z "$$PY_PATH" ]]; then \
	  echo "ERROR: Could not determine Python path (micromamba env '$(ENV_NAME)' missing and python3 not found)."; \
	  echo "       Tip: create env with 'make env' or install python3."; \
	  exit 1; \
	fi; \
	printf '%s\n' '{' \
	  '  "python.defaultInterpreterPath": "__PY_PATH__",' \
	  '  "python.terminal.activateEnvironment": true,' \
	  '  "python.envFile": "$$${workspaceFolder}/$(ENV_FILE)",' \
	  '' \
	  '  "python.testing.pytestEnabled": true,' \
	  '  "python.testing.pytestArgs": ["tests"],' \
	  '' \
	  '  "editor.formatOnSave": true,' \
	  '  "editor.codeActionsOnSave": {' \
	  '    "source.fixAll": "explicit",' \
	  '    "source.organizeImports": "explicit"' \
	  '  },' \
	  '' \
	  '  "ruff.enable": true' \
	  '}' \
	  > "$(SETTINGS_JSON)"; \
	$(SED_INPLACE) -e "s#__PY_PATH__#$$PY_PATH#g" "$(SETTINGS_JSON)";
	@echo "==> Wrote $(SETTINGS_JSON)"

tasks: ensure-tools
	@echo "==> Generating $(TASKS_JSON)"
	@mkdir -p "$(VSCODE_DIR)"
	printf '%s\n' '{' \
	  '  "version": "2.0.0",' \
	  '  "tasks": [' \
	  '    {' \
	  '      "label": "uv: sync (dev)",' \
	  '      "type": "shell",' \
	  '      "command": "micromamba run -n $(ENV_NAME) uv sync --all-extras",' \
	  '      "problemMatcher": []' \
	  '    },' \
	  '    {' \
	  '      "label": "test: pytest",' \
	  '      "type": "shell",' \
	  '      "command": "micromamba run -n $(ENV_NAME) pytest",' \
	  '      "problemMatcher": []' \
	  '    },' \
	  '    {' \
	  '      "label": "lint: ruff",' \
	  '      "type": "shell",' \
	  '      "command": "micromamba run -n $(ENV_NAME) ruff check .",' \
	  '      "problemMatcher": []' \
	  '    },' \
	  '    {' \
	  '      "label": "typecheck: mypy",' \
	  '      "type": "shell",' \
	  '      "command": "micromamba run -n $(ENV_NAME) mypy src",' \
	  '      "problemMatcher": []' \
	  '    }' \
	  '  ]' \
	  '}' \
	  > "$(TASKS_JSON)";
	@echo "==> Wrote $(TASKS_JSON)"

launch: ensure-tools
	@echo "==> Generating $(LAUNCH_JSON)"
	@mkdir -p "$(VSCODE_DIR)"
	printf '%s\n' '{' \
	  '  "version": "0.2.0",' \
	  '  "configurations": [' \
	  '    {' \
	  '      "name": "Run main",' \
	  '      "type": "python",' \
	  '      "request": "launch",' \
	  '      "module": "$(PACKAGE_NAME).main",' \
	  '      "justMyCode": true,' \
	  '      "envFile": "$${workspaceFolder}/$(ENV_FILE)"' \
	  '    },' \
	  '    {' \
	  '      "name": "Pytest current file",' \
	  '      "type": "python",' \
	  '      "request": "launch",' \
	  '      "module": "pytest",' \
	  '      "args": [],' \
	  '      "console": "integratedTerminal",' \
	  '      "justMyCode": true,' \
	  '      "envFile": "$${workspaceFolder}/$(ENV_FILE)"' \
	  '    }' \
	  '  ]' \
	  '}' \
	  > "$(LAUNCH_JSON)";
	# no sed needed; VS Code variables printed via printf tokenization to avoid Make expansion
	@echo "==> Wrote $(LAUNCH_JSON)"

# --- Project files generation -------------------------------------------------

pyproject:
	@if [[ -f pyproject.toml ]]; then \
	  echo "==> pyproject.toml already exists (skip)"; \
	else \
	  echo "==> Generating pyproject.toml"; \
	  printf '%s\n' \
	    '[project]' \
	    'name = "$(PROJECT_NAME)"' \
	    'version = "$(PROJECT_VERSION)"' \
	    'description = "Micromamba + uv + VS Code template"' \
	    'readme = "README.md"' \
	    'requires-python = ">=$(PYTHON_VERSION)"' \
	    'dependencies = [' \
	    '  "python-dotenv>=1.0.0",' \
	    '  "requests>=2.32.0",' \
	    ']' \
	    '' \
	    '[project.optional-dependencies]' \
	    'dev = [' \
	    '  "pytest>=8.0.0",' \
	    '  "pytest-cov>=5.0.0",' \
	    '  "ruff>=0.6.0",' \
	    '  "mypy>=1.10.0",' \
	    '  "ipykernel>=6.29.0",' \
	    ']' \
	    '' \
	    '[tool.pytest.ini_options]' \
	    'testpaths = ["tests"]' \
	    'addopts = "-q"' \
	    '' \
	    '[tool.ruff]' \
	    'line-length = 100' \
	    'target-version = "py311"' \
	    '' \
	    '[tool.mypy]' \
	    'python_version = "$(PYTHON_VERSION)"' \
	    'warn_return_any = true' \
	    'warn_unused_configs = true' \
	    'disallow_untyped_defs = false' \
	    'ignore_missing_imports = true' \
	    > pyproject.toml; \
	  echo "==> Wrote pyproject.toml"; \
	fi

gitignore:
	@if [[ -f .gitignore ]]; then \
	  echo "==> .gitignore already exists (skip)"; \
	else \
	  echo "==> Generating .gitignore"; \
	  printf '%s\n' \
	    '# env files' \
	    '.env' \
	    '' \
	    '# python caches' \
	    '__pycache__/' \
	    '*.py[cod]' \
	    '' \
	    '# tooling caches' \
	    '.pytest_cache/' \
	    '.mypy_cache/' \
	    '.ruff_cache/' \
	    '.coverage' \
	    'htmlcov/' \
	    '' \
	    '# build artifacts' \
	    'build/' \
	    'dist/' \
	    '*.egg-info/' \
	    '' \
	    '# notebooks' \
	    '.ipynb_checkpoints/' \
	    '' \
	    '# OS / editor' \
	    '.DS_Store' \
	    '.vscode/.ropeproject/' \
	    > .gitignore; \
	  echo "==> Wrote .gitignore"; \
	fi

envfile:
	@echo "==> Ensuring $(ENV_FILE) exists"
	@if [[ -f "$(ENV_FILE)" ]]; then \
	  echo "==> $(ENV_FILE) already exists (skip)"; \
	elif [[ -f "$(ENV_EXAMPLE)" ]]; then \
	  cp "$(ENV_EXAMPLE)" "$(ENV_FILE)"; \
	  echo "==> Copied $(ENV_EXAMPLE) -> $(ENV_FILE)"; \
	else \
	  printf '%s\n' '# Example runtime env vars' 'AWS_REGION=us-east-1' 'OPENSEARCH_ENDPOINT=your-collection.us-east-1.aoss.amazonaws.com' > "$(ENV_FILE)"; \
	  echo "==> Created $(ENV_FILE) with placeholders"; \
	fi

ensure-src-layout:
	@mkdir -p "src/$(PACKAGE_NAME)"
	@mkdir -p "tests"
	@if [[ ! -f "src/$(PACKAGE_NAME)/__init__.py" ]]; then echo "__all__ = []" > "src/$(PACKAGE_NAME)/__init__.py"; fi
	@if [[ ! -f "src/$(PACKAGE_NAME)/main.py" ]]; then \
	  printf '%s\n' \
	    'from __future__ import annotations' \
	    '' \
	    'import os' \
	    'from dotenv import load_dotenv' \
	    '' \
	    'def main() -> None:' \
	    '    load_dotenv()' \
	    '    print("Python:", os.sys.executable)' \
	    '    print("AWS_REGION:", os.getenv("AWS_REGION"))' \
	    '    print("OPENSEARCH_ENDPOINT:", os.getenv("OPENSEARCH_ENDPOINT"))' \
	    '' \
	    'if __name__ == "__main__":' \
	    '    main()' \
	    > "src/$(PACKAGE_NAME)/main.py"; \
	  echo "==> Created src/$(PACKAGE_NAME)/main.py (smoke script)"; \
	fi
	@if [[ ! -f "tests/test_smoke.py" ]]; then \
	  printf '%s\n' 'def test_smoke():' '    assert 1 + 1 == 2' > "tests/test_smoke.py"; \
	  echo "==> Created tests/test_smoke.py"; \
	fi

# --- Common micromamba aliases ------------------------------------------------
# Adds (idempotently) to ~/.bashrc and ~/.zshrc:
#   mm    -> micromamba
#   mamba -> micromamba
#   mma   -> micromamba activate
#   mmd   -> micromamba deactivate
#   mme   -> micromamba env list
#   mmr   -> micromamba run
aliases:
	@set -e; \
	if [[ "$(WITH_ALIASES)" -ne 1 ]]; then \
	  echo "INFO: aliases are opt-in. Run WITH_ALIASES=1 make aliases"; \
	  exit 0; \
	fi; \
	for rc in "$$HOME/.bashrc" "$$HOME/.zshrc"; do \
	  if [[ -f "$$rc" ]]; then \
	    if ! grep -q '^### BEGIN MICROMAMBA ALIASES' "$$rc"; then \
	      {
	        echo "### BEGIN MICROMAMBA ALIASES"; \
	        echo "alias mm=micromamba"; \
	        echo "alias mamba=micromamba"; \
	        echo "alias mma='micromamba activate'"; \
	        echo "alias mmd='micromamba deactivate'"; \
	        echo "alias mme='micromamba env list'"; \
	        echo "alias mmr='micromamba run'"; \
	        echo "### END MICROMAMBA ALIASES"; \
	      } >> "$$rc"; \
	      echo "Added alias block to $$rc"; \
	    else \
	      echo "Aliases block already present in $$rc (skip)"; \
	    fi; \
	  fi; \
	done; \
	echo ""; \
	echo "✅ Common micromamba aliases ensured (opt-in)."; \
	echo "👉 Restart your shell or run:"; \
	echo "   source ~/.bashrc   or   source ~/.zshrc"

uninstall-aliases:
	@set -e; \
	for rc in "$$HOME/.bashrc" "$$HOME/.zshrc"; do \
	  if [[ -f "$$rc" ]]; then \
	    $(SED_INPLACE) -e '/^### BEGIN MICROMAMBA ALIASES/,/^### END MICROMAMBA ALIASES/d' "$$rc"; \
	    echo "Removed alias block from $$rc (if present)"; \
	  fi; \
	done; \
	echo "✅ Uninstalled micromamba aliases block."

# --- One-shot setup -----------------------------------------------------------

init: ensure-tools env pyproject ensure-src-layout sync vscode envfile gitignore aliases
	@echo "==> Pre-check (doctor)"
	@$(MAKE) doctor || { echo "❌ Pre-check failed"; exit 1; }
	@echo "==> Provisioning"
	@echo ""
	@echo "✅ Done."
	@echo "Next:"
	@echo "  1) Open this folder in VS Code"
	@echo "  2) Run: make test"
	@echo ""
	@echo "Verification:"
	@echo "  micromamba run -n $(ENV_NAME) python -c \"import sys; print(sys.executable)\""
	@echo "==> Post-check (doctor)"
	@$(MAKE) doctor || { echo "❌ Post-check failed"; exit 1; }

# --- Dev commands -------------------------------------------------------------

test: ensure-tools
	@echo "==> pytest (env: $(ENV_NAME))"
	@micromamba run -n "$(ENV_NAME)" pytest

lint: ensure-tools
	@echo "==> ruff (env: $(ENV_NAME))"
	@micromamba run -n "$(ENV_NAME)" ruff check .

typecheck: ensure-tools
	@echo "==> mypy (env: $(ENV_NAME))"
	@micromamba run -n "$(ENV_NAME)" mypy src

clean:
	@echo "==> Cleaning caches"
	@rm -rf __pycache__ .pytest_cache .mypy_cache .ruff_cache .coverage htmlcov

# --- CI helper ---------------------------------------------------------------

ci-setup:
	@echo "==> CI Setup"
	@echo "Assuming tools preinstalled and PATH configured."
	@echo "You can run: make env sync vscode test"

# --- Makefile lint -----------------------------------------------------------

lint-makefile:
	@set -e; \
	BAD=$$(awk 'prev && match($$0,/^[ ]+/) {print NR} {prev = match($$0,/^[^#].*:$$/)}' Makefile); \
	if [[ -n "$$BAD" ]]; then \
	  echo "ERROR: space-indented recipe lines at: $$BAD"; \
	  exit 1; \
	else \
	  echo "OK: recipe indentation uses tabs"; \
	fi

# --- Doctor / Checks ---------------------------------------------------------

doctor:
	@set -euo pipefail; \
	FAIL=0; \
	echo "==> Doctor: prerequisites"; \
	for tool in micromamba uv curl; do \
	  if ! command -v $$tool >/dev/null 2>&1; then \
	    echo "ERROR: $$tool not found in PATH"; \
	    FAIL=1; \
	  else \
	    echo "OK: $$tool found ($$(command -v $$tool))"; \
	  fi; \
	done; \
	if [[ ! -f environment.yml ]]; then \
	  echo "ERROR: environment.yml missing"; \
	  FAIL=1; \
	else \
	  echo "OK: environment.yml present"; \
	fi; \
	echo "==> Doctor: micromamba env ($(ENV_NAME))"; \
	ENV_PY="$$(micromamba run -n "$(ENV_NAME)" python -c 'import sys; print(sys.executable)' 2>/dev/null || true)"; \
	if [[ -z "$$ENV_PY" ]]; then \
	  echo "ERROR: micromamba env '$(ENV_NAME)' not available or python not runnable"; \
	  FAIL=1; \
	else \
	  echo "OK: env python: $$ENV_PY"; \
	  case "$$ENV_PY" in *"$(ENV_NAME)"*) echo "OK: python path contains env name" ;; *) echo "WARN: python path may not be under the '$(ENV_NAME)' prefix" ;; esac; \
	fi; \
	echo "==> Doctor: VS Code JSON validity"; \
	JSON_CHECKER=$$(command -v python3 || echo ""); \
	for f in "$(SETTINGS_JSON)" "$(TASKS_JSON)" "$(LAUNCH_JSON)"; do \
	  if [[ -f "$$f" ]]; then \
	    if [[ -n "$$JSON_CHECKER" ]]; then \
	      if ! python3 -m json.tool "$$f" >/dev/null 2>&1; then \
	        echo "ERROR: invalid JSON: $$f"; \
	        FAIL=1; \
	      else \
	        echo "OK: valid JSON: $$f"; \
	      fi; \
	    elif [[ -n "$$ENV_PY" ]]; then \
	      if ! micromamba run -n "$(ENV_NAME)" python -m json.tool "$$f" >/dev/null 2>&1; then \
	        echo "ERROR: invalid JSON (env python): $$f"; \
	        FAIL=1; \
	      else \
	        echo "OK: valid JSON (env python): $$f"; \
	      fi; \
	    else \
	      echo "WARN: no python available to validate JSON for $$f"; \
	    fi; \
	  else \
	    echo "INFO: missing $$f (generate with 'make vscode')"; \
	  fi; \
	done; \
	echo "==> Doctor: pyproject.toml validity"; \
	if [[ -f "pyproject.toml" ]]; then \
	  if [[ -n "$$JSON_CHECKER" ]]; then \
	    if ! python3 -c 'import sys;\ntry:\n import tomllib;\n import pathlib;\n tomllib.load(pathlib.Path("pyproject.toml").open("rb"))\n print("OK: valid TOML: pyproject.toml")\nexcept Exception as e:\n print("ERROR: invalid TOML: pyproject.toml", file=sys.stderr);\n raise' >/dev/null 2>&1; then \
	      FAIL=1; \
	    fi; \
	  elif [[ -n "$$ENV_PY" ]]; then \
	    if ! micromamba run -n "$(ENV_NAME)" python -c 'import sys;\ntry:\n import tomllib;\n import pathlib;\n tomllib.load(pathlib.Path("pyproject.toml").open("rb"))\n print("OK: valid TOML (env python): pyproject.toml")\nexcept Exception as e:\n print("ERROR: invalid TOML (env python): pyproject.toml", file=sys.stderr);\n raise' >/dev/null 2>&1; then \
	      FAIL=1; \
	    fi; \
	  else \
	    echo "WARN: no python available to validate TOML"; \
	  fi; \
	else \
	  echo "INFO: pyproject.toml missing (generate with 'make pyproject')"; \
	fi; \
	echo "==> Doctor: Make variables"; \
	echo "ENV_NAME=$(ENV_NAME)"; \
	echo "PYTHON_VERSION=$(PYTHON_VERSION)"; \
	echo "PACKAGE_NAME=$(PACKAGE_NAME)"; \
	echo "PROJECT_NAME=$(PROJECT_NAME)"; \
	echo "PROJECT_VERSION=$(PROJECT_VERSION)"; \
	echo "ENV_FILE=$(ENV_FILE)"; \
	echo "UNAME_S=$(UNAME_S)"; \
	echo "==> Doctor: .env variables ($(ENV_FILE))"; \
	if [[ -f "$(ENV_FILE)" ]]; then \
	  while IFS= read -r line; do \
	    case "$$line" in \#*|'' ) continue ;; esac; \
	    key="$${line%%=*}"; \
	    val="$${line#*=}"; \
	    if [[ -n "$$val" ]]; then masked="$${val:0:4}***"; else masked=""; fi; \
	    printf 'ENV %s=%s\n' "$$key" "$$masked"; \
	  done < "$(ENV_FILE)"; \
	else \
	  echo "INFO: $(ENV_FILE) missing (create with 'make envfile')"; \
	fi; \
	if [[ $$FAIL -ne 0 ]]; then \
	  echo "❌ Doctor found issues"; \
	  exit 1; \
	else \
	  echo "✅ Doctor passed"; \
	fi

environment-yml:
	@if [[ -f environment.yml ]]; then \
	  echo "==> environment.yml already exists (skip)"; \
	else \
	  echo "==> Generating environment.yml (name=$(ENV_NAME), python=$(PYTHON_VERSION))"; \
	  printf '%s\n' \
	    'name: $(ENV_NAME)' \
	    'channels:' \
	    '  - conda-forge' \
	    'dependencies:' \
	    '  - python=$(PYTHON_VERSION)' \
	    '  - pip' \
	    > environment.yml; \
	  echo "==> Wrote environment.yml"; \
	fi
