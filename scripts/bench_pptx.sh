#!/usr/bin/env bash
# Modified for office.mbt: official module namespace.
# Cross-library benchmark: build N slides with one text box each and
# serialise to bytes, in moon-pptx, python-pptx and PptxGenJS.
#
# Measures the whole process — start-up included — because that is what a
# user waits for, plus peak RSS, which no in-process timer can see. The
# per-phase breakdown for the PPTX module alone comes from `moon bench` instead:
#
#   moon bench pptx/integration --target native --release
#
# Nothing is written to disk: the PPTX library has no file I/O, so the
# other two serialise to an in-memory buffer to keep the comparison level.
#
# Requires: python3 with python-pptx, node, and `npm install pptxgenjs`
# inside tools/pptx-bench. See pptx/docs/pptx-benchmarks.md.
#
# Usage:  scripts/bench_pptx.sh [reps] [sizes...]      (default: 3, 10 100 1000)
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
here="$ROOT/tools/pptx-bench"
reps="${1:-3}"
shift || true
sizes=("${@:-10 100 1000}")
# shellcheck disable=SC2206
sizes=(${sizes[@]})

# GNU time (-v) and BSD time (-l) report peak RSS in different units:
# Linux in KB, macOS in bytes.
case "$(uname -s)" in
  Darwin) time_flag="-l"; rss_div=1048576 ;;
  *)      time_flag="-v"; rss_div=1024 ;;
esac

# Run one command `reps` times; echo "best_wall_ms peak_rss_mb".
measure() {
  local best_ms="" best_rss=0 out start end ms rss
  for _ in $(seq "$reps"); do
    out="$(mktemp)"
    start=$(python3 -c 'import time; print(int(time.time()*1000))')
    /usr/bin/time $time_flag "$@" >/dev/null 2>"$out"
    end=$(python3 -c 'import time; print(int(time.time()*1000))')
    ms=$((end - start))
    rss=$(grep -iE 'maximum resident set size' "$out" | grep -oE '[0-9]+' | head -1)
    rss=$(( ${rss:-0} / rss_div ))
    [ -z "$best_ms" ] && best_ms=$ms
    [ "$ms" -lt "$best_ms" ] && best_ms=$ms
    [ "$rss" -gt "$best_rss" ] && best_rss=$rss
    rm -f "$out"
  done
  echo "$best_ms $best_rss"
}

printf '%-14s %8s %12s %10s\n' library slides "wall (ms)" "RSS (MB)"
printf '%-14s %8s %12s %10s\n' -------------- -------- ------------ ----------

# moon-pptx runs from a prebuilt native binary so the figure is the
# library, not the compiler.
moon -C "$ROOT" build --target native --release pptx/cmd/bench >/dev/null
mbt_bin="$ROOT/_build/native/release/build/moonbitlang/pptx/cmd/bench/bench.exe"
if [ ! -x "$mbt_bin" ]; then
  echo "PPTX benchmark binary not found: $mbt_bin" >&2
  exit 1
fi

for n in "${sizes[@]}"; do
  if [ -n "$mbt_bin" ]; then
    read -r ms rss <<<"$(measure "$mbt_bin" "$n")"
    printf '%-14s %8s %12s %10s\n' moon-pptx "$n" "$ms" "$rss"
  fi
  read -r ms rss <<<"$(measure python3 "$here/bench_pptx.py" "$n")"
  printf '%-14s %8s %12s %10s\n' python-pptx "$n" "$ms" "$rss"
  read -r ms rss <<<"$(measure node "$here/bench_pptxgenjs.js" "$n")"
  printf '%-14s %8s %12s %10s\n' PptxGenJS "$n" "$ms" "$rss"
done
