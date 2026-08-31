// F0 witnesses: the lexical rPr engine's edits are minimal, spelled at
// schema positions, byte-preserving outside their spans — and the
// oracle shares the planner's reading, so agreement is structural.

///|
/// Apply a plan's slice-relative edits to a run slice, right-to-left.
fn apply_format_plan(
  source : String,
  plan : @docx.RunFormatPlan,
) -> String raise {
  let bytes = @utf8.encode(source)
  let mut result = source
  let edits = plan.edits()
  let mut index = edits.length() - 1
  while index >= 0 {
    let edit = edits[index]
    // Slice offsets are byte offsets; the fixtures are pure ASCII so
    // byte and char offsets coincide — asserted here so a non-ASCII
    // fixture cannot silently lie.
    assert_eq(bytes.length(), source.length())
    result = result.substring(start=0, end=edit.start()).to_string() +
      edit.replacement() +
      result.substring(start=edit.end(), end=result.length()).to_string()
    index -= 1
  }
  result
}

///|
fn plan_for(
  source : String,
  bold? : Bool,
  italic? : Bool,
  underline? : Bool,
  color? : String,
) -> @docx.RunFormatPlan raise {
  @docx.plan_run_format(
    @utf8.encode(source)[:],
    prefix="w",
    format=@docx.docx_direct_format(bold?, italic?, underline?, color?),
  )
}

///|
fn format_result(
  source : String,
  bold? : Bool,
  italic? : Bool,
  underline? : Bool,
  color? : String,
) -> String raise {
  apply_format_plan(
    source,
    plan_for(source, bold?, italic?, underline?, color?),
  )
}

