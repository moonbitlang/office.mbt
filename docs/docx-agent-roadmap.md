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

Our repo at the **pre-PR-A baseline** (origin/main before this roadmap's first PR — PR A
itself adds the `docx` binary, the shared runner, and the docx wasm smoke): `docx2html`
(9,805 production .mbt lines excluding tests at that baseline) —
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

---

# Phase 2 — annotations (comments, footnotes, endnotes): steps J–M (v6; plan-review rounds 1–5 incorporated)

Motivated by the OfficeCLI gap check (2026-07-11). Standing directive: close
the full gap, then exceed it. Out of scope this phase (issues at J1's
landing): tracked changes; destructive comment delete; modern-comment
sidecars beyond commentsExtended. Per-step protocol unchanged; schema docs
land WITH each feature PR.

## Locked design decisions

- **No public AST changes.** `Comment`/`DocxPackageResult` are `pub(all)` —
  MoonBit-source-breaking to extend. New data lives in a new **opaque**
  public type: `pub struct AnnotationIndex` (priv fields, accessor
  methods), built in `docx2html/docx` and returned by a NEW entry point
  `read_docx_annotated(BytesView) -> DocxAnnotatedResult` (opaque;
  `result()` + `annotations()` accessors). `.mbti` change purely additive.
- **Package layout (cycle-free).** The path grammar and projection-path
  types currently live PRIVATE in `inspect`; `docx` cannot import
  `inspect` (which imports `docx`'s consumers). J1 therefore EXTRACTS the
  grammar into a new shared leaf package `docx2html/paths` (types +
  parse/render; no reader knowledge); `inspect` and `docx` both import
  it: paths ← docx ← inspect, one direction. Conformance tests pin that
  `inspect`'s behavior is unchanged by the extraction (pure move PR
  section, reviewed as such).
- **Source spans come from a raw-byte story scanner.** The XML tree
  retains no offsets, so J1 includes a dedicated scanner over each story
  part's ORIGINAL bytes (namespace-aware start/end/empty-element
  tokenizer) that assigns byte spans to projection nodes and locates
  annotation markers. This scanner is deliberately the SAME foundation
  L0's splicer builds on — J1 proves it read-only; L0 adds mutation.
- **commentsExtended keys on the LAST comment paragraph.** CT_CommentEx
  defines `paraId` AND `paraIdParent` as the `w14:paraId` of the comment
  body's **last** paragraph (Microsoft CT_CommentEx docs). OfficeCLI keys
  on the FIRST paragraph — a divergence we deliberately do not copy; a
  multi-paragraph parent/reply fixture with distinct first/last paraIds
  pins the difference in J1, K2, and L2.
- **Anchor placement: read everything legal, write one canonical shape.**
  The schema permits `commentRangeStart`/`End` under body, tbl, tr, tc,
  hyperlink, and more — the READ side (J1) must scan every legal
  placement. The WRITE side emits only the canonical intra-paragraph
  shape: `pPr?`, rangeStart, content, rangeEnd, reference-run (reference
  is RUN content), start in the first paragraph / end + reference in the
  last for multi-paragraph ranges. Word ignores range markers in headers,
  footers, text boxes, and notes — `annotate` REJECTS anchors in those
  stories rather than authoring inert comments.
- **`docx.batch/2`** for annotation authoring: new binaries accept `/1`
  (unchanged, closed) and `/2` (superset). The consumed-schema evolution
  rule — new majors widen the accepted set; producers pick the lowest
  major they need — is documented in the schema doc.
- **Selector enum** (Ordinal | ById) in the path grammar. Ids match the
  literal AST string (`0` valid); no match → not-found; duplicate ids →
  "ambiguous" error naming ordinal alternatives; emitted paths use the id
  form only when unique, else ordinal + diagnostic.
- **Timestamps are lexical**: `w:date` optional both directions; scripts
  provide ISO-8601 emitted verbatim (no local-time conversion).
- **Comment/note bodies are plain-content in this phase**: paragraph
  specs restricted to text runs + formatting flags — NO hyperlinks,
  images, or nested notes (they would need part-local relationship/media
  contexts: comments.xml.rels etc.). Fail closed with a "not supported in
  annotation bodies" error; lifting this is a later phase.
