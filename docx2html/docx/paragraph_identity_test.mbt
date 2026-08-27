// Blackbox witnesses for paragraph identity provenance (paraId R1):
// imported ids are immutable observed identity — validated, part-scoped,
// and never repaired.

///|
fn identity_fixture(
  body : String,
  extra_namespaces? : String = "",
) -> @docx.DocxAnnotatedResult raise {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"\{extra_namespaces}><w:body>\{body}<w:sectPr/></w:body></w:document>"
  @docx.read_docx_annotated(fixture_docx(document))
}

///|
fn anchor_of(
  annotated : @docx.DocxAnnotatedResult,
  path : String,
) -> (String, String?, Array[String]) raise {
  let index = @docx.docx_paragraph_anchor_index(
    annotated,
    annotated.main_story_source(),
  )
  match index.anchor_at(path) {
    Some(anchor) =>
      (anchor.status(), anchor.para_id(), anchor.physical_para_ids())
    None => ("<absent>", None, [])
  }
}

///|
/// The validator is the addressing judgment: eight hex digits either
/// case, nonzero, high bit clear. Canonical form is uppercase.
test "validated_para_id accepts the range and rejects the rest" {
  assert_eq(@docx.validated_para_id("00000001"), Some("00000001"))
  assert_eq(@docx.validated_para_id("7FFFFFFF"), Some("7FFFFFFF"))
  assert_eq(@docx.validated_para_id("1a2b3c4d"), Some("1A2B3C4D"))
  assert_eq(@docx.validated_para_id("DeadBeef"), None) // high bit set
  assert_eq(@docx.validated_para_id("00000000"), None) // zero
  assert_eq(@docx.validated_para_id("80000000"), None) // reserved
  assert_eq(@docx.validated_para_id("FFFFFFFF"), None)
  assert_eq(@docx.validated_para_id("1234567"), None) // short
  assert_eq(@docx.validated_para_id("123456789"), None) // long
  assert_eq(@docx.validated_para_id("1234567G"), None) // non-hex
  assert_eq(@docx.validated_para_id(""), None)
}

///|
/// A stamped paragraph reports its canonical id; lowercase source
/// spelling canonicalizes to uppercase without touching the bytes.
/// An unstamped paragraph reports `missing` with no id invented.
test "identity reports unique and missing anchors" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"1a2b3c4d\"><w:r><w:t>one</w:t></w:r></w:p><w:p><w:r><w:t>two</w:t></w:r></w:p>",
  )
  debug_inspect(
    anchor_of(annotated, "p[1]"),
    content=(
      #|("unique", Some("1A2B3C4D"), [])
    ),
  )
  debug_inspect(
    anchor_of(annotated, "p[2]"),
    content=(
      #|("missing", None, [])
    ),
  )
}

///|
/// Duplicates are part-scoped and case-insensitive: both carriers
/// report the shared value with status `duplicate` — neither is an
/// addressable anchor, and first-wins never happens.
test "identity refuses duplicate ids on both carriers" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"1A2B3C4D\"><w:r><w:t>one</w:t></w:r></w:p><w:p w14:paraId=\"1a2b3c4d\"><w:r><w:t>two</w:t></w:r></w:p><w:p w14:paraId=\"22222222\"><w:r><w:t>three</w:t></w:r></w:p>",
  )
  debug_inspect(
    anchor_of(annotated, "p[1]"),
    content=(
      #|("duplicate", Some("1A2B3C4D"), [])
    ),
  )
  debug_inspect(
    anchor_of(annotated, "p[2]"),
    content=(
      #|("duplicate", Some("1A2B3C4D"), [])
    ),
  )
  // The undisputed neighbour keeps its unique anchor.
  debug_inspect(
    anchor_of(annotated, "p[3]"),
    content=(
      #|("unique", Some("22222222"), [])
    ),
  )
}

