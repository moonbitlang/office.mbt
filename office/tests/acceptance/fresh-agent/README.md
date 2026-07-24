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
PATH="$prefix/bin:$PATH" codex exec \
  --ephemeral \
  --skip-git-repo-check \
  --ignore-user-config \
  --ignore-rules \
  --sandbox workspace-write \
  -m gpt-5.6-sol \
  -c 'model_reasoning_effort="max"' \
  -C "$probe" \
  --output-last-message "$probe/final-message.md" \
  - < office/tests/acceptance/fresh-agent/prompt.md \
  > "$probe/codex-transcript.log" 2>&1
```

Attach the exact candidate head, `CANDIDATE`, `probe-result.md`,
`probe-transcript.md`, final message, and Codex transcript to the scoped F1b
pull request. If the candidate head changes, prepare a new prefix and repeat the
probe. Record every P0-P2 gap as a follow-up issue under the Office parity epic;
do not silently coach around it or claim that this baseline closes the epic.