- **Orphan policy: surface, don't skip.** Definitions without anchors are
  exposed (no `anchored_to`) + WARN; dangling markers/references exposed
  as position-only entries + WARN — EXCEPT anchorless replies, which are
  normal (they live through their parent's thread) and get no warning.

## J1 — annotation index + reader fixes (library PR, no CLI change)

- **Position model** (the load-bearing definition): a position is
  `(story, projection_path, boundary)` — the story id (body, header[n],
  footer[n], footnotes, endnotes, comments), the logical path of the
  nearest PROJECTION node (the flattened-AST element paths the CLI
  already emits), and `boundary ∈ {before, inside_start, inside_end,
  after}` relative to that node. During traversal each projection node
  also records its raw source span (byte offsets in the story part) —
  unused by J2 but the exact input L0/L1 need for path→byte-span
  resolution. Positions in different stories are incomparable;
  same-story validation is structural.
- **Index model** (cardinality-honest): `definitions:
  Array[CommentDefinition]` in comments.xml order — each with the literal
  id string, author/initials/date?, body paragraph handles, LAST-paragraph
  `w14:paraId?`, and w15 `done?`/`paraIdParent?`; plus per-id marker
  arrays `starts/ends/references: Array[Position]` keyed by the literal
  id (duplicates representable). Multiple definitions sharing an id: all
  exposed ordinally; id-addressing them is the "ambiguous" error. Notes:
  each definition with `references: Array[Position]` (multi-reference
  representable).
- **Anchor construction (total algorithm)**: per comment id, per story,
  walk the story in document order keeping a FIFO of unmatched starts:
  a start is enqueued; an end pairs with the OLDEST unmatched start; an
  end with no unmatched start is a DANGLING end (diagnostic +
  position-only exposure), and starts still unmatched at story end are
  DANGLING starts. Each pair forms a range anchor. Every reference then
  attaches to the FIRST (in anchor order) paired range whose [start, end]
  span contains it, or — implementation-discovered refinement (J1): when
  no range contains it, to the nearest same-id range whose END precedes
  it in the same story, because Word's canonical emission places the
  reference run immediately AFTER commentRangeEnd — an anchor carries
  `references: Array[path]` (0..n;
  in document order), so multiple references on one range are
  representable; a reference inside no range forms its own POINT anchor
  (references = exactly that one path, no start/end). Anchor total order:
  story rank first (body, header[1..], footer[1..], footnotes, endnotes,
  comments — the order `text` emits), then start-else-first-reference
  document position within the story; `anchored_to` = the first anchor in
  this order. `anchors: Array[{start?, end?, references}]` — cardinality
  never collapsed. Pins:
  multi-range one id, extra references (outside + inside ranges),
  inverted `end,start` sequences, cross-story anchors for one id.
- **Interval semantics**: a projection element is covered by comment id C
  iff its span INTERSECTS any of C's paired [start, end] anchors
  (intersection, not containment — agents asking "what does this comment
  touch" want every affected element; documented in the schema doc).
  Point anchors cover the reference's paragraph.
- **commentsExtended duplicates**: multiple commentEx records for one
  paraId → FIRST wins + WARN diagnostic (deterministic; pinned).
- Reader fix: exclude `continuationNotice` plumbing notes (currently
  leaks as a user note).
- Deliberate J1 limit (found in review round 3): IMAGE nodes are not
  projected by the scanner — the reader emits zero..many Images per
  drawing (blip resolution needs the relationship graph) and wraps them
  in Hyperlink for a:hlinkClick, so faithful mirroring is L0-scope work.
  Pinned consequences: image-path coverage queries return empty; markers
  inside drawings resolve to their run; image byte spans arrive with L0.
- Pins, split into two fixture classes:
  **Conformance (SDK-green, validated before commit)**: point comments;
  multi-paragraph ranges; markers under tbl/tr/tc and body; table-cell
  anchors; legacy no-date/no-commentsExtended files; multi-reference
  notes; first≠last paraId reply fixture.
  **Tolerant-reader negatives (deliberately invalid — the SDK gate
  asserts the EXPECTED diagnostics, not green)**: duplicate ids,
  non-numeric ids (invalid per the OOXML datatype), orphan definitions,
  dangling markers/references, duplicate commentEx records.

## J2 — read surface: `/comments`, `/footnotes`, `/endnotes` addressable

- Selector enum lands here (grammar locked: `[@id=` + a non-empty token
  of characters excluding `]` and `=`, matched LITERALLY against the AST
  id string; no escaping — an id containing `]` is unaddressable by id
  and gets ordinal paths + a diagnostic). `docx.element/1` additive kinds
  `comment|footnote|endnote`: `id`, `author`, `initials`, `date?`,
  `done?`, `parent_id?`, and `anchors:
  [{start?, end?, references: […]}, …]` (full cardinality; paths as
  values),
  plus convenience `anchored_to?` = the first anchor's start-else-
  reference path. Notes carry `references: [path, …]` (multi-reference
  preserved). `outline`: `comments` inventory; `text`: annotation
  paragraphs after headers/footers. Reverse link: covered body elements
  gain `comment_ids` (intersection semantics). Dangling markers and
  references surface as position-only inventory entries.
- Cram + snapshots + schema-doc section in this PR.

## K1 — write: comments in `docx.batch/2`

- `{"op": "comment", "params": {"on": <op index> | {"from": i, "to": j},
  "text"|"paragraphs" (plain-content), "author", "initials"?, "date"?}}`;
  `on` endpoints must be earlier PARAGRAPH-producing ops (tables
  rejected). Canonical anchor emission per the locked shape. Emits
  word/comments.xml wired as a relationship of the MAIN DOCUMENT PART
  (annotation parts always hang off the main part, never the anchor's
  story part). Dense id allocation. Fail-closed matrix: empty body, bad
  indexes, forward/self/comment-target references, table targets,
  invalid date, rel-bearing body content.
- Index-level round-trip pins (writer ranges reproduce through J1's
  index); dual validation; SDK gate; docx.batch/2 schema-doc section.

## K2 — write: threading + resolution (w15)

- `"reply_to": <comment op index>` is MUTUALLY EXCLUSIVE with `on` (a
  reply's anchor is its parent's, logically — per the locked anchorless-
  reply policy a reply emits its definition + commentsExtended linkage
  and NO range/reference markers of its own). `reply_to` must reference
  an EARLIER `comment` op; chains allowed; `"done": true` valid on any
  comment op. commentsExtended
  keyed by the LAST body paragraph's 8-hex `w14:paraId` (see locked
  decision — deliberate OfficeCLI divergence); `w15:paraIdParent` = the
  PARENT's last-paragraph paraId; paraIds stamped only on comment body
  paragraphs; w14/w15 + mc:Ignorable declared; collision-free
  allocation. Tests: reply chains; resolve-without-reply; multi-paragraph
  parent fixture; missing/dangling/duplicate commentEx on read-back; SDK
  gate.

## K3 — write: footnotes/endnotes in `docx.batch/2` (after K2 — both
touch the batch parser/writer context; serialized)

