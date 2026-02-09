#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

shopt -s nullglob
demo_tests=(mbtexcel_demo_*_roundtrip_test.mbt)

if [[ ${#demo_tests[@]} -eq 0 ]]; then
  echo "No demo roundtrip tests found."
  exit 1
fi

echo "Running ${#demo_tests[@]} demo roundtrip tests..."
for test_file in "${demo_tests[@]}"; do
  echo "==> moon test ${test_file}"
  moon test "${test_file}"
done

echo "==> moon test demos_openxml_validity_test.mbt"
moon test demos_openxml_validity_test.mbt

echo "Demo roundtrip regression suite passed."
