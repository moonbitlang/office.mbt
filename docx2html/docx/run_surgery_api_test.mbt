// Blackbox witnesses for the addressed run-replacement boundary
// (#462 A1): the contract a shipped surface will trust, exercised
// through the public API only.

///|
fn run_text_fixture() -> Bytes raise {
  fixture_docx(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>alpha</w:t></w:r><w:r><w:t>beta</w:t></w:r></w:p><w:p><w:r><w:t>gamma</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
    ),
  )
}

///|
test "an addressed run replacement plans, applies, and preserves" {
  let bytes = run_text_fixture()
  let archive = try! @mbtzip.read(bytes)
  let annotated = @docx.read_docx_annotated_archive(archive)
  let (plan, receipt) = @docx.plan_run_text_replacement(
    annotated,
    annotated.main_story_source(),
    at_relative="p[1]/r[2]",
    expect="beta",
    text="BETA",
  )
  @debug.debug_inspect(
    (
      receipt.story_part(),
      receipt.at_relative(),
      receipt.replaced_text(),
      receipt.edit_count(),
    ),
    content=(
      #|("word/document.xml", "p[1]/r[2]", "beta", 1)
    ),
  )
  let spliced = @splice.splice_docx_archive(
    archive,
    plan,
    max_output_bytes=1 << 22,
  )
  // the claim, through the real reader: only the addressed run changed
  let reread = @docx.read_docx_annotated(spliced)
  let texts : Array[String] = []
  for pair in reread.result().document.to_raw_text().split("\n\n") {
    if pair.to_owned().length() > 0 {
      texts.push(pair.to_owned())
    }
  }
  @debug.debug_inspect(
    texts,
    content=(
      #|["alphaBETA", "gamma"]
    ),
  )
  // and the edited package still reads mutation-safe with a fresh
  // projection: the address is re-usable on the NEW snapshot
  let (_, again) = @docx.plan_run_text_replacement(
    reread,
    reread.main_story_source(),
    at_relative=receipt.at_relative(),
    expect=receipt.result_text(),
    text=receipt.replaced_text(),
  )
  inspect(again.replaced_text(), content="BETA")
}

///|
test "an addressed run replacement refuses every wrong premise typed" {
  let bytes = run_text_fixture()
  let archive = try! @mbtzip.read(bytes)
  let annotated = @docx.read_docx_annotated_archive(archive)
  fn refusal(at : String, expect : String) -> String {
    try {
      let _ = @docx.plan_run_text_replacement(
        annotated,
        annotated.main_story_source(),
        at_relative=at,
        expect~,
        text="x",
      )
      "accepted"
    } catch {
      Unsupported(message~) => message
      _ => "other error"
    }
  }
  // a stale expectation refuses without echoing content
  inspect(
    refusal("p[1]/r[2]", "stale"),
    content="the run at 'p[1]/r[2]' in 'word/document.xml' does not carry the expected text; re-read the document and retry with a fresh address",
  )
  // a path that names nothing counts the addressable runs
  inspect(
    refusal("p[9]/r[1]", "beta"),
    content="'p[9]/r[1]' does not name a run in 'word/document.xml' (3 runs are addressable)",
  )
  // a TOLERANT read retains no projection and refuses up front
  let budget = @xml.xml_read_budget(
    max_source_units=1 << 20,
    max_tokens=1 << 20,
    max_materialized_chars=1 << 20,
    max_token_chars=1 << 16,
  )
  let tolerant = @docx.read_docx_annotated_archive_tolerant_limited(
    try! @mbtzip.read(bytes),
    budget,
  )
  let mut tolerant_refused = false
  try {
    let _ = @docx.plan_run_text_replacement(
      tolerant,
      tolerant.main_story_source(),
      at_relative="p[1]/r[1]",
      expect="alpha",
      text="x",
    )
  } catch {
    Unsupported(message~) => {
      tolerant_refused = true
      assert_true(message.contains("mutation-safe read"))
    }
    _ => fail("expected a typed refusal")
  }
  assert_true(tolerant_refused)
}

///|
test "an addressed run inside a field instruction refuses through the boundary" {
  let bytes = fixture_docx(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>7</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p><w:sectPr/></w:body></w:document>
    ),
  )
  let archive = try! @mbtzip.read(bytes)
  let annotated = @docx.read_docx_annotated_archive(archive)
  let mut refused = false
  try {
    let _ = @docx.plan_run_text_replacement(
      annotated,
      annotated.main_story_source(),
      at_relative="p[1]/r[2]",
      expect="",
      text="GONE",
    )
  } catch {
    Unsupported(message~) => {
      refused = true
      assert_true(message.contains("field instruction"))
    }
    _ => fail("expected the field refusal")
  }
  assert_true(refused)
  // Criterion (d): the cached RESULT refuses too, and says why. The
  // reader projects the cached value, so a caller's read-back would
  // confirm an edit that the next recalculation discards -- the one
  // failure mode nothing in this repository can detect after the fact.
  let mut result_refusal = ""
  try {
    let _ = @docx.plan_run_text_replacement(
      annotated,
      annotated.main_story_source(),
      at_relative="p[1]/r[4]",
      expect="7",
      text="8",
    )
  } catch {
    Unsupported(message~) => result_refusal = message
    _ => fail("expected the cached-result refusal")
  }
  assert_true(
    result_refusal.contains("cached result"),
    msg="expected a cached-result refusal, got '" + result_refusal + "'",
  )
}