- Run-spec inline keys `{"footnote": {...}}` / `{"endnote": {...}}`
  (plain-content bodies). Emits footnotes.xml/endnotes.xml as MAIN-part
  relationships with separator + continuationSeparator plumbing notes;
  per note: the in-note `footnoteRef`/`endnoteRef` mark run AND the body
  reference run. Positive note-id allocation excluding plumbing ids.
  Fail closed: notes in comments, nested notes. M's acceptance/wasm
  gates cover notes as well as comments.

## L0 — preservation spike (gate for L1; starts after J1+K1, parallel to K2/K3)

The XML layer is canonicalizing — write(parse(x)) ≠ x — so surgery uses
**byte-span splicing**: locate insertion points via J1's source spans,
splice well-formed fragments, keep original bytes elsewhere.

- **Go/no-go acceptance criteria (all must pass before L1 starts)**:
  namespace-URI-aware element matching (alternate prefixes for w:/w14:/
  w15:); self-closing paragraph/run forms; declared-encoding handling
  (UTF-8/UTF-16 or explicit fail-closed rejection of others); fragment
  namespace correctness in context; duplicate-zip-entry rejection; ZERO
  output file on every failure path.
- Fidelity pins: byte-equality outside declared edit spans for mutated
  parts; uncompressed-payload equality for untouched entries (raw member
  identity impossible — the reader discards compression metadata;
  documented). **Mutated-part matrix (the oracle: any part not in the
  operation's row must be byte-identical)**:
  | operation | main story part | main .rels | [Content_Types].xml | comments.xml | commentsExtended.xml |
  |---|---|---|---|---|---|
  | add | always (anchor markers) | only if comments.xml is created | only if a part is created | always | never |
  | reply | never | only if commentsExtended.xml is created | only if a part is created | always (reply definition; + parent paraId retrofit when needed) | always |
  | resolve/unresolve | never | only if commentsExtended.xml is created | only if a part is created | only for paraId retrofit | always |
  Sidecars detected by RELATIONSHIP TYPE/content type (not filename);
  presence → mutating commands fail closed. Follow the officeDocument
  relationship; never hardcode word/document.xml.

### L0 verdict (2026-07-11): **GO**

The spike shipped as `docx2html/splice` (SpanEdit/SplicePlan/splice_docx)
plus scanner insertion offsets (`NodeSpan` via `body_paragraph_span` /
`body_run_span`: content_start past a leading pPr/rPr, close_tag_start,
self_closing) and
the proof — a comment spliced into an existing document passes the
Microsoft SDK, reads back through the index anchored at the right
paths with zero warnings, and holds the fidelity oracle (mutated parts
byte-identical outside declared spans; exactly the matrix row changed;
untouched parts payload-identical). Criteria disposition:

- namespace-URI-aware matching: GO — offsets come from the J1 scanner
  (URI-aware by construction; alternate-prefix pin). **Fragments must
  be namespace-SELF-CONTAINED** (every spliced element declares the
  bindings for its own prefixes): correctness cannot depend on what
  the document happened to bind — pinned against a hostile document
  that binds `w:` to a FOREIGN URI, where the self-declaration locally
  shadows it. This is the locked fragment rule for L1/L2.
- self-closing forms: GO for BOTH paragraphs and runs — spans flag
  `self_closing` (`body_paragraph_span` / `body_run_span`, with
  content_start past a leading pPr/rPr), and the open-form rewrite is
  a span edit of the node's own extent (pinned end to end for `<w:p/>`
  and for an alternate-prefix `<x:r/>`).
