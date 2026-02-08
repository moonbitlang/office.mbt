# Architecture improvements (proposal)

This document proposes a refactor direction for `mbtexcel` that improves
maintainability and testability without losing Excelize parity.

It is intentionally staged: you can stop after any phase and still have a
cleaner architecture than today.

Companion doc: `docs/architecture.md` (describes the current as-is design).

## Status (as of 2026-01-30)

This repo has already implemented several items from the roadmap:

- [x] Phase 1: split large IO hub files inside `xlsx/`
  - `xlsx/read.mbt` helpers extracted into:
    - `xlsx/read_shared_strings.mbt`
    - `xlsx/read_styles_xfs.mbt`
    - `xlsx/read_workbook_xml.mbt`
    - `xlsx/read_worksheet_xml.mbt`
    - `xlsx/read_drawing_xml.mbt`
    - `xlsx/read_sheet_rel_parts.mbt`
  - `xlsx/write.mbt` helpers extracted into:
    - `xlsx/write_workbook_xml.mbt`
    - `xlsx/write_shared_strings.mbt`
    - `xlsx/write_worksheet_layout_xml.mbt`
    - `xlsx/write_comments_vml.mbt`
- [x] Phase 1: centralize OOXML string + `.rels` helpers
  - `xlsx/ooxml_utils.mbt`
  - `xlsx/ooxml_rels.mbt`
- [x] Phase 1: extract workbook package-part resolution from read hub
  - `xlsx/read_package_parts.mbt` now owns workbook part selection from
    `[Content_Types].xml` and fallback behavior.
  - Covered by `xlsx/read_package_parts_wbtest.mbt`.
- [x] Phase 2: extract pure libraries out of `xlsx/`
  - `crypto/` (AES + hashes)
  - `base64/` (codec; `xlsx/base64.mbt` keeps error-mapping wrappers)
- [x] Phase 3 (partial): reduce IO config coupling in write helpers
  - `Workbook::save_as` does not need to mutate `Workbook.file_path` just to
    select workbook content type during write.
- [x] Phase 1: start splitting the formula engine for navigability
  - `xlsx/formula_eval_types.mbt`, `xlsx/formula_parse.mbt`,
    `xlsx/formula_eval.mbt`, `xlsx/formula_builtins.mbt`
- [x] Phase 1: extract `Workbook`/`Worksheet` type definitions and accessors
  into dedicated files (`xlsx/workbook_types.mbt`, `xlsx/worksheet_types.mbt`)
- [x] Phase 4 (partial): add worksheet cell index cache for hot get/set paths
  - `Worksheet` now tracks an internal `cell_index` cache that is lazily built
    and invalidated on structural row/column mutations.
  - Covered by `xlsx/worksheet_cell_index_wbtest.mbt`.

## Current pain points (why refactor)

1. The `xlsx/` package is “everything”
   - It contains the core model, most feature APIs, OOXML parsing, OOXML writing,
     a formula engine, and crypto primitives.
   - Several subsystems are large and worth keeping split into focused files
     (formula engine, worksheet/workbook APIs, and OOXML IO helpers).
   - This hurts navigation, makes “small changes” risky, and increases compile
     times for unrelated edits.

2. Model and IO concerns are coupled in `Workbook`
   - `Workbook` stores `file_path`, a ZIP writer override, a charset transcoder,
     and default options alongside domain state (`xlsx/workbook.mbt`).
   - This coupling makes it harder to reason about what is “document data”
     vs “how the document was read/will be written”.

3. “OOXML string plumbing” utilities are scattered
   - There are multiple XML helpers across `xlsx/xml.mbt`, `xlsx/read.mbt`,
     `xlsx/worksheet.mbt`, and `ooxml/xml.mbt`.
   - Relationship parsing exists only as ad-hoc helpers inside the reader
     (`xlsx/read.mbt`), while the `ooxml/` package is currently write-only.

4. Cell storage is simple but not scalable
   - Cells are stored as `Array[Cell]` per worksheet and many operations scan
     linearly (e.g., `Workbook::get_cell_value` style patterns in
     `xlsx/workbook.mbt`).
   - Write-time sorting uses insertion sort (`sort_cells` in
     `xlsx/worksheet.mbt`), which is fine for small sheets but quadratic for
     large data unless stream mode is used.

