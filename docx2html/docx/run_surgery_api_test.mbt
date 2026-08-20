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
  let (plan, receipt) = @docx.plan_run_text_replacement_archive(
    annotated,
    archive,
    annotated.main_story_source(),
    at_relative="p[1]/r[2]",
    expect="beta",
    text="BETA",
  )
  inspect(
    (
      receipt.story_part(),
      receipt.at_relative(),
      receipt.replaced_text(),
      receipt.edit_count(),
    ),
    content=(
      #|(word/document.xml, p[1]/r[2], beta, 1)
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
    if pair.to_string().length() > 0 {
      texts.push(pair.to_string())
    }
  }
  inspect(
    texts,
    content=(
      #|[alphaBETA, gamma]
    ),
  )
  // and the edited package still reads mutation-safe with a fresh
  // projection: the address is re-usable on the NEW snapshot
  let (_, again) = @docx.plan_run_text_replacement_archive(
    reread,
    try! @mbtzip.read(spliced),
    reread.main_story_source(),
    at_relative="p[1]/r[2]",
    expect="BETA",
    text="beta",
  )
  inspect(again.replaced_text(), content="BETA")
}

///|
test "an addressed run replacement refuses every wrong premise typed" {
  let bytes = run_text_fixture()
  let archive = try! @mbtzip.read(bytes)
  let annotated = @docx.read_docx_annotated_archive(archive)
  fn refusal(at : String, expect : String) -> String raise {
    try {
      let _ = @docx.plan_run_text_replacement_archive(
        annotated,
        archive,
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
    let _ = @docx.plan_run_text_replacement_archive(
      tolerant,
      archive,
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
    let _ = @docx.plan_run_text_replacement_archive(
      annotated,
      archive,
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
  // the cached result stays plannable
  let (_, receipt) = @docx.plan_run_text_replacement_archive(
    annotated,
    archive,
    annotated.main_story_source(),
    at_relative="p[1]/r[4]",
    expect="7",
    text="8",
  )
  inspect(receipt.edit_count(), content="1")
}
