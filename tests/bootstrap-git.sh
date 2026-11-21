#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cd "$tmp"
home="$tmp/fresh home"
cfg="$tmp/mise checkout"
mkdir -p "$home" "$cfg"
cp -R "$root/config.toml" "$root/dotfiles" "$cfg/"

# Run the real dotfiles phase outside the checkout without user settings or tokens.
clean() {
  env -i HOME="$home" PATH="$PATH" MISE_CONFIG_DIR="$cfg" MISE_OFFLINE=1 MISE_YES=1 \
    MISE_SELF_UPDATE_AUTO=0 GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0 "$@"
}
g() { clean git "$@"; }
bootstrap() { clean mise --quiet bootstrap --only dotfiles; }
expect() {
  [[ $1 == "$2" ]] || { printf 'Expected %q, got %q\n' "$2" "$1" >&2; exit 1; }
}

bootstrap
[[ -f "$home/.gitconfig" && ! -L "$home/.gitconfig" ]]
expect "$(g config --get-all push.default)" simple
expect "$(g config --bool pull.rebase)" false
expect "$(g config --bool fetch.prune)" true
expect "$(g config diff.algorithm)" histogram
expect "$(g config merge.conflictStyle)" zdiff3
expect "$(g config --bool user.useConfigOnly)" true
if g config --get user.name >/dev/null || g config --get user.email >/dev/null; then
  printf 'The shared defaults must not supply a commit identity.\n' >&2; exit 1
fi

# Exercise the initial branch and first push without contacting a Git host.
g init -q checkout
g init -q --bare origin.git
g -C checkout remote add origin "$tmp/origin.git"
expect "$(g -C checkout symbolic-ref --short HEAD)" main
g -C checkout switch -qc topic
g -C checkout config user.name 'Fixture User'
g -C checkout config user.email fixture@example.invalid
g -C checkout commit -q --allow-empty -m fixture
g -C checkout push -q
expect "$(g -C checkout rev-parse --abbrev-ref '@{upstream}')" origin/topic

# A preconfigured sandbox keeps its own settings, including writes after bootstrap.
home="$tmp/preconfigured home"
mkdir -p "$home"
g config --global user.email local@example.invalid
g config --global credential.helper fixture
g config --global pull.rebase true
bootstrap
g config --global push.default current
cp "$home/.gitconfig" first.gitconfig
bootstrap
cmp first.gitconfig "$home/.gitconfig"
expect "$(g config user.email)" local@example.invalid
expect "$(g config credential.helper)" fixture
expect "$(g config --bool pull.rebase)" true
expect "$(g config push.default)" current
expect "$(g config --get-all fetch.prune)" true
printf 'Git dotfile bootstrap checks passed.\n'
