#!/bin/sh
set -eu

if [ "$#" -ne 8 ]; then
  echo "permission canary: expected 8 arguments" >&2
  exit 2
fi

install_root="$1"
probe_root="$2"
scratch_root="$3"
evidence_root="$4"
isolated_state="$5"
original_auth="$6"
source_root="$7"
ambient_write_path="$8"

test -r "$install_root/CANDIDATE.json"
test -x "$install_root/bin/office-native"

probe_marker="$probe_root/.permission-canary"
scratch_marker="$scratch_root/.permission-canary"
mkdir "$probe_marker"
mkdir "$scratch_marker"
rmdir "$probe_marker" "$scratch_marker"

if mkdir "$install_root/.permission-canary" >/dev/null 2>&1; then
  echo "permission canary: install prefix is writable" >&2
  exit 11
fi
if ls "$evidence_root" >/dev/null 2>&1; then
  echo "permission canary: evidence directory is readable" >&2
  exit 12
fi
if cat "$isolated_state/auth.json" >/dev/null 2>&1; then
  echo "permission canary: isolated credential is readable" >&2
  exit 13
fi
if cat "$original_auth" >/dev/null 2>&1; then
  echo "permission canary: original credential is readable" >&2
  exit 14
fi
if ls "$source_root" >/dev/null 2>&1; then
  echo "permission canary: candidate checkout is readable" >&2
  exit 15
fi
if mkdir "$ambient_write_path" >/dev/null 2>&1; then
  echo "permission canary: ambient temporary storage is writable" >&2
  exit 16
fi
if [ -n "${CODEX_HOME:-}" ]; then
  echo "permission canary: CODEX_HOME leaked into child commands" >&2
  exit 17
fi

echo "FRESH-AGENT PERMISSION CANARY PASS"
