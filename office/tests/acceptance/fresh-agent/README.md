# Installed-command fresh-agent probe

This is the uncoached half of the F1b baseline. It intentionally runs outside
the repository. The agent gets two installed commands from one exact candidate
head, `office-native` and `office-wasm`, and the task outcomes in `prompt.md`.
It must discover command syntax and every consumed JSON shape from installed
help. Do not add schema examples, repository paths, or corrective hints to the
probe invocation.

From a clean candidate checkout, prepare a new isolated prefix:

```sh
prefix="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-install.XXXXXX")"
bash office/tests/acceptance/fresh-agent/prepare.sh "$prefix"
```

Create a separate empty working directory and start a brand-new ephemeral Codex
CLI instance. The F1b evidence run uses the current CLI's `max` reasoning tier;
ordinary incremental reviews may use `xhigh`. Point `auth_json` at the current
Codex `auth.json` (normally `~/.codex/auth.json`). The runner copies only that
credential into temporary state; it launches Codex with an empty environment,
an isolated Codex home, and an isolated user home containing only generated
login-shell PATH guards, so global `AGENTS.md` files, personal skills, plugins,
configuration, and rules cannot coach the probe. An explicit Codex subprocess
environment policy and the guards restore the allowlist after system login
profiles run. Its PATH therefore contains only the installed Office commands, a
private launcher directory, and fixed system directories. That private
directory exposes the exact `/usr/bin/env` runtime. Private forwarding entries
preserve the runtime's original invocation path without retaining shell-added
environment variables.
A fixed `/usr/bin/perl` exec trampoline keeps executable paths out of
`/usr/bin/env`'s assignment grammar; the original runtime and launcher
directories are never added wholesale. The runner resolves paths physically
without ambient `CDPATH` semantics and rejects overlapping probe/evidence paths
before capture files are created.

```sh
probe="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-probe.XXXXXX")"
evidence="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-evidence.XXXXXX")"
auth_json="$HOME/.codex/auth.json"
bash office/tests/acceptance/fresh-agent/run.sh \
  "$prefix" "$probe" "$evidence" "$auth_json"
```

If `codex` is a shell wrapper that invokes bare co-installed helper commands,
inspect the wrapper and pass their exact basenames as a colon-separated
`OFFICE_F1B_CODEX_LAUNCHER_HELPERS` allowlist. Path-qualified helpers need no
entry because the original wrapper path is preserved. Each allowlisted helper
is validated and forwarded through its original path without exposing unrelated
siblings:

```sh
OFFICE_F1B_CODEX_LAUNCHER_HELPERS="codex-helper:codex-real" \
  bash office/tests/acceptance/fresh-agent/run.sh \
  "$prefix" "$probe" "$evidence" "$auth_json"
```

Attach the exact candidate head, `$prefix/CANDIDATE`, the probe's
`probe-result.md` and `probe-transcript.md`, and the evidence directory's final
message, Codex transcript, and exit-status file to the scoped F1b pull request.
Keeping capture files outside `$probe` makes the agent's working directory
genuinely empty at startup. The temporary isolated homes (including the copied
credential) are removed when the runner exits. If the candidate head changes,
prepare a new prefix and repeat the probe. Record every P0-P2 gap as a follow-up
issue under the Office parity epic; do not silently coach around it or claim
that this baseline closes the epic.
