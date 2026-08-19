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
/// The one construction path every surgery test uses: the story joined,
/// segmented and projected from the reader's OWN read, fields classified.
fn surgery_native_projection(source : String) -> ReaderProjection raise {
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  guard segment_joined_reader_story(
      "word/document.xml",
      story,
      empty_body_reader({ relationships: [] }),
    )
    is SegmentedStory(output) else {
    fail("expected the story to segment")
  }
  guard project_joined_reader_output(output) is Projected(projection) else {
    fail("expected a projection")
  }
  classify_reader_projection_fields(projection)
  projection
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
  // The native projection is derived from the reader's OWN joined read,
  // so the projection/reader disagreement class (#436) is closed by
  // construction -- there is no second story to agree with.
  let projection = surgery_native_projection(source)
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
  let reprojected = surgery_native_projection(spliced)
  assert_true(paragraph < reprojected.paragraphs.length())
  let edited = reprojected.paragraphs[paragraph]
  assert_true(run < edited.runs.length())
  let target = edited.runs[run].source
  let seen = StringBuilder::new()
  let mut found = false
  for contribution in edited.contributions {
    if contribution.run_source == Some(target) {
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
  assert_untouched_bytes_survive(bytes, spliced_bytes, edits)
  // The check above exempts exactly what the plan declared, so it cannot see a
  // declaration that is itself too wide. What a correct plan is *allowed* to
  // touch is derived here from the projection instead: the run's own element,
  // and nothing else in the part.
  assert_edits_touch_only_editable_bytes(projection, edits, paragraph, run)
}

///|
/// Every edit falls on something a whole-run replacement is allowed to touch.
///
/// Bounding edits by the run's outer span was too loose: replacing
/// `<w:rPr>...</w:rPr><w:tab/>` wholesale stays inside the run, reads back
/// correctly and re-projects correctly, while silently deleting the run's
/// formatting.
///
/// The allowlist is built from the source tree -- where each atom and each
/// `w:t` actually sits -- not from the plan. It says which bytes could
/// legitimately be involved; which of them a correct plan chooses is what the
/// other assertions are for. Run properties are not in it, which is what makes
/// the wholesale replacement above fail.
fn assert_edits_touch_only_editable_bytes(
  projection : ReaderProjection,
  edits : Array[RunSurgeryEdit],
  paragraph : Int,
  run : Int,
) -> Unit raise {
  let elements = projection.scan.elements()
  let target = projection.paragraphs[paragraph].runs[run].source
  let allowed : Array[(Int, Int)] = []
  for contribution in projection.paragraphs[paragraph].contributions {
    if contribution.run_source == Some(target) {
      let SourceElementId(source_identity) = contribution.source
      let element = elements[source_identity]
      match contribution.kind {
        // boundaries and suppressed content are preserved, never touched
        Transparent | SuppressedContent => ()
        ProjectedText(FromText) =>
          if is_wml_uri(element.uri) && element.local_name == "t" {
            // its text, its open tag where `xml:space` lives, and the `/>` a
            // self-closing one turns into a body
            if element.content_start == element.byte_end {
              allowed.push((element.byte_end - 2, element.byte_end))
              allowed.push((element.byte_start, element.byte_end - 2))
            } else {
              allowed.push((element.content_start, element.content_end))
              allowed.push((element.byte_start, element.content_start))
            }
          } else {
            allowed.push((element.byte_start, element.byte_end))
          }
        _ => allowed.push((element.byte_start, element.byte_end))
      }
    }
  }
  // a run with nothing to replace still needs somewhere to put the text
  let SourceElementId(run_identity) = target
  let run_element = elements[run_identity]
  allowed.push((run_element.content_start, run_element.content_start))
  allowed.push((run_element.content_end, run_element.content_end))
  if run_element.content_start == run_element.byte_end {
    allowed.push((run_element.byte_end - 2, run_element.byte_end))
  }
  let mut child = run_element.first_child_index
  while child >= 0 {
    let candidate = elements[child]
    if is_wml_uri(candidate.uri) && candidate.local_name == "rPr" {
      allowed.push((candidate.byte_end, candidate.byte_end))
    }
    child = candidate.next_sibling_index
  }
  for edit in edits {
    let mut inside = false
    for span in allowed {
      let (from, to) = span
      if edit.byte_start >= from && edit.byte_end <= to {
        inside = true
      }
    }
    assert_true(inside)
  }
}

///|
/// Every byte the plan did not claim is still there, at the offset the plan's
/// length changes put it.
///
/// Searching for the slice anywhere in the output was too weak: a removal
/// spanning more than it declared could still leave a matching run of bytes
/// somewhere else. This walks the whole part, exempting exactly the declared
/// ranges and requiring everything else to appear at its shifted position --
/// including the tail after the last edit, which the search version skipped.
fn assert_untouched_bytes_survive(
  source : Bytes,
  spliced : Bytes,
  edits : Array[RunSurgeryEdit],
) -> Unit raise {
  let mut cursor = 0
  let mut shift = 0
  for edit in edits {
    for at in cursor..<edit.byte_start {
      assert_eq(spliced[at + shift], source[at])
    }
    shift = shift +
      @utf8.encode(edit.replacement).length() -
      (edit.byte_end - edit.byte_start)
    cursor = edit.byte_end
  }
  for at in cursor..<source.length() {
    assert_eq(spliced[at + shift], source[at])
  }
  assert_eq(spliced.length(), source.length() + shift)
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
  let projection = surgery_native_projection(source)
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
  let projection = surgery_native_projection(source)
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
  let projection = surgery_native_projection(source)
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
  let projection = surgery_native_projection(source)
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
  let projection = surgery_native_projection(source)
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
  let projection = surgery_native_projection(source)
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
    let projection = surgery_native_projection(source)
    let edits = plan_whole_run_replacement(projection, bytes, 0, 0, text)
    let spliced_bytes = apply_run_surgery_edits(bytes, edits)
    let spliced = @utf8.decode(spliced_bytes)
    // it parses, and the reader sees the text
    assert_eq(current_reader_story_text(spliced), "written\n\n")
    // written with the document's own prefix, not a borrowed one
    // the document's own prefix, and a binding that makes it mean WML wherever
    // it landed
    assert_true(spliced.contains("<x:t xmlns:x="))
    assert_true(spliced.contains("</x:t>"))
    assert_true(!spliced.contains("<w:t"))
  }
}

///|
/// A run reaching into a second logical paragraph is refused.
///
/// `p[i]/r[j]` names a run within a paragraph, not a physical run uniquely: a
/// run whose content straddles a nested block is re-opened after the split and
/// so appears in both halves. Editing it by naming one half would rewrite
/// bytes the other half also owns -- incomplete for one, a surprise for the
/// other.
///
/// This was found by asserting the opposite invariant and watching it fail
/// after 57 generated documents, not by reasoning about the walk.
test "whole-run replacement refuses a run that spans two paragraphs" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>before</w:t><w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:t>after</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 0, "new") catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused)
}