///|
/// The plan is bound to the snapshot it was computed from: it pins the
/// RETAINED source bytes, so applying it to a same-shaped archive whose
/// part differs refuses as stale instead of editing the wrong bytes.
test "a plan from one snapshot refuses to apply to another" {
  let bytes = run_text_fixture()
  let annotated = @docx.read_docx_annotated(bytes)
  let (plan, _) = @docx.plan_run_text_replacement(
    annotated,
    annotated.main_story_source(),
    at_relative="p[1]/r[2]",
    expect="beta",
    text="BETA",
  )
  // a different snapshot with the same layout: beta -> zeta
  let other = fixture_docx(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>alpha</w:t></w:r><w:r><w:t>zeta</w:t></w:r></w:p><w:p><w:r><w:t>gamma</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
    ),
  )
  let mut stale = false
  try {
    let _ = @splice.splice_docx_archive(
      try! @mbtzip.read(other),
      plan,
      max_output_bytes=1 << 22,
    )
  } catch {
    Unsupported(message~) => {
      stale = true
      assert_true(message.contains("stale"))
    }
    _ => fail("expected the stale-plan refusal")
  }
  assert_true(stale)
}

///|
/// The no-op plan keeps the snapshot pin: replacing text with itself
/// plans no edits, but the returned plan still refuses to apply to a
/// different snapshot -- the public every-plan-is-pinned contract has
/// no empty-plan exception.
test "a self-replacement plan still refuses a foreign snapshot" {
  let bytes = run_text_fixture()
  let annotated = @docx.read_docx_annotated(bytes)
  let (plan, receipt) = @docx.plan_run_text_replacement(
    annotated,
    annotated.main_story_source(),
    at_relative="p[1]/r[2]",
    expect="beta",
    text="beta",
  )
  inspect(receipt.edit_count(), content="0")
  let other = fixture_docx(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>alpha</w:t></w:r><w:r><w:t>zeta</w:t></w:r></w:p><w:p><w:r><w:t>gamma</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
    ),
  )
  let mut stale = false
  try {
    let _ = @splice.splice_docx_archive(
      try! @mbtzip.read(other),
      plan,
      max_output_bytes=1 << 22,
    )
  } catch {
    Unsupported(message~) => {
      stale = true
      assert_true(message.contains("stale"))
    }
    _ => fail("expected the stale-plan refusal")
  }
  assert_true(stale)
}

///|
/// Criterion (d): a no-op suppresses byte EDITING, never VALIDATION.
///
/// The public entry used to return an empty pinned plan as soon as
/// `text == expect`, before the surgery ever ran, so a caller received a
/// SUCCESS receipt for a run the surgery would have refused and could
/// not learn the run was unwritable by writing what it already said.
///
/// The fixture matters: the addressed run must PROJECT the expected
/// text and still be unwritable, or the expectation check refuses first
/// and the trial witnesses nothing. This run projects "old" and owns a
/// suppressed `w:footnoteRef`.
test "a self-replacement is validated, not waved through" {
  let owning =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:footnoteRef/><w:t>old</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
  let annotated = @docx.read_docx_annotated(fixture_docx(owning))
  for text in ["old", "new"] {
    let mut refusal = ""
    try {
      let _ = @docx.plan_run_text_replacement(
        annotated,
        annotated.main_story_source(),
        at_relative="p[1]/r[1]",
        expect="old",
        text~,
      )
    } catch {
      Unsupported(message~) => refusal = message
      _ => fail("expected the surgery's own refusal")
    }
    // Named, so a refusal from the EXPECTATION check cannot stand in
    // for the one this trial is about.
    assert_true(
      refusal.contains("suppressed content"),
      msg="setting the run to '" +
        text +
        "' should raise the suppressed-content refusal, got '" +
        refusal +
        "'",
    )
  }
  // A writable run still no-ops exactly as before: zero edits.
  let plain = @docx.read_docx_annotated(run_text_fixture())
  let (_, receipt) = @docx.plan_run_text_replacement(
    plain,
    plain.main_story_source(),
    at_relative="p[1]/r[2]",
    expect="beta",
    text="beta",
  )
  inspect(receipt.edit_count(), content="0")
}
