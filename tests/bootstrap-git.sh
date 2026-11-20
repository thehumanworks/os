#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
home="$tmp/test home"
cfg="$home/.config/mise"
mkdir -p "$cfg/scripts" "$cfg/dotfiles/fnox" "$tmp/bin"
mise_bin=$(type -P mise)
ln -s "$mise_bin" "$tmp/bin/mise"
ln -s "$(MISE_OFFLINE=1 "$mise_bin" -C "$root" which fnox)" "$tmp/bin/fnox"

# Run the real task without loading the user's tools, dotfiles or secrets.
awk '/^\[/ { keep = ($0 == "[tasks.bootstrap]") } keep' "$root/config.toml" > "$cfg/config.toml"
cp "$root/scripts/"{bootstrap-git,git-credential-fnox} "$cfg/scripts/"
cat > "$cfg/dotfiles/fnox/config.toml" <<'TOML'
[secrets]
GIT_PERSONAL_NAME = { default = "Fixture Personal" }
GIT_PERSONAL_EMAIL = { default = "personal@example.invalid" }
GIT_WORK_NAME = { default = "Fixture Work" }
GIT_WORK_EMAIL = { default = "work@example.invalid" }
TOML

clean() {
  env -i HOME="$home" PATH="$tmp/bin:$PATH" MISE_OFFLINE=1 MISE_YES=1 MISE_SELF_UPDATE_AUTO=0 \
    FNOX_NON_INTERACTIVE=1 FNOX_NO_DAEMON=1 GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file \
    GIT_TERMINAL_PROMPT=0 "$@"
}
g() { clean git "$@"; }
expect() {
  [[ $1 == "$2" ]] || { printf 'Expected %q, got %q\n' "$2" "$1" >&2; exit 1; }
}
cd "$tmp"

# Adopt the old hand-installed rules, even duplicated; preserve unrelated values.
key=url.https://github.com/.insteadOf
g config --global --add "$key" 'my-shortcut:'
g config --global --add "$key" 'git@github.com:'
g config --global --add "$key" 'git@github.com:'
g config --global push.default matching
g config --global init.defaultBranch master
clean mise bootstrap --only task
cp "$home/.gitconfig" first.gitconfig
work_config="$home/.config/git/mise-work.gitconfig"
cp "$work_config" first-work.gitconfig
clean mise bootstrap --only task
cmp first.gitconfig "$home/.gitconfig"
cmp first-work.gitconfig "$work_config"
expect "$(g config --global --fixed-value --get-all "$key" 'my-shortcut:')" 'my-shortcut:'
expect "$(g config --global --get push.default)" simple
expect "$(g config --global --bool user.useConfigOnly)" true

# Exercise an actual first push, to a local bare remote. No network allowed.
g init -q checkout
g init -q --bare origin.git
g -C checkout remote add origin "$tmp/origin.git"
expect "$(g -C checkout symbolic-ref --short HEAD)" main
g -C checkout switch -qc topic
g -C checkout commit -q --allow-empty -m fixture
g -C checkout push -q
expect "$(g -C checkout rev-parse --abbrev-ref '@{upstream}')" origin/topic
expect "$(g --git-dir=origin.git rev-parse refs/heads/topic)" "$(g -C checkout rev-parse HEAD)"

for host in github.com leadforensics.ghe.com; do
  identity="Fixture Personal"; email=personal@example.invalid
  if [[ $host != github.com ]]; then identity="Fixture Work"; email=work@example.invalid; fi
  for prefix in "git@$host:" "ssh://git@$host/"; do
    expect "$(g config --global --fixed-value --get-all "url.https://$host/.insteadOf" "$prefix")" "$prefix"
    g -C checkout remote set-url origin "${prefix}org/repo.git"
    expect "$(g -C checkout remote get-url origin)" "https://$host/org/repo.git"
    expect "$(g -C checkout remote get-url --push origin)" "https://$host/org/repo.git"
    expect "$(g -C checkout config user.name)" "$identity"
    expect "$(g -C checkout config user.email)" "$email"
  done
done
expect "$(g -C checkout config mise.githubHost)" leadforensics.ghe.com
g -C checkout config user.email local@example.invalid
expect "$(g -C checkout config user.email)" local@example.invalid
g -C checkout remote set-url origin git@other.invalid:org/repo.git
expect "$(g -C checkout remote get-url origin)" git@other.invalid:org/repo.git
printf 'Git bootstrap checks passed.\n'
