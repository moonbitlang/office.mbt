// Blackbox witnesses for the replace planner (N2b), through the public
// API only: plan, splice, re-read with the real reader, compare.

///|
fn replace_fixture(body : String) -> @docx.DocxAnnotatedResult raise {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:body>\{body}<w:sectPr/></w:body></w:document>"
  @docx.read_docx_annotated(fixture_docx(document))
}

///|
/// Replacing across run boundaries: the needle exists only in the
/// projection, and the re-read paragraph matches the receipt's expected
/// FULL projection.
test "replace plans across run boundaries and the readback agrees" {
  let annotated = replace_fixture(
    "<w:p><w:r><w:t>Hel</w:t></w:r><w:r><w:t>lo world</w:t></w:r></w:p>",
  )
  let (plan, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="lo wo",
    replacement="p wo",
  )
  assert_eq(receipt.replaced(), 1)
  debug_inspect(receipt.selected(), content="[1]")
  assert_eq(receipt.affected().length(), 1)
  assert_eq(receipt.affected()[0].path(), "p[1]")
  assert_eq(receipt.affected()[0].expected(), "Help world")
  // Apply and re-read with the real reader.
  let spliced = @splice.splice_docx_archive(
    try! @mbtzip.read(
      fixture_docx(
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:body><w:p><w:r><w:t>Hel</w:t></w:r><w:r><w:t>lo world</w:t></w:r></w:p><w:sectPr/></w:body></w:document>",
      ),
    ),
    plan,
    max_output_bytes=1 << 22,
  )
  let reread = @docx.read_docx_annotated(spliced)
  let text = reread.result().document.to_raw_text()
  assert_true(
    text.contains("Help world"),
    msg="re-read text was '" + text + "'",
  )
}

///|
/// The full-projection expectation is what makes the readback sound: the
/// replacement text pre-exists elsewhere in the paragraph, so a
/// substring probe would pass even if the splice landed in the wrong
/// place. The expected string pins position, not presence.
test "replace expectations are full projections, not substring probes" {
  let annotated = replace_fixture(
    "<w:p><w:r><w:t>done and not done</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="not done",
    replacement="done",
  )
  assert_eq(receipt.affected()[0].expected(), "done and done")
}

///|
/// Without `nth`, every candidate is selected — including several in one
/// paragraph, which plan as ONE batch so the partial planner validates
/// them together.
test "replace acts on all candidates and batches per paragraph" {
  let annotated = replace_fixture(
    "<w:p><w:r><w:t>aa then aa</w:t></w:r></w:p><w:p><w:r><w:t>aa</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="aa",
    replacement="b",
  )
  assert_eq(receipt.replaced(), 3)
  debug_inspect(receipt.selected(), content="[1, 2, 3]")
  assert_eq(receipt.affected().length(), 2)
  assert_eq(receipt.affected()[0].expected(), "b then b")
  assert_eq(receipt.affected()[1].expected(), "b")
}

///|
/// `nth` selects one candidate by the ordinal find reports.
test "replace nth selects one candidate by find's ordinal" {
  let annotated = replace_fixture("<w:p><w:r><w:t>aa then aa</w:t></w:r></w:p>")
  let (_, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="aa",
    replacement="b",
    nth=2,
  )
  assert_eq(receipt.replaced(), 1)
  debug_inspect(receipt.selected(), content="[2]")
  assert_eq(receipt.affected()[0].expected(), "aa then b")
  // Out of range names the real count.
  let mut refusal = ""
  try
    ignore(
      @docx.plan_docx_replacements(
        annotated,
        annotated.main_story_source(),
        needle="aa",
        replacement="b",
        nth=3,
      ),
    )
  catch {
    Unsupported(message~) => refusal = message
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(
    refusal.contains("2 candidate(s)"),
    msg="expected the out-of-range refusal, got '" + refusal + "'",
  )
}

///|
/// A restricted candidate in scope refuses by ordinal and reason —
/// replace never silently skips what find reports. And `nth` pointed AT
/// the restricted candidate refuses the same way, while `nth` pointed at
/// the editable one succeeds: selection narrows scope, it does not
/// bypass the policy.
test "replace refuses restricted candidates by ordinal and reason" {
  let body =
    #|<w:p><w:r><w:t>seven</w:t></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>seven</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
  let annotated = replace_fixture(body)
  // All-candidates mode: the field-region candidate poisons the scope.
  let mut refusal = ""
  try
    ignore(
      @docx.plan_docx_replacements(
        annotated,
        annotated.main_story_source(),
        needle="seven",
        replacement="eight",
      ),
    )
  catch {
    Unsupported(message~) => refusal = message
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(
    refusal.contains("candidate 2") && refusal.contains("field-region"),
    msg="expected candidate 2 refused as field-region, got '" + refusal + "'",
  )
  // nth at the restricted one: same refusal.
  let mut nth_refusal = ""
  try
    ignore(
      @docx.plan_docx_replacements(
        annotated,
        annotated.main_story_source(),
        needle="seven",
        replacement="eight",
        nth=2,
      ),
    )
  catch {
    Unsupported(message~) => nth_refusal = message
    _ => ()
  } noraise {
    _ => ()
  }
  assert_true(nth_refusal.contains("field-region"))
  // nth at the editable one: plans exactly it.
  let (_, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="seven",
    replacement="eight",
    nth=1,
  )
  assert_eq(receipt.replaced(), 1)
  assert_eq(receipt.affected()[0].expected(), "eight")
}

///|
/// Zero candidates is an empty plan and an empty receipt, not an error:
/// whether zero is acceptable is the caller's policy.
test "replace plans nothing for an absent needle" {
  let annotated = replace_fixture("<w:p><w:r><w:t>alpha</w:t></w:r></w:p>")
  let (_, receipt) = @docx.plan_docx_replacements(
    annotated,
    annotated.main_story_source(),
    needle="absent",
    replacement="x",
  )
  assert_eq(receipt.replaced(), 0)
  assert_eq(receipt.selected().length(), 0)
  assert_eq(receipt.affected().length(), 0)
}

///|
/// A tolerated NESTED paragraph makes two logical paragraphs claim one
/// path. The planner must refuse rather than plan against whichever
/// claimant a map happened to keep — the selection named the other.
test "replace refuses a path two paragraphs claim" {
  let annotated = replace_fixture(
    "<w:p><w:r><w:t>boo</w:t></w:r><w:p><w:r><w:t>aoo</w:t></w:r></w:p></w:p>",
  )
  try
    @docx.plan_docx_replacements(
      annotated,
      annotated.main_story_source(),
      needle="oo",
      replacement="ee",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("a collided path cannot be planned against")
  }
}
