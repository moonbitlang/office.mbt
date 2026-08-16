// Whole-run surgery, checked against the reader rather than against the plan.
//
// The temptation is to verify a splice by comparing it with what the
// projection predicted, but the plan was built *from* the projection -- that
// oracle would share its premise with the code and pass while the edit landed
// on the wrong bytes. So every case here applies the edits to the source,
// re-parses the result from scratch, runs the real `BodyReader` over it, and
// requires *its* story text to be what was asked for.
//
// The second half of the claim is independent by construction: every byte
// outside the edited ranges is compared with the original.

///|
/// Apply planned edits to a source string, checking they neither overlap nor
/// run backwards.
fn apply_run_surgery_edits(
  source : String,
  edits : Array[RunSurgeryEdit],
) -> String raise {
  let out = StringBuilder::new()
  let mut cursor = 0
  for edit in edits {
    assert_true(edit.byte_start >= cursor)
    assert_true(edit.byte_end >= edit.byte_start)
    assert_true(edit.byte_end <= source.length())
    out.write_string(
      source.view(start_offset=cursor, end_offset=edit.byte_start).to_owned(),
    )
    out.write_string(edit.replacement)
    cursor = edit.byte_end
  }
  out.write_string(source.view(start_offset=cursor).to_owned())
  out.to_string()
}

///|
/// Replace `p[paragraph]/r[run]`'s text and require the reader to agree.
fn assert_whole_run_replacement(
  body : String,
  paragraph~ : Int,
  run~ : Int,
  text : String,
  expected~ : String,
) -> Unit raise {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  let edits = plan_whole_run_replacement(projection, paragraph, run, text)
  let spliced = apply_run_surgery_edits(source, edits)
  // The claim: re-read the edited bytes with the real reader.
  assert_eq(current_reader_story_text(spliced), expected)
  // Reader equality alone is not enough, and mutation testing showed exactly
  // where it falls short: a `w:t` synthesised *outside* the run reads the same
  // as one inside it, and this reader does not strip edge whitespace whether
  // or not `xml:space` is declared. Both would be wrong in Word and both would
  // break the address.
  //
  // So re-project the spliced bytes and require the same address to still name
  // that run, now carrying the new text. That is not circular: it is a
  // different document, parsed from scratch, and it is the invariant surgery
  // actually needs -- an edit you cannot address again is an edit you cannot
  // build on.
  let reprojected = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(spliced),
  )
  assert_true(paragraph < reprojected.paragraphs.length())
  let edited = reprojected.paragraphs[paragraph]
  let seen = StringBuilder::new()
  let mut found = false
  for contribution in edited.contributions {
    if contribution.logical_run_index == run &&
      contribution.run_identity is Some(_) {
      found = true
      seen.write_string(contribution.value)
    }
  }
  assert_true(found)
  assert_eq(seen.to_string(), text)
  // And the whitespace policy, which no reader assertion here can see.
  if text.length() > 0 && text != text.trim(chars=" \t\n\r").to_owned() {
    assert_true(spliced.contains("xml:space=\"preserve\""))
  }
  // And every byte outside the edited ranges is untouched.
  let mut cursor = 0
  for edit in edits {
    assert_eq(
      spliced_prefix_matches(source, spliced, cursor, edit.byte_start),
      true,
    )
    cursor = edit.byte_end
  }
}

///|
/// Whether `[start, end)` of the original survives somewhere in the splice.
///
/// The offsets shift as earlier edits change length, so this compares the
/// slice's content rather than its position.
fn spliced_prefix_matches(
  source : String,
  spliced : String,
  start : Int,
  end : Int,
) -> Bool {
  if end <= start {
    return true
  }
  let slice = source.view(start_offset=start, end_offset=end).to_owned()
  spliced.contains(slice)
}

///|
test "whole-run replacement rewrites the first w:t in place" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>old</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "new",
    expected="new\n\n",
  )
}

///|
test "whole-run replacement empties later w:t elements" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>one</w:t><w:t>two</w:t><w:t>three</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "only",
    expected="only\n\n",
  )
}

///|
test "whole-run replacement removes the run's other projecting atoms" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>a</w:t><w:tab/><w:softHyphen/><w:noBreakHyphen/><w:t>b</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "x",
    expected="x\n\n",
  )
}

///|
test "whole-run replacement leaves other runs alone" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>first</w:t></w:r><w:r><w:t>second</w:t></w:r></w:p>",
    paragraph=0,
    run=1,
    "changed",
    expected="firstchanged\n\n",
  )
}

///|
test "whole-run replacement escapes structural characters" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>old</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "a & b < c > d",
    expected="a & b < c > d\n\n",
  )
}

///|
test "whole-run replacement synthesises a w:t for a self-closing run" {
  assert_whole_run_replacement(
    "<w:p><w:r/></w:p>",
    paragraph=0,
    run=0,
    "written",
    expected="written\n\n",
  )
}

///|
test "whole-run replacement synthesises a w:t for an atom-only run" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:tab/></w:r></w:p>",
    paragraph=0,
    run=0,
    "written",
    expected="written\n\n",
  )
}

///|
test "whole-run replacement synthesises a w:t for a run with only properties" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:rPr><w:b/></w:rPr></w:r></w:p>",
    paragraph=0,
    run=0,
    "written",
    expected="written\n\n",
  )
}

///|
test "whole-run replacement preserves edge whitespace" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>old</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "  spaced  ",
    expected="  spaced  \n\n",
  )
}

///|
test "whole-run replacement keeps an existing xml:space declaration" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t xml:space=\"preserve\"> old </w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    " new ",
    expected=" new \n\n",
  )
}

///|
test "whole-run replacement reaches a run inside a flattened wrapper" {
  assert_whole_run_replacement(
    "<w:p><w:hyperlink><w:r><w:t>old</w:t></w:r></w:hyperlink></w:p>",
    paragraph=0,
    run=0,
    "new",
    expected="new\n\n",
  )
}

///|
test "whole-run replacement refuses what it cannot address" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  for address in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
    let (paragraph, run) = address
    let mut refused = false
    try plan_whole_run_replacement(projection, paragraph, run, "x") catch {
      _ => refused = true
    } noraise {
      _ => ()
    }
    assert_true(refused)
  }
}

///|
test "whole-run replacement refuses control characters" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  let mut refused = false
  try plan_whole_run_replacement(projection, 0, 0, "a\u{0000}b") catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused)
}

///|
/// A `w:t` whose text came through CDATA is refused.
///
/// The projection knows the text but not how its bytes map to it: `<![CDATA[
/// a<b ]]>` projects `a<b` without any escaping, so rewriting the content
/// range would have to reproduce the CDATA framing or silently change the
/// document's lexical form. The token map records this, and surgery stops.
test "whole-run replacement refuses text drawn from CDATA" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t><![CDATA[a<b]]></w:t></w:r></w:p></w:body></w:document>
  // the reader does see the text, so this is a refusal about *writing*
  assert_eq(current_reader_story_text(source), "a<b\n\n")
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  let mut refused = false
  try plan_whole_run_replacement(projection, 0, 0, "x") catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused)
}
