# MoonBit Office Toolkit — feasibility assessment

**Question:** can `bobzhang/mbtexcel` (xlsx), `bobzhang/docx2html` (docx), and
`bobzhang/pdflite` (pdf) be combined into one "office toolkit" via a `moon work`
workspace?

**Verdict: yes — as a monorepo of three independent format engines.** They
coexist in one `moon work` workspace and `moon check` passes across all of them
(188 tasks) once `moon work sync` reconciles their dependency versions. "Toolkit"
here means a shared workspace plus a thin umbrella that re-exports three engines
(xlsx / docx / pdf) — **not** a shared document model, and not (yet) cross-format
conversion (docx→pdf etc.), which is greenfield.

`moon work` is MoonBit's analogue of Go's `go work`: `moon.work` lists local
member module directories so cross-module development uses the local copies
instead of the published versions.

## What this branch sets up

- **`moon.work`** — workspace manifest with four members: `.`
  (`bobzhang/mbtexcel`), `./docx2html`, `./pdflite`, `./office`.
- **`.gitmodules`** — `docx2html` and `pdflite` as git submodules, pinned to
  their published `main` HEADs on `github.com/bobzhang/{docx2html,pdflite}`
  (both pins verified to be `refs/heads/main` on the public remotes, so the
  workspace is reproducible with `git submodule update --init`).
- **`office/`** — a 4th member: a minimal `bobzhang/office` umbrella module that
  imports and links all three libraries in one package (composability proof).

## The three engines

| Module | Version | Format | Direction | Lineage |
| --- | --- | --- | --- | --- |
| `bobzhang/mbtexcel` | 0.1.6 | XLSX (Excel) | read + write | Go `excelize` |
| `bobzhang/docx2html` | 0.1.41 | DOCX → HTML / Markdown / text | read / convert only | JS `mammoth` |
| `bobzhang/pdflite` | 0.1.39 | PDF | read + write + manipulate | OCaml `camlpdf`/`cpdf` |

The formats are complementary and non-overlapping. The three are strikingly
consistent stylistically (same author): Apache-2.0, byte-oriented
`BytesView` → `Bytes` codecs, typed `suberror` + `raise` error handling, `async`
confined to the IO edge, root-package-as-flat-facade layout, and `cmd/main` +
`argparse` + cram-test CLIs.

## Empirical results

1. **Version reconciliation.** The members diverged on shared deps
   (`async` 0.20.1 / 0.19.4 / 0.19.1; `x` 0.4.38 / 0.4.43). `moon work sync`
   converged all members onto the newest of each — **`moonbitlang/async@0.20.1`**
   and **`moonbitlang/x@0.4.43`** — bumping docx2html and pdflite up a minor
   `async` generation (0.19 → 0.20) and mbtexcel's `x` (0.4.38 → 0.4.43).
2. **Workspace check.** `moon check --target native` across the workspace:
   **PASS, 188 tasks.** So the `async` 0.19 → 0.20 jump did not break docx2html
   or pdflite at type-check level — the compatibility risk the skew implied did
   not materialize.
3. **Umbrella link proof.** `office/` imports all three and exposes
   `make_workbook_bytes()`, `make_pdf_bytes()`, and `docx_to_html(BytesView)`,
   one entry point per engine. With the umbrella added, the whole workspace
   checks green (**190 tasks**), warning-free. Notably, all three engines raise
   distinct suberrors (`@xlsx.XlsxError`, `@core.PdfError`, `DocxError`) yet a
   single bare `raise` signature absorbs all of them — MoonBit's error
   polymorphism means the umbrella needs no error-type plumbing. (On this branch
   `office/moon.mod` pins `bobzhang/mbtexcel@0.1.5`, the local member version;
   the 0.1.6 bump lives on the docstrings branch. The workspace resolves all
   three to the local members regardless.)

## Obstacles & caveats

1. **Dependency version skew — resolved, but only in-workspace.**
   `moon work sync` fixes it by rewriting the *member* manifests. The *published*
   packages still declare the old versions, so the umbrella only builds against
   the reconciled locals; a standalone `bobzhang/office` published to mooncakes
   would need the three upstreams to actually release the aligned versions.
2. **No shared document IR.** Each library has its own model (`Workbook`/
   `Worksheet`, `DocumentElement`/`HtmlNode`, `PdfDocument`). A "unified API" is
   namespace aggregation + shared conventions, not a common type. Value-add
   pipelines (docx→pdf, xlsx→pdf, html→pdf) do not exist and are new work:
   docx2html only emits HTML/Markdown strings, and pdflite has no HTML→PDF
   renderer.
3. **Submodule members vs. `moon work sync`.** `sync` edits
   `docx2html/moon.mod` and `pdflite/moon.mod`, which live inside their own
   repos. Those edits can't be committed to the parent monorepo without
   committing upstream in each submodule (or vendoring the sources instead of
   submoduling). A fresh clone reproduces the state with
   `git submodule update --init && moon work sync`.
4. **Target-matrix mismatch.** mbtexcel is `native+js+wasm`; pdflite has
   native-only C-FFI pieces (clipping / RNG / strftime) and native-only
   `async_io`; docx2html's library is all-targets but its CLI is native-only. A
   toolkit advertising js/wasm must gate pdflite's native-only features.
5. **Duplicated infrastructure.** Two ZIP stacks — mbtexcel's own `zip` package
   vs docx2html's `hustcer/fzip` — for two ZIP-container formats. A consolidation
   opportunity.

## A note on git submodules inside a git worktree

This branch was assembled inside a linked git *worktree*, so the submodule git
directories were created under `.git/worktrees/office-toolkit-monorepo/modules/…`
(worktree-private) rather than the shared `.git/modules/…`. Consequences:

- The submodule checkouts are **bound to this worktree** — removing the worktree
  drops them, and the same branch checked out elsewhere needs
  `git submodule update --init` to re-materialize them (normal submodule
  behavior, but the objects aren't shared through the main repo).
- The **committed artifacts are unaffected**: `.gitmodules`, the gitlinks, and
  `moon.work` are ordinary tracked files/tree-entries that commit and push
  normally, and the pinned SHAs exist on the public remotes.

For a durable monorepo, initialize the submodules from the **primary checkout**,
not a throwaway worktree.

## Recommendation

- **Now:** keep three independently published packages; add the thin
  `bobzhang/office` umbrella (this branch's `office/`) for one-import
  convenience, plus the `moon work` workspace for coordinated local development.
- **Next:** align `async`/`x` versions across the three *upstream* so
  `moon work sync` becomes a no-op and a published umbrella is possible; consider
  vendoring instead of submodules to avoid the sync-inside-submodule friction;
  consolidate onto one ZIP implementation.
- **Later (optional):** a shared document IR plus cross-format renderers
  (html→pdf via pdflite primitives; xlsx/docx→pdf) to make this a true toolkit
  rather than an aggregation.
