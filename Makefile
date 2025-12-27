# Makefile: Micromamba + uv + VS Code "batteries-included" template
#
# Includes:
# - Tool bootstrapping:
#     - If micromamba missing: curl -L micro.mamba.pm/install.sh | bash
#     - If uv missing:        curl -fsSL https://astral.sh/uv/install.sh | bash
# - micromamba env create/update from environment.yml
# - uv sync --all-extras inside micromamba env
# - Generates:
#     - .vscode/settings.json (auto-detects env python path via micromamba info --json + jq)
#     - .vscode/tasks.json
#     - .vscode/launch.json
#     - pyproject.toml (if missing)
#     - .gitignore (if missing)
#     - .env (from .env.example if exists; else creates placeholders)
#     - src/<PACKAGE_NAME>/main.py + tests/test_smoke.py (if missing)
# - Adds common micromamba aliases to ~/.bashrc and ~/.zshrc (idempotent)
#
# Usage:
#   make init
#   make ensure-tools
#   make env sync vscode aliases
#   make test lint typecheck
#
# Configure:
#   make ENV_NAME=llm PACKAGE_NAME=your_project PYTHON_VERSION=3.11 init

SHELL := /bin/bash

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

.PHONY: help ensure-tools ensure-jq env sync vscode settings tasks launch \
        pyproject gitignore envfile init test lint typecheck clean \
        ensure-src-layout aliases

help:
	@echo "Targets:"
	@echo "  make init           One-shot setup (tools + env + deps + vscode + files + aliases)"
	@echo "  make ensure-tools   Install micromamba/uv if missing"
	@echo "  make env            Create/update micromamba env from environment.yml"
	@echo "  make sync           uv sync --all-extras (inside micromamba env)"
	@echo "  make vscode         Generate .vscode/settings.json + tasks.json + launch.json"
	@echo "  make pyproject      Generate pyproject.toml if missing"
	@echo "  make gitignore      Generate .gitignore if missing"
	@echo "  make envfile        Create .env (from .env.example if exists)"
	@echo "  make aliases        Add common micromamba aliases to ~/.bashrc and ~/.zshrc"
	@echo "  make test           Run pytest"
	@echo "  make lint           Run ruff check ."
	@echo "  make typecheck      Run mypy"
	@echo "  make clean          Remove caches"
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
	  echo "==> micromamba not found. Installing..."; \
	  curl -L micro.mamba.pm/install.sh | bash; \
	  NEED_RESTART=1; \
	else \
	  echo "==> micromamba found: $$(command -v micromamba)"; \
	fi; \
	if ! command -v uv >/dev/null 2>&1; then \
	  echo "==> uv not found. Installing..."; \
	  curl -fsSL https://astral.sh/uv/install.sh | bash; \
	  NEED_RESTART=1; \
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

# jq is required to locate the env path for VS Code settings generation
ensure-jq:
	@command -v jq >/dev/null 2>&1 || { \
	  echo "ERROR: jq not found in PATH (required for 'make settings')."; \
	  echo "       Install jq (e.g., via Homebrew: brew install jq) and retry."; \
	  exit 1; \
	}

# --- Micromamba environment ---------------------------------------------------

env: ensure-tools
	@test -f environment.yml || { echo "ERROR: environment.yml not found"; exit 1; }
	@echo "==> Creating/updating micromamba env: $(ENV_NAME)"
	@micromamba env create -f environment.yml -n "$(ENV_NAME)" >/dev/null 2>&1 || \
	  micromamba env update -f environment.yml -n "$(ENV_NAME)"

sync: ensure-tools
	@echo "==> uv sync (with extras) in env: $(ENV_NAME)"
	@micromamba run -n "$(ENV_NAME)" uv sync --all-extras

# --- VS Code generation -------------------------------------------------------

vscode: settings tasks launch
	@echo "==> VS Code files generated under $(VSCODE_DIR)/"