///|
/// A reader paragraph joined from several physical ones is still editable.
///
/// A deleted paragraph mark joins two physical paragraphs into one reader
/// paragraph, so its runs come from different sources. That is not ambiguous
/// -- each run still belongs to exactly this paragraph -- and refusing it
/// would rule out a shape real documents contain.
test "whole-run replacement handles a paragraph joined from two sources" {
  assert_whole_run_replacement(
    "<w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>first</w:t></w:r></w:p><w:p><w:r><w:t>second</w:t></w:r></w:p>",
    paragraph=0,
    run=1,
    "changed",
    expected="firstchanged\n\n",
  )
}

///|
/// Synthesised text goes where the atom it replaces was, not at the run's end.
///
/// Putting it at the run's content end walks it past every seam the run
/// contains: for `<bookmarkStart/><tab/><bookmarkEnd/>` the tab is deleted and
/// the replacement lands *outside* the bookmark, reading the same and meaning
/// something else.
test "whole-run synthesis lands inside the run's seams" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:bookmarkStart w:id="1" w:name="b"/><w:tab/><w:bookmarkEnd w:id="1"/></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, "inside")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), "inside\n\n")
  // between the bookmark's ends, where the tab was
  let opened = spliced.contains(
    "<w:bookmarkStart w:id=\"1\" w:name=\"b\"/><w:t xmlns:w=",
  )
  assert_true(opened)
  assert_true(spliced.contains(">inside</w:t><w:bookmarkEnd"))
}

