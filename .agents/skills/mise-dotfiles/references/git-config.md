# Why Git uses an include

**There is one source of shared settings and no Git installation script.** Mise copies `dotfiles/git/config` to `~/.config/git/mise-defaults`. Its second entry prepends this valid Git config line to the sandbox's regular `~/.gitconfig` if it is missing:

```gitconfig
[include] path = ~/.config/git/mise-defaults
```

Git reads settings in order. A later value in `~/.gitconfig` can override a shared scalar default. `git config --global` writes to the user's file, not the defaults in the checkout. The copy also works after the source checkout is gone. Use `git config --show-origin --get pull.rebase` to check one effective value without printing credentials.

## Why not copy straight to ~/.gitconfig?

These results were checked with mise 2026.11.8 and Git 2.55.0 in temporary homes. The fixture used an invented identity, no credentials, and no network login.

| Deployment | Fresh sandbox | Existing file or second apply |
| --- | --- | --- |
| Plain `copy` to `~/.gitconfig` | Installed all defaults. | Reapplying removed the fixture identity and reset the user's pull preference. No force flag was needed. |
| `copy` with `create_if_missing = true` | Installed all defaults. | Preserved the existing file in full, but added no missing defaults. A later change to the source did not reach the seeded file. |
| `merge = "missing", format = "ini"` | Installed all defaults. | The INI editor compared keys as written. With existing `init.defaultbranch = guest` and source `defaultBranch = main`, Git saw two values for the same key and selected `main`. |
| Copied defaults plus a prepended include (this repo) | Created a writable global file and made the defaults effective. | Kept the fixture's identity, credential helper and pull preference. Updating the source and reapplying changed a key the user had not overridden. |

If the requirement is **only** to seed a missing file and never update it, one entry is enough: `"~/.gitconfig" = { source = "dotfiles/git/config", mode = "copy", create_if_missing = true }` under `[dotfiles]`. Do not use this alternative alongside the include and expect them to stay in sync.

## What the shell scripts do

- `tasks/bootstrap` is the [personal GitHub authentication task](../../mise-bootstrap-auth/SKILL.md). A full bootstrap runs it; `mise dot apply` and `mise bootstrap --only dotfiles` do not. It sets up the GitHub.com HTTPS credential helper, not the shared Git defaults.
- `bash tests/bootstrap-git.sh` **tests** the declarations with temporary homes and a local bare remote. It is not an install step.

On an older installation, a marked `mise:mise-defaults` block may still exist in `~/.config/git/config`. Removing a declaration does not remove a deployed edit. Inspect the old block before removing just that include; do not delete the file.
