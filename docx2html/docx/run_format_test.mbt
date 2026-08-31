// F0 witnesses: the lexical rPr engine's edits are minimal, spelled at
// schema positions, byte-preserving outside their spans — and the
// oracle EXTRACTS observed values and compares them, keeping the
// planner's fixed point only as a cross-check.

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
  extension_prefixes? : Array[String],
) -> @docx.RunFormatPlan raise {
  @docx.plan_run_format(
    @utf8.encode(source)[:],
    prefix="w",
    extension_prefixes?,
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
  extension_prefixes? : Array[String],
) -> String raise {
  apply_format_plan(
    source,
    plan_for(source, bold?, italic?, underline?, color?, extension_prefixes?),
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
  let mut message = ""
  try
    ignore(
      plan_for(
        "<w:r><w:rPr><w14:glow/><w:i/></w:rPr><w:t>x</w:t></w:r>",
        bold=true,
        extension_prefixes=["w14"],
      ),
    )
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected a refusal for a ranked property after the block")
  }
  assert_true(message.contains("after the trailing extension block"))
}

///|
/// The oracle extracts and compares independently, then cross-checks
/// that the planner sees a fixed point: satisfied slices verify,
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
/// (w14:glow etc.) is legal under a caller-vouched extension prefix,
/// and new properties insert before it.
test "format inserts before a trailing extension block" {
  inspect(
    format_result(
      "<w:r><w:rPr><w:i/><w14:glow w14:rad=\"101600\"/></w:rPr><w:t>x</w:t></w:r>",
      bold=true,
      extension_prefixes=["w14"],
    ),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs/><w:i/><w14:glow w14:rad="101600"/></w:rPr><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// Round 2's boundary: the extension tolerance reaches exactly as far
/// as the caller's warrant. An unvouched prefix, a ranked property
/// name under a foreign prefix (a possible WML alias), same-prefix
/// children outside the schema, markup-compatibility content, and a
/// warrant naming a reserved or WML prefix all refuse.
test "format refuses extension shapes it cannot interpret" {
  fn refuse_ext(
    source : String,
    extension_prefixes : Array[String],
  ) -> String raise {
    let mut message = ""
    try ignore(plan_for(source, bold=true, extension_prefixes~)) catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a refusal for " + source)
    }
    message
  }

  assert_true(
    refuse_ext("<w:r><w:rPr><w:i/><w14:glow/></w:rPr><w:t>x</w:t></w:r>", []).contains(
      "outside the caller-vouched extension prefixes",
    ),
  )
  assert_true(
    refuse_ext("<w:r><w:rPr><w:i/><x:b/></w:rPr><w:t>x</w:t></w:r>", ["x"]).contains(
      "may be a WML alias",
    ),
  )
  for mce in ["AlternateContent", "Choice", "Fallback", "ProcessContent"] {
    assert_true(
      refuse_ext(
        "<w:r><w:rPr><w:i/><q:" + mce + "/></w:rPr><w:t>x</w:t></w:r>",
        ["q"],
      ).contains("markup-compatibility"),
      msg=mce,
    )
  }
  assert_true(
    refuse_ext("<w:r><w:rPr><w:bogus/></w:rPr><w:t>x</w:t></w:r>", []).contains(
      "does not recognize",
    ),
  )
  assert_true(
    refuse_ext("<w:r><w:rPr><w:i/></w:rPr><w:t>x</w:t></w:r>", ["mc"]).contains(
      "extension prefix",
    ),
  )
  assert_true(
    refuse_ext("<w:r><w:rPr><w:i/></w:rPr><w:t>x</w:t></w:r>", ["w"]).contains(
      "extension prefix",
    ),
  )
}

///|
/// A default-namespace document spells its ELEMENTS without prefixes,
/// but default namespaces do not apply to attributes: its WML
/// attributes stay qualified under whatever prefix the document bound
/// to the WML namespace (here `s`) — and the caller states that
/// prefix explicitly.
test "format handles a default-namespace document with qualified attributes" {
  let source = "<r><rPr><b s:val=\"0\"/><bCs s:val=\"0\"/></rPr><t>x</t></r>"
  let plan = @docx.plan_run_format(
    @utf8.encode(source),
    prefix="",
    attr_prefix="s",
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
      #|<r><rPr><b s:val="1"/><bCs s:val="1"/></rPr><t>x</t></r>
    ),
  )
}

///|
/// The namespace shapes this engine refuses to guess about: a
/// default-namespace request without an attribute prefix, a bare
/// (no-namespace) `val` on an on/off property, and a foreign-prefixed
/// val — each would change what the planner is reading.
test "format refuses namespace shapes it cannot vouch for" {
  let mut message = ""
  try
    ignore(
      @docx.plan_run_format(
        @utf8.encode("<r><t>x</t></r>"),
        prefix="",
        format=@docx.docx_direct_format(bold=true),
      ),
    )
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected a refusal without an attribute prefix")
  }
  assert_true(message.contains("default namespaces do not apply to attributes"))
  for
    poisoned in [
      "<w:r><w:rPr><w:b val=\"0\"/></w:rPr><w:t>x</w:t></w:r>", "<w:r><w:rPr><w:b x:val=\"0\"/></w:rPr><w:t>x</w:t></w:r>",
    ] {
    let mut attr_message = ""
    try ignore(plan_for(poisoned, bold=true)) catch {
      error => attr_message = repr(error)
    } noraise {
      _ => fail("expected a refusal for " + poisoned)
    }
    assert_true(
      attr_message.contains("refuses the attribute"),
      msg=poisoned + " -> " + attr_message,
    )
  }
  // Round 3: an ALIASED WML attribute — a theme local under a foreign
  // prefix — may be WML after namespace resolution; both the planner
  // and the verifier refuse rather than read past it.
  let aliased = "<w:r><w:rPr><w:color w:val=\"112233\" x:themeColor=\"accent1\"/></w:rPr><w:t>x</w:t></w:r>"
  let mut alias_message = ""
  try ignore(plan_for(aliased, color="112233")) catch {
    error => alias_message = repr(error)
  } noraise {
    _ => fail("expected an aliased-theme refusal")
  }
  assert_true(alias_message.contains("x:themeColor"))
  let mut verify_message = ""
  try
    ignore(
      @docx.verify_run_format(
        @utf8.encode(aliased),
        prefix="w",
        format=@docx.docx_direct_format(color="112233"),
      ),
    )
  catch {
    error => verify_message = repr(error)
  } noraise {
    _ => fail("expected the verifier to refuse the alias")
  }
  assert_true(verify_message.contains("x:themeColor"))
  // Reserved and malformed prefixes never become the binding.
  fn refuse_binding(
    element : String,
    attribute : String?,
    extensions : Array[String]?,
  ) -> String raise {
    let mut message = ""
    try
      ignore(
        @docx.plan_run_format(
          @utf8.encode("<w:r><w:t>x</w:t></w:r>"),
          prefix=element,
          attr_prefix?=attribute,
          extension_prefixes?=extensions,
          format=@docx.docx_direct_format(bold=true),
        ),
      )
    catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a binding refusal")
    }
    message
  }

  assert_true(
    refuse_binding("w", Some("xml"), None).contains("reserved namespace prefix"),
  )
  assert_true(refuse_binding("w", Some("x:y"), None).contains("NCNames"))
  assert_true(refuse_binding("1w", None, None).contains("NCNames"))
  assert_true(refuse_binding("w", None, Some(["a:b"])).contains("NCNames"))
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
    refuse("<w:r><w:rPr xmlns=\"urn:x\"><w:b/></w:rPr><w:t>a</w:t></w:r>").contains(
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

///|
/// Round 2's lexical strictness: whitespace may follow an end-tag
/// name but never precede it (`</ w:b>` can never pass as `w:b`), and
/// element and attribute names must be XML names.
test "format refuses malformed close tags and names" {
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
    refuse("<w:r><w:rPr><w:b></ w:b><w:bCs/></w:rPr><w:t>x</w:t></w:r>").contains(
      "malformed XML name",
    ),
  )
  assert_true(
    refuse("<w:r><w:rPr><1b/></w:rPr><w:t>x</w:t></w:r>").contains(
      "malformed XML name",
    ),
  )
  assert_true(
    refuse("<w:r><w:rPr><w:b w:val=\"1\" 2x=\"3\"/></w:rPr><w:t>x</w:t></w:r>").contains(
      "malformed XML name",
    ),
  )
  // Whitespace AFTER the end-tag name is valid XML and accepted.
  let plan = plan_for(
    "<w:r><w:rPr><w:u w:val=\"single\"></w:u ></w:rPr><w:t>x</w:t></w:r>",
    underline=true,
  )
  assert_false(plan.changed())
  // ...including on the CONTAINER close tags: a satisfied slice with
  // `</w:rPr >` and `</w:r >` stays a fixed point, and insertion
  // lands before the rPr close, never inside it.
  let ws_plan = plan_for(
    "<w:r><w:rPr><w:b/><w:bCs/></w:rPr ><w:t>x</w:t></w:r >",
    bold=true,
  )
  assert_false(ws_plan.changed())
  inspect(
    format_result("<w:r><w:rPr><w:i/></w:rPr ><w:t>x</w:t></w:r>", bold=true),
    content=(
      #|<w:r><w:rPr><w:b/><w:bCs/><w:i/></w:rPr ><w:t>x</w:t></w:r>
    ),
  )
}