///|
/// Run properties keep their place when a `w:t` is synthesised.
test "whole-run synthesis goes after w:rPr" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:rPr><w:b/></w:rPr></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, "bold")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), "bold\n\n")
  assert_true(spliced.contains("</w:rPr><w:t xmlns:w="))
  assert_true(spliced.contains(">bold</w:t>"))
}

///|
/// Field instruction text is machinery, not content.
///
/// Rewriting it changes what the field computes rather than what it shows. A
/// field's cached *result* is content and stays editable -- checked rather than
/// refused by association.
test "whole-run replacement refuses field instructions but not results" {
  let field =
    #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText>PAGE</w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>7</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\{field}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 1, "GONE") catch {
    _ => refused = true
  } noraise {
    _ => ()
  }
  assert_true(refused)
  // the result run is content
  let edits = plan_whole_run_replacement(projection, bytes, 0, 3, "8")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), "8\n\n")
  // The case above refuses for a reason that would hold anyway: `w:instrText`
  // is a hard barrier. This one needs the field classification -- a plain
  // `w:t` inside the instruction region looks like ordinary content and is
  // not, and with the region check removed it is accepted.
  let plain =
    #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:t>PAGE</w:t></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>7</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
  let plain_source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\{plain}</w:body></w:document>"
  let plain_bytes = @utf8.encode(plain_source)
  let plain_projection = surgery_native_projection(plain_source)
  let mut plain_refused = false
  try
    plan_whole_run_replacement(plain_projection, plain_bytes, 0, 1, "X")
  catch {
    _ => plain_refused = true
  } noraise {
    _ => ()
  }
  assert_true(plain_refused)
}

///|
/// A run inside a text box is editable.
///
/// Its paragraph reaches the story through the extras pass rather than the
/// content walk, but its runs are ordinary elements with ordinary spans, so
/// there is nothing to refuse. Checked rather than refused by association.
test "whole-run replacement reaches a run inside a text box" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>inner</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>",
    paragraph=1,
    run=0,
    "edited",
    expected="\n\nedited\n\n",
  )
}

///|
/// Characters XML cannot carry are refused, and a carriage return is written
/// as a reference because the parser would otherwise turn it into a newline.
test "whole-run replacement validates the replacement text" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  for bad in ["a\u{0001}b", "a\u{FFFE}b", "a\u{FFFF}b"] {
    let mut refused = false
    try plan_whole_run_replacement(projection, bytes, 0, 0, bad) catch {
      _ => refused = true
    } noraise {
      _ => ()
    }
    assert_true(refused)
  }
  // a carriage return survives as itself rather than becoming a newline
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, "a\rb")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_true(spliced.contains("&#xD;"))
  assert_eq(current_reader_story_text(spliced), "a\rb\n\n")
}

///|
/// `xml:space` is found where an attribute name can start, not anywhere.
///
/// The same text can sit inside another attribute's *value*. Matching there
/// produced a range running from the middle of one value to the quote of the
/// next, and replacing it wrote `w:id="xml:space="preserve"x"` -- which does
/// not parse. Found by trying the shape, not by reading the scan.
///
/// The declaration is also written with either quote style, with spaces around
/// the `=`, and on a self-closing element.
test "whole-run replacement finds xml:space only as an attribute" {
  let document = fn(body : String) -> String {
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\{body}</w:body></w:document>"
  }
  let cases = [
    // the name inside another attribute's value, with one following it
    "<w:p><w:r><w:t w:id=\"xml:space\" w:rsid=\"x\">old</w:t></w:r></w:p>",
    // and with nothing following
     "<w:p><w:r><w:t w:id=\"xml:space\">old</w:t></w:r></w:p>",
    // genuine declarations in every spelling
     "<w:p><w:r><w:t xml:space=\"default\">old</w:t></w:r></w:p>", "<w:p><w:r><w:t xml:space='default'>old</w:t></w:r></w:p>",
    "<w:p><w:r><w:t xml:space = \"default\">old</w:t></w:r></w:p>", "<w:p><w:r><w:t w:id=\"1\" xml:space=\"default\">old</w:t></w:r></w:p>",
    "<w:p><w:r><w:t xml:space=\"default\"/></w:r></w:p>",
  ]
  for body in cases {
    let source = document(body)
    let bytes = @utf8.encode(source)
    let projection = surgery_native_projection(source)
    let edits = plan_whole_run_replacement(projection, bytes, 0, 0, " new ")
    let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
    // it parses, reads back, and preserves the edge whitespace
    assert_eq(current_reader_story_text(spliced), " new \n\n")
    assert_true(spliced.contains("xml:space=\"preserve\""))
    assert_true(!spliced.contains("xml:space=\"default\""))
    assert_true(!spliced.contains("xml:space='default'"))
  }
}