5. Hybrid “typed + raw XML fragments” is useful, but not explicitly structured
   - Storing fragments (e.g., data validations / conditional formats) is a
     pragmatic choice, but it blurs boundaries unless the project makes it a
     first-class pattern (types + fragment preservation + focused rewrite tools).

## Desired target architecture (principles)

Keep these principles in mind while refactoring:

- Preserve behavior unless explicitly changing it (parity and tests are the
  project’s superpower).
- Keep lower layers acyclic and dependency-light.
- Make “lossless-ish preservation” explicit: if we store raw XML fragments, give
  them a type, a home, and tests.
- Make IO configuration explicit and separate from the workbook data model.
- Prefer small, composable units (files first, packages later).

Conceptual layers:

```
API facade (mbtexcel, xlsx public)
  |
Domain model (Workbook/Worksheet + typed feature models)
  |
Serialization (OOXML read/write, fragment rewrites)
  |
Container (zip)  +  Security (encryption)  +  Utilities (xml/base64/etc)
```

## Recommended refactor roadmap

### Phase 1: “File-level architecture” inside `xlsx/` (safe, fast wins)

Goal: keep package boundaries unchanged, but reorganize so files reflect
subsystems and utilities are centralized.

Suggested actions:

1. Split the hub files by responsibility (no public API change)
   - Split `xlsx/read.mbt` into multiple files such as:
     - `read_workbook.mbt`, `read_styles.mbt`, `read_worksheet.mbt`,
       `read_drawings.mbt`, `read_tables.mbt`, `read_pivots.mbt`, etc.
   - Split `xlsx/write.mbt` similarly:
     - `write_workbook.mbt`, `write_styles.mbt`, `write_worksheet.mbt`,
       `write_drawings.mbt`, ...
   - Split `xlsx/formula_eval.mbt` by categories:
     - tokenizer/parser, value model, core eval, function registry,
       financial functions, date/time functions, ...

2. Introduce an explicit “OOXML utils” module inside `xlsx/`
   - Create a focused file (or files) that own:
     - attribute parsing (`attr_value`-like)
     - “open tag” extraction (`tag_attributes_in`)
     - simple body extraction (`extract_tag_body_from`)
     - fragment rewrite helpers (`replace_attr_value_in_open_tag`)
   - Move existing implementations from `xlsx/xml.mbt`, `xlsx/read.mbt`, and
     `xlsx/worksheet.mbt` into that module.
   - Add tiny unit tests for edge cases (quotes, spacing, missing attrs).

3. Make relationships parsing a reusable module (still inside `xlsx/`)
   - Extract `parse_relationship_targets`, `rels_path_for`,
     `resolve_rel_target` helpers from `xlsx/read.mbt`.
   - Add tests using small inlined `.rels` strings.

4. Normalize part-name constants and path building
   - Collect frequently used part paths and relationship types into a single
     module (e.g., `part_names.mbt`).
   - Benefits: fewer typos, easier future migration to a “PartStore”.

Why Phase 1 first:

- MoonBit’s `///|` block structure makes file splitting low risk.
- This phase improves navigation and reduces cognitive load without changing
  package paths or public types.

### Phase 2: Extract “pure libraries” out of `xlsx/` into new packages (still low risk)

Goal: reduce the compile surface of `xlsx/` without touching its public API.

Selection criteria for extraction:

- No dependency on `Workbook`/`Worksheet` types (or easy to remove).
- Used by multiple subsystems (read + write + feature code).
- High LOC but logically independent.

Good candidates (based on current layout):

- Crypto + hashes
  - Implemented: moved into `crypto/` and `xlsx/encryption.mbt` imports
    `@crypto`.
- Base64
  - Implemented: moved into `base64/` with `xlsx/base64.mbt` wrappers.
- XML helpers
  - Either:
    - expand `ooxml/` into a general-purpose `ooxml_xml` helper package, or
    - create a new `xml/` package shared by both `ooxml/` and `xlsx/`.

