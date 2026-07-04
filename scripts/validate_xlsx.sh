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
  if grep -Eq '^Microsoft\.NETCore\.App 8\.' <<<"$(dotnet --list-runtimes 2>/dev/null)"; then
    DOTNET="dotnet"
  fi
fi

export DOTNET_NOLOGO=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_CLI_HOME="$ROOT/.tools/dotnet/.cli-home"
export NUGET_PACKAGES="$ROOT/.tools/dotnet/.nuget/packages"

# The required-parts pre-check gives a clear early error for an incompletely
# written archive before the (slower) .NET SDK validation.
#
# ROOT CAUSE of the historical "missing required part: _rels/.rels" flake
# (found in code review): this used `printf ... | grep -Fxq`, and under
# `set -o pipefail` `grep -q` exits on its first match, so `printf` can take
# SIGPIPE and the pipeline reports non-zero -- making a PRESENT part look
# missing. That is intermittent, load/scheduling-dependent, and more likely on
# larger archives, which matches the flake exactly (the earlier retry masked
# it). Generation was independently confirmed deterministic (in-memory
# validate_ooxml_package never drops a part, 150x) and temp paths never
# collide, so this pipeline bug was the sole cause. Fix: a here-string check
# (no pipe, no SIGPIPE). A short retry still covers a not-yet-readable archive,
# and diagnostics are dumped on final failure.
required_parts=(
  "[Content_Types].xml"
  "_rels/.rels"
  "xl/workbook.xml"
  "xl/_rels/workbook.xml.rels"
)
attempts=5
missing=""
for attempt in $(seq 1 "$attempts"); do
  missing=""
  if unzip -t "$XLSX" >/dev/null 2>&1; then
    entries="$(unzip -Z1 "$XLSX")"
    for part in "${required_parts[@]}"; do
      # here-string (no pipe) -- a `printf | grep -q` here false-negatives
      # under pipefail when grep exits early and printf takes SIGPIPE.
      if ! grep -Fxq "$part" <<<"$entries"; then
        missing="$part"
        break
      fi
    done
    if [ -z "$missing" ]; then
      break
    fi
  else
    missing="<archive not yet readable>"
  fi
  if [ "$attempt" -eq "$attempts" ]; then
    {
      echo "error: missing required part: $missing (after $attempt attempts)"
      echo "--- diagnostics for $XLSX ---"
      ls -la "$XLSX" 2>&1 || true
      echo "size: $(wc -c <"$XLSX" 2>/dev/null || echo '?') bytes"
      echo "unzip -t:"
      unzip -t "$XLSX" 2>&1 | tail -5 || true
      echo "unzip -l:"
      unzip -l "$XLSX" 2>&1 | tail -25 || true
    } >&2
    exit 1
  fi
  sleep 0.2
done

DOTNET_PROJECT="$ROOT/tools/openxml-validator/OpenXmlValidator.csproj"
acquire_lock
trap release_lock EXIT INT TERM
"$DOTNET" build "$DOTNET_PROJECT" -p:UseAppHost=false >/dev/null
VALIDATOR_DLL="$ROOT/tools/openxml-validator/bin/Debug/net8.0/OpenXmlValidator.dll"
"$DOTNET" "$VALIDATOR_DLL" "$XLSX"
