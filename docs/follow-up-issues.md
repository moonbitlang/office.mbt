# Follow-up issues

These are non-blocking follow-ups discovered while investigating slow tests.

1. **Optimize ISO protection hashing**
   - Motivation: workbook/sheet protection tests are slow because `spinCount=100000` is intentionally expensive.
   - Potential improvement: avoid per-iteration buffer concatenation in `gen_iso_password_hash` by implementing incremental/streaming hashing (similar to `excelize/crypt.go`’s `hashing` function with `hash.Hash.Write`).

2. **Keep dynamic-array spill shape inference in sync**
   - The spill shape inference now short-circuits scalar functions and only computes shapes for functions that may spill.
   - If new array-returning functions are added later, the spill allowlist should be updated (tests should catch this, but it’s easy to miss in reviews).

3. **Combo chart long-tail parity**
   - Current combo chart support focuses on common CatAx/ValAx combos (e.g. column + line) with optional secondary Y axis.
   - Follow-ups: improve secondary-axis OOXML fidelity (delete/crosses/crossBetween) and expand edge-case coverage as needed.

4. **Semantic parity runner**
   - True “Excelize behavior parity” needs comparing outputs against a runnable Go Excelize (or porting more of Excelize’s Go test assertions 1:1).
   - This environment currently has no `go` toolchain, so the workflow is: build an API-by-API mapping report and iterate tests/behavior one-by-one.

## Architecture refactor backlog

These are follow-ups discovered while reviewing the current package architecture
(see `docs/architecture.md` and `docs/architecture-improvements.md`).

1. **Split `xlsx/read.mbt` and `xlsx/write.mbt` by subsystem**
   - Goal: smaller files with clearer ownership boundaries (workbook/styles/worksheet/drawings/etc).
   - Guardrail: no public API changes; `moon test` must remain green.

2. **Centralize OOXML string/fragment utilities**
   - Move scattered helpers (`attr_value`, `tag_attributes_in`, fragment attribute rewrite, etc.) into a single focused module and add unit tests.

3. **Extract relationships parsing/target resolution into a reusable module**
   - Reduce duplication and make read-side `.rels` parsing independently testable.

4. **Extract crypto/hash implementations from `xlsx/` into a dedicated package**
   - Reduce `xlsx/` compile surface; keep behavior identical.

5. **Decouple IO configuration from `Workbook`**
   - Move `file_path`, `zip_writer`, and `charset_transcoder` toward an explicit IO context passed into read/write paths (keep compat shims during migration).

6. **Introduce a scalable worksheet cell store (if performance becomes a priority)**
   - Options: index cache, row-grouped storage, or dual representation; maintain deterministic write output and stream-writer semantics.

7. **Decide whether `ooxml/` should become a shared read/write “package layer”**
   - Either keep it write-only, or add parsing for `.rels` / content types and consume it from `xlsx/read`.