- encoding: UTF-8 (BOM or not) spliced; **UTF-16 and every other
  declared encoding fail closed** — offsets index UTF-8 bytes and the
  J1 scanner is UTF-8-only, so this is the consistent reading of the
  criterion; recorded as the locked decision. MALFORMED XML
  declarations (unquoted/unterminated encoding values) also fail
  closed — the well-formedness belt skips declarations, so the gate
  is the only defense.
- deterministic edit ordering: equal-offset insertions apply in PLAN
  order ((start, consuming-vs-insertion, plan ordinal) key) — pinned
  on an empty open paragraph where content_start == close_tag_start.
- fragment namespace correctness: the splice layer's well-formedness
  belt (re-parse of every edited part) catches structural breakage;
  namespace WISDOM stays the fragment author's contract, gated by the
  dual validators downstream.
- duplicate-zip-entry rejection: GO (pinned).
- zero output on failure: GO — `splice_docx` is pure and all-or-nothing
  (fail-closed matrix pinned); atomic publication stays the CLI's
  contract, identical to batch.

Raw member identity is impossible (the zip layer recompresses); the
guarantee is uncompressed-payload equality plus preserved entry order,
names, and compression method — documented in the module header.

## L1 — `docx annotate add` (existing documents)

- Contract, two branch-exclusive forms:
  `docx annotate add <in> <out> --at <path> [--to <path>] --text <t>
  --author <a> [--initials i] [--date iso]`
  or
  `docx annotate add <in> <out> --at <path> [--to <path>] --json <file>`
  (the JSON envelope owns all metadata; metadata flags rejected).
  Admissible anchors: BODY-story paragraph paths only (ordinal or
  table-cell paragraph paths); `--to` must be same-story, not before
  `--at`. `--json <file>` names a FILE (never inline JSON) holding the
  strict `docx.annotate/1` envelope:
  `{"schema": "docx.annotate/1", "comment": {"author", "initials"?,
  "date"?, "paragraphs": [<plain-content paragraph specs, the same
  grammar as docx.batch/2 comment bodies>]}}` — validated with the full
  batch discipline (raw-text scanner: duplicate keys and integer lexemes
  rejected; unknown keys/enums addressed errors). **Metadata ownership is
  branch-exclusive**: with `--text`, the CLI flags own metadata
  (`--author` required, `--initials`/`--date` optional); with `--json`,
  the envelope owns ALL metadata and the `--author`/`--initials`/`--date`
  flags are REJECTED if present (no precedence, no merging). `--text` and
  `--json` are mutually exclusive; exactly one is required. The same rule
  applies verbatim to L2's reply. Publication: the
  batch contract verbatim — output must not exist, unique CreateNew
  temp, no-replace rename, in==out rejected structurally (not string
  comparison). Id allocation scans definitions AND all markers across
  every story; unrepairable pre-existing ids → fail closed, zero output.
  Both validation tiers + L0 fidelity pins on every mutation.

## L2 — `docx annotate reply|resolve` (after L1 AND K2)

- Reply, the same two branch-exclusive forms:
  `docx annotate reply <in> <out> --comment <selector> --text <t>
  --author <a> [--initials i] [--date iso]` or
  `docx annotate reply <in> <out> --comment <selector> --json <file>`.
  A reply inherits the parent's anchor (no --at accepted); emits the
  reply definition + commentsExtended linkage per K2's last-paragraph
  rule.
  `docx annotate resolve|unresolve <in> <out> --comment <selector>`:
  flips w15 done, creating the part if absent.