///|
/// No run inside a checkbox content control can be edited.
///
/// The transform replaces the *first* text in the whole control, so editing an
/// earlier run that had none moves the replacement onto the new text and lets
/// the text it had been hiding through. Measured on a control holding a
/// tab-only run and then `secret`: asked to set the first run to "MINE", the
/// document went from showing a tab to showing "secret". The caller's text
/// vanished and hidden text appeared.
///
/// Refusing only runs whose own text was blanked did not cover this, which is
/// why the refusal is by ancestry.
test "whole-run replacement refuses every run inside a checkbox control" {
  let properties =
    #|<w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr>
  let content =
    #|<w:p><w:r><w:tab/></w:r><w:r><w:t>secret</w:t></w:r></w:p>
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body><w:sdt>\{properties}<w:sdtContent>\{content}</w:sdtContent></w:sdt></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // the run whose text is suppressed, and the earlier one that has none
  for run in [0, 1] {
    let mut refused = false
    try plan_whole_run_replacement(projection, bytes, 0, run, "MINE") catch {
      _ => refused = true
    } noraise {
      _ => ()
    }
    assert_true(refused)
  }
}

///|
/// Supplementary-plane noncharacters are permitted.
///
/// XML 1.0 excludes `U+FFFE` and `U+FFFF` from `Char`; the other planes'
/// equivalents are discouraged but legal, and refusing them would reject text a
/// conforming parser accepts.
test "whole-run replacement accepts supplementary noncharacters" {
  assert_whole_run_replacement(
    "<w:p><w:r><w:t>old</w:t></w:r></w:p>",
    paragraph=0,
    run=0,
    "a\u{1FFFE}b",
    expected="a\u{1FFFE}b\n\n",
  )
}

///|
/// Visible non-text -- a break here -- is reader-visible content the
/// plan has no representation for: replacing "the run's text" cannot
/// say what removing the break would cost, so it refuses.
test "whole-run replacement refuses visible non-text content" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t><w:br/></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 0, "x") catch {
    Unsupported(message~) => {
      refused = true
      assert_true(message.contains("visible non-text"))
    }
    _ => fail("expected an Unsupported refusal")
  } noraise {
    _ => ()
  }
  assert_true(refused)
}

///|
/// A suppressed site is a classified nothing, not a barrier: the reader
/// decided it contributes no content, so replacing the run's text
/// neither needs nor may touch its bytes.
test "whole-run replacement preserves suppressed content in the run" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:footnoteRef/><w:t>old</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // precondition: the marker really is a suppressed contribution owned
  // by this run -- otherwise this test witnesses nothing
  let target = projection.paragraphs[0].runs[0].source
  let mut suppressed_owned = false
  for contribution in projection.paragraphs[0].contributions {
    if contribution.run_source == Some(target) &&
      contribution.kind is SuppressedContent {
      suppressed_owned = true
    }
  }
  assert_true(suppressed_owned)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, "new")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), "new\n\n")
  assert_true(spliced.contains("<w:footnoteRef/>"))
  assert_untouched_bytes_survive(bytes, @utf8.encode(spliced), edits)
  assert_edits_touch_only_editable_bytes(projection, edits, 0, 0)
}

