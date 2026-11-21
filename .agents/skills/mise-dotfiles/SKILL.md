---
name: mise-dotfiles
description: Add, change, or troubleshoot files deployed by this repository's mise [dotfiles] entries. Use when a sandbox needs Git defaults, shell snippets, agent settings, or hooks without replacing machine-local configuration.
---

# Deploy a dotfile with mise

Edit `config.toml` and its sources under `dotfiles/` from the repository root. Use a declarative entry before considering a setup script. An entry key names the target on the machine. A relative `source` starts at the directory of the **declaring config file**, not the shell's working directory.

## Decide who owns the file

| Desired behavior | Entry to use |
| --- | --- |
| The repository owns the file; edits should go back to the source | `mode = "symlink"`. Use `symlink-each` to share a directory with unmanaged files. The checkout must stay in place. |
| The repository owns the contents, but the app needs a regular file | `mode = "copy"`. A later apply can overwrite edits to the copy. |
| Seed a regular file once, then let the machine own it | File `copy` with `create_if_missing = true`. An existing file gets **no** defaults or later updates. |
| Add an exact line or a marked block to a file someone else owns | Use `"~/file/edit-id"` with `line` or `block`. Only a missing **line** can be prepended with `position = "prepend"`. |
| The app rewrites structured data | Use `merge = true` for keys the repository owns, or `merge = "missing"` to fill absent keys. Check the format's matching rules; Git config is not generic INI. |
| Save history of the live file rather than deploy a source | `track` is a separate workflow. Do not start tracking, syncing, or capturing a user's whole home config to deploy defaults. |

For Git, keep the shared defaults in `dotfiles/git/config` and the writable global file in the sandbox. Read [the Git case study](references/git-config.md) before changing this split; it compares a whole-file copy, a seed, and an INI merge against an existing identity.

## Apply and verify the smallest change

For Git only, from this checkout's root **inside the intended sandbox**:

```sh
MISE_CONFIG_DIR="$PWD" mise dot apply --dry-run ~/.config/git/mise-defaults ~/.gitconfig
MISE_CONFIG_DIR="$PWD" mise dot apply ~/.config/git/mise-defaults ~/.gitconfig
MISE_CONFIG_DIR="$PWD" mise dot status --missing ~/.config/git/mise-defaults ~/.gitconfig
git config --show-origin --get push.default
```

Name the actual target file, not the edit ID, on the command line. Use `mise dot apply` without targets only when all dotfiles are wanted. Neither form requires a bootstrap task. Check hooks and templates before running a preview; a template rendered by `status` or `diff` can run commands.

Use `bash tests/bootstrap-git.sh` for the offline regression check. For a new entry, also test an empty home, a home with an existing value, and a second apply. Verify with the consuming app, not just a file-exists check. Stop on a conflicting symlink or damaged block; inspect the real source rather than forcing replacement. Do not put identities, tokens, or credential stores in a shared source or diff output.

**Official docs:** [Deployment vs tracking](https://mise.jdx.dev/dotfiles.html) · [Modes and seed-only files](https://mise.jdx.dev/dotfiles/managed.html) · [Partial edits and removal](https://mise.jdx.dev/dotfiles/edits.html) · [Keys and status states](https://mise.jdx.dev/dotfiles/reference.html).
