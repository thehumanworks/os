---
name: mise-bootstrap-auth
description: Add or verify personal GitHub authentication as a mise bootstrap file task. Use for global task discovery, passing a Doppler token to gh, understanding which Git settings change, and testing without a live login.
---

# Bootstrap the personal GitHub account

Use a dotfile for shared Git settings and a task for a login that changes credential state. Keep the token out of mise's global environment, templates, command arguments, and logs.

## Put the operation in the right phase

- In this global-config repository, an **executable** `tasks/bootstrap` is discovered at `$MISE_CONFIG_DIR/tasks/bootstrap`. Its filename is the task name; it needs no TOML registration, hook, or path back to the checkout. An application's task of the same name can shadow it. Use `mise tasks info bootstrap` to check the source.
- The [mise bootstrap guide](https://mise.jdx.dev/bootstrap.html#the-bootstrap-task) gives an authentication check as an example of work for the named task. Keep this login there: it needs `gh` and `doppler` from `[tools]`, not a preceding project task. Do not also call it from `[bootstrap.hooks.final]`; a full run would log in twice. `mise bootstrap --only task` reruns login without installing tools; `--skip task` omits login, whereas `--no-hooks` does not. See [the two end phases](../mise-bootstrap/SKILL.md#distinguish-the-bootstrap-task-from-the-final-hook).
- From this checkout's root, prefix commands with `MISE_CONFIG_DIR="$PWD"` unless this is already the active global config. Preview with `mise bootstrap --only task --dry-run`; a preview is not proof of successful authentication.

If an earlier tool download or declared repository needs private GitHub access, the late task cannot authorize it. From an existing checkout with Git and Doppler access, install just the two public CLIs first (`mise install gh doppler`), run `mise bootstrap --only task`, then complete the setup with `mise bootstrap --skip task`. Initial access to clone a private config repository is a separate prerequisite.

Mise's [bootstrap secret inputs](https://mise.jdx.dev/bootstrap/secrets.html) feed file templates, not tasks. Its [fnox task grants](https://mise.jdx.dev/environments/secrets/fnox.html#launchers-that-refuse-grants) are not allowed for global tasks or tasks started by bootstrap. Neither replaces the scoped Doppler command here.

## Limit what gets changed

1. Use the one secret requested: `doppler run --only-secrets GITHUB_TOKEN -p vault -c prd -- …`. Fail before login if it is unavailable or empty. Pass the value on stdin to `gh auth login --hostname github.com --with-token`. **The login process must not inherit `GH_TOKEN` or `GITHUB_TOKEN`**: gh uses an environment token in preference to stored credentials and refuses to save the stdin token in that case.
2. Let the Doppler token identify the account. A successful `gh auth status` for github.com would not prove it is the *personal* account. Reapplying intentionally makes the Doppler account active and can pick up a rotated token. Do not log other accounts out or change the host's Git protocol.
3. Only after login succeeds, use `gh auth setup-git --hostname github.com`. Without the hostname it configures all authenticated hosts. With it, gh replaces the HTTPS credential helper entries for **github.com and gist.github.com**. This is intentional; do not replace the whole Git config, reset unrelated helpers, or add enterprise login. Skip the task on a machine where those entries or the active account must stay unchanged. If helper setup fails after login, the account can already be active: fix the Git error and retry `--only task`; there is no rollback.
4. Let gh choose its credential store. Without a working keyring it can fall back to a plaintext file in its config directory. Never deploy or collect that file as a dotfile. A later shell with its own exported `GH_TOKEN` or `GITHUB_TOKEN` can still override the stored account.

## Verify without production credentials

Run `bash tests/bootstrap-auth.sh` from the checkout root. It uses a temporary home and config directory, a fixture Doppler command, and a login stub that checks stdin and fails on token environment variables. Exercise discovery from outside the checkout, dry run, repeat apply, and failure before helper setup. The real `gh auth setup-git` can be tested against a temporary gh host configuration without contacting GitHub. Check individual Git keys and the active account where appropriate; never use `--show-token` or dump an environment.

**Sources:** [Mise bootstrap task](https://mise.jdx.dev/bootstrap.html#the-bootstrap-task) · [Global task discovery](https://mise.jdx.dev/tasks/task-discovery.html#global-tasks) · [File tasks](https://mise.jdx.dev/tasks/file-tasks.html) · [Mise secrets](https://mise.jdx.dev/environments/secrets/) · [Doppler CLI](https://docs.doppler.com/docs/accessing-secrets) · [gh login](https://cli.github.com/manual/gh_auth_login) · [gh setup-git](https://cli.github.com/manual/gh_auth_setup-git) · [Host and Gist helper writes in gh 2.104.0](https://github.com/cli/cli/blob/v2.104.0/pkg/cmd/auth/shared/gitcredentials/helper_config.go).