settings: ensure-tools ensure-jq
	@echo "==> Generating $(SETTINGS_JSON) for env: $(ENV_NAME)"
	@mkdir -p "$(VSCODE_DIR)"
	@ENV_PREFIX="$$(micromamba info --json | jq -r '.envs[] | select(endswith("/$(ENV_NAME)"))' | head -n 1)"; \
	if [[ -z "$$ENV_PREFIX" || "$$ENV_PREFIX" == "null" ]]; then \
	  echo "ERROR: Could not find env prefix for '$(ENV_NAME)' via micromamba info --json"; \
	  echo "       Try: micromamba env list"; \
	  exit 1; \
	fi; \
	PY_PATH="$$ENV_PREFIX/bin/python"; \
	if [[ ! -x "$$PY_PATH" ]]; then \
	  echo "ERROR: Python not found/executable at: $$PY_PATH"; \
	  exit 1; \
	fi; \
	cat > "$(SETTINGS_JSON)" <<EOF
{
  "python.defaultInterpreterPath": "$$PY_PATH",
  "python.terminal.activateEnvironment": true,
  "python.envFile": "\$${workspaceFolder}/$(ENV_FILE)",

  "python.testing.pytestEnabled": true,
  "python.testing.pytestArgs": ["tests"],

  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit",
    "source.organizeImports": "explicit"
  },

  "ruff.enable": true
}
EOF
	@echo "==> Wrote $(SETTINGS_JSON)"

tasks: ensure-tools
	@echo "==> Generating $(TASKS_JSON)"
	@mkdir -p "$(VSCODE_DIR)"
	@cat > "$(TASKS_JSON)" <<EOF
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "uv: sync (dev)",
      "type": "shell",
      "command": "uv sync --all-extras",
      "problemMatcher": []
    },
    {
      "label": "test: pytest",
      "type": "shell",
      "command": "pytest",
      "problemMatcher": []
    },
    {
      "label": "lint: ruff",
      "type": "shell",
      "command": "ruff check .",
      "problemMatcher": []
    },
    {
      "label": "typecheck: mypy",
      "type": "shell",
      "command": "mypy src",
      "problemMatcher": []
    }
  ]
}
EOF
	@echo "==> Wrote $(TASKS_JSON)"

launch: ensure-tools
	@echo "==> Generating $(LAUNCH_JSON)"
	@mkdir -p "$(VSCODE_DIR)"
	@cat > "$(LAUNCH_JSON)" <<EOF
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run main",
      "type": "python",
      "request": "launch",
      "module": "$(PACKAGE_NAME).main",
      "justMyCode": true,
      "envFile": "\$${workspaceFolder}/$(ENV_FILE)"
    },
    {
      "name": "Pytest current file",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["\${file}"],
      "console": "integratedTerminal",
      "justMyCode": true,
      "envFile": "\$${workspaceFolder}/$(ENV_FILE)"
    }
  ]
}
EOF
	@echo "==> Wrote $(LAUNCH_JSON)"

# --- Project files generation -------------------------------------------------

pyproject:
	@if [[ -f pyproject.toml ]]; then \
	  echo "==> pyproject.toml already exists (skip)"; \
	else \
	  echo "==> Generating pyproject.toml"; \
	  cat > pyproject.toml <<EOF
