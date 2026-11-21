---
name: mise-tools-and-tasks
description: Change or diagnose mise tool versions, lockfiles, environment variables, and tasks in this checkout or a consuming project. Use when a sandbox or CI selects the wrong runtime, misses a command, or needs a reproducible install.
---

# Resolve the tool before changing config

1. From the failing command's directory, inspect `mise --version`, `mise config ls` (low to high precedence), and `mise tool <tool> --config-source`. Check the actual command with `mise which <tool>` once installed. Do not start by editing global config.
2. Decide scope. **This repo's `config.toml` supplies global defaults** when selected as `MISE_CONFIG_DIR`. An application's `mise.toml` normally takes precedence per tool; also check local/environment variants and any global override file. When this repo is checked out elsewhere, `MISE_CONFIG_DIR="$PWD" mise config ls` from its root verifies you are inspecting it rather than the host's setup.
3. For Python and Node, check the application's `.python-version`, `.nvmrc` or `.node-version`. This config enables idiomatic files for those tools. Prefer one version declaration per tool in the app. Distinguish mise's Python selection from uv's virtual environment: `mise tool python --config-source` and `mise exec -- uv python find` answer different questions.

## Lock for the machines that will install

- `"24"` and `"latest"` are requests, not pins. Edit the declaration for the intended scope. Generate the lock; do not edit release URLs or hashes by hand.
- For an **application** lock, run `mise lock --dry-run --platform linux-x64,macos-arm64` from its root, substituting the real target platforms. Remove `--dry-run` to write. For **this global config repository**, use `MISE_CONFIG_DIR="$PWD" mise lock --global --dry-run --platform linux-x64,macos-arm64`. `--global` includes system config; check the scope before allowing writes.
- A normal lock refresh keeps matching locked versions. Use `--bump` only for an intended upgrade. Inspect the config and lock diff, commit the lock (and dependency sidecars if generated), and verify with `mise install --locked` on a target platform. Locked is not offline: artifacts may still need downloading. Missing platform metadata is a reason to fix the lock, not to disable verification.
- Check `mise lock --help` for version differences. For example, the live docs describe `lock --check`; the 2026.11.8 CLI inspected for this repo has `--dry-run` but not `--check`. A preview is not proof of a successful locked install.

## Run commands without assuming an interactive shell

Use `mise exec -- <command>` for a one-off command and `mise run <task>` for a named workflow. Neither needs shell activation. A shell alias from `[shell_alias]` is not a portable task. Put a short command in `[tasks.<name>]`; use an executable file task for a longer script. Inspect declared tasks rather than assuming an arbitrary file in `scripts/` is one. Task dependencies can run in parallel; a list is not a sequence.

Use `[env]` for non-secret values a command needs; `[vars]` is for config templating. Keep credentials out of both committed values and diagnostic output. The wrappers in this repo request named secrets for particular processes; a runtime selection check should not invoke those wrappers or print the entire environment. After a change, report the winning config path, the observed version or task result, and which platforms were actually tested.

**Official docs:** [Config precedence](https://mise.jdx.dev/configuration.html) · [Version files](https://mise.jdx.dev/dev-tools/versions.html) · [Locks and platforms](https://mise.jdx.dev/dev-tools/mise-lock.html) · [CI](https://mise.jdx.dev/continuous-integration.html) · [Tasks](https://mise.jdx.dev/tasks/) · [Environment](https://mise.jdx.dev/environments/) · [Secrets](https://mise.jdx.dev/environments/secrets/).
