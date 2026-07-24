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
an empty user home, and an empty Codex home, so global `AGENTS.md` files,
personal skills, plugins, configuration, and rules cannot coach the probe.

```sh
probe="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-probe.XXXXXX")"
evidence="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-evidence.XXXXXX")"
auth_json="$HOME/.codex/auth.json"
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
