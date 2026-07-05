// Tests for the range-expansion helper used by the `style` command.

///|
test "expand_range: a single cell is just itself" {
  inspect(expand_range("A1").join(","), content="A1")
  inspect(expand_range("C7").join(","), content="C7")
}

///|
test "expand_range: an A1:B2 range expands row-major" {
  inspect(expand_range("A1:B2").join(","), content="A1,B1,A2,B2")
  inspect(expand_range("A1:C1").join(","), content="A1,B1,C1")
}

///|
test "expand_range: reversed endpoints normalize" {
  inspect(expand_range("B2:A1").join(","), content="A1,B1,A2,B2")
}

///|
test "expand_range: rejects an over-large range" {
  try expand_range("A1:Z100000") |> ignore catch {
    CliError(message) =>
      inspect(message.has_prefix("error: range"), content="true")
    _ => fail("expected a CliError")
  } noraise {
    _ => fail("expected an over-large range to raise")
  }
  // The maximum XLSX range: its cell count (~1.7e10) would overflow 32-bit
  // Int and wrap past the cap, so this must be rejected via the Int64 count.
  try expand_range("A1:XFD1048576") |> ignore catch {
    CliError(_) => ()
    _ => fail("expected a CliError")
  } noraise {
    _ => fail("expected the maximum range to raise, not overflow")
  }
}
