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

On a new machine, check out this repository at `~/.config/mise` and run
`mise bootstrap --only dotfiles`. Mise adds an include to `~/.config/git/config`
and leaves `~/.gitconfig` alone. The shared file sets the initial branch to `main`,
push mode to `simple`, automatic upstream setup (Git 2.37+), and
`user.useConfigOnly = true` so Git won't guess a commit identity.

Names, emails, work identity includes and credential helpers remain local.
Set up your identity and authentication separately on new machines. Entries
in `~/.gitconfig` and repository config can override the defaults.
Check the active value and its source with `git config --show-origin --get push.default`.

## Secrets
The project uses `fnox` for secret management, with `age` as the provider. The hosts must have either:
- ~/.config/fnox/age.txt
- `FNOX_AGE_KEY` defined as an `env` var with the identity. This identity starting with `AGE-SECRET-*` is only usable for decryption.

Prefer `FNOX_AGE_KEY` in remote sandboxes.
