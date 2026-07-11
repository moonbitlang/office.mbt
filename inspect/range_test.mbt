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
test "parse_range_unbounded accepts large ranges but keeps the grid grammar" {
  // The same range parse_range rejects (100,001 cells) is fine unbounded —
  // callers that never enumerate cells (defining a table) only need bounds.
  inspect(
    @inspect.parse_range_unbounded("A1:K9091").cell_count(),
    content=(
      #|100001
    ),
  )
  // Corner order is still irrelevant and bounds normalize.
  debug_inspect(
    @inspect.parse_range_unbounded("B3:A1"),
    content=(
      #|{ col_lo: 1, row_lo: 1, col_hi: 2, row_hi: 3 }
    ),
  )
  // In-grid strictness is unchanged: out-of-grid and malformed refs raise.
  for bad in ["A1:XFE9", "A1048577", "A", "1", "A1:", "A$1$"] {
    try ignore(@inspect.parse_range_unbounded(bad)) catch {
      _ => ()
    } noraise {
      _ => fail("parse_range_unbounded should reject '\{bad}'")
    }
  }
}

///|
test "parse_range accepts anchors, lowercase, and leading zeros" {
  debug_inspect(
    @inspect.parse_range("$A$01"),
    content=(
      #|{ col_lo: 1, row_lo: 1, col_hi: 1, row_hi: 1 }
    ),
  )
  debug_inspect(
    @inspect.parse_range("$B$2:$C$3"),
    content=(
      #|{ col_lo: 2, row_lo: 2, col_hi: 3, row_hi: 3 }
    ),
  )
  debug_inspect(
    @inspect.parse_range("xfd1048576"),
    content=(
      #|{ col_lo: 16384, row_lo: 1048576, col_hi: 16384, row_hi: 1048576 }
    ),
  )
}

///|
test "parse_range rejects malformed references" {
  for bad in ["", "A0", "1A", "A1:B", ":", "A1:", "A", "1", "A1B2", "A 1"] {
    try ignore(@inspect.parse_range(bad)) catch {
      _ => ()
    } noraise {
      _ => fail("expected '\{bad}' to be rejected")
    }
  }
}

///|
test "parse_range rejects references the tolerant parser would alias" {
  // The workbook's coordinate parser skips `$` anywhere ("A$B1" -> AB1) and
  // its column accumulator can wrap on long letter runs; the strict parser
  // must reject these instead of silently reading a different cell.
  for
    bad in [
      "A$B1", "QJYLAVITCVEBUJK1", "ZZZZ1", "XFE1", "A1048577", "A12345678", "$$A1",
      "A$$1",
    ] {
    try ignore(@inspect.parse_range(bad)) catch {
      err => {
        // Every rejection is the strict parser's own error, not an alias.
        let message = "\{err}"
        if !message.has_prefix("invalid cell reference") {
          fail("expected a MalformedRef for '\{bad}', got: \{message}")
        }
      }
    } noraise {
      _ => fail("expected '\{bad}' to be rejected")
    }
  }
  // The error names the full user input, not just the bad half.
  try ignore(@inspect.parse_range("A1:XFE9")) catch {
    err => inspect(err, content="invalid cell reference 'A1:XFE9'")
  } noraise {
    _ => fail("expected 'A1:XFE9' to be rejected")
  }
}

///|
test "parse_range accepts zero-padded rows of any width, still in-grid" {
  debug_inspect(
    @inspect.parse_range("A00000001"),
    content=(
      #|{ col_lo: 1, row_lo: 1, col_hi: 1, row_hi: 1 }
    ),
  )
  debug_inspect(
    @inspect.parse_range("A0001048576"),
    content=(
      #|{ col_lo: 1, row_lo: 1048576, col_hi: 1, row_hi: 1048576 }
    ),
  )
  // Padding does not smuggle out-of-grid rows past the bound.
  try ignore(@inspect.parse_range("A0001048577")) catch {
    err => inspect(err, content="invalid cell reference 'A0001048577'")
  } noraise {
    _ => fail("expected the padded out-of-grid row to be rejected")
  }
}
