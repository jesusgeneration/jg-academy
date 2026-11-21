#!/usr/bin/env bash
set -euo pipefail
umask 077

export PATH="$HOME/.t3/cli:$HOME/.opencode/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

installed_version() {
  local version
  version=$("$1" --version)
  version=${version##* }
  printf '%s\n' "${version#v}"
}

install_tools() {
  # Docker creates new named volume roots as root. Repair only these dedicated
  # container volumes, also after the Dev Container CLI adjusts vscode's UID.
  # Never chown /app, the whole home, or anything mounted from the host's home.
  local directory
  for directory in "$HOME/.t3" "$HOME/.opencode" \
    "$HOME/.local/share/opencode" "$HOME/.config/opencode" \
    "$HOME/.config/gh" "$HOME/.config/git"; do
    if [[ ! -d "$directory" ]]; then
      sudo -n mkdir -p "$directory"
    fi
    if [[ $(stat -c '%u:%g' "$directory") != "$(id -u):$(id -g)" ]]; then
      sudo -n chown -R "$(id -u):$(id -g)" "$directory"
    fi
    chmod 700 "$directory"
  done

  local temporary
  temporary=$(mktemp -d)
  trap 'rm -f "$temporary/t3-install" "$temporary/opencode-install"; rmdir "$temporary"' RETURN
  if [[ ! -x "$HOME/.t3/cli/t3" ]] || \
    [[ $(installed_version t3) != "${T3CODE_VERSION:?}" ]]; then
    curl --fail --silent --show-error --location --retry 3 \
      https://t3.codes/install.sh -o "$temporary/t3-install"
    T3CODE_INSTALL_BIN_DIR="$HOME/.t3/cli" sh "$temporary/t3-install"
  fi
  if [[ ! -x "$HOME/.opencode/bin/opencode" ]] || \
    [[ $(installed_version opencode) != "${OPENCODE_VERSION:?}" ]]; then
    curl --fail --silent --show-error --location --retry 3 \
      https://opencode.ai/v2/install -o "$temporary/opencode-install"
    bash "$temporary/opencode-install" --version "$OPENCODE_VERSION" --no-modify-path
  fi
  t3 --version
  opencode --version
}

case "${1:-}" in
  serve)
    if [[ $(id -u) == 0 ]]; then
      echo "Run this container as vscode, not root." >&2
      exit 1
    fi
    install_tools
    # exec preserves signals and exit status; Docker's init reaps child processes.
    # No service manager, daemon, background shell, or automatic cloud exposure.
    exec t3 serve --lan --host 0.0.0.0 --port 3773 /app
    ;;
  prepare)
    cd /app
    if [[ ! -w . || ! -w .git ]]; then
      echo "The vscode user cannot write /app and .git. Check host checkout ownership; do not recursively chown it from the container." >&2
      exit 1
    fi
    bundle check || bundle install
    bin/rails db:prepare
    bin/rails db:test:prepare
    ;;
  ready)
    # postStart waits for install + startup on first use; HTTP status itself is
    # irrelevant here (the paired API is authenticated). Never mint/log a token.
    deadline=$((SECONDS + 600))
    while ((SECONDS < deadline)); do
      if curl --silent --output /dev/null --connect-timeout 1 --max-time 2 http://127.0.0.1:3773/; then
        echo "T3 is listening on container port 3773. See docs/ONBOARDING.md to pair."
        exit 0
      fi
      sleep 2
    done
    echo "T3 did not start within 10 minutes. Inspect docker compose -f .devcontainer/compose.yml logs jg-lead (may contain pairing secrets)." >&2
    exit 1
    ;;
  *)
    echo "Usage: bash .devcontainer/container.sh {serve|prepare|ready}" >&2
    exit 2
    ;;
esac
