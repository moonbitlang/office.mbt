# Unified Office acceptance

This directory is the mechanical half of the F1 non-PowerPoint acceptance
gate. It proves that the schema-driven `office` command can perform one
representative XLSX workflow and one representative DOCX workflow without
falling back to the legacy format-specific executables.

Run both portable targets from the workspace root:

```sh
bash office-lib/tests/acceptance/run.sh native
bash office-lib/tests/acceptance/run.sh wasm
```

The harness covers capability discovery, format identification, fresh
creation, strict batch authoring/mutation, outline/get/text/query inspection,
template merge, DOCX annotation, validation, issues, deterministic preview,
dump/replay fixpoints, raw OOXML reads, and a zero-output failure check. It is
deliberately target-parameterized so the same assertions exercise the native
and Wasm filesystem paths.

CI runs these scenarios on native and Wasm alongside the workspace tests,
OpenXML SDK validators, and resource-boundary tests. The macOS transaction job
also runs both acceptance targets. No Codex installation or agent permission
probe is required to validate the Office CLI.
