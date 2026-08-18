#!/usr/bin/env bash
# Corpus smoke: run the docx CLI over every vendored corpus fixture and hold
# the outcomes to expectations.tsv. Run from the repo root:
#
#   bash docx2html/tests/corpus/run.sh
#
# DOCX_CLI overrides the CLI path; by default the native debug CLI is built and
# used. Exit codes are compared normalised (0 stays 0, anything else is 1):
# the pin is "accepted" versus "refused with this class", not a specific code.
#
# For every fixture the CLI accepts for annotation, the round trip is also
# held to what surgery requires: the annotated package still validates, and
# every story except the new comment reads back byte-identical.
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
here="$root/docx2html/tests/corpus"

if [ -z "${DOCX_CLI:-}" ]; then
  ( cd "$root" && moon build --target native docx2html/cmd/docx >/dev/null 2>&1 )
  DOCX_CLI="$root/_build/native/debug/build/bobzhang/docx2html/cmd/docx/docx.exe"
fi

fail=0
report() { echo "CORPUS FAIL: $*" >&2; fail=1; }

norm() { [ "$1" -eq 0 ] && echo 0 || echo 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/docx-corpus.XXXXXX")"
trap 'rm -rf "$work"' EXIT

count=0
while IFS=$'\t' read -r file want_v want_t want_c want_a class; do
  [ "$file" = "file" ] && continue
  fx="$here/fixtures/$file"
  [ -f "$fx" ] || { report "$file: fixture missing"; continue; }
  count=$((count + 1))

  set +e
  "$DOCX_CLI" validate "$fx" >/dev/null 2>&1; v=$(norm $?)
  "$DOCX_CLI" text "$fx" >/dev/null 2>&1; t=$(norm $?)
  "$DOCX_CLI" convert "$fx" >/dev/null 2>&1; c=$(norm $?)
  out="$work/annotated.docx"; rm -f "$out"
  "$DOCX_CLI" annotate add --at '/body/p[1]' --text probe --author corpus \
    "$fx" "$out" >/dev/null 2>&1; a=$(norm $?)
  set -e

  [ "$v" = "$want_v" ] || report "$file: validate $v, expected $want_v"
  [ "$t" = "$want_t" ] || report "$file: text $t, expected $want_t"
  [ "$c" = "$want_c" ] || report "$file: convert $c, expected $want_c"
  [ "$a" = "$want_a" ] || report "$file: annotate $a, expected $want_a"

  if [ "$a" = 0 ] && [ "$want_a" = 0 ]; then
    set +e
    "$DOCX_CLI" validate "$out" >/dev/null 2>&1; rv=$?
    set -e
    [ "$rv" -eq 0 ] || report "$file: annotated output fails validation"
    # `docx text` prints every story, so the probe comment itself appears;
    # the claim is that every OTHER story is untouched.
    if ! diff <("$DOCX_CLI" text "$fx" 2>/dev/null | grep -v '^\[/comments/') \
              <("$DOCX_CLI" text "$out" 2>/dev/null | grep -v '^\[/comments/') \
              >/dev/null; then
      report "$file: annotation changed story text outside comments"
    fi
  fi
done < "$here/expectations.tsv"

[ "$count" -gt 0 ] || report "no fixtures ran"
if [ "$fail" -eq 0 ]; then
  echo "corpus smoke: $count fixtures, all outcomes as pinned"
else
  exit 1
fi
