#!/usr/bin/env bash
# Shared by the isolated release checks. Callers define ROOT, SANDBOX, MODULE.
source "$ROOT/scripts/release_tree_guard.sh"

stage_registry_module() {
  local directory="$1"
  python3 "$ROOT/scripts/registry_release.py" stage "$ROOT" "$directory" "$MODULE"
  # Detached modules no longer inherit the repository's ignore rules. Preserve
  # module-specific rules too, then explicitly exclude generated release inputs.
  printf '\n' >> "$MODULE/.gitignore"
  cat "$ROOT/.gitignore" >> "$MODULE/.gitignore"
  printf '\n_build/\n.mooncakes/\ntarget/\n.tools/\n__pycache__/\n' >> "$MODULE/.gitignore"
}

stage_registry_validators() {
  mkdir -p "$SANDBOX/scripts" "$SANDBOX/tools/openxml-validator"
  cp "$ROOT/scripts/ensure_dotnet.sh" "$ROOT/scripts/validate_docx.sh" \
    "$ROOT/scripts/validate_xlsx.sh" "$SANDBOX/scripts/"
  cp "$ROOT/tools/openxml-validator/OpenXmlValidator.csproj" \
    "$ROOT/tools/openxml-validator/Program.cs" "$SANDBOX/tools/openxml-validator/"
}

stage_registry_docx_fixtures() {
  # Copy only test data, never the sibling module manifest or implementation.
  python3 "$ROOT/scripts/registry_release.py" stage "$ROOT" \
    docx2html/tests/cram/fixtures "$SANDBOX/docx2html/tests/cram/fixtures"
}

prepare_registry_dependencies() {
  local dependency expected_version dependency_tree
  moon update
  # moon update refreshes the index; a non-frozen check hydrates the fresh
  # module's dependencies before any frozen validation command is attempted.
  moon check --target native
  dependency_tree="$(moon tree)"
  printf '%s\n' "$dependency_tree"
  for dependency in "$@"; do
    expected_version="$(python3 "$ROOT/scripts/registry_release.py" version \
      "$MODULE/moon.mod" "$dependency")"
    assert_selected_dependency "$dependency_tree" "$dependency" "$expected_version"
  done
}

check_registry_publish() {
  local archive publish_output publish_status=0 dependency_tree_before dependency_tree_after
  dependency_tree_before="$(moon tree)"
  # Inspect the real archive before the dry run can send it to the registry.
  moon package --frozen
  local archives=("$MODULE"/_build/publish/*.zip)
  if [[ ${#archives[@]} -ne 1 || ! -f "${archives[0]}" ]]; then
    echo "error: expected exactly one publish archive in $MODULE/_build/publish" >&2
    return 1
  fi
  archive="${archives[0]}"
  python3 "$ROOT/scripts/registry_release.py" archive "$archive"
  # publish checks a second, freshly extracted copy of the archive. Passing
  # --frozen also freezes that empty copy, so Moon cannot install its deps.
  # Source checks/tests and packaging remain frozen with exact internal guards;
  # only publish's independent extraction is allowed to hydrate from registry.
  publish_output="$(moon publish --dry-run 2>&1)" || publish_status=$?
  printf '%s\n' "$publish_output"
  dependency_tree_after="$(moon tree)"
  if [[ "$dependency_tree_before" != "$dependency_tree_after" ]]; then
    echo "error: dependency selections changed during publish dry run" >&2
    return 1
  fi
  # Some Moon versions exit 255 even after server-confirmed dry-run success.
  if ! grep -Fq "Dry run completed successfully" <<<"$publish_output"; then
    echo "error: publish dry run did not report server success (exit $publish_status)" >&2
    return 1
  fi
}
