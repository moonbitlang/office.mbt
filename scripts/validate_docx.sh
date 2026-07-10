#!/usr/bin/env bash
# Schema-validates a .docx with the Microsoft DocumentFormat.OpenXml SDK —
# the docx sibling of validate_xlsx.sh (kept as an adapted copy rather than a
# shared lib on purpose: the xlsx script is flake-hardened with its own
# history, and coupling the two risks both; see that file for the SIGPIPE
# here-string rationale repeated below).
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

LOCK_DIR="$ROOT/.tools/openxml-validator/.lock"

acquire_lock() {
  local attempts=0
  while true; do
    # Ignore signals only across the atomic mkdir and the flag assignment;
    # rearm before the retry sleep so lock contention stays cancellable.
    trap '' INT TERM
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      LOCK_HELD=1
      trap handle_signal INT TERM
      return
    fi
    trap handle_signal INT TERM
    sleep 0.1
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 600 ]]; then
      echo "error: timeout waiting for OpenXML validator lock" >&2
      exit 1
    fi
  done
}

# Lock lifecycle vs catchable signals. Invariants: no double-release (a
# release IGNORES further INT/TERM for the rest of cleanup — `trap ''`,
# not `trap -`, which would restore terminating dispositions and let a
# second signal kill the shell between rmdir and the flag clear), and no
# catchable-signal strand (signals are ignored only across the atomic
# mkdir + ownership-flag assignment; the contention retry sleeps stay
# cancellable). Only an uncatchable KILL can strand the lock.
LOCK_HELD=0
release_lock() {
  trap '' INT TERM
  if [[ "$LOCK_HELD" == 1 ]]; then
    rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
    LOCK_HELD=0
  fi
}

handle_signal() {
  trap - EXIT
  release_lock
  exit 1
}

mkdir -p "$ROOT/.tools/openxml-validator"

if [[ $# -ne 1 ]]; then
  echo "usage: scripts/validate_docx.sh <path-to-docx>" >&2
  exit 2
fi

DOCX="$1"
if [[ ! -f "$DOCX" ]]; then
  echo "error: file not found: $DOCX" >&2
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

# Fast pre-check for an incompletely written archive before the (slower)
# .NET validation. Unlike xlsx there is NO fixed main-part path — the main
# document is found by following the officeDocument relationship (the
# portable `docx validate` tier checks that) — so only the two genuinely
# fixed parts are required here.
required_parts=(
  "[Content_Types].xml"
  "_rels/.rels"
)
attempts=5
missing=""
for attempt in $(seq 1 "$attempts"); do
  missing=""
  if unzip -t "$DOCX" >/dev/null 2>&1; then
    entries="$(unzip -Z1 "$DOCX")"
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
      echo "--- diagnostics for $DOCX ---"
      ls -la "$DOCX" 2>&1 || true
      echo "size: $(wc -c <"$DOCX" 2>/dev/null || echo '?') bytes"
      echo "unzip -t:"
      unzip -t "$DOCX" 2>&1 | tail -5 || true
      echo "unzip -l:"
      unzip -l "$DOCX" 2>&1 | tail -25 || true
    } >&2
    exit 1
  fi
  sleep 0.2
done

DOTNET_PROJECT="$ROOT/tools/openxml-validator/OpenXmlValidator.csproj"
trap release_lock EXIT
trap handle_signal INT TERM
acquire_lock
"$DOTNET" build "$DOTNET_PROJECT" -p:UseAppHost=false >/dev/null
VALIDATOR_DLL="$ROOT/tools/openxml-validator/bin/Debug/net8.0/OpenXmlValidator.dll"
"$DOTNET" "$VALIDATOR_DLL" "$DOCX"
