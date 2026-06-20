#!/usr/bin/env bash
#
# Architecture guard for the pdflite refactor.
# See ARCHITECTURE_PROPOSAL.md and EXECUTION_PLAN.md (commit A4).
#
# Enforces two ratchets so the root monolith cannot regrow during the refactor:
#   1. No feature package imports the root package "bobzhang/pdflite".
#      Entry-point / test / glue packages may (they are the top of the graph).
#   2. No NEW source file appears in the root package outside the allowlist.
#      Removing root files (the goal of extraction) is always fine.
#
# Exit non-zero on any violation. Pure bash + coreutils; no moon required.

set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
allowlist="scripts/root_files.allow"

# --- Rule 1: feature packages must not import the root package ----------------
# These packages sit at/above the root and legitimately import it.
is_allowed_importer() {
  case "$1" in
    cmd/main | markdown | markdown/cmd | async_io | fixture_acceptance) return 0 ;;
    */fixture_acceptance) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r pkgfile; do
  pkg="${pkgfile%/moon.pkg}"
  pkg="${pkg#./}"
  [ "$pkg" = "moon.pkg" ] && continue # root package (path was ".")
  # Match the exact root import "bobzhang/pdflite" (not a subpackage path).
  if grep -qE '"bobzhang/pdflite"[[:space:]]*,?' "$pkgfile"; then
    if ! is_allowed_importer "$pkg"; then
      echo "ARCH VIOLATION: package '$pkg' imports the root package 'bobzhang/pdflite'."
      echo "  Feature packages must depend downward (document/syntax/core), not on root."
      fail=1
    fi
  fi
done < <(find . -name moon.pkg \
  -not -path './target/*' -not -path './.mooncakes/*' \
  -not -path './_build/*' -not -path './scripts/*' -not -path './.repos/*')

# --- Rule 2: no new root *.mbt file outside the allowlist ---------------------
if [ ! -f "$allowlist" ]; then
  echo "ARCH GUARD ERROR: missing $allowlist"
  exit 2
fi
current="$(find . -maxdepth 1 -name '*.mbt' | sed 's|^\./||' | sort)"
new_files="$(comm -23 <(printf '%s\n' "$current") <(sort "$allowlist") || true)"
if [ -n "$new_files" ]; then
  echo "ARCH VIOLATION: new root .mbt file(s) not in $allowlist:"
  printf '%s\n' "$new_files" | sed 's/^/  /'
  echo "  Put new feature code in its own package, or add the file to $allowlist"
  echo "  deliberately if it is genuinely root-level facade/glue."
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "arch guard: OK ($(printf '%s\n' "$current" | grep -c . ) root .mbt files allowlisted)"
fi
exit "$fail"
