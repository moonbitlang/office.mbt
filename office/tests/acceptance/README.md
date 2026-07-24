# Unified Office acceptance

This directory is the mechanical half of the F1 non-PowerPoint acceptance
gate. It proves that the schema-driven `office` command can perform one
representative XLSX workflow and one representative DOCX workflow without
falling back to the legacy format-specific executables.

Run both portable targets from the workspace root:

```sh
bash office/tests/acceptance/run.sh native
bash office/tests/acceptance/run.sh wasm
```

The harness covers capability discovery, format identification, fresh
creation, strict batch authoring/mutation, outline/get/text/query inspection,
template merge, DOCX annotation, validation, issues, deterministic preview,
dump/replay fixpoints, raw OOXML reads, and a zero-output failure check. It is
deliberately target-parameterized so the same assertions exercise the native
and Wasm filesystem paths.

This is not a substitute for the rest of F1: the full workspace test matrix,
OpenXML SDK validators, fuzz/resource-boundary tests, and a fresh Codex agent
probe remain independent gates. The fresh agent receives only the installed
command, `office help all --json`, and a task prompt; its transcript and verdict
should be attached to the F1 PR rather than encoded as a deterministic test.

The reproducible installed-command probe lives in
[`fresh-agent/`](fresh-agent/README.md). It builds native and Wasm release
artifacts from one clean candidate commit, installs them outside the checkout,
and gives a brand-new agent only those commands and the checked-in task prompt.
