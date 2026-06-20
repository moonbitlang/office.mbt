# pdflite Architecture Improvement Proposal

Status: REVISED 2026-06-20 — the keystone (`document` extraction) approach is
abandoned; see §0. Earlier sections (4 "Document core", 5 Slice 0.5/1, 8) are kept
for history but are SUPERSEDED by §0.
Date: 2026-06-20
Scope: maintainability & comprehensibility of the library, not behavior change

## 0. Status & corrected strategy (supersedes the keystone plan)

**The central idea of this proposal — extracting `PdfDocument` into a mid-level
`document` package (the "keystone", Slice 1 / Phase C / C1) — was attempted and is
INFEASIBLE in MoonBit. Do not retry it.**

What was actually done and merged (the *right* kind of work):

- **Phase A** — hygiene + guardrails (doc archive, rule-based target matrix,
  `scripts/check_arch.sh` CI ratchet). Merged (PR #12).
- **Phase B** — leaf extraction below root: `xref_model` package
  (`ObjectStreamReference`), `crypt_core` security state
  (`PdfEncryptionValues`/`PdfSavedEncryption`), plus an async-dep upgrade and a
  `derive(ToJson)` cleanup. Merged (PR #13).

Why the keystone fails (verified empirically + `moon explain --diagnostic 4059`):

- MoonBit **forbids `pub` methods on a foreign type**: `pub fn @document.PdfDocument::m`
  is rejected ([4059]). Only the package that *defines* a type may define its
  public methods.
- `PdfDocument` has **1157 methods (450 `pub`)** and a **~445-method public API**.
  Moving the struct to a thin `document` package forces the entire public method
  surface (and its transitive private helpers) down with it — i.e. it just renames
  root. Non-`pub` `fn @document.PdfDocument::m` *extension* methods work, but
  cannot carry a public API.
- Of the 450 `pub` methods, only **11** are used by real external packages
  (markdown, async_io, cmd, README); **386** are `pub` only for blackbox tests.

**Corrected strategy (this is the plan going forward):** keep `PdfDocument` in the
ROOT package as the public facade. Decompose by extracting **leaf packages BELOW
root** — pure models, state, and algorithms that do NOT depend on `PdfDocument`
(exactly what Phase B did). Root methods orchestrate those leaf packages. Do not
move `PdfDocument`; do not pursue a `document` layer. Lower-risk follow-on:
per-domain public-API boundary cleanup (demote test-only `pub` methods to non-pub,
move those tests to whitebox, keep blackbox coverage for the genuine public API).

Everything below predates this finding and is retained for context only.

---

> Original revision note (pre-C1): Section 3a, the revised Slice 0.5/1, the
> corrected slice ordering, and the CI guard in Section 6 incorporate an external
> engineering review. Key corrections: the monolith is *method*-shaped (446 public
> `PdfDocument::` methods), not just file-shaped; the `document` keystone has two
> hidden upward dependencies (`PdfSavedEncryption`, `ObjectStreamReference`) that
> must be resolved *before* it can be extracted; and ownership of those 446
> methods must be decided per domain or the coupling just moves to new packages.
> (This keystone framing is now abandoned — see §0.)

## 1. Executive summary

The foundation and object-model layers of pdflite are already well factored into
small, acyclic packages (`core`, `syntax`, `crypt_core`, `flate`, `codec`,
`text/*data`, `geometry`, etc.). The problem is concentrated in **one giant root
package** that still holds the overwhelming majority of feature logic. The
directory tree suggests a layered design that the code does not actually have
yet.

This proposal recommends finishing the extraction the existing `ARCHITECTURE.md`
already calls for, but adds the one structural change that currently blocks it:
moving the central `PdfDocument` type out of the root into a mid-level
`document` package. With that keystone moved, feature domains can be pulled out
of root one prefix-group at a time, in behavior-preserving slices.

## 2. Current state (measured 2026-06-20)

Project packages (excluding vendored deps) form a clean, acyclic graph:

```
core            -> (none)            syntax  -> core, crypt_core
crypt_core      -> core              reader  -> core, syntax
geometry        -> core              writer  -> core, crypt_core
flate / codec   -> core              font    -> syntax
content         -> core, geometry, syntax
page            -> core, geometry, syntax
```

But the root package (`.`) is a monolith:

| Metric | Value |
| --- | --- |
| Non-test source files in root | 637 |
| Non-test source LOC in root | ~85,600 |
| Test LOC in root | ~115,400 |
| Total `.mbt` files in root | 836 |
| Public API surface (`pkg.generated.mbti`) | 3,201 lines |
| Packages imported by root `moon.pkg` | ~30 internal + ~10 stdlib |

Root files are grouped only by **filename prefix**, which acts as a fake
namespace with no encapsulation. The largest prefix groups (non-test file
counts):

```
page 68   content 55   text 52   ua 36   draw 33   reader 32
image 29  metadata 29  bookmark 21  addtext 21  ocg 19  crypt 17
codec 16  util 13  merge 14  tweak 13  writer 10  fun 9  truetype 8
```
(Counts match `docs/packages.md`, which is the canonical measured table.)

Several of these already have a sibling package, but the package is a near-empty
stub while the real code stays in root. Example — bookmarks:

- `bookmark/pdf_bookmark_model.mbt` — 32 LOC (just the model type)
- root `pdf_bookmark_*.mbt` — 2,236 LOC (all the actual logic)

So the extraction is ~1–2% done for those domains: the directory exists, the code
did not move.

## 3. Problems, ranked by pain

1. **No encapsulation across 637 files.** Every root file can read every other
   root file's internals. Changing any "private" helper is a whole-package
   concern. Newcomers cannot reason about a feature in isolation.

2. **The directory tree lies.** `bookmark/`, `annotation/`, `metadata/`,
   `page/`, etc. exist but hold a fraction of their domain. A reader who opens
   `bookmark/` to understand bookmarks finds 32 lines and misses 2,236.

3. **The `PdfDocument` keystone is in the wrong layer.** `PdfDocument`,
   `PdfObjects`, `PdfObjectMap`, and the object-table accessors live in root
   (`pdf_document.mbt`). Root sits *above* every other package, so no
   document-level feature can be extracted downward — the feature would need a
   type that only exists above it. This single placement blocks essentially all
   remaining extraction.

4. **Manual 4-target test matrix.** `moon.pkg` enumerates ~150 test files, each
   repeated across `wasm-gc / js / native / llvm`. Every new test edits this
   block by hand; drift and omissions are easy and invisible.

5. **Oversized public API.** A 3,201-line `.mbti` means the root exports a flat
   sea of functions with no domain grouping, making "what is the supported API"
   unanswerable.

6. **Root clutter from migration history.** `CamlPDFMigrationTodo.md` (763 KB),
   `CamlPDFMigrationPlan.md` (142 KB), and `CamlPDFArchitecturePlan.md` (50 KB)
   sit at repo root and dominate any file listing, obscuring current docs.

## 3a. The deeper problem: the API is method-monolithic, not just file-monolithic

Moving files into packages is necessary but **not sufficient**. The root exposes
**446 public `PdfDocument::` methods** in `pkg.generated.mbti`, many belonging to
feature domains (page, bookmark, crypt, metadata, ...). If we only relocate files,
those methods either:

- stay defined on `PdfDocument` (a `@document.PdfDocument`) from inside feature
  packages — which couples every feature package back to the document type and,
  in MoonBit, makes method discovery/re-export through a root facade awkward; or
- get blanket-promoted to `pub` / fields widened to `pub(all)` so feature code can
  reach `doc.objects` and friends — which just relocates the no-encapsulation
  problem.

So extraction must decide, per method, one of: **(a)** root-owned facade method,
**(b)** domain free function taking `PdfDocument` (preferred for feature logic),
or **(c)** drop/deprecate (old CamlPDF/cpdf compatibility shims). This decision,
not the file move, is the real work.

Two concrete upward dependencies made `PdfDocument` non-trivial to lift out.
Both are now RESOLVED (Slice 0.5 / commits B1, B2):

- `PdfObjectData::ObjectToParseFromObjectStream` referenced
  `@reader.ObjectStreamReference`; the type was moved to the new `xref_model`
  package (B1), so it is now `@xref_model.ObjectStreamReference`.
- `PdfDocument.saved_encryption` referenced `PdfSavedEncryption`, defined in root
  crypt code; `PdfSavedEncryption`/`PdfEncryptionValues` were moved into
  `crypt_core` (B2), so the field is now `@crypt_core.PdfSavedEncryption?`.

A naive `document -> reader, syntax, core` is therefore wrong: it omits the crypt
state dependency, and pinning `document` *above* `reader` blocks later moving the
document-level readers (currently in root) down into a reader layer without a
cycle.

## 4. Target architecture

> SUPERSEDED by §0: Layer 2 ("Document core" / a `document` package) does NOT
> exist and cannot — `PdfDocument` stays in root as the facade (Layer 4/5 collapse
> into root). The foundation/syntax/leaf layers below are still the right target.

Keep the layer model already written in `ARCHITECTURE.md`, but make it real and
name the missing middle layer:

```
Layer 0  Foundation        core, geometry, (data: text/*data)
Layer 1  Syntax/object     syntax, reader, crypt_core, xref_model
Layer 2  Document core     [ABANDONED] PdfDocument stays in root (facade);
                           MoonBit forbids pub methods on a foreign type, so its
                           ~445-method public API cannot leave root
Layer 3  Codecs/filters    flate, codec, (image codecs), crypt stream policy
Layer 4  Feature domains   leaf models/algorithms extracted BELOW root; the
                           document-facing feature logic stays in root as methods
Layer 5  Entry points      cmd/main, markdown/cmd, async_io, fixture_acceptance
```

Rules (unchanged in spirit, enforced going forward):

- Dependencies point down only. A feature package may depend on `document`,
  syntax/object, codecs, foundation — never on another feature package unless
  that dependency is itself acyclic and intentional (e.g. `markdown -> page`).
- The root package shrinks to a **thin facade**: re-exports + cross-domain glue
  only. Ideally it eventually disappears or becomes a small `pdflite` umbrella.

## 5. Migration plan (behavior-preserving slices)

The ordering matters because of the keystone. Each slice ends with
`moon check && moon info && moon fmt && moon test` and an intentional review of
the `.mbti` diff.

### Slice 0 — Tooling & hygiene (low risk, unblocks the rest)
- Replace the hand-maintained per-file `targets` map in `moon.pkg` with the
  broadest default that works, scoping exceptions only for the genuinely
  target-specific files (the `*_native*` ones). Goal: adding a test should not
  require editing the target matrix.
- Move `CamlPDF*.md` into `docs/history/` (or an archive) so the repo root
  reflects the *current* design.
- Add a short `docs/packages.md` mapping each domain to its package + remaining
  root files, so the "directory lies" gap is at least documented during the
  transition.

### Slice 0.5 — Resolve `document`'s upward dependencies & method ownership (pre-work)
This must land before any `document` extraction, or the keystone move stalls.
- **Lower the shared model types** that `PdfDocument` transitively needs:
  - Move/keep `ObjectStreamReference` (and any xref *model* types) in a low-level
    model package that both `reader` and `document` can sit above. Keep `reader`
    as a low-level xref/parser package; do **not** let `document` depend on the
    high-level reader entry points.
  - Move `PdfSavedEncryption` / `PdfEncryptionValues` (security *state*, not crypt
    algorithms) down into `crypt_core` (or a tiny `security_state` package) so
    `document` can reference it without depending on root crypt logic.
- **Inventory the 446 `PdfDocument::` methods by domain** (one-time artifact).
  For the keystone extraction (Slice 1) only the coarse split is needed —
  document-core method vs feature method. The fine per-method decision
  (`facade` / `domain-function` / `drop`) is made lazily in each feature slice,
  not all 446 up front (consistent with §10). This table is the running contract
  that prevents the coupling from silently re-forming.

### Slice 1 — Extract the `document` package (the keystone) — ABANDONED (see §0)
> This slice is INFEASIBLE: MoonBit forbids `pub` methods on a foreign type, so
> PdfDocument's ~445-method public API cannot live in root once the type moves to
> `document`. The text below is retained only to document what was tried.
- Create `document/` containing `PdfDocument`, `PdfObjects`, `PdfObjectMap`,
  `PdfObjectEntry`, `PdfObjectData`, `PdfObjectEvent`, plus a **deliberate set of
  public accessor/mutation APIs** (e.g. object-table get/set/allocate, event-log
  append) so feature packages never need `doc.objects` field access. Do not widen
  fields to `pub(all)` as the access mechanism.
- Move the core object-table/lookup/allocation/event-log helpers from root
  (`pdf_document*.mbt`, object-map parts of `pdf_lookup_*.mbt` / `pdf_tree_*.mbt`).
- Resulting layer: `document -> {xref-model, syntax, crypt_core/security-state,
  core}`, with the high-level `reader`/`writer` entry points *above* `document`
  (consider naming them `document_reader` / `document_writer` to make the
  direction obvious). `document` itself holds no feature logic.
- Root now depends on `document`. This is the single highest-leverage change.

### Slice 2+ — Extract feature domains, dependency order first
Process one prefix group per slice. Ordering corrected so prerequisites precede
dependents (note: `crypt` is deferred until its saved-state contract from Slice
0.5 exists; `content` precedes `page`/`draw`; `ua` is near the end):

1. **Pure codec/filter split** — stream/image filters still in root
   (`pdf_codec_*`, `pdf_ccitt_*`, `pdf_jpeg*`) folded into existing `codec`.
   Self-contained, no document coupling.
2. **`content` model** (55) — content-stream model & operators; depends on
   syntax/geometry/`document`. Must precede page and draw.
3. **`page`** (68) + `merge`/`impose`/`chop`/`pad`/`squeeze` — biggest group;
   depends on `document` + `content`.
4. **`image`** (29) — depends on codecs + `document`.
5. **Finish started extractions**: `bookmark` (21), `annotation`, `ocg` (19),
   `metadata` (29), `attachment`, `portfolio`, `destination` — delete the
   stub-vs-root split for each.
6. **`text`** (52) + `font`/`truetype` (root parts, 8 each) — depends on
   `text/*data` and `document`; move predefined CMap tables to data packages first.
7. **`draw`** (33) + **`addtext`** (21) + `fun` (functions/shading, 9) — depend on
   content/page.
8. **`crypt`** (17) — only after Slice 0.5 fixed where `PdfSavedEncryption` lives;
   it also touches writer/recrypt flows, so it is not the freebie it first looks.
9. **`ua`** (36, accessibility/Matterhorn) + `structure`/`tree` — depend on page +
   content; do last. `tweak`, `redact` mop-up.

For each domain slice:
- Move source files unchanged into the package; fix only the now-cross-package
  references (add `@pkg.` qualifiers; widen visibility only where required).
- Move the matching `*_test.mbt` files with them.
- Prune the root `.mbti` for symbols that became package-internal.

### Slice N — Collapse the root
Once domains are out, the root should be a thin re-export umbrella (or removed in
favor of a `pdflite` facade package). Re-evaluate whether a facade is even wanted
given there are few external users.

## 6. Conventions to lock in (prevent regression)

- **One domain = one package.** New feature code never lands in root.
- **Naming:** drop the `pdf_` filename prefix once a file lives in its own
  package (the package name already namespaces it). e.g. `bookmark/write.mbt`,
  not `bookmark/pdf_bookmark_write.mbt`.
- **Visibility:** prefer package-private; promote to `pub` only what the `.mbti`
  review shows is a real cross-package need. Reach document internals through the
  Slice-1 accessor API, never by widening fields to `pub(all)`.
- **Method ownership:** feature logic is a domain free function taking
  `PdfDocument`, not a `PdfDocument::` method defined from a feature package.
  Reserve `PdfDocument::` methods for the (small) root facade.
- **Tests travel with code:** a domain's tests live in its package.
- **CI guard (dependency graph, not just counts):** fail the build if any feature
  package imports root, or if a new root `pdf_*.mbt` source file appears outside
  an allowlisted facade set. A raw root-file-count ratchet is a weaker secondary
  check.

## 7. Risks & mitigations

- *Visibility churn:* moving a file across a package boundary turns implicit
  intra-package access into compile errors. Mitigation: do one prefix group at a
  time; let the compiler enumerate the boundary; widen minimally.
- *Hidden cycles:* a domain may reach "sideways" into another domain's helper.
  Mitigation: when found, push the shared helper *down* into `document` or
  foundation, never sideways.
- *Test target matrix regressions:* do Slice 0 first so test moves don't fight a
  hand-maintained matrix.
- *Big-bang temptation:* explicitly avoid. Every slice is behavior-preserving and
  green on its own; the `.mbti` diff is the contract reviewed each time.

## 8. Success metrics

> SUPERSEDED by §0: "root -> < 50 files" and "`document` package exists" are NOT
> goals — `PdfDocument` and its ~445-method API stay in root by design. Realistic
> metrics: leaf packages keep growing below root; root's `.mbti` shrinks toward the
> genuine ~11-method external surface; no feature/leaf package imports root.

- ~~Root non-test source files: 637 -> < 50 (target: facade only).~~ (not a goal)
- No domain has a "stub package + bulk-in-root" split *for the leaf parts*.
- ~~`document` package exists~~; no leaf/feature package depends on root.
- `moon.pkg` target matrix is rule-based, not per-file enumerated. (done, A3)
- New contributor can find a *leaf* domain's pure code by opening its package.

## 9. Open questions for review

1. Is a final thin `pdflite` umbrella/facade worth keeping, or should consumers
   import domain packages directly (given few external users)?
2. Should `document` also own catalog/trailer/page-tree accessors, or should
   those be a separate `catalog` package above `document`?
3. Is there appetite for the CI "root file count ratchet", or is convention
   enough?
4. Preferred slice ordering — is the dependency-driven order above acceptable, or
   should we prioritize the domains under most active change first?

## 10. Minimum viable improvement (if appetite is limited)

If the full multi-slice extraction is too much to commit to now, the
highest-value-per-effort subset is:

1. Slice 0 tooling/hygiene: rule-based `moon.pkg` target matrix, move `CamlPDF*.md`
   to `docs/history/`, add `docs/packages.md`.
2. Slice 0.5 + Slice 1 only: lower the two upward deps, then extract `document/`
   with a minimal stable accessor API. Leave existing root feature methods in
   place as facade wrappers for now.
3. Add the dependency-graph CI guard so the monolith cannot regrow.

This captures most of the comprehensibility win (a real document core + a guard
rail) without forcing the per-method ownership decisions for all 446 methods up
front — those can then happen lazily, one domain slice at a time.
