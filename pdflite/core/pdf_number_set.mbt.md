# pdflite/core number sets

`PdfNumberSet` is a small mutable helper for tracking object numbers during
reconstruction, page cleanup, and xref processing. It lives in `core` because it
is a foundation data structure with no dependency on document or feature code.

```mermaid
flowchart LR
  Input[object numbers] --> Set[PdfNumberSet]
  Candidate[new number] --> Check[contains]
  Check --> Push[pdf_push_unique_number]
  Push --> Output[deduplicated array]
```

## Checked Examples

```moonbit check
///|
test "number set pushes only unseen values" {
  let seen = @core.pdf_number_set([2, 4])
  let output : Array[Int] = []
  @core.pdf_push_unique_number(output, seen, 2)
  @core.pdf_push_unique_number(output, seen, 5)
  @core.pdf_push_unique_number(output, seen, 5)
  if output != [5] {
    fail("expected only the first unseen number to be pushed")
  }
  inspect(seen.contains(4), content="true")
  inspect(seen.contains(5), content="true")
}
```

## Package Notes

- `PdfNumberSet::add` mutates the backing hash map.
- `pdf_push_unique_number` updates the set and appends only first-seen numbers.
- The package intentionally has no dependency on the public document model.

## Pedantic Boundaries

- This is a low-level foundation helper for algorithms that need object-number
  de-duplication.
- It owns set membership, not ordering policy. Ordering is determined by the
  caller's traversal and the output array passed to `pdf_push_unique_number`.
- Mutability is intentional: `PdfNumberSet` is a stateful visited-number set,
  not a persistent data structure.
- Do not add PDF document, page, or parser dependencies here; that would turn a
  utility package into a cycle risk.

## Verification Notes

- README examples are blackbox tests for the core package API.
- Tests should cover duplicate suppression and mutation of the visited set.
- Run `moon test core/pdf_number_set.mbt.md` after editing this file.
- Run `moon info` before review; this README should not change
  `core/pkg.generated.mbti`.
