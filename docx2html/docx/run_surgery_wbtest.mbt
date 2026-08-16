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
/// Apply planned edits, checking they neither overlap nor run backwards.
///
/// On bytes, not on a `String`: the projection's offsets index the part's UTF-8
/// bytes, while a MoonBit `String` is indexed in UTF-16 units. The two agree
/// only while the document is ASCII, so slicing the string would have quietly
/// worked for every test here and broken on the first document with an accent
/// in it.
fn apply_run_surgery_edits(
  source : Bytes,
  edits : Array[RunSurgeryEdit],
) -> Bytes raise {
  let out : Array[Byte] = []
  let mut cursor = 0
  for edit in edits {
    assert_true(edit.byte_start >= cursor)
    assert_true(edit.byte_end >= edit.byte_start)
    assert_true(edit.byte_end <= source.length())
    for at in cursor..<edit.byte_start {
      out.push(source[at])
    }
    for byte in @utf8.encode(edit.replacement) {
      out.push(byte)
    }
    cursor = edit.byte_end
  }
  for at in cursor..<source.length() {
    out.push(source[at])
  }
  Bytes::from_array(out)
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
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  let edits = plan_whole_run_replacement(
    projection, bytes, paragraph, run, text,
  )
  let spliced_bytes = apply_run_surgery_edits(bytes, edits)
  let spliced = @utf8.decode(spliced_bytes)
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
    "word/document.xml", spliced_bytes,
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
      spliced_prefix_matches(bytes, spliced_bytes, cursor, edit.byte_start),
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
  source : Bytes,
  spliced : Bytes,
  start : Int,
  end : Int,
) -> Bool {
  if end <= start {
    return true
  }
  let width = end - start
  let mut at = 0
  while at + width <= spliced.length() {
    let mut matched = true
    for offset in 0..<width {
      if spliced[at + offset] != source[start + offset] {
        matched = false
        break
      }
    }
    if matched {
      return true
    }
    at = at + 1
  }
  false
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
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  for address in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
    let (paragraph, run) = address
    let mut refused = false
    try
      plan_whole_run_replacement(projection, bytes, paragraph, run, "x")
    catch {
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
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 0, "a\u{0000}b") catch {
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
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 0, "x") catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused)
}

///|
/// A self-closing `w:t` has no content range to write into.
///
/// The scanner puts its content range at the element's end, so writing there
/// would insert *after* `/>` and leave no closing tag. Splicing it produced
/// `<w:t/ xml:space="preserve"> x </w:r>`, which does not parse -- found by
/// trying the case rather than by reading the code, since every test until then
/// used a paired `w:t`.
test "whole-run replacement rewrites a self-closing w:t" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t/></w:r></w:p>",
    paragraph=0,
    run=0,
    "written",
    expected="written\n\n",
  )
  assert_whole_run_replacement(
    "<w:p><w:r><w:t/></w:r></w:p>",
    paragraph=0,
    run=0,
    " spaced ",
    expected=" spaced \n\n",
  )
}

///|
/// `xml:space` is added only when it is not already there.
///
/// A second declaration is malformed, and this reader accepts it without
/// complaint -- the duplicate only showed up by looking at the spliced bytes.
/// Word would not be so forgiving.
test "whole-run replacement does not duplicate xml:space" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t xml:space="preserve"> old </w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, " new ")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), " new \n\n")
  // exactly one declaration survives
  let mut declarations = 0
  let mut at = 0
  while at + 9 <= spliced.length() {
    if spliced.view(start_offset=at, end_offset=at + 9).to_owned() ==
      "xml:space" {
      declarations = declarations + 1
    }
    at = at + 1
  }
  assert_eq(declarations, 1)
}

///|
/// Byte offsets index bytes.
///
/// The projection's offsets are into the part's UTF-8 bytes, while a MoonBit
/// `String` is indexed in UTF-16 units. Every test above is ASCII, where the
/// two agree, so a string-based splice would have passed all of them and
/// mangled the first document with an accent in it.
test "whole-run replacement handles a non-ascii document" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>café</w:t></w:r><w:r><w:t>über</w:t></w:r></w:p>",
    paragraph=0,
    run=1,
    "naïve",
    expected="cafénaïve\n\n",
  )
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>a😀b</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "😀😀",
    expected="😀😀\n\n",
  )
}

///|
/// A run whose text the reader already replaces is refused.
///
/// Inside a checkbox content control the projection blanks the replaced text
/// while keeping the contribution, so its bytes stay addressable. Writing into
/// it produced a plan the reader answered by blanking the new text too: asked
/// to set text, the document showed none. Measured before the refusal existed.
test "whole-run replacement refuses text the reader replaces" {
  let properties =
    #|<w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr>
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body><w:sdt>\{properties}<w:sdtContent><w:p><w:r><w:t>old</w:t></w:r></w:p></w:sdtContent></w:sdt></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 0, "new") catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused)
}

///|
/// `xml:space="default"` is replaced, not joined.
///
/// Detecting the attribute is not enough -- `default` declares the opposite of
/// what edge whitespace needs, so a plan that only avoided duplicates would
/// leave Word to strip the text it had just been asked to write.
test "whole-run replacement replaces a wrong xml:space value" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t xml:space="default">old</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = scan_reader_order_projection("word/document.xml", bytes)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, " new ")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), " new \n\n")
  assert_true(spliced.contains("xml:space=\"preserve\""))
  assert_true(!spliced.contains("xml:space=\"default\""))
}

///|
/// Synthesis uses the prefix the run itself is written with.
///
/// A part is free to bind the WML namespace to any prefix, or to make it the
/// default. Hard-coding `<w:t>` produces an unbound prefix there, and a
/// hard-coded `</w:r>` against an `<x:r/>` opening is not even well-formed.
test "whole-run synthesis is namespace-correct" {
  let cases = [
    // an alternate prefix, self-closing run
    (
      "<x:document xmlns:x=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><x:body><x:p><x:r/></x:p></x:body></x:document>",
      "written",
    ),
    // and an alternate prefix with a paired run holding only properties
    (
      "<x:document xmlns:x=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><x:body><x:p><x:r><x:rPr><x:b/></x:rPr></x:r></x:p></x:body></x:document>",
      "written",
    ),
  ]
  for case in cases {
    let (source, text) = case
    let bytes = @utf8.encode(source)
    let projection = scan_reader_order_projection("word/document.xml", bytes)
    let edits = plan_whole_run_replacement(projection, bytes, 0, 0, text)
    let spliced_bytes = apply_run_surgery_edits(bytes, edits)
    let spliced = @utf8.decode(spliced_bytes)
    // it parses, and the reader sees the text
    assert_eq(current_reader_story_text(spliced), "written\n\n")
    // written with the document's own prefix, not a borrowed one
    assert_true(spliced.contains("<x:t>"))
    assert_true(!spliced.contains("<w:t>"))
  }
}
