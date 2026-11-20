# README

## Git bootstrap

On a new machine, run `mise bootstrap`. Its package phase ensures Git is installed through the host package manager; its final task runs `scripts/bootstrap-git`. Git **2.37+** is required for automatic upstream setup. If an older Git is already installed, upgrade it first.

The task needs the two names and two emails in fnox. If they aren't already set, run this once from this repository. Each command prompts for the value and stores it encrypted with age:

```sh
for key in GIT_PERSONAL_NAME GIT_PERSONAL_EMAIL GIT_WORK_NAME GIT_WORK_EMAIL; do
  fnox --config "$PWD/dotfiles/fnox/config.toml" set --provider age "$key" || break
done
```

With Git and fnox installed, `mise bootstrap --only task` reapplies just the Git setup. `mise bootstrap --only task --dry-run` previews the task without fetching secrets or changing Git config. The task requests only the four identity values; names and emails are written to Git config and commits, not exported to the shell.

| Setting | Result |
| --- | --- |
| `init.defaultBranch = main` | New repositories start on `main`. Existing branches are not renamed. |
| `push.default = simple` and `push.autoSetupRemote = true` | With a default remote such as `origin`, the first plain `git push` of a new branch pushes it and sets its upstream. Committing does **not** trigger a push. |
| `user.name`, `user.email`, `user.useConfigOnly = true` | Personal identity by default; Git doesn't guess a missing identity. A matching work remote selects the work name, email, and `mise.githubHost`. Repo-local settings still win. |
| HTTPS rewrites | For `github.com` and `leadforensics.ghe.com`, both `git@HOST:ORG/REPO` and `ssh://git@HOST/ORG/REPO` use HTTPS for fetch **and** push. The work identity still matches the stored URL. |
| HTTPS credentials | Each of those hosts has its own credential helper. It reads `GH_TOKEN` from the fnox profile for the **requested host**, not the checkout's identity. No token is stored in Git config. |

No manual URL rewrites are needed: bootstrap adopts existing identical rules, removes duplicate copies, and leaves other URL mappings alone. To check a checkout without connecting, use `git remote get-url origin` and `git remote get-url --push origin`.

Run `bash tests/bootstrap-git.sh` to exercise the task against a temporary home and a local bare remote.

## GitHub CLI

Plain `gh` selects its token by explicit `GH_HOST`, then the checkout's `mise.githubHost`, then `github.com`. The two hostname profiles in `dotfiles/fnox/config.toml` expose `GH_TOKEN` from the existing encrypted `GITHUB_TOKEN` (personal) or `GITHUB_ENTERPRISE_TOKEN` (work). You don't need `gh auth login` or a shell-wide token.

```sh
gh pr list                                 # use the checkout's account
GH_HOST=leadforensics.ghe.com gh auth status # force work for this command
GH_HOST=github.com gh auth status            # force personal for this command
```

`GH_HOST` is a default, not a host restriction. In mixed-remote checkouts or when targeting another host with `-R`, `GH_REPO`, or `--hostname`, select the matching token explicitly (e.g. `GH_HOST=leadforensics.ghe.com gh pr list -R leadforensics.ghe.com/ORG/REPO`).

## Secrets
The project uses `fnox` for secret management, with `age` as the provider. The hosts must have either:
- ~/.config/fnox/age.txt
- `FNOX_AGE_KEY` defined as an `env` var with the identity. This identity starting with `AGE-SECRET-*` is only usable for decryption.

Prefer `FNOX_AGE_KEY` in remote sandboxes.