///|
/// The verifier EXTRACTS observed values and compares them — it is
/// not a replan. Round 2's counterexample: a default-namespace slice
/// whose qualified attributes state bold OFF fails verification for
/// bold ON (it never false-verifies); a missing complex-script twin
/// and remaining theme linkage are named; a satisfied slice verifies
/// clean.
test "the verifier extracts observed values rather than replanning" {
  debug_inspect(
    @docx.verify_run_format(
      @utf8.encode(
        "<r><rPr><b s:val=\"0\"/><bCs s:val=\"0\"/></rPr><t>x</t></r>",
      ),
      prefix="",
      attr_prefix="s",
      format=@docx.docx_direct_format(bold=true),
    ),
    content=(
      #|Some("b states off where bold on was requested")
    ),
  )
  debug_inspect(
    @docx.verify_run_format(
      @utf8.encode("<w:r><w:rPr><w:b/></w:rPr><w:t>x</w:t></w:r>"),
      prefix="w",
      format=@docx.docx_direct_format(bold=true),
    ),
    content=(
      #|Some("complex-script bold is not stated explicitly")
    ),
  )
  debug_inspect(
    @docx.verify_run_format(
      @utf8.encode(
        "<w:r><w:rPr><w:color w:val=\"112233\" w:themeColor=\"accent1\"/></w:rPr><w:t>x</w:t></w:r>",
      ),
      prefix="w",
      format=@docx.docx_direct_format(color="112233"),
    ),
    content=(
      #|Some("w:color keeps theme linkage (w:themeColor) where an absolute color was requested")
    ),
  )
  debug_inspect(
    @docx.verify_run_format(
      @utf8.encode("<w:r><w:rPr><w:sz w:val=\"24\"/></w:rPr><w:t>x</w:t></w:r>"),
      prefix="w",
      format=@docx.docx_direct_format(italic=true),
    ),
    content=(
      #|Some("italic is not stated explicitly")
    ),
  )
  debug_inspect(
    @docx.verify_run_format(
      @utf8.encode("<w:r><w:rPr><w:i/></w:rPr><w:t>x</w:t></w:r>"),
      prefix="w",
      format=@docx.docx_direct_format(italic=true),
    ),
    content=(
      #|Some("complex-script italic is not stated explicitly")
    ),
  )
  debug_inspect(
    @docx.verify_run_format(
      @utf8.encode("<w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>x</w:t></w:r>"),
      prefix="w",
      format=@docx.docx_direct_format(bold=true),
    ),
    content="None",
  )
}

