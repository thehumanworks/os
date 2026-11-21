# README

## Runtime defaults

With mise active (or under `mise exec`), projects can select Python via `.python-version` and Node via `.nvmrc` or `.node-version`. Commit an exact version there **or** in the project's `mise.toml`; the global versions are fallbacks. Run `mise install` after checkout. uv still manages the project's `.venv`, but it looks for a compatible local Python and fails rather than downloading one. To check a selection, run `mise tool python --config-source` and `mise exec -- uv python find` in the project.

When resolving floating tool versions such as `latest` or `node = "24"`, mise skips releases less than 24 hours old if the backend knows their release dates. This [release delay](https://mise.jdx.dev/security.html#minimum-release-age) is not a version pin and doesn't change existing locked versions.

**Certificates:** Install approved private CAs in each workstation or CI image's OS trust store. Node and Bun add system roots via `NODE_USE_SYSTEM_CA=1`; uv uses the system store via `UV_SYSTEM_CERTS=true`. Don't set a shared `SSL_CERT_FILE`: it [replaces uv's default roots](https://docs.astral.sh/uv/concepts/authentication/certificates/#custom-certificates). If a client needs a separate bundle, configure just that client on the affected host rather than disabling verification.

**In application repos:**
- Commit `mise.lock` for the target platforms and run `mise install --locked` in CI. For dependencies, pair the project's lockfile with its CI command: `uv.lock` → `uv sync --locked`, `bun.lock` → `bun ci`, or `package-lock.json` → `npm ci`.
- Keep `typescript` in the project's dev dependencies. Set `"strict": true` in its `tsconfig.json` and run the local compiler in a typecheck script (e.g. `tsc --noEmit`) in CI.
- Leave cache settings at their defaults unless there's a measured bottleneck. For fast uv installs, keep its cache on the same filesystem as `.venv`; enable bytecode compilation in an image build if faster startup is worth the extra build time.

## Git defaults

Git settings are dotfiles; no bootstrap script or login is required. To apply
**only Git's defaults**, run this from the checkout root inside the sandbox:

```sh
MISE_CONFIG_DIR="$PWD" mise dot apply ~/.config/git/mise-defaults ~/.gitconfig
```

If this checkout is already the active global mise config, omit `MISE_CONFIG_DIR`.
`mise bootstrap --only dotfiles` applies the same entries along with the other
dotfiles. Mise copies `dotfiles/git/config` to `~/.config/git/mise-defaults` and
prepends an include to a writable `~/.gitconfig`, creating it if needed. A direct
copy over `~/.gitconfig` would erase existing identity and credential settings.

New repositories start on `main`. The first plain push sets the upstream
(Git 2.37+); pulls merge rather than rebase, and fetches prune stale remote-tracking
branches. Diffs use the histogram algorithm, and merge conflicts show the common
ancestor with `zdiff3`.

Git won't guess a commit identity. Set `user.name` and `user.email` with
`git config --global` in the sandbox, or `git config --local` for one repository.
To check which settings won, run `git config --show-origin --get pull.rebase`.

If you used the previous setup, remove only the old `mise:mise-defaults` block
from `~/.config/git/config` to avoid loading the defaults twice. Run
`bash tests/bootstrap-git.sh` to check the setup offline in a temporary home.

## Personal GitHub login

On a full `mise bootstrap`, [`tasks/bootstrap`](tasks/bootstrap) runs after tool installation.
It is the last step **this repo configures**, not mise’s optional [`final` hook](https://mise.jdx.dev/bootstrap.html#how-it-runs), which would run after it.
With Git, `gh`, `doppler`, and access to `GITHUB_TOKEN` in `vault/prd`, run just the login from this checkout:

```sh
MISE_CONFIG_DIR="$PWD" mise bootstrap --only task
```

`--only task` does not install missing tools. If a private clone or tool download needs
GitHub access earlier in bootstrap, run `MISE_CONFIG_DIR="$PWD" mise install gh doppler`
from the checkout first, run the login above, then finish with
`MISE_CONFIG_DIR="$PWD" mise bootstrap --skip task`.

Each run makes the Doppler token's account active on **github.com**, even if another
account was active. `gh auth setup-git --hostname github.com` replaces the HTTPS
credential helpers for `github.com` and `gist.github.com`; it does not change your
commit identity, SSH remotes, or helpers for other hosts. To keep an existing login,
use `--skip task`, **not** `--no-hooks`. For settings alone, use `--only dotfiles`.

To check the stored login without using a shell token, run
`env -u GH_TOKEN -u GITHUB_TOKEN gh auth status --active --hostname github.com`.
`gh` uses the system credential store when available, but may store the token in
plaintext in its own config if no keyring works. Do not share that directory.
`bash tests/bootstrap-auth.sh` tests the flow offline without fetching a real token.

## Project-local mise skills

- [Deploy dotfiles](.agents/skills/mise-dotfiles/SKILL.md): choose between copying, seeding, or editing a file without losing local settings.
- [Bootstrap a sandbox](.agents/skills/mise-bootstrap/SKILL.md): select the right config and preview only the resources you want to apply.
- [Bootstrap personal GitHub authentication](.agents/skills/mise-bootstrap-auth/SKILL.md): pass a scoped secret to a global file task and verify what it changes.
- [Manage tools and tasks](.agents/skills/mise-tools-and-tasks/SKILL.md): diagnose version selection and verify locks and commands in CI.

## Secrets
The GitHub bootstrap task and the command wrappers in `config.toml` use Doppler's
`--only-secrets` to request named values for a single command. Neither GitHub
login nor dotfile deployment requires a fnox age key.
