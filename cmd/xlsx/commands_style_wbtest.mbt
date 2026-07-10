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

///|
test "expand_range: single-cell passthrough is verbatim, even noncanonical" {
  // A bare cell name (no colon) is not parsed or normalized — `$A$01` and
  // lowercase names reach the library call exactly as typed, as before the
  // shared parser was introduced.
  inspect(expand_range("$A$01").join(","), content="$A$01")
  inspect(expand_range("a1").join(","), content="a1")
}

///|
test "expand_range: legacy error texts are pinned exactly" {
  // The oversized-range message must stay byte-identical to the pre-parser
  // wording (agents and cram docs match on it).
  try expand_range("A1:K9091") |> ignore catch {
    CliError(message) =>
      inspect(
        message,
        content="error: range A1:K9091 covers 100001 cells; max is 100000",
      )
    _ => fail("expected a CliError")
  } noraise {
    _ => fail("expected an over-large range to raise")
  }
  // A malformed range half fails with the strict parser's message.
  try expand_range("A1:NOPE") |> ignore catch {
    err => inspect(err, content="invalid cell reference 'A1:NOPE'")
  } noraise {
    _ => fail("expected a malformed range to raise")
  }
}
