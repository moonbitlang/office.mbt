# OfficeCLI parity handoff

Last updated: 2026-07-19 (Asia/Shanghai)

This file is the handoff for the non-PPT OfficeCLI parity effort tracked by
[#139](https://github.com/moonbitlang/office.mbt/issues/139). PowerPoint and MCP
are deliberate non-goals. There are no third-party compatibility obligations,
so future work should prefer a clean, durable contract over compatibility
aliases.

## Landing state

- [PR #172](https://github.com/moonbitlang/office.mbt/pull/172) is merged into
  `main`. It delivered the bounded unified XLSX read surface (`outline`, `get`,
  `text`, and `query`) while retaining authenticated OOXML relationship
  discovery, Markup Compatibility processing, cancellation checks, preserved
  drawing state, and fail-closed resource accounting.
- [PR #173](https://github.com/moonbitlang/office.mbt/pull/173) is merged into
  `main` and closed [#162](https://github.com/moonbitlang/office.mbt/issues/162).
  It delivered transactional XLSX creation and strict batch mutation.
- [PR #182](https://github.com/moonbitlang/office.mbt/pull/182) is merged into
  `main` and closed [#176](https://github.com/moonbitlang/office.mbt/issues/176).
  It isolated the post-#173 compatibility fix for Excel-produced overlaps
  between distinct shared-formula indexes.
- [PR #185](https://github.com/moonbitlang/office.mbt/pull/185) is merged into
  `main` and closed [#165](https://github.com/moonbitlang/office.mbt/issues/165)
  and [#75](https://github.com/moonbitlang/office.mbt/issues/75). It delivered
  cross-format `office validate` and `office issues` on the exact pre-commit
  mutation gate, with versioned bounded findings and non-zero validate exit
  status.

The reference OfficeCLI checkout remains `.repos/officecli` in the primary
repository working tree.

## What is complete after #173

The following major-parity foundations are implemented and should not be
rebuilt in later PRs:

- A1-A5: the umbrella `office` command, versioned capability/help protocol,
  canonical selectors, atomic validated transactions, and validated raw OOXML
  fallback.
- D1-D2: preservation-safe DOCX edit sessions plus bounded DOCX `outline`,
  `get`, `text`, and `query`.
- X1-X2: provenance-checked bounded XLSX reads plus bounded XLSX `outline`,
  `get`, `text`, and `query`.
- X3 (#173): `office create xlsx`, strict `xlsx.batch/1` parsing, transactional
  XLSX mutation, dry-run/no-replace/overwrite behavior, preservation reports,
  bounded serialization, and OpenXML validation.
- [#176](https://github.com/moonbitlang/office.mbt/issues/176): tolerant reads
  for Excel-produced overlaps between distinct shared-formula indexes, while
  duplicate masters and out-of-range followers remain rejected per index.

Important implementation invariants:

- File publication uses `moonbitlang/async`; no new C stubs are required.
- Sync and async paths share the same semantic implementation and resource
  policy. Async scheduling cooperation inside long parser work is intentionally
  deferred to #174 rather than being faked with entry- or sheet-level yields.
- XLSX full rewrites must preserve unsupported drawing anchors, relationships,
  and dependent parts already retained by the reader. Generated drawing object
  and relationship ids must avoid preserved ids.
- Read limits remain cumulative across a package. Relationship defaults match
  the stricter #172 parser boundaries so a workbook written by the library is
  not rejected by the default reader; callers can still select lower limits.
- Capability output is schema-driven and snapshot-tested. Never advertise a
  command or format variant before its end-to-end implementation exists.

The detailed contracts live in:

- `docs/office-major-parity.md`
- `docs/office-xlsx-read.md`
- `docs/office-xlsx-mutations.md`
- `docs/office-docx-read.md`
- `docs/office-transactions.md`
- `docs/agent-json-schemas.md`

## Remaining work, in recommended order

Each item below already has an issue. Do not duplicate it. Take one issue per
PR unless the issue itself is first split into independently useful children.

1. [#163 — D3 fresh DOCX create and batch](https://github.com/moonbitlang/office.mbt/issues/163).
   Reuse the existing DOCX writer and the X3 transaction/publication pattern;
   do not copy the XLSX engine or mix annotation mutation into this PR.
   Header/footer authoring remains separately tracked by #95.
2. [#164 — D4 DOCX annotation mutations](https://github.com/moonbitlang/office.mbt/issues/164).
   Build only on the source-pinned D1 edit session and preserve unrelated parts.
3. [#166 — P1 deterministic HTML/SVG preview](https://github.com/moonbitlang/office.mbt/issues/166).
   Static/offline output only; no browser service, watch mode, or screenshot
   dependency.
4. [#167 — R1 replayable semantic dump](https://github.com/moonbitlang/office.mbt/issues/167).
   Replay must use the canonical create/batch engines rather than a new writer.
5. [#168 — T1 XLSX/DOCX template merge](https://github.com/moonbitlang/office.mbt/issues/168).
   Keep the placeholder language strict and non-executable.
6. [#169 — F1 final non-PPT acceptance](https://github.com/moonbitlang/office.mbt/issues/169).
   Run only after the child capabilities above have landed. This is the place
   for the final fresh-agent discoverability exercise and the ultra review.

Architecture work that can proceed independently, but must stay in its own PR:

- [#174 — scheduler-cooperative Office parsing](https://github.com/moonbitlang/office.mbt/issues/174).
  Implement pure-MoonBit fuel-bounded resumable machines with sync and async
  drivers. Use public `moonbitlang/async` APIs, no C stubs, native threads,
  private runtime imports, or duplicated parsers. Scheduling fuel is separate
  from security budgets.

Other existing component issues (#74, #76, #94, #95, and #155) remain open and
must not be silently folded into an Office parity PR. Publication in #155 needs
separate authorization.

## Small-PR rule

Do not repeat the size of #172 or #173. A PR should have one root cause or one
user-visible capability, one independently testable acceptance boundary, and a
clear revert story.

- Do not stack a new capability on an unmerged feature branch.
- Separate reusable foundation, CLI exposure, and unrelated compatibility
  fixes when each can land and be useful independently.
- As a review trigger, stop and split when a PR approaches roughly 1,000
  hand-written changed lines or touches more than about 15 production files.
  Generated interfaces/snapshots are excluded, but they do not justify mixing
  scopes.
- If a review discovers a non-blocking issue outside the stated acceptance
  criteria, file an issue and fix it in a new small PR. Do not let it expand the
  current PR.
- Commit logical, buildable steps regularly. Avoid one final catch-all commit.

## Required review and landing protocol

For every PR:

1. Rebase on current `origin/main`; do not review a stale stacked base.
2. Run `moon info && moon fmt`, inspect all `.mbti` changes, then run
   `moon check` and the focused tests.
3. Run the relevant native, Wasm, and JS gates. For Office CLI changes, build
   the native CLI and run `moon cram test office/cmd/office/cram` from the same
   stub setup used by CI. Mutation work also needs Microsoft
   `DocumentFormat.OpenXml` validation with .NET 8.
   Pin all validation runs to one exact commit. To reduce wall time, use a
   separate detached worktree (or at least a separate `--target-dir`) for each
   target so native, Wasm, and JS can run concurrently without contending on
   `.moon-lock`; do not edit the source while those runs are active.
4. Ask a brand-new, ephemeral Codex CLI session to review the exact pushed
   head. Use at least `xhigh`; use `max` routinely for cross-package changes
   and `ultra` for security architecture or final epic acceptance. Never reuse
   the implementation session as the approving reviewer.
5. If the reviewer changes the code, commit the fix and run a new fresh review
   over the changed exact head (or a clearly bounded delta ending at it).
6. Merge only when exact-head CI and the fresh review are both green. Update or
   close the corresponding issue immediately after landing.

CI-equivalent local commands are documented in `.github/workflows/ci.yml`. The
complete matrix currently includes:

```text
moon info
moon fmt
moon check
moon check --target wasm
moon check --target js
moon test --target wasm
moon test --target js
moon test --target native
```

The workspace currently resolves `moonbitlang/async@0.20.2`. An async upgrade
is allowed when it has a concrete benefit, but it must be an isolated dependency
PR with native/Wasm scheduler and filesystem tests; do not combine it with a
feature PR.

## Deliberate deferrals

- PowerPoint/PPTX.
- MCP, resident mode, and live watch/selection.
- Plugin and language-SDK wrappers.
- Pixel-perfect DOCX pagination, tracked-change authoring, OLE, diagrams, and
  other low-frequency long-tail Office features.
- Backwards-compatibility aliases for unreleased APIs.

Keep `docs/office-major-parity.md`, issue #139, and this handoff synchronized as
work lands. The final acceptance issue #169, not an informal percentage, is the
authority for declaring the non-PPT parity effort complete.