///|
/// Invalid spellings are reported, never repaired — and an invalid
/// value is not an identity, so it cannot contest a valid one.
test "identity reports invalid without contesting valid ids" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"00000000\"><w:r><w:t>zero</w:t></w:r></w:p><w:p w14:paraId=\"XYZ\"><w:r><w:t>junk</w:t></w:r></w:p><w:p w14:paraId=\"33333333\"><w:r><w:t>fine</w:t></w:r></w:p>",
  )
  debug_inspect(
    anchor_of(annotated, "p[1]"),
    content=(
      #|("invalid", None, [])
    ),
  )
  debug_inspect(
    anchor_of(annotated, "p[2]"),
    content=(
      #|("invalid", None, [])
    ),
  )
  debug_inspect(
    anchor_of(annotated, "p[3]"),
    content=(
      #|("unique", Some("33333333"), [])
    ),
  )
}

///|
/// The attribute is identified by its NAMESPACE, not its prefix: an
/// alternate prefix bound to the w14 URI matches, and a `paraId` bound
/// to some other URI does not.
test "identity matches the w14 namespace not the prefix" {
  let annotated = identity_fixture(
    "<w:p xmlns:idns=\"http://schemas.microsoft.com/office/word/2010/wordml\" idns:paraId=\"44444444\"><w:r><w:t>alt</w:t></w:r></w:p>",
  )
  debug_inspect(
    anchor_of(annotated, "p[1]"),
    content=(
      #|("unique", Some("44444444"), [])
    ),
  )
  let foreign = identity_fixture(
    "<w:p xmlns:other=\"http://example.com/not-w14\" other:paraId=\"55555555\"><w:r><w:t>foreign</w:t></w:r></w:p>",
  )
  debug_inspect(
    anchor_of(foreign, "p[1]"),
    content=(
      #|("missing", None, [])
    ),
  )
}

///|
/// A deleted paragraph mark joins physical paragraphs into one logical
/// paragraph: no singular anchor is invented — the joined paragraph
/// reports `multi_physical` with its physical inventory.
test "identity refuses a singular anchor for joined paragraphs" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"66666666\"><w:pPr><w:rPr><w:del w:id=\"1\" w:author=\"a\"/></w:rPr></w:pPr><w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"77777777\"><w:r><w:t>second</w:t></w:r></w:p>",
  )
  debug_inspect(
    anchor_of(annotated, "p[1]"),
    content=(
      #|("multi_physical", None, ["66666666", "77777777"])
    ),
  )
}

///|
/// The anchors ride the match surface: find stamps every entry with the
/// paragraph's judgment, and anchor health never alters actionability.
test "find matches carry anchor provenance" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"1a2b3c4d\"><w:r><w:t>needle here</w:t></w:r></w:p><w:p><w:r><w:t>needle too</w:t></w:r></w:p>",
  )
  let hits = @docx.find_docx_matches(
    annotated,
    annotated.main_story_source(),
    needle="needle",
  ).matches()
  assert_eq(hits.length(), 2)
  debug_inspect(
    (hits[0].para_id(), hits[0].anchor_status(), hits[0].actionable()),
    content=(
      #|(Some("1A2B3C4D"), "unique", true)
    ),
  )
  debug_inspect(
    (hits[1].para_id(), hits[1].anchor_status(), hits[1].actionable()),
    content=(
      #|(None, "missing", true)
    ),
  )
}

///|
/// The replace receipt's affected entries copy their paragraph's
/// judgment, so a caller can re-anchor on identity after publishing.
test "replace affected entries carry anchor provenance" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"5B5B5B5B\"><w:r><w:t>swap me</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="swap",
    replacement="keep",
  )
  assert_eq(receipt.affected().length(), 1)
  debug_inspect(
    (
      receipt.affected()[0].path(),
      receipt.affected()[0].para_id(),
      receipt.affected()[0].anchor_status(),
    ),
    content=(
      #|("p[1]", Some("5B5B5B5B"), "unique")
    ),
  )
}