- **paraId retrofit** (existing documents predate w14): if the parent's
  last body paragraph lacks `w14:paraId`, allocate a fresh 8-hex id
  (collision scope: every paraId in comments.xml AND all document
  stories) and splice the attribute into comments.xml via the byte-span
  layer, declaring w14 + mc:Ignorable on its root if absent —
  comments.xml joins the mutated-part set with the same fidelity pins. A
  parent commentEx entry is created when missing (done=false). Fail
  closed (zero output): parent has no paragraph, duplicate paraIds, or
  ambiguous/duplicate commentEx entries for the parent.
- Same publication/fidelity gates as L1.

## L3 — delete: DEFERRED (issue with the graph contract: marker fan-out
across all stories, definition/commentEx/sidecar consistency, reply
cascade-vs-promote).

## M — skill, recipes, acceptance

- Skill/reference + review-workflow recipe (read → reply → resolve on an
  existing document). Acceptance protocol extended (author commented doc
  from docs alone via /2; annotate an existing fixture; read back
  threading incl. notes); run.sh extended; fresh-agent probe re-run
  against the draft branch before M merges. CI wasm smoke: comment ops,
  notes, annotate.

## Ordering (dependency-honest)

J1 → J2 → K1 → K2 → K3; L0 after {J1, K1}; L1 after L0;
L2 after {L1, K2}; M after {J2, K1, L1} minimum (full M after everything
except deferred L3). Highest agent value first: J1/J2, K1, L1, then
K2/L2 threading, then K3.

---

# Beyond Phase 2 — full-gap outlook (vision, not yet a reviewed plan)

Standing directive (2026-07-11): aim high — close the FULL OfficeCLI gap on
the agent-relevant Word surface, phase by phase, under the same protocol.
Each phase gets its own reviewed plan before work starts; this section only
fixes the order and the strategic bets.

- **Phase 3 — targeted edits of existing documents.** The L0 byte-span
  layer generalizes past annotations: set/replace text in an addressed run
  or paragraph, insert/delete paragraphs at a path, find/replace with
  hit-listing (`docx edit`, `docx replace --dry-run` listing matches as
  paths). This is OfficeCLI's core `set`/find-replace surface, rebuilt on
  preservation-safe splicing instead of a DOM. Success criterion: an agent
  can fix a typo in a real-world document without disturbing one byte it
  didn't touch.
- **Phase 4 — styles, sections, headers/footers write** (issue #95 folds
  in here): style definitions beyond the fixed Normal/Heading set,
  section properties, header/footer authoring — batch ops for fresh
  documents and surgery for existing ones.
- **Phase 5 — tracked changes.** Read first (revisions surfaced in
  outline/get with author/date/type; accept/reject preview), write later
  (attributed insertions/deletions). OfficeCLI's 1.6k-line revision
  surface is the map; its bug history is the minefield chart. Hardest and
  last.
- **Continuous**: every phase extends the acceptance probe and the skill;
  the fresh-agent test remains the definition of "agent-friendly"; parity
  claims are only made for surfaces the probe has passed.

- **Beyond parity — be BETTER (standing goal once the gap closes).**
  Directions where OfficeCLI structurally cannot follow, to be planned as
  their own phases:
  - **Semantic document diff**: `docx diff a.docx b.docx --json` — changed
    elements as addressed paths with before/after payloads. Agents verify
    edits by diffing, not re-reading; nothing comparable exists in
    OfficeCLI.
  - **Script extraction (decompile)**: `docx script <file>` emitting the
    `docx.batch/N` script that reproduces a document's supported surface —
    making authoring round-trippable and "edit by regenerate" a real
    workflow, with the unsupported remainder listed explicitly.
  - **docx → PDF inside the sandbox**: the office-toolkit monorepo already
    has pdflite; a docx2html→pdflite pipeline gives sandboxed PDF export —
    OfficeCLI has no PDF path without external dependencies.
  - **Hostile-file hardening as a product**: finish the resource-limit
    policy (issue #76) and publish the sandbox + limits contract; "safe to
    open anything" is a capability, not a footnote.
  - **Validation as a first-class surface**: we already ship a portable
    validator OfficeCLI lacks; extend findings with addressed paths so
    agents can repair broken files, not just detect them.

Non-goals remain non-goals until a phase promotes them deliberately:
PowerPoint, mermaid/diagram rendering, template merge, HTML preview
fidelity beyond the existing converter.