///|
/// Two contributions sharing one physical source would compose two
/// edits over one span; the planner refuses rather than composing.
test "whole-run replacement refuses a twice-projected physical element" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // force the defect the guard exists for: the same text contribution
  // observed twice
  let paragraph = projection.paragraphs[0]
  let mut duplicated = false
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) && !duplicated {
      paragraph.contributions.push(contribution)
      duplicated = true
    }
  }
  assert_true(duplicated)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 0, "x") catch {
    Unsupported(message~) => {
      refused = true
      assert_true(message.contains("twice"))
    }
    _ => fail("expected an Unsupported refusal")
  } noraise {
    _ => ()
  }
  assert_true(refused)
}

///|
/// An EMPTY run inside a field is still inside the field: it has no
/// contributions to carry the region, so the run record carries it, and
/// synthesis into an instruction region -- which would change what the
/// field computes -- refuses. Same for a truncated field, whose whole
/// story is malformed.
test "whole-run replacement refuses an empty run inside a field" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r/><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>7</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let mut refused = false
  try plan_whole_run_replacement(projection, bytes, 0, 1, "X") catch {
    Unsupported(message~) => {
      refused = true
      assert_true(message.contains("field instruction"))
    }
    _ => fail("expected an Unsupported refusal")
  } noraise {
    _ => ()
  }
  assert_true(refused)
  // the cached result stays editable, exactly as with a populated run
  let edits = plan_whole_run_replacement(projection, bytes, 0, 3, "8")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), "8\n\n")
  // and a TRUNCATED field's empty run still refuses: its region is the
  // instruction region it sat in (truncation itself is recorded as the
  // field's refusal, not as a region change)
  let truncated =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r/></w:p></w:body></w:document>
  let truncated_bytes = @utf8.encode(truncated)
  let truncated_projection = surgery_native_projection(truncated)
  let mut truncated_refused = false
  try
    plan_whole_run_replacement(truncated_projection, truncated_bytes, 0, 1, "X")
  catch {
    Unsupported(message~) => {
      truncated_refused = true
      assert_true(message.contains("field instruction"))
    }
    _ => fail("expected an Unsupported refusal")
  } noraise {
    _ => ()
  }
  assert_true(truncated_refused)
}

///|
/// #436 CLOSED BY CONSTRUCTION.
///
/// The legacy walker kept its own story: a stray flow-level run a
/// checkbox transform consumed existed for the reader but not for the
/// projection, so from there `p[0]` named a different paragraph on each
/// side and the planner silently rewrote the wrong run -- the defect
/// this test used to pin. The native projection is derived from the
/// reader's OWN joined read, so there is no second story to disagree
/// with: both paragraphs project, every run inside the checkbox control
/// refuses by ancestry, and the paragraph that used to take the mis-edit
/// is addressable at its true index.
test "a checkbox-consumed flow run no longer shifts addresses" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:r><w:t>x</w:t></w:r><w:p><w:r><w:tab/></w:r></w:p></w:sdtContent></w:sdt><w:p><w:r><w:t>z</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  assert_eq(current_reader_story_text(source), "\t\n\nz\n\n")
  let projection = surgery_native_projection(source)
  // Two paragraphs to the reader, two to the projection.
  assert_eq(reader_paragraph_texts(source).length(), 2)
  assert_eq(projection.paragraphs.length(), 2)
  // Both physical runs are registered -- the transformed flow run and
  // the tab run -- and EACH refuses by checkbox ancestry specifically.
  // document=0 body=1 sdt=2 sdtPr=3 checkbox=4 sdtContent=5 r=6 t=7
  // p=8 r=9 tab=10 p=11 r=12 t=13
  let run_ids : Array[Int] = []
  for run in projection.paragraphs[0].runs {
    let SourceElementId(id) = run.source
    run_ids.push(id)
  }
  assert_eq(run_ids, [6, 9])
  for run_index in 0..<projection.paragraphs[0].runs.length() {
    let mut refused = false
    try
      plan_whole_run_replacement(projection, bytes, 0, run_index, "EDITED")
    catch {
      Unsupported(message~) => {
        refused = true
        assert_true(message.contains("checkbox"))
      }
      _ => fail("expected an Unsupported refusal")
    } noraise {
      _ => ()
    }
    assert_true(refused)
  }
  // The paragraph that used to take the mis-edit edits at its own index.
  let edits = plan_whole_run_replacement(projection, bytes, 1, 0, "EDITED")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_eq(current_reader_story_text(spliced), "\t\n\nEDITED\n\n")
}
