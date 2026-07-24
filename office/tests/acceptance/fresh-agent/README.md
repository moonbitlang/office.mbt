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
ordinary incremental reviews may use `xhigh`.

```sh
probe="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-probe.XXXXXX")"
evidence="$(mktemp -d "${TMPDIR:-/tmp}/office-f1b-evidence.XXXXXX")"
PATH="$prefix/bin:$PATH" codex exec \
  --ephemeral \
  --skip-git-repo-check \
  --ignore-user-config \
  --ignore-rules \
  --sandbox workspace-write \
  -m gpt-5.6-sol \
  -c 'model_reasoning_effort="max"' \
  -C "$probe" \
  --output-last-message "$evidence/final-message.md" \
  - < office/tests/acceptance/fresh-agent/prompt.md \
  > "$evidence/codex-transcript.log" 2>&1
```

Attach the exact candidate head, `$prefix/CANDIDATE`, the probe's
`probe-result.md` and `probe-transcript.md`, and the evidence directory's final
message and Codex transcript to the scoped F1b pull request. Keeping capture
files outside `$probe` makes the agent's working directory genuinely empty at
startup. If the candidate head changes, prepare a new prefix and repeat the
probe. Record every P0-P2 gap as a follow-up issue under the Office parity epic;
do not silently coach around it or claim that this baseline closes the epic.
