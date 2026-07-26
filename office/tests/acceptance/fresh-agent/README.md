# Installed-command fresh-agent probe

This is the uncoached half of the F1b baseline. It builds one exact commit from
a fresh exported snapshot, installs native and Wasm commands outside the
checkout, and gives a new Codex session only those commands and their installed
help. The task prompt contains outcomes, not command syntax, JSON examples,
repository paths, or corrective hints.

## Prepare an exact candidate

Start from a clean checkout. Pass the full 40-character HEAD and an absent
install path whose existing parent is owned by the caller and has no group or
other permissions:

```sh
head="$(git rev-parse --verify HEAD)"
install_parent="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-install.XXXXXX")"
prefix="$install_parent/candidate"
bash office/tests/acceptance/fresh-agent/prepare.sh "$head" "$prefix"
```

The installer derives the checkout from its own physical path, so its behavior
does not depend on the caller's working directory. It exports exactly `head`
with `git archive`, resolves pinned dependencies in that new tree, performs
frozen native and Wasm release builds, and compares their complete installed
help. Ignored checkout caches such as `_build` and `.mooncakes` are
never build inputs.

Publication is an atomic rename from a private sibling staging directory.
`CANDIDATE.json` is a strict machine-readable manifest containing the
full commit, toolchain and dependency-tree hashes, capability identity, and
hashes and modes for every installed executable, runtime, runner, prompt,
schema, and permission canary. `control/private.json` records the source
and Git-common paths needed to deny checkout access; it is separately denied to
probe commands.

## Run in split permissions

The live runner requires Codex CLI 0.138 or newer; this harness is verified
against Codex CLI 0.145.0. Use the runner copied into the candidate, not the
checkout copy. The probe and evidence paths must be absent siblings under a
fresh private parent:

```sh
run_parent="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-run.XXXXXX")"
probe="$run_parent/probe"
evidence="$run_parent/evidence"
auth_json="$HOME/.codex/auth.json"
"$prefix/control/run.sh" \
  "$head" "$probe" "$evidence" "$auth_json"
```

The runner verifies the entire candidate manifest before and after the session
and revalidates directory device/inode identities. It rejects pre-existing,
shared, overlapping, source-contained, protected-home, or PATH-ambiguous
locations. Spaces and `=` are supported; `:` is rejected because
POSIX PATH cannot represent it safely.

Codex receives a runner-generated isolated configuration:

- `web_search = "disabled"`, network disabled, approvals disabled,
  project instructions disabled, and no personal skills, plugins, apps,
  browser, Computer Use, memories, or subagents;
- user/workspace roots plus the exact source and Git-common paths are denied;
- the installed candidate and isolated shell home are read-only;
- only the empty probe directory and private scratch directory are writable;
- the original and copied auth, isolated Codex state, and evidence directory
  are denied to model-authored commands; and
- `CODEX_HOME` is available to the Codex parent for authentication but
  omitted from every model-authored child environment.

No legacy `--sandbox` option is passed because it would override the
custom permission profile. Before the model starts,
`codex sandbox -P fresh_agent` runs the installed permission canary. It
proves candidate read/no-write, probe/scratch write, source/auth/evidence
denial, no ambient `/tmp` write, and no child `CODEX_HOME`. A
failed canary aborts the probe.

If the Codex launcher uses a simple `#!/usr/bin/env runtime` shebang, the
runner exposes only an exact private forwarder for that runtime. Complex
`env -S`, option-bearing, or assignment-bearing shebangs are rejected. A
shell wrapper that invokes co-installed helpers by basename may use an explicit
colon-separated allowlist:

```sh
OFFICE_F1B_CODEX_LAUNCHER_HELPERS="codex-helper:codex-real" \
  "$prefix/control/run.sh" \
  "$head" "$probe" "$evidence" "$auth_json"
```

## Evidence and cleanup

Successful completion requires both a zero Codex process status and a final
JSON object matching `control/final.schema.json`. The runner returns
nonzero for an incomplete/malformed response and returns 3 for
`BASELINE FAIL`.

Retain:

- `CANDIDATE.json`;
- `RUN-PREFLIGHT.json`, `RUN.json`, and
  `permission-canary.log`;
- `probe-result.md` and `probe-transcript.md`;
- `final-message.json`, `codex-transcript.jsonl`, and
  `codex-exit-status.txt`.

The normal EXIT/HUP/INT/TERM trap deletes the isolated Codex home and copied
credential. SIGKILL and machine failure cannot run a trap. Prefer a short-lived
credential when available, keep each `run_parent` one-shot and mode 0700,
and after collecting evidence inspect it for a hidden
`.office-f1b-isolation.*` directory before deleting the entire one-shot
parent. That removes any stale credential copy without scanning or deleting
unrelated temporary directories.

If the candidate head changes, discard the prefix and evidence and repeat from
preparation. Record every P0-P2 product gap as a follow-up issue under the
Office parity epic. This baseline does not close the epic.
