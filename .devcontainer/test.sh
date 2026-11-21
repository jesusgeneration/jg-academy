#!/usr/bin/env bash
# Fast launcher regression test; no Docker, downloads, or real home/auth access.
set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home"
export TMPDIR="$temporary" T3CODE_HOME="$HOME/.t3"
export PATH="$temporary/bin:$PATH"
export T3CODE_VERSION=0.1.11 OPENCODE_VERSION=2.0.18
mkdir -p "$HOME/.t3/cli" "$HOME/.opencode/bin" "$temporary/bin"
for directory in .local/share/opencode .config/opencode .config/gh .config/git; do
  mkdir -p "$HOME/$directory"
done

# Isolate the root-user check too, so tests can run in a CI root container.
cat > "$temporary/bin/id" <<'SH'
#!/usr/bin/env bash
if [[ $* == -u ]]; then echo "${TEST_UID:-1234}"; else /usr/bin/id "$@"; fi
SH
cat > "$temporary/bin/stat" <<'SH'
#!/usr/bin/env bash
if [[ $1 == -c && $2 == '%u:%g' ]]; then
  echo "1234:$(/usr/bin/id -g)"
else
  /usr/bin/stat "$@"
fi
SH
cat > "$temporary/bin/curl" <<'SH'
#!/usr/bin/env bash
echo 'Unexpected download: matching installed versions must be reused.' >&2
exit 1
SH
cat > "$HOME/.t3/cli/t3" <<'SH'
#!/usr/bin/env bash
if [[ $1 == --version ]]; then
  echo "t3 v$T3CODE_VERSION"
else
  [[ $* == 'serve --lan --host 0.0.0.0 --port 3773 /app' ]]
  [[ $PATH == *"$HOME/.local/share/mise/shims"* ]]
  echo 'foreground launch OK'
fi
SH
cat > "$HOME/.opencode/bin/opencode" <<'SH'
#!/usr/bin/env bash
echo "${VERSION_PREFIX-opencode v}2.0.18"
SH
chmod +x "$temporary/bin/"* "$HOME/.t3/cli/t3" "$HOME/.opencode/bin/opencode"

bash -n "$script_directory/container.sh"
for prefix in 'opencode v' ''; do
  output=$(VERSION_PREFIX="$prefix" bash "$script_directory/container.sh" serve)
  [[ $output == *'foreground launch OK'* ]]
done
# A second ordinary start must not redownload or require privileged repair.
bash "$script_directory/container.sh" serve >/dev/null
for directory in .t3 .opencode .local/share/opencode .config/opencode .config/gh .config/git; do
  [[ $(/usr/bin/stat -c '%a' "$HOME/$directory") == 700 ]]
done
# A failed installer must fail startup instead of silently serving with the
# wrong version; root must be rejected before touching volume permissions.
if OPENCODE_VERSION=0.0.0 bash "$script_directory/container.sh" serve >"$temporary/failure" 2>&1; then
  echo 'A version mismatch unexpectedly bypassed installation.' >&2
  exit 1
fi
grep -q 'Unexpected download' "$temporary/failure"
if TEST_UID=0 bash "$script_directory/container.sh" serve >"$temporary/root" 2>&1; then
  echo 'Root startup unexpectedly succeeded.' >&2
  exit 1
fi
grep -q 'not root' "$temporary/root"
if bash "$script_directory/container.sh" unknown >/dev/null 2>&1; then
  echo 'Unknown subcommand unexpectedly succeeded.' >&2
  exit 1
else
  [[ $? == 2 ]]
fi
echo 'Launcher regression tests passed.'
