# Plan v3: docx agent tooling — closing the OfficeCLI gap (office.mbt monorepo)

Revised per codex review rounds 1 and 2 (r1: 10 changes, r2: 7 refinements — all
incorporated).

## Background / gap analysis

Vendored competitor: `.repos/OfficeCLI` (~266k lines C#, ~82k in the Word handler). Its docx
surface: semantic-path read/write (`get/query/set/add/remove/move/swap`) over **44
schema-described element types with per-operation support** (not every verb on every type),
views (text/outline/annotated/stats/issues/html/screenshot), OpenXML validate, dump/batch
replay, template merge, HTML render engine. It distinguishes stable `p[@paraId=…]` anchors
from positional `p[N]` paths.

Our repo today (docx side): `docx2html` (9,805 production .mbt lines excluding tests) —
a Mammoth port with a **public typed reader** (`read_docx` → `DocumentElement` AST +
diagnostics) and HTML/Markdown/text converters. Coverage is deliberately **lossy** (Mammoth
semantics): lists collapse to ordered/unordered + level (no numId identity), bookmark ends
and comment ranges are dropped, content controls/revisions are flattened, and the
main-document story surface is **body-only** (no sectPr/headers/footers; footnote,
endnote, and comment bodies ARE modeled and parsed), no OMML equations. What is missing is an **agent-facing
JSON/CLI surface** (the reader itself is structured), plus validation and any authoring.
The CLI is a single-purpose flag-only converter (native+wasm).

Building blocks in-repo:
- `zip/` — general zip writer (Store/Deflate), already used by docx2html's embed path.
- `docx2html/xml` — XML parser + writer; the writer is Mammoth-specific today (no root
  attributes such as `mc:Ignorable`, no `xml:space="preserve"` policy, no illegal-char
  handling) and needs hardening before serving as OOXML write infrastructure.
- `ooxml/` — Excel-specific in its public surface (`WorkbookManifest`; `ContentTypes`/
  `Relationships` are private). NOT reused for docx: a **DOCX-local OPC helper** will live
  in the docx2html module (avoids the mbtexcel-publish-first release train: docx2html
  0.1.42 depends on registry mbtexcel@0.1.7, and workspace resolution can hide an
  impossible registry dep).
- `tools/openxml-validator` — .NET SDK validator, currently opens `SpreadsheetDocument`
  only; the same SDK validates `WordprocessingDocument`.
- xlsx precedent: `inspect/` + `cmd/xlsx` outline/get JSON with versioned schemas
  (`docs/agent-json-schemas.md`); `xlsx.batch/1` implemented on the in-flight PR #70.

## Strategy

Do NOT chase OfficeCLI 1:1. Order of leverage:
1. Agent read/orient surface (outline, path-tagged text, structured get).
2. Validation as a command + test gate (portable structural tier; SDK tier natively).
3. Header/footer/section READ representation — **before** any serialization or mutation
   (otherwise a future write path silently drops sectPr/headers on existing files).
4. Write foundation: canonical from-scratch writer with a dedicated package model;
   Mammoth AST used ONLY as semantic content input, never as the package model.

Non-goals (recorded, revisit later): HTML render fidelity engine, screenshots/watch,
resident mode, revisions/tracked changes, SmartArt/OLE/ActiveX, template merge,
dump/replay, equations (read and write).

## CLI shape (codex-accepted)

New binary `docx2html/cmd/docx` (subcommand CLI mirroring `cmd/xlsx`; native+wasm;
CliError-to-nonzero-exit). The published `docx2html` binary stays frozen; its conversion
runner is extracted into a shared package **preserving all observable quirks** (warning
placement, output-dir behavior, error prefixes, wasm newline-stdout, exact legacy help).
Command handlers are modularized from day one (one file per command family) to minimize
cross-PR conflicts in the command tree.

Commands: `convert` (= legacy behavior), `outline`, `text`, `get`, `validate`; later
`create`, `batch`. CI gains a docx wasm runtime smoke test (currently only xlsx runs
under wasm in CI).

## Path semantics (contract, spec'd in docs before docx.element/1 ships)

Paths are **logical, snapshot-relative projection paths** over a *logical document
snapshot* — the body AST plus supported extras (footnotes/endnotes/comments today;
headers/footers/sections when PR H lands) — not literal OOXML paths and not stable
anchors. Because the reader flattens some OOXML nodes (content controls, revisions),
path *kinds* are the snapshot's semantic kinds with OOXML-like spellings; the contract
doc enumerates the complete kind table (every addressable `DocumentElement` variant →
its path segment name), deterministic header/footer enumeration (by section index, then
type: default/first/even), and how sections associate with body ranges and
header/footer sets:
- Grammar: 1-based, OOXML local names: `/body/p[3]`, `/body/tbl[1]/tr[2]/tc[1]/p[1]`.
- Indices count same-local-name direct siblings within the parent.
- Valid for one document snapshot; positional paths shift after any edit.
- Nested content always gets its full path (a table-cell paragraph is never flattened to
  `/body/p[N]`).
- Path ROOTS are reserved up front for the full document surface: `/body`, `/header[n]`,
  `/footer[n]`, `/footnotes/note[id]`, `/endnotes/note[id]`, `/comments/comment[id]` —
  body ships first; the grammar doc lists the others as reserved so `docx.element/1`
  needn't break when they arrive.
- Future batch ops resolve each path against the document state produced by the
  preceding ops in the same script (OfficeCLI-replay semantics), stated normatively in
  the batch schema doc.

## JSON schema conventions

- Emitted payloads (`docx.outline/1`, `docx.element/1`): additive-only evolution, no
  `null` ever emitted, consumers ignore unknown keys — same rules as xlsx payloads.
- Consumed payloads (`docx.batch/1`, later): STRICT validation (unknown op/key/type →
  error naming the op index), and `null` is allowed only where it has defined mutation
  meaning — mirroring `xlsx.batch/1`.
- Schema IDs are declared once per module (docx IDs in a `docx2html/inspect` package);
  docs/agent-json-schemas.md gets a docx section and stops implying all IDs live in root
  `inspect/schema.mbt`.

## Write-path architecture (codex-corrected)

- New docx2html packages: `opc` (DOCX-local content-types/relationships/part builder) and
  `write` (working name) holding a dedicated **package/resource context**: styles,
  numbering definitions (numId identity), relationships, media parts, section properties,
  generated IDs. This context — not the Mammoth AST — is the write model.
- `DocumentElement` content (paragraphs/runs/tables/…) is accepted as **semantic input**
  to build canonical documents from scratch.
- v1 contract is **fresh-document-only and fail-closed**, enforced simply: a batch
  script must either target a nonexistent file or open with a `create` op — no
  "self-authored file" recognition (that would need provenance markers or a lossless
  reload path; deferred with the preservation milestone). Mutating existing files is out
  of scope until a preservation contract exists (the reader is lossy, so
  read→mutate→write would silently drop sectPr/headers/footers/bookmark-ends/etc. — the
  CLI must refuse, not corrupt).
- Every staged writer **errors on unsupported `DocumentElement` variants** (e.g. a
  table before F2 ships) rather than silently omitting content.
- Round-trip tests (`write → read_docx → semantic equality`) prove canonical generation
  only; SDK validation is the structural gate. Preservation of existing files is a
  separate future milestone with its own tests.

## PR sequence

Command-tree PRs are serialized (A→B→C→D…); each rebases on origin/main before push.
A and B may be DEVELOPED in parallel with xlsx batch P1 (#70) but MUST rebase onto
origin/main after #70 lands, before merging (it touches ci.yml + agent-json-schemas.md).

1. **PR A — `docx` CLI skeleton + `convert`.** New `docx2html/cmd/docx`; extract shared
   conversion runner (behavior-identical; legacy cram stays green verbatim); modular
   command-handler layout; cram doc for `docx convert`; CI build target + PATH + docx
   wasm smoke step. Landing includes filing the issue that schedules removal of the CI
   Format-check `git checkout -- '**/moon.pkg'` shield once the nightly parser accepts
   pkgtype by default.
2. **PR B — `docx outline` (`docx.outline/1`).** Counts (paragraphs, tables, images,
   footnotes, endnotes, comments, hyperlinks, bookmarks), heading tree resolved from the
   reader's existing style-name resolution (Mammoth `Heading N` name convention — NO new
   style parsing in this PR; `outlineLvl`-based resolution is deferred to the H/styles
   follow-up), styles-in-use (id+name), image inventory (content type + **byte length**
   only — dimensions don't exist in the AST), reader warnings. `docx2html/inspect`
   package, snapshot tests, schema-doc section, cram agent doc.
3. **PR C — path engine, then `docx text` + `docx get` (`docx.element/1`).** Two stages
   in one PR but reviewable separately: (1) pure traversal/path assignment + parser with
   its own unit tests; (2) CLI wiring (`text` path-tagged output incl. table-cell
   paragraphs; `get <path> --json`). Path contract doc lands here.
4. **PR D — `docx validate`.** Portable MoonBit structural validation (native+wasm):
   follows the root office-document relationship (NO hardcoded xlsx-style required-part
   list; `word/_rels/document.xml.rels` and `styles.xml` are conditional), checks
   content-type coverage, rel-target resolution, malformed/duplicate names, **XML
   well-formedness of the OPC parts it touches, and that the resolved main-document
   root is present and parseable** (any narrower guarantee must be stated in the
   command's help/docs). Duplicate-name detection consumes RAW archive entries — the
   existing map-backed `open_zip` silently overwrites duplicates, so it cannot see
   them. The `docx2html/opc` package is BORN here with the read/validation primitives;
   PR E extends it with builders. **Nonzero exit on invalid** (better than xlsx
   `validate`'s print-and-exit-0; xlsx alignment filed as a follow-up issue, not
   smuggled in). SDK tier: extend `tools/openxml-validator` to open
   `WordprocessingDocument` by extension + `scripts/validate_docx.sh` + native tests
   over fixtures and embed_style_map output. If the SDK harness is split out, E depends
   on BOTH validation PRs.
5. **PR H (moved before E/F) — header/footer/section READ representation.** Parse sectPr
   + header/footer refs and parts. Source-compatible by construction: a NEW versioned
   entry point (e.g. `read_docx_package`) returning a NEW result struct (body +
   sections + header/footer stories + notes/comments); existing reader signatures and
   the `pub(all)` `DocxReadResult` stay byte-identical — explicitly not a silent enum
   extension. Section boundaries attach as: body-final `sectPr` = last section;
   paragraph-level `sectPr` = section break ending after that paragraph (each body
   range maps to exactly one section; each section names its header/footer set).
   Surface in outline (+counts) and reserved path roots; converter output unchanged.
6. **PR E — write foundation (needs D merged).** `docx2html/opc` + minimal canonical
   package writer + `docx create` (content types, rels, document.xml body+sectPr,
   styles.xml); XML-writer hardening (root attributes, xml:space, illegal-char policy)
   scoped to what the emitted parts need; SDK + structural validation tests; wasm-capable.
7. **PR F1..F4 — content serialization, one feature family per PR.**
   F1 paragraphs/runs/headings + minimal styles.xml; F2 tables; F3 lists/numbering
   (numId/abstractNum generation); F4 hyperlinks/images/media (relationships). Each PR:
   semantic round-trip tests + SDK validity matrix entries + fuzz coverage where the
   parser meets new writer output.
8. **PR G — `docx batch` (`docx.batch/1`), batch-first authoring.** Strict consumed
   schema; ops mirror the write API (add-paragraph/add-heading/add-table/add-list/…);
   **fresh-document-only** (nonexistent target or leading `create` op), fail-closed on
   any existing file with a clear error naming the preservation limitation; temp-file +
   rename atomicity; `--dry-run`. A lightweight fresh-agent **acceptance probe runs
   after C (read surface) and again against G's draft branch** — G's
   header/footer-write decision is conditioned on that probe, not on PR I (which cannot
   retroactively change G); if the probe demands more, a conditional post-G writer PR
   is added.
9. **PR I — office skill update + acceptance test.** Update
   `.claude/skills/office/reference/docx.md` + SKILL.md task table (claims must match
   shipped reality; read-skill and write-skill updates split if they land apart). Run the
   fresh-agent acceptance test and **check the harness + transcript/result into the repo**
   (e.g. `docx2html/tests/acceptance/`) so it is reproducible, not folklore. Fix findings,
   re-run.

## Quality gates (every PR)

- Finish with `moon info && moon fmt` (AGENTS.md order); then inspect
  `git diff -- '*moon.pkg'` and revert ONLY hunks that are the nightly pkgtype
  migration — never blanket `git checkout -- '**/moon.pkg'` when a PR intentionally
  edits or adds manifests (re-apply intentional edits after fmt if needed); review the
  .mbti and manifest diffs before committing.
- `moon check` native + wasm, scoped
  `moon test --target native` for touched members (full member suite before merge), cram
  via stub project (never whole-workspace exe builds), run touched skill examples fresh.
- Tests/builds write to a log file; check exit code; then grep the log (tail masks
  failures).
- **codex review per PR** (`codex exec --sandbox read-only`, default model/effort —
  never lowered), backgrounded with a long monitor; prompt via file; verdict read from
  the end of the output file (the echoed prompt false-matches grep). Multi-round loops
  expected; push back with evidence when codex is wrong.
- **CI gate:** green nightly CI on the PR is the default bar. If nightly CI is red from a
  toolchain tear provably unrelated to the diff, a stable-toolchain full local gate
  (check + test + cram, native+wasm) satisfies the user's stated "nightly OR stable" bar —
  documented in the PR with the tear reference. Stable runs are otherwise diagnostic
  evidence only.
- Merge only when codex APPROVE and the CI gate holds:
  `gh pr merge --repo moonbitlang/mbtexcel --rebase --delete-branch`. Rebase on
  origin/main first when other agents have landed work.
- Landing-the-plane (AGENTS.md, every session/PR): file issues for remaining work
  (e.g. xlsx validate exit-code alignment, zip resource-limit policy below, outlineLvl
  styles resolution), run quality gates, update issue status.

## Recorded risks / follow-up issues to file

- Wasm/agent resource limits: the zip reader materializes every entry with generous
  declared-expansion allowances — a resource-limit policy for agent reads (caps tied to
  input size) should be designed; file an issue in PR B's landing, don't scope-creep.
- `pub(all)` AST evolution policy (PR H design question above) — needs an explicit
  module-version/API migration decision in review.
- mooncakes release sequencing: docx work stays DOCX-local (no root `ooxml` changes), so
  no mbtexcel-first publish train; if that ever changes, publish mbtexcel first, bump
  docx2html's registry dep, and add a registry-isolated consumer check.
- xlsx `validate` exits 0 on invalid — align with docx behavior in a follow-up.
