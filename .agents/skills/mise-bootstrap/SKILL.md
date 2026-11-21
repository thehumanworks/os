---
name: mise-bootstrap
description: Plan, scope, and verify provisioning a sandbox or new machine from this repository's global mise config. Use for config discovery, bootstrap phases, --adopt versus --from, or checking a partial or repeated setup.
---

# Bootstrap from the right config

First establish **which machine, home, checkout, and resources** the user wants to change. `MISE_CONFIG_DIR` selects config; it does not isolate the filesystem or change where `~/` points. A temporary home is useful for audited home-only dotfiles, not for testing host packages, accounts, or services.

## Select the source

- **Existing checkout of this repository:** its root file is a global `config.toml`, not an application's `mise.toml`. From the checkout root, use `MISE_CONFIG_DIR="$PWD" mise config ls` and confirm the path. Keep the same prefix for later commands. If the checkout already is the active global config directory (normally `~/.config/mise`), no prefix is needed.
- **New machine that should keep this repo as its global config:** after reviewing the repository, use `mise bootstrap --adopt <repo> --only dotfiles` (substitute its URL or owner/repo). Adoption persists beyond this run. Do not replace an existing setup to test a change.
- **Separate bootstrap project with a root `mise.toml`:** `--from <repo>` runs from a managed checkout; it does not replace global config by default. Global declarations can still apply. `--from ... --config-dir <dir>` explicitly links global config to that directory of the checkout; it is not a temporary selector.

## Choose the smallest operation

| Goal | Use |
| --- | --- |
| Just a file or two | `mise dot apply --dry-run <targets>`, then `mise dot apply <targets>`. See [the dotfiles skill](../mise-dotfiles/SKILL.md). |
| All declared dotfiles, not tool installation or the bootstrap task | `mise bootstrap --only dotfiles --dry-run`, then `mise bootstrap --only dotfiles`. |
| Also install configured tools | Select both parts: `mise bootstrap --only dotfiles,tools`. For tools alone use `mise install`. |
| Apply the whole machine setup | Review `mise bootstrap --dry-run` first, then run `mise bootstrap` on the intended machine. |

Repositories precede dotfiles; dotfiles precede tool installation. A late login cannot supply credentials for an earlier clone or tool download. Select prerequisites explicitly: `--only task` does not install missing tools.

## Distinguish the bootstrap task from the final hook

At the end of a successful full run, mise handles two independently selectable parts:

| Part | Where it comes from | When to use it |
| --- | --- | --- |
| `task` | The named `bootstrap` task, here the executable `tasks/bootstrap` | Work needing the task environment and managed tools, like [personal GitHub login](../mise-bootstrap-auth/SKILL.md). A project task can shadow the global one; inspect `mise tasks info bootstrap` in the intended directory. |
| `final-hook` | `final` in `[bootstrap.hooks]` | Work that must follow the selected parts, including the task if selected. Hooks from applicable configs combine, global first. They run in mise's own environment; use `mise exec --` for managed tools. |

A final hook is not error cleanup: when the task fails, bootstrap exits before the hook. Both run again when selected. `--only final-hook` does not run the task; `--no-hooks` disables hooks **but still runs the task** on a full bootstrap. To omit this repo's login, use `--skip task`. This repo declares no final hook.

## Verify before broadening scope

1. Review config, hooks and template sources before running mise on an unfamiliar checkout. A dry run prints hook commands rather than executing them, but some inspections render templates containing `exec()`. Neither `--yes` nor CI is a trust check.
2. Use `mise dot status --missing` for dotfiles or `mise bootstrap status` for the configured machine. **`mise bootstrap plan` does not cover dotfiles, shell activation, tools, or the bootstrap task.** Use the phase dry run for those.
3. Check the actual result and run the selected operation a second time. Bootstrap is not a transaction: if a later step fails, earlier changes remain. Fix the failing declaration; do not retry by forcing dotfiles, replacing history, or pulling updates.
4. For this repo's Git setup, `bash tests/bootstrap-git.sh` exercises the real phase in disposable homes without loading user tokens. Test authentication with fixtures, not the user's Doppler or GitHub credentials.

**Official docs:** [Bootstrap run order](https://mise.jdx.dev/bootstrap.html#how-it-runs) · [Hook environment and ordering](https://mise.jdx.dev/bootstrap.html#hooks) · [Named bootstrap task](https://mise.jdx.dev/bootstrap.html#the-bootstrap-task) · [Bootstrap from a repository](https://mise.jdx.dev/bootstrap/from-repository.html) · [Config discovery](https://mise.jdx.dev/configuration.html) · [Trust](https://mise.jdx.dev/security.html) · [Documentation index](https://mise.jdx.dev/llms.txt).
