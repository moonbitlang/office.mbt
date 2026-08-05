# Git Hooks

These hooks move the cheapest CI checks to before the push, where they cost
seconds instead of a CI round trip.

## Why

Of the ten most recent red CI runs on this repository, **six failed on
`Format check` or `Interface check`** — a `moon fmt` diff and a
`pkg.generated.mbti` diff that together take about thirteen seconds to
reproduce locally. In CI they surface roughly six minutes into a job, so each
one costs a full push/wait/fix cycle. One pull request needed eleven CI
attempts across nearly four hours, five of them consecutive `Format check`
failures.

`scripts/ci/local-gate.sh` runs exactly what CI's `lint` job runs, and leaves
the corrections applied rather than merely reporting them.

## Enabling

```bash
git config core.hooksPath .githooks
```

That is all — the hooks are already executable and committed.

## What runs when

| Hook         | Runs                                            | Cost |
| ------------ | ----------------------------------------------- | ---- |
| `pre-commit` | `moon check`                                    | seconds (warm) |
| `pre-push`   | `scripts/ci/local-gate.sh` — `moon fmt`, `moon info`, `moon check` for native/wasm/js | ~13 s (warm) |

`moon fmt` and `moon info` rewrite files, so they belong in `pre-push` rather
than `pre-commit`: rewriting mid-commit would leave the corrected copies
unstaged and commit the uncorrected ones.

Run the gate by hand at any time:

```bash
scripts/ci/local-gate.sh          # everything the lint job runs
scripts/ci/local-gate.sh --fast   # skip the wasm and js type checks
```

## Bypassing

Standard git escape hatches apply when you genuinely need them:

```bash
git commit --no-verify
git push --no-verify
```
