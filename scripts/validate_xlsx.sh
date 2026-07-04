#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

LOCK_DIR="$ROOT/.tools/openxml-validator/.lock"

acquire_lock() {
  local attempts=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 0.1
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 600 ]]; then
      echo "error: timeout waiting for OpenXML validator lock" >&2
      exit 1
    fi
  done
}

release_lock() {
  rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
}

mkdir -p "$ROOT/.tools/openxml-validator"

if [[ $# -ne 1 ]]; then
  echo "usage: scripts/validate_xlsx.sh <path-to-xlsx>" >&2
  exit 2
fi

XLSX="$1"
if [[ ! -f "$XLSX" ]]; then
  echo "error: file not found: $XLSX" >&2
  exit 2
fi

"$ROOT/scripts/ensure_dotnet.sh"

DOTNET_LOCAL="$ROOT/.tools/dotnet/dotnet"
DOTNET="$DOTNET_LOCAL"
if command -v dotnet >/dev/null 2>&1; then
  # Only use the system `dotnet` if it has the net8 runtime installed.
  if dotnet --list-runtimes 2>/dev/null | grep -Eq '^Microsoft\.NETCore\.App 8\.'; then
    DOTNET="dotnet"
  fi
fi

export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_CLI_HOME="$ROOT/.tools/dotnet/.cli-home"
export NUGET_PACKAGES="$ROOT/.tools/dotnet/.nuget/packages"

unzip -t "$XLSX" >/dev/null

entries="$(unzip -Z1 "$XLSX")"
require_entry() {
  local want="$1"
  if ! printf '%s\n' "$entries" | grep -Fxq "$want"; then
    echo "error: missing required part: $want" >&2
    exit 1
  fi
}

require_entry "[Content_Types].xml"
require_entry "_rels/.rels"
require_entry "xl/workbook.xml"
require_entry "xl/_rels/workbook.xml.rels"

DOTNET_PROJECT="$ROOT/tools/openxml-validator/OpenXmlValidator.csproj"
acquire_lock
trap release_lock EXIT INT TERM
"$DOTNET" build "$DOTNET_PROJECT" -p:UseAppHost=false >/dev/null
VALIDATOR_DLL="$ROOT/tools/openxml-validator/bin/Debug/net8.0/OpenXmlValidator.dll"
"$DOTNET" "$VALIDATOR_DLL" "$XLSX"
