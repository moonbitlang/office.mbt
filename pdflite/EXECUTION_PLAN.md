# pdflite Architecture Refactor — Execution Plan

Companion to `ARCHITECTURE_PROPOSAL.md`. This is the commit-by-commit sequence.

Branch: `refactor/architecture-slices`

## Ground rules (every commit)

1. One commit = one reviewable, behavior-preserving step (unless explicitly a
   docs/tooling commit).
2. Before committing, run the gate (warn-list matches CI in
   `.github/workflows/ci.yml`, env `MOON_WARN_LIST: "+a-39@65@73@74@75"`):
   ```
   moon fmt
   moon check
   moon check --warn-list +a-39@65@73@74@75   # exactly the CI policy
   moon test
   ```
3. Commit, then have `codex` review the single commit diff
   (`git show --stat` + full diff) for correctness/regressions before moving on.
4. If codex flags a real issue, fix in a follow-up commit (don't rewrite history).
5. `.mbti` diffs are part of the review: API changes must be intentional.

## Phase A — Hygiene & guardrails (safe, mechanical)

These carry near-zero behavior risk and unblock everything else.

### Commit A1 — Archive historical migration docs
- Move ONLY the three genuinely-historical CamlPDF docs into `docs/history/`
  (use `git mv`): `CamlPDFArchitecturePlan.md`, `CamlPDFMigrationPlan.md`,
  `CamlPDFMigrationTodo.md`.
- KEEP at root (verified to be living, not historical): `OCaml2MoonBit.md` is an
  actively-maintained porting guide ("Update it whenever a reusable porting rule
  ... is verified"); `PdfMarkdownAcceptancePlan.md` is an active plan ("This plan
  tracks ..."). Archiving these was rejected after reading them.
- No code touched. Gate: `moon check` (should be a no-op) + repo builds.

### Commit A2 — Land planning docs
- Add `ARCHITECTURE_PROPOSAL.md`, `EXECUTION_PLAN.md`, and `docs/packages.md`
  (current domain → package + remaining-root-files map).
- Additive docs only.

### Commit A3 — Rule-based test target matrix
- Replace the ~150-entry per-file `targets` map in root `moon.pkg` with the
  broadest default that builds, keeping explicit entries ONLY for the files that
  are genuinely native-only. Use an EXPLICIT native-only list, NOT a `*_native*`
  glob: `pdf_clip_native*`, `pdf_random_native*`, `pdf_strftime_native*`. Note
  `pdf_native_acceptance*.mbt` contains the substring "native" but is all-target
  today, so a glob would wrongly restrict it.
- Gate: full multi-target `moon test` must stay green. This is the one Phase A
  commit with real (build-config) risk — validate carefully per target.

### Commit A4 — Dependency-graph CI guard
- Add a script (e.g. `scripts/check_arch.sh`) asserting:
  - **No feature package imports the root package.** Define the set explicitly.
    Entry-point / glue packages legitimately import root TODAY and are excluded:
    `cmd/main`, `markdown`, `markdown/cmd`, `async_io`, and every
    `*/fixture_acceptance` package. The guard's deny-list is "all project
    packages MINUS those entry/test packages". As domains are extracted in
    Phase D, remove them from any temporary exclusion.
  - **No new root source file outside an allowlist.** Allowlist ALL current root
    `*.mbt` files (not just `pdf_*.mbt` — there are only ~3 non-`pdf_` ones), so
    the guard cannot be bypassed by adding `new_feature.mbt`.
- Wire it into `.github/workflows/ci.yml`.
- Seed the allowlist with today's root files so it is green now and ratchets down.

## Phase B — Keystone prep (Slice 0.5) — resolve upward deps

> Progress: a prerequisite `deps` commit upgraded moonbitlang/async 0.17.0 ->
> 0.19.4 (restoring local native validation). **B1 DONE** (xref_model package).
> **B2 DONE** (crypt state in crypt_core). Both upward deps now point downward;
> C1 (document extraction) is unblocked.

`document` cannot be extracted until these two type dependencies point downward.

### Commit B1 — Lower the xref model types
- DECISION (per review): create a small new `xref_model` package (depends on
  `core`, `syntax`) and move the pure xref *model* types there:
  `ObjectStreamReference`, `PdfClassicXRefEntry`, `PdfXRefSection`,
  `PdfClassicXRefIndex` (from `reader/pdf_reader_xref_model.mbt`). Then both
  `reader` and the future `document` depend DOWNWARD on `xref_model`. Do NOT keep
  them in `reader` (that would force `document -> reader`, the very cycle risk
  this refactor removes).
- Behavior-preserving; use `moon ide rename` for references.

### Commit B2 — Lower the saved-encryption state
- Move `PdfEncryptionValues` and `PdfSavedEncryption` (package-private, in root
  `pdf_crypt_model.mbt`, only depend on `@core.PdfCryptType`) down into
  `crypt_core` so `document` can hold a `saved_encryption` field without
  depending on root crypt logic.
- DO NOT move `PdfDecryptionResult` — it contains a `PdfDocument` field and so
  must stay above `document`, not below it.
- Visibility caveat: root crypt code reads these record fields directly (e.g.
  `pdf_crypt_encrypt_dictionaries.mbt`, `pdf_crypt_passwords.mbt`). Moving the
  types across the boundary means either exposing fields `pub(all)` or adding
  deliberate constructors/accessors. Prefer accessors; only widen fields where
  the field-read volume makes accessors impractical, and note it in the commit.
- Behavior-preserving.

### Commit B3 — Method-ownership inventory (phased, not all-at-once)
- Generate `docs/document-method-inventory.md`: list all 446 public
  `PdfDocument::` methods, each assigned a `domain` (page/crypt/metadata/...).
- For C1 it is ONLY required to decide the coarse split: which methods are
  genuine document-core (stay in `document`) vs feature methods (stay in root as
  facade wrappers for now). The fine `facade` / `domain-function` / `drop`
  decision per method is made lazily in each Phase D domain slice, NOT up front.
- This resolves the apparent tension with proposal §10: the inventory is created
  once (B3), but per-method ownership is decided incrementally per domain.
- Additive doc; becomes the running contract for Phase D slices.

## Phase C — Keystone extraction (Slice 1)

### Commit C1 — Create the `document` package
- New `document/` package holding `PdfDocument`, `PdfObjects`, `PdfObjectMap`,
  `PdfObjectEntry`, `PdfObjectData`, `PdfObjectEvent`, plus a deliberate public
  accessor/mutation API (object get/set/allocate, event-log append) — NOT
  `pub(all)` field exposure.
- `document -> {xref-model, syntax, crypt_core/security-state, core}`.
- Root re-exports `PdfDocument` so existing call sites keep compiling; root
  feature methods stay as facade wrappers for now.
- Largest behavior-preserving commit; may need several visibility fixes the
  compiler enumerates. Keep them minimal.

## Phase D — Per-domain feature slices (one domain per commit)

Order (prereqs first): codec filters → content → page (+merge/impose/chop/pad/
squeeze) → image → bookmark/annotation/ocg/metadata/attachment/portfolio/
destination → text(+font/truetype) → draw/addtext/fun → crypt → ua/structure →
tweak/redact mop-up.

Each domain commit:
1. Move source + test files into the domain package.
2. Convert feature logic to domain free functions taking `PdfDocument` (per the
   B3 inventory); leave only facade wrappers (if any) in root.
3. Fix cross-package visibility minimally (prefer accessors over `pub(all)`).
4. Prune the now-internal symbols from root `.mbti`.
5. Gate + commit + codex review.

## Checkpoints

- After Phase A: pause, report, confirm appetite for the semantic phases.
- After Commit C1: re-run the full acceptance/fixture suites; this is the
  riskiest single step.
- Track progress by the §8 success metrics in the proposal (root file count,
  no stub-vs-root splits, no feature package importing root).