///|
/// A run with no rPr gains a complete one as its first child, in
/// schema order (b, bCs, i, iCs, color, u).
test "format inserts a fresh rPr in schema order" {
  inspect(
    format_result(
      "<w:r><w:t>x</w:t></w:r>",
      bold=true,
      italic=true,
      underline=true,
      color="c00000",
    ),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs/><w:i/><w:iCs/><w:color w:val="C00000"/><w:u w:val="single"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
  // Explicit off is stated, never omitted.
  inspect(
    format_result("<w:r><w:t>x</w:t></w:r>", bold=false),
    content=(
      #|<w:r><w:rPr><w:b w:val="0"/><w:bCs w:val="0"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// A self-closing run expands with the synthesized rPr as its content.
test "format expands a self-closing run" {
  inspect(
    format_result("<w:r/>", bold=true),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs/></w:rPr></w:r>
    ),
  )
}

///|
/// Every existing on/off spelling is recognized; a semantically
/// equivalent spelling is preserved byte-for-byte (no edit at all).
test "format preserves equivalent on spellings" {
  for
    spelling in [
      "<w:b/>", "<w:b w:val=\"1\"/>", "<w:b w:val=\"true\"/>", "<w:b w:val=\"on\"/>",
    ] {
    let source = "<w:r><w:rPr>" +
      spelling +
      "<w:bCs/></w:rPr><w:t>x</w:t></w:r>"
    let plan = plan_for(source, bold=true)
    assert_false(plan.changed(), msg="spelling '" + spelling + "' must satisfy")
  }
  for
    spelling in [
      "<w:b w:val=\"0\"/>", "<w:b w:val=\"false\"/>", "<w:b w:val=\"off\"/>",
    ] {
    let source = "<w:r><w:rPr>" +
      spelling +
      "<w:bCs w:val=\"0\"/></w:rPr><w:t>x</w:t></w:r>"
    let plan = plan_for(source, bold=false)
    assert_false(plan.changed(), msg="spelling '" + spelling + "' must satisfy")
  }
}

///|
/// Flipping an opposite value patches ONLY the val text; an on-form
/// without val gains exactly one attribute.
test "format patches the smallest span when flipping" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:b w:val=\"0\"/><w:bCs w:val=\"false\"/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
    ),
    content=(
      #|<w:r><w:rPr><w:b w:val="1"/><w:bCs w:val="1"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
  inspect(
    format_result(
      "<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>x</w:t></w:r>",
      bold=false,
    ),
    content=(
      #|<w:r><w:rPr><w:b w:val="0"/><w:bCs w:val="0"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// Insertion respects schema order around EXISTING children, which are
/// never moved: bold lands before an existing color; underline lands
/// after it; unrelated properties (rStyle, sz) stay byte-identical.
test "format inserts at schema positions without moving neighbours" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:rStyle w:val=\"Em\"/><w:color w:val=\"112233\"/><w:sz w:val=\"24\"/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
      underline=true,
    ),
    content=(
      #|<w:r><w:rPr><w:rStyle w:val="Em"/><w:b/><w:bCs/><w:color w:val="112233"/><w:sz w:val="24"/><w:u w:val="single"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// Underline becomes exactly single or none; an existing style's OTHER
/// attributes (color here) are unrelated and preserved.
test "format overwrites underline style preserving its attributes" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:u w:val=\"double\" w:color=\"FF0000\"/></w:rPr><w:t>x</w:t></w:r>",
      underline=true,
    ),
    content=(
      #|<w:r><w:rPr><w:u w:val="single" w:color="FF0000"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
  inspect(
    format_result(
      "<w:r><w:rPr><w:u w:val=\"single\"/></w:rPr><w:t>x</w:t></w:r>",
      underline=false,
    ),
    content=(
      #|<w:r><w:rPr><w:u w:val="none"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// An absolute RGB set patches the val and REMOVES theme linkage —
/// leaving themeColor would not be an absolute set.
test "format color removes theme linkage" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:color w:val=\"auto\" w:themeColor=\"accent1\" w:themeTint=\"99\"/></w:rPr><w:t>x</w:t></w:r>",
      color="00B050",
    ),
    content=(
      #|<w:r><w:rPr><w:color w:val="00B050"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// The refusal matrix: duplicate rPr, duplicate properties, rPrChange,
/// unranked/foreign children at the insertion path, and non-on/off
/// vocabulary each refuse typed — never first-wins, never normalize.
test "format refuses every ambiguity" {
  fn refuse(source : String) -> String raise {
    let mut message = ""
    try ignore(plan_for(source, bold=true)) catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a refusal for " + source)
    }
    message
  }
  assert_true(
    refuse("<w:r><w:rPr><w:b/></w:rPr><w:rPr><w:i/></w:rPr><w:t>x</w:t></w:r>").contains(
      "duplicate rPr",
    ),
  )
  assert_true(
    refuse("<w:r><w:rPr><w:b/><w:b/></w:rPr><w:t>x</w:t></w:r>").contains(
      "duplicate w:b",
    ),
  )
  assert_true(
    refuse(
      "<w:r><w:rPr><w:i/><w:rPrChange w:id=\"1\" w:author=\"a\" w:date=\"2020-01-01T00:00:00Z\"><w:rPr><w:b/></w:rPr></w:rPrChange></w:rPr><w:t>x</w:t></w:r>",
    ).contains("rPrChange"),
  )
  assert_true(
    refuse("<w:r><w:rPr><w:b w:val=\"maybe\"/></w:rPr><w:t>x</w:t></w:r>").contains(
      "unrecognized on/off",
    ),
  )
  // A ranked property AFTER the extension block is the ambiguity;
  // the trailing block itself is legal (see the dedicated witness).
  assert_true(
    refuse("<w:r><w:rPr><w14:glow/><w:i/></w:rPr><w:t>x</w:t></w:r>").contains(
      "after the trailing extension block",
    ),
  )
}

///|
/// The oracle shares the planner's reading: satisfied slices verify,
/// unsatisfied ones name the discrepancy, and applying a plan always
/// yields a slice the oracle accepts.
test "the oracle agrees with the planner" {
  let source = "<w:r><w:rPr><w:sz w:val=\"28\"/></w:rPr><w:t>x</w:t></w:r>"
  let format = @docx.docx_direct_format(bold=true, color="FF0000")
  assert_true(
    @docx.verify_run_format(@utf8.encode(source)[:], prefix="w", format~)
    is Some(_),
  )
  let formatted = apply_format_plan(
    source,
    @docx.plan_run_format(@utf8.encode(source)[:], prefix="w", format~),
  )
  assert_eq(
    @docx.verify_run_format(@utf8.encode(formatted)[:], prefix="w", format~),
    None,
  )
  // And the unrelated size survived byte-for-byte.
  assert_true(formatted.contains("<w:sz w:val=\"28\"/>"))
}

///|
/// Round 1's corpus-grounded rule: a TRAILING extension block
/// (w14:glow etc.) is legal, and new properties insert before it.
test "format inserts before a trailing extension block" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:i/><w14:glow w14:rad=\"101600\"/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
    ),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs/><w:i/><w14:glow w14:rad="101600"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// A default-namespace document spells names without prefixes — and
/// its WML attributes carry NO prefix at all.
test "format handles a default-namespace document" {
  let source = "<r><rPr><b val=\"0\"/><bCs val=\"0\"/></rPr><t>x</t></r>"
  let plan = @docx.plan_run_format(
    @utf8.encode(source),
    prefix="",
    format=@docx.docx_direct_format(bold=true),
  )
  let mut result = source
  let edits = plan.edits()
  let mut index = edits.length() - 1
  while index >= 0 {
    let edit = edits[index]
    result = result.substring(start=0, end=edit.start()).to_string() +
      edit.replacement() +
      result.substring(start=edit.end(), end=result.length()).to_string()
    index -= 1
  }
  inspect(
    result,
    content=(
      #|<r><rPr><b val="1"/><bCs val="1"/></rPr><t>x</t></r>
    ),
  )
}

///|
/// A self-closing rPr expands only its "/>": the open tag's own
/// attributes survive byte-for-byte.
test "format preserves a self-closing rPr's attributes" {
  inspect(
    format_result(
      "<w:r><w:rPr w:something=\"kept\"/><w:t>x</w:t></w:r>",
      bold=true,
    ),
    content=(
      #|<w:r><w:rPr w:something="kept"><w:b/><w:bCs/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// Whitespace around `=` is valid XML: recognized when reading, and a
/// theme-attribute removal takes the WHOLE attribute with it.
test "format accepts attribute whitespace and removes whole attributes" {
  let source = "<w:r><w:rPr><w:color w:val = \"auto\" w:themeColor =\"accent1\" w:themeShade= \"80\"/></w:rPr><w:t>x</w:t></w:r>"
  inspect(
    format_result(source, color="00B050"),
    content=(
      #|<w:r><w:rPr><w:color w:val = "00B050"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// A lowercase-equivalent RGB is a semantic no-op: no edit at all.
test "format preserves an equivalent lowercase color spelling" {
  let plan = plan_for(
    "<w:r><w:rPr><w:color w:val=\"ff0000\"/></w:rPr><w:t>x</w:t></w:r>",
    color="FF0000",
  )
  assert_false(plan.changed())
}

///|
/// Asymmetric twins converge: bold-on with bCs-off patches ONLY the
/// out-of-line twin.
test "format converges asymmetric complex-script twins" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:b/><w:bCs w:val=\"0\"/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
    ),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs w:val="1"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// Equal-offset insertions keep schema order — the stable tie-break a
/// bare sort would lose (b, bCs, i, iCs all insert at one offset).
test "format keeps schema order for equal-offset insertions" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:sz w:val=\"24\"/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
      italic=true,
    ),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs/><w:i/><w:iCs/><w:sz w:val="24"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// The predecessor/successor matrix over the rank table: for a sample
/// of anchors across the CT_RPr order, an inserted property lands
/// after every lower-ranked neighbour and before every higher-ranked
/// one.
test "format schema-rank matrix places every property between its neighbours" {
  // color (rank 18) between b (2) and sz (23).
  inspect(
    format_result(
      "<w:r><w:rPr><w:b/><w:sz w:val=\"24\"/></w:rPr><w:t>x</w:t></w:r>",
      color="112233",
    ),
    content=(
      #|<w:r><w:rPr><w:b/><w:color w:val="112233"/><w:sz w:val="24"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
  // u (rank 26) after highlight (25).
  inspect(
    format_result(
      "<w:r><w:rPr><w:highlight w:val=\"yellow\"/></w:rPr><w:t>x</w:t></w:r>",
      underline=true,
    ),
    content=(
      #|<w:r><w:rPr><w:highlight w:val="yellow"/><w:u w:val="single"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
  // b (rank 2) after rStyle (0) and rFonts (1), before i (4).
  inspect(
    format_result(
      "<w:r><w:rPr><w:rStyle w:val=\"Em\"/><w:rFonts w:ascii=\"Arial\"/><w:i/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
    ),
    content=(
      #|<w:r><w:rPr><w:rStyle w:val="Em"/><w:rFonts w:ascii="Arial"/><w:b/><w:bCs/><w:i/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// The structural refusals round 1 demanded: wrong close tags,
/// out-of-order ranked children, non-leaf targeted properties, local
/// xmlns declarations, and non-whitespace character data.
test "format refuses structural ambiguities" {
  fn refuse(source : String) -> String raise {
    let mut message = ""
    try ignore(plan_for(source, bold=true)) catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a refusal for " + source)
    }
    message
  }
  assert_true(
    refuse(
      "<w:r><w:rPr><w:u w:val=\"x\"></w:i></w:u></w:rPr><w:t>a</w:t></w:r>",
    ).contains("close tag"),
  )
  assert_true(
    refuse("<w:r><w:rPr><w:sz w:val=\"24\"/><w:i/></w:rPr><w:t>a</w:t></w:r>").contains(
      "out of schema order",
    ),
  )
  assert_true(
    refuse("<w:r><w:rPr><w:b><w:i/></w:b></w:rPr><w:t>a</w:t></w:r>").contains(
      "non-leaf",
    ),
  )
  assert_true(
    refuse("<w:r><w:rPr xmlns:w=\"urn:other\"><w:b/></w:rPr><w:t>a</w:t></w:r>").contains(
      "namespace declaration",
    ),
  )
  assert_true(
    refuse("<w:r><w:rPr>stray<w:i/></w:rPr><w:t>a</w:t></w:r>").contains(
      "character data",
    ),
  )
  assert_true(refuse("<w:rr><w:t>a</w:t></w:rr>").contains("expected a <w:r>"))
}
