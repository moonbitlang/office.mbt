#!/usr/bin/env bash
# Recompute every vendored fixture's SHA-256 against fixtures/MANIFEST.md.
# With --download, also fetch each source URL and check the served hash --
# network-dependent, so not part of CI.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
fail=0
while IFS='|' read -r _ file url size served vendored _; do
  file=$(echo "$file" | tr -d ' `'); url=$(echo "$url" | tr -d ' `')
  served=$(echo "$served" | tr -d ' `'); vendored=$(echo "$vendored" | tr -d ' `')
  case "$file" in docxcorp-*.docx) ;; *) continue ;; esac
  got=$(shasum -a 256 "$here/fixtures/$file" | cut -d' ' -f1)
  if [ "$got" != "$vendored" ]; then
    echo "MISMATCH $file: vendored $got, manifest $vendored" >&2; fail=1
  fi
  if [ "${1:-}" = "--download" ]; then
    got=$(curl -fsS --max-time 120 "$url" | shasum -a 256 | cut -d' ' -f1)
    if [ "$got" != "$served" ]; then
      echo "MISMATCH $file: served $got, manifest $served (CDN content moved?)" >&2; fail=1
    fi
  fi
done < "$here/fixtures/MANIFEST.md"
[ "$fail" -eq 0 ] && echo "verify: all manifest hashes match"
exit "$fail"
