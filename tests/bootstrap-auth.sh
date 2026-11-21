#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
home="$tmp/sandbox home"; cfg="$tmp/mise checkout"; bin="$tmp/bin"
mise_bin=$(type -P mise); real_gh=$(type -P gh)
mkdir -p "$home/.config/gh" "$cfg" "$bin"
cd "$tmp"
cp -R "$root/tasks" "$cfg/"
# A fixture-only final hook makes the boundary between the two phases observable.
cat > "$cfg/config.toml" <<'TOML'
[settings]
experimental = true

[bootstrap.hooks]
final = 'echo final >> "$HOME/calls"'
TOML

# Only setup-git is real. No login, keyring access or network request is needed.
cat > "$bin/doppler" <<'SH'
#!/usr/bin/env bash
set -eu
[[ ${*:1:8} == 'run --only-secrets GITHUB_TOKEN -p vault -c prd --' ]] || exit 1
shift 8
echo doppler >> "$HOME/calls"
[[ ${FAIL:-} != doppler ]] || exit 1
export GITHUB_TOKEN=fixture-personal-token
if [[ ${FAIL:-} == empty ]]; then GITHUB_TOKEN=''; fi
exec "$@"
SH
cat > "$bin/gh" <<'SH'
#!/usr/bin/env bash
set -eu
[[ ! ${GH_TOKEN+x} && ! ${GITHUB_TOKEN+x} ]] || exit 1
case "$*" in
  'auth login --hostname github.com --with-token')
    echo login >> "$HOME/calls"
    IFS= read -r token
    [[ $token == fixture-personal-token && ${FAIL:-} != login ]] || exit 1
    printf 'github.com:\n    user: fixture\n' > "$GH_CONFIG_DIR/hosts.yml"
    ;;
  'auth setup-git --hostname github.com')
    echo setup >> "$HOME/calls"
    [[ ${FAIL:-} != setup ]] || exit 1
    exec "$REAL_GH" "$@"
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$bin/doppler" "$bin/gh"

clean() {
  env -i HOME="$home" PATH="$bin:/usr/bin:/bin" MISE_CONFIG_DIR="$cfg" MISE_OFFLINE=1 \
    MISE_YES=1 MISE_SELF_UPDATE_AUTO=0 GH_CONFIG_DIR="$home/.config/gh" REAL_GH="$real_gh" \
    GH_TOKEN=ambient GITHUB_TOKEN=ambient GH_HOST=work.example.invalid GH_NO_UPDATE_NOTIFIER=1 \
    GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file "$@"
}
apply() {
  local parts=$1; shift
  clean env "$@" "$mise_bin" --quiet bootstrap --only "$parts"
}
g() { clean git config --global "$@"; }
expect() { [[ $1 == "$2" ]] || { printf 'Expected %q, got %q\n' "$2" "$1" >&2; exit 1; }; }
g user.email fixture@example.invalid
g credential.helper original
g credential.https://work.example.invalid.helper work
g credential.https://github.com.helper old

clean "$mise_bin" --quiet bootstrap --only task,final-hook --dry-run
apply dotfiles
test ! -e "$home/calls"
expect_run() {
  local expected=$1; shift
  : > "$home/calls"
  apply "$@" >> "$tmp/output" 2>&1
  expect "$(<"$home/calls")" "$expected"
}
login_calls=$'doppler\nlogin\nsetup'
expect_run final final-hook
expect_run "$login_calls" task
cp "$home/.gitconfig" first.gitconfig
expect_run "$login_calls"$'\nfinal' task,final-hook
expect_run "$login_calls" task,final-hook MISE_NO_HOOKS=1
cmp first.gitconfig "$home/.gitconfig"
if grep -Fq fixture-personal-token "$tmp/output" "$home/.gitconfig"; then exit 1; fi
expect "$(g user.email)" fixture@example.invalid
expect "$(g credential.helper)" original
expect "$(g credential.https://work.example.invalid.helper)" work
for host in github.com gist.github.com; do
  [[ $(g --get-all "credential.https://$host.helper") == $'\n!'*' auth git-credential' ]] || exit 1
done

for failure in doppler empty login setup; do
  : > "$home/calls"
  if apply task,final-hook "FAIL=$failure" > "$tmp/output" 2>&1; then echo "Expected $failure to fail" >&2; exit 1; fi
  expected=doppler
  case $failure in
    login) expected+=$'\nlogin' ;;
    setup) expected+=$'\nlogin\nsetup' ;;
  esac
  expect "$(<"$home/calls")" "$expected"
  cmp first.gitconfig "$home/.gitconfig"
done
printf 'Personal GitHub bootstrap checks passed.\n'
