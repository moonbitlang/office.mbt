#!/usr/bin/env bash

# Verifies every occurrence selected for an internal dependency. This catches
# both a stale direct resolution and a conflicting transitive resolution.
assert_selected_dependency() {
  local tree="$1"
  local dependency="$2"
  local expected_version="$3"
  local prefix="$dependency -> $dependency@"
  local found=0
  local line selected
  while IFS= read -r line; do
    if [[ "$line" == *"$prefix"* ]]; then
      found=1
      selected="${line#*"$prefix"}"
      selected="${selected%%[[:space:]]*}"
      if [[ "$selected" != "$expected_version" ]]; then
        echo "error: $dependency resolved to $selected, expected $expected_version" >&2
        return 1
      fi
    fi
  done <<<"$tree"
  if [[ "$found" -ne 1 ]]; then
    echo "error: moon tree did not select $dependency@$expected_version" >&2
    return 1
  fi
}