This phase is intentionally conservative: it does not move public types like
`Workbook`, `Worksheet`, `Style`, etc.

### Phase 3: Decouple IO configuration from the domain model (medium risk, big payoff)

Goal: make `Workbook` represent “document data”, not “where it came from / how to
write it”.

Proposed direction:

- Create an internal `IoContext`/`WriteContext` record:
  - `zip_writer?`, `charset_transcoder?`, `file_format?` (xlsx/xlsm/...), and
    default `Options`.
- Update IO entrypoints to thread this context explicitly:
  - `read(bytes, options?, transcoder?)`
  - `write(workbook, options? , zip_writer? , file_format?)`
- Keep ergonomic helpers:
  - `Workbook::save_as(path, ...)` can still exist, but it should compute
    `file_format` from the path and call the context-aware writer.

Migration approach that avoids breaking callers:

- Keep existing `Workbook.file_path` and setters temporarily, but make them a
  thin convenience layer that populates a context passed into the writer.
- Mark the “stateful IO” fields as legacy in docs and migrate internal call
  sites first.

### Phase 4: Make cell storage scalable (optional, performance-focused)

If performance becomes a priority, consider one of these designs:

Option A: Keep `Array[Cell]`, add an index cache

- Maintain an internal cache:
  - `Map[Int, Map[Int, Int]]` mapping row -> col -> index in `cells`.
- Invalidate/update it on cell insert/delete.
- Benefits: keep current serialized order logic; fast lookups.

Option B: Store cells grouped by row

- `Map[Int, Array[Cell]]` with per-row sorted-by-col arrays.
- Writer becomes naturally row-ordered; iterators get cheaper.
- Some operations (insert/delete rows/cols) become simpler/safer.

Option C: Dual representation (write-optimized + lookup-optimized)

- Maintain both:
  - a lookup structure (map), and
  - a deterministic list used only for serialization.
- Rebuild the serialization list at write time.

Whichever you pick, keep the stream writer concept: it’s valuable as an ordering
and API-safety mechanism even if it doesn’t truly stream to disk.

## Making “raw OOXML fragments” a first-class pattern

The current hybrid approach is practical; it just needs structure:

- Introduce wrapper types:
  - `struct XmlFragment { xml : String }` or feature-specific wrappers like
    `DataValidationXml`, `ConditionalFormatXml`.
- Centralize fragment parsing/rewriting helpers (Phase 1).
- Document the contract:
  - which features are “typed source of truth”
  - which are “raw fragment source of truth”
  - how edits are applied (typed -> fragment, fragment rewrite, etc.)

This makes it clearer how to add new parity features without accidentally
breaking round-trip behavior.

## `ooxml/` package: expand or keep minimal?

Today `ooxml/` is primarily used by the writer (`WorkbookManifest` builds
`[Content_Types].xml` and `.rels` files), while the reader does its own parsing.

Two reasonable directions:

1. Keep `ooxml/` write-only and make `xlsx/` own read-side parsing utilities.
   - Lowest churn; still lets you refactor aggressively inside `xlsx/`.

2. Expand `ooxml/` into a shared OOXML “package layer”
   - Add parsing for:
     - `.rels` files (Relationships -> Map)
     - `[Content_Types].xml` (optional)
   - Then `xlsx/read` uses `@ooxml` for both read and write metadata logic.
   - This reduces duplication and clarifies layering, at the cost of touching
     more code at once.

If you plan to eventually implement a “PartStore” abstraction, direction (2)
usually pays off.

## Suggested first refactor PR (minimal, high leverage)

If you want a low-risk first step that improves architecture immediately:

1. Split `xlsx/read.mbt` and `xlsx/write.mbt` by subsystem (Phase 1.1).
2. Centralize XML/fragment utilities into a single `xlsx/` file (Phase 1.2),
   with small unit tests.
3. Extract crypto/hashes into a new `crypto/` package (Phase 2), keeping all
   behavior identical.

These changes are “mechanical refactors” with low behavioral risk and make later
architecture work much easier.
