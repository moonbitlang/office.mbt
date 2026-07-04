# MoonBit rough edges — notes from an AI agent

Observations collected while an AI coding agent (Claude) built out this
project over one long session: a validity-test harness, an `xlsx`
command-line tool, wasm-backend support, a `view` ASCII-table command,
several refactors, and a warning-cleanup pass. These are the specific
places the language or tooling made the agent slower, wrong, or forced a
workaround — written down so they can be triaged later.

Each item is: **what happened**, a **concrete example**, the **impact**,
and a **suggested fix**. A "What worked well" section is at the end so the
list stays honest.

---

## 1. `inspect` vs `debug_inspect` (Show vs Debug) is guess-and-check

**What happened.** The single most repeated mistake of the session. Given
a value, there is no way to tell from the call site whether it wants
`inspect` (types with `Show`) or `debug_inspect` (types deriving
`Debug`). The agent only learns by writing the test, running it, and
reading the snapshot diff.

**Example.** Snapshotting an `Option[String]`:

```
inspect(part_extension("x.xml"), content="Some(\"xml\")")   // fails
// Diff: - Some("xml")   (expected)
//       + Some(xml)     (actual — Option uses Debug-style unquoted)
debug_inspect(part_extension("x.xml"), content=(#|Some("xml")))  // correct
```

This happened repeatedly across `Option`, arrays, tuples.

**Impact.** A whole class of avoidable failed test runs; each costs a
compile+run cycle to discover.

**Suggested fix.** When an `inspect` snapshot mismatches and the type
derives `Debug` (or vice-versa), add a hint to the diagnostic:
"`this type derives Debug; use debug_inspect`". The compiler already
knows which traits the type implements.

**Note (from the MoonBit team).** For interpolation/debugging of a
`Debug`-deriving value, use `\{repr(x)}` (or `to_repr(x)`) — the
interpolation analog of `debug_inspect`. Knowing this up front removes
much of the guesswork: `debug_inspect` / `repr` for `Debug`, `inspect` /
plain `\{x}` for `Show`.

---

## 2. Migrating `derive(Show)` off deprecation is a discoverability trap

**What happened.** `derive(Show)` emits a `deprecated_syntax` warning
recommending `derive(Debug)` or a manual `Show` impl. The agent assumed
error types *required* `Show` because they are routinely interpolated as
`"\{err}"`, and concluded the migration needed a hand-written `impl Show`
per type — so it deferred the whole thing.

**The actual answer** (pointed out by the MoonBit team): switch to
`derive(Debug)` and interpolate via `\{repr(err)}` instead of `\{err}`.
No manual `Show` impl is needed. So the migration is mechanical, not a
contradiction — but it is **not discoverable**: nothing tells you that
`\{err}` needs `Show` while `\{repr(err)}` works with `Debug`, so the
natural (wrong) conclusion is "I must keep `Show`."

**Example.** `pub suberror ZipError { ... } derive(Show)` → change to
`derive(Debug)` and rewrite interpolation sites from `"error: \{err}"` to
`"error: \{repr(err)}"`.

**Impact.** The agent produced a ~90-site `deprecated_syntax` backlog it
believed was blocked, and suppressed the category (`-deprecated_syntax`),
when in fact a mechanical `repr`-based migration was available.