///|
/// EVERY name in the CT_RPr rank table, exercised: an inserted color
/// (rank 18) lands after each lower-ranked neighbour and before each
/// higher-ranked one, so the whole table drives real insertion
/// positions — no entry is dead weight.
test "format ranks every CT_RPr property in the table" {
  let order = [
    "rStyle", "rFonts", "b", "bCs", "i", "iCs", "caps", "smallCaps", "strike", "dstrike",
    "outline", "shadow", "emboss", "imprint", "noProof", "snapToGrid", "vanish",
    "webHidden", "color", "spacing", "w", "kern", "position", "sz", "szCs", "highlight",
    "u", "effect", "bdr", "shd", "fitText", "vertAlign", "rtl", "cs", "em", "lang",
    "eastAsianLayout", "specVanish", "oMath",
  ]
  let color_xml = "<w:color w:val=\"112233\"/>"
  for index, name in order {
    if name == "color" {
      inspect(
        format_result(
          "<w:r><w:rPr><w:color w:val=\"00FF00\"/></w:rPr><w:t>x</w:t></w:r>",
          color="112233",
        ),
        content=(
          #|<w:r><w:rPr><w:color w:val="112233"/></w:rPr><w:t>x</w:t></w:r>
        ),
      )
      continue
    }
    let child = "<w:" + name + "/>"
    let expected = if index < 18 {
      "<w:r><w:rPr>" + child + color_xml + "</w:rPr><w:t>x</w:t></w:r>"
    } else {
      "<w:r><w:rPr>" + color_xml + child + "</w:rPr><w:t>x</w:t></w:r>"
    }
    let got = format_result(
      "<w:r><w:rPr>" + child + "</w:rPr><w:t>x</w:t></w:r>",
      color="112233",
    )
    assert_true(got == expected, msg="rank neighbour " + name + ": " + got)
  }
}
