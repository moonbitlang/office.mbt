// Boundary and normalization tests for the shared bounded range parser.

///|
test "parse_range normalizes corner order" {
  debug_inspect(
    @inspect.parse_range("B3:A1"),
    content=(
      #|{ col_lo: 1, row_lo: 1, col_hi: 2, row_hi: 3 }
    ),
  )
  debug_inspect(
    @inspect.parse_range("A1"),
    content=(
      #|{ col_lo: 1, row_lo: 1, col_hi: 1, row_hi: 1 }
    ),
  )
}

///|
test "parse_range cell list and normalized ref" {
  let range = @inspect.parse_range("B2:C3")
  inspect(
    range.cells().join(","),
    content=(
      #|B2,C2,B3,C3
    ),
  )
  inspect(
    range.range_ref(),
    content=(
      #|B2:C3
    ),
  )
  inspect(
    @inspect.parse_range("D4").range_ref(),
    content=(
      #|D4
    ),
  )
}

///|
test "parse_range allows exactly the cap and rejects one past it" {
  // 10 cols x 10,000 rows = exactly 100,000 cells.
  inspect(
    @inspect.parse_range("A1:J10000").cell_count(),
    content=(
      #|100000
    ),
  )
  // 11 cols x 9,091 rows = 100,001 cells: one over the cap.
  try ignore(@inspect.parse_range("A1:K9091")) catch {
    err =>
      inspect(
        err,
        content=(
          #|range A1:K9091 covers 100001 cells; max is 100000
        ),
      )
  } noraise {
    _ => fail("expected the range cap to reject 100001 cells")
  }
}

///|
test "parse_range rejects malformed references" {
  for bad in ["", "A0", "1A", "A1:B", ":", "A1:"] {
    try ignore(@inspect.parse_range(bad)) catch {
      _ => ()
    } noraise {
      _ => fail("expected '\{bad}' to be rejected")
    }
  }
}
