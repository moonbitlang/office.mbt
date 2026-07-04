#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOTNET_DIR="$ROOT/.tools/dotnet"
DOTNET="$DOTNET_DIR/dotnet"

if command -v dotnet >/dev/null 2>&1; then
  # here-string (no pipe): `... | grep -q` can false-negative under pipefail
  # when grep exits early and the producer takes SIGPIPE.
  if grep -Eq '(^|[[:space:]])8\.' <<<"$(dotnet --list-sdks 2>/dev/null)"; then
    exit 0
  fi
fi

if [[ -x "$DOTNET" ]]; then
  exit 0
fi

mkdir -p "$DOTNET_DIR"

INSTALLER="$DOTNET_DIR/dotnet-install.sh"
if [[ ! -f "$INSTALLER" ]]; then
  curl -fsSL "https://dot.net/v1/dotnet-install.sh" -o "$INSTALLER"
fi
chmod +x "$INSTALLER"

# Pin to .NET 8 to keep the validator project stable.
"$INSTALLER" \
  --install-dir "$DOTNET_DIR" \
  --channel "8.0" \
  --quality "ga"