**Suggested fix.** Make the `deprecated_syntax` message for
`derive(Show)` name the concrete path ("use `derive(Debug)` and
`\{repr(x)}` for interpolation"), so the migration is obvious rather than
inferred. This overlaps with item #1 — surfacing `Debug`/`repr` at the
point of confusion is the single highest-leverage fix.

---

## 3. No public `exit(code)` for CLIs

**What happened.** A command-line tool needs to exit non-zero on failure
so scripts can detect it. The async runtime exposes no public
process-exit, so the only way to set a non-zero exit code is to let an
error escape `main`.

**Example (the workaround this repo now ships).** `cmd/xlsx` defines a
`CliError(String)` suberror whose `Show` prints the message, and `main`'s
catch does `raise CliError(...)` purely to force a non-zero exit:

```moonbit
async fn main {
  run_cli() catch {
    err => raise CliError(format(err))  // escape main -> non-zero exit
  }
}
```

**Impact.** Exit-code handling is done by clever error-raising rather than
an honest API. Also: the runtime prints the escaping error's `Show` to
**stdout** and appends a newline, so getting a single clean line required
an empty/`Show`-carrying sentinel dance.

**Suggested fix.** A first-class `@sys.exit(code : Int)` (or
`@async.exit`) that works on native and wasm.

---

## 4. `@async/stdio` is native-only — no `stderr` on wasm

**What happened.** `@async/stdio.stderr` (and `stdout`) exist only on the
native backend. A CLI that targets both native and wasm cannot write
errors to stderr uniformly.

**Example.** `moon check --target wasm cmd/xlsx` →
`Value stderr not found in package async/stdio`. The CLI had to route all
error output to `println` (stdout) on both targets as a result.

**Impact.** Cross-target CLIs cannot follow the stdout=data / stderr=errors
convention.

**Suggested fix.** Provide `stdout`/`stderr` writers on the wasm backend
(even if backed by the host's fd 1/2).

---

## 5. `moon.pkg` imports cannot be target-scoped

**What happened.** A package that uses `@async/fs` / `@async/process`
only in native(+wasm)-gated code still imports them unconditionally in
`moon.pkg`. On the js backend, where that gated code is not compiled, the
imports are reported as `unused_package` with no clean fix.

**Example.** After enabling the default warning set, `moon check
--target js` reports 5 residual `unused_package` warnings for
`moonbitlang/async/fs` and `.../process` in `moon.pkg` / `xlsx/moon.pkg`
— genuinely used on native+wasm, unused on js, and impossible to silence
short of dropping the import (which breaks the other targets).

**Impact.** A supported target (js) cannot be made warning-clean.

**Suggested fix.** Allow a target filter on imports, mirroring the
existing `import { ... } for "test"` mechanism — e.g.
`import { "moonbitlang/async/fs" } for "native,wasm"`.

---

## 6. `#label_migration` deprecations are invisible to `moon check`

**What happened.** The `create` option of `@async/fs.write_file` is
deprecated via `#label_migration`, which is a *migration hint*, not a
warning. `moon check` reports 0 warnings for it, so an agent auditing
"are the deprecations gone?" via `moon check` gets a false all-clear.

**Impact.** The agent briefly claimed a set of deprecations were resolved
when they weren't, because the check surface didn't show them.

**Suggested fix.** Surface `#label_migration` usages under a
warning category (even a quiet, opt-in one) so `moon check` /
`--warn-list` can find them.

---

## 7. Smaller footguns

- **argparse positionals default to optional.** A subcommand declared
  with required-looking positionals (`get <file> <sheet> <cell>`) parsed
  successfully with *none* supplied, passing empty strings downstream,
  which then failed deep in an unrelated file-open. A missing required
  positional should error at parse time.
- **`@env.now()` is millisecond-resolution.** Three calls in immediate
  succession returned identical values, so timestamp-derived unique paths
  can collide under parallel test execution.
- **`moon fmt` reshapes calls across lines**, which silently defeats
  line-oriented edits (e.g. a `sed` targeting `create=0o644` misses it
  once fmt has split the call over several lines). Minor, but it bit a
  scripted migration.
- **The default `warnings = "-a"` idiom.** Blanket-disabling all
  warnings on a package is easy to reach for during a big port, but it
  also hides real lints (`unused_mut`, `unused_try`) indefinitely. A
  "disable only the noisy categories" idiom would age better.

---

## What worked well (kept for balance)

These made the agent genuinely faster and are worth protecting:

- **`mbt check` tested doc-blocks.** `README.mbt.md` examples are
  compiled and run as tests, so documentation cannot drift from the API.
  This is the standout feature — the agent trusts docs it can compile,
  and wrote the project's READMEs as executable examples.
- **`raise` over `Result`.** Clean error propagation that keeps the happy
  path readable; the `result_error_return` lint nudges toward it well.
- **Diagnostics.** The box-with-carets format is clear *and*
  machine-parseable, and `moon explain --diagnostic <name>` gives the fix
  inline.
- **`#cfg` conditional compilation + `supported_targets`.** Bringing the
  CLI to the wasm backend was smooth once the gates were found.
- **Fast `moon check`, `moon fmt` as ground truth, `moon ide`, cram
  tests, structured `--warn-list`.** All agent-friendly.

Net: the rough edges above are narrow and mostly a matter of *tooling
telling the agent what it already knows* — which is the most fixable
kind.