[project]
name = "$(PROJECT_NAME)"
version = "$(PROJECT_VERSION)"
description = "Micromamba + uv + VS Code template"
readme = "README.md"
requires-python = ">=$(PYTHON_VERSION)"
dependencies = [
  "python-dotenv>=1.0.0",
  "requests>=2.32.0",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.0.0",
  "pytest-cov>=5.0.0",
  "ruff>=0.6.0",
  "mypy>=1.10.0",
  "ipykernel>=6.29.0",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-q"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.mypy]
python_version = "$(PYTHON_VERSION)"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = false
ignore_missing_imports = true
EOF \
	  ; echo "==> Wrote pyproject.toml"; \
	fi

gitignore:
	@if [[ -f .gitignore ]]; then \
	  echo "==> .gitignore already exists (skip)"; \
	else \
	  echo "==> Generating .gitignore"; \
	  cat > .gitignore <<'EOF'
# env files
.env

# python caches
__pycache__/
*.py[cod]

# tooling caches
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
htmlcov/

# build artifacts
build/
dist/
*.egg-info/

# notebooks
.ipynb_checkpoints/

# OS / editor
.DS_Store
.vscode/.ropeproject/
EOF \
	  ; echo "==> Wrote .gitignore"; \
	fi

envfile:
	@echo "==> Ensuring $(ENV_FILE) exists"
	@if [[ -f "$(ENV_FILE)" ]]; then \
	  echo "==> $(ENV_FILE) already exists (skip)"; \
	elif [[ -f "$(ENV_EXAMPLE)" ]]; then \
	  cp "$(ENV_EXAMPLE)" "$(ENV_FILE)"; \
	  echo "==> Copied $(ENV_EXAMPLE) -> $(ENV_FILE)"; \
	else \
	  cat > "$(ENV_FILE)" <<EOF
# Example runtime env vars
AWS_REGION=us-east-1
OPENSEARCH_ENDPOINT=your-collection.us-east-1.aoss.amazonaws.com
EOF \
	  ; echo "==> Created $(ENV_FILE) with placeholders"; \
	fi

ensure-src-layout:
	@mkdir -p "src/$(PACKAGE_NAME)"
	@mkdir -p "tests"
	@if [[ ! -f "src/$(PACKAGE_NAME)/__init__.py" ]]; then echo "__all__ = []" > "src/$(PACKAGE_NAME)/__init__.py"; fi
	@if [[ ! -f "src/$(PACKAGE_NAME)/main.py" ]]; then \
	  cat > "src/$(PACKAGE_NAME)/main.py" <<'EOF'
from __future__ import annotations

import os
from dotenv import load_dotenv

def main() -> None:
    load_dotenv()
    print("Python:", os.sys.executable)
    print("AWS_REGION:", os.getenv("AWS_REGION"))
    print("OPENSEARCH_ENDPOINT:", os.getenv("OPENSEARCH_ENDPOINT"))

if __name__ == "__main__":
    main()
EOF \
	  ; echo "==> Created src/$(PACKAGE_NAME)/main.py (smoke script)"; \
	fi
	@if [[ ! -f "tests/test_smoke.py" ]]; then \
	  cat > "tests/test_smoke.py" <<'EOF'
def test_smoke():
    assert 1 + 1 == 2
EOF \
	  ; echo "==> Created tests/test_smoke.py"; \
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
	add_alias() { \
	  line="$$1"; file="$$2"; \
	  if [[ -f "$$file" ]] && ! grep -Fxq "$$line" "$$file"; then \
	    echo "$$line" >> "$$file"; \
	    echo "Added to $$file: $$line"; \
	  fi; \
	}; \
	for rc in "$$HOME/.bashrc" "$$HOME/.zshrc"; do \
	  if [[ -f "$$rc" ]]; then \
	    add_alias "alias mm=micromamba" "$$rc"; \
	    add_alias "alias mamba=micromamba" "$$rc"; \
	    add_alias "alias mma='micromamba activate'" "$$rc"; \
	    add_alias "alias mmd='micromamba deactivate'" "$$rc"; \
	    add_alias "alias mme='micromamba env list'" "$$rc"; \
	    add_alias "alias mmr='micromamba run'" "$$rc"; \
	  fi; \
	done; \
	echo ""; \
	echo "✅ Common micromamba aliases added (if not already present)."; \
	echo "👉 Restart your shell or run:"; \
	echo "   source ~/.bashrc   or   source ~/.zshrc"

# --- One-shot setup -----------------------------------------------------------

init: ensure-tools env pyproject ensure-src-layout sync vscode envfile gitignore aliases
	@echo ""
	@echo "✅ Done."
	@echo "Next:"
	@echo "  1) Open this folder in VS Code"
	@echo "  2) Run: make test"
	@echo ""
	@echo "Verification:"
	@echo "  micromamba run -n $(ENV_NAME) python -c \"import sys; print(sys.executable)\""

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
