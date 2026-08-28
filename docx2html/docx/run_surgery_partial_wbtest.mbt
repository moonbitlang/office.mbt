///|
/// N0c2 B1 oracle. Same methodology as run_surgery_wbtest: never verify a
/// splice against the projection that built it — apply the edits, re-read
/// with the REAL reader, and hold the result to the receipt's precomputed
/// paragraph projection; then hold every byte outside the declared union.
fn assert_partial_edits(
  body : String,
  paragraph~ : Int,
  edits : Array[ParagraphTextEdit],
  expected~ : String,
) -> Unit raise {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(
    projection, bytes, paragraph, edits,
  )
  assert_eq(receipt.expected_projection, expected)
  assert_eq(receipt.paragraph_index, paragraph)
  assert_eq(receipt.logical_edits.length(), edits.length())
  let spliced_bytes = apply_run_surgery_edits(bytes, byte_edits)
  let spliced = @utf8.decode(spliced_bytes)
  // The claim, through the real reader: the paragraph now projects exactly
  // the receipt's precomputed string.
  let reprojected = surgery_native_projection(spliced)
  assert_true(paragraph < reprojected.paragraphs.length())
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[paragraph].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), expected)
  // Structural revalidation: the whole story still reads.
  current_reader_story_text(spliced) |> ignore
  // Byte-union witness: every byte outside the declared edits survives at
  // its shifted offset.
  assert_untouched_bytes_survive(bytes, spliced_bytes, byte_edits)
}

///|
fn assert_partial_refusal(
  body : String,
  paragraph~ : Int,
  edits : Array[ParagraphTextEdit],
  refusal~ : String,
) -> Unit raise {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  try
    plan_paragraph_text_edits(projection, bytes, paragraph, edits) |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(
        message.contains("partial surgery [\{refusal}]"),
        msg="expected [\{refusal}] in: \{message}",
      )
    _ => fail("expected a typed partial-surgery refusal")
  } noraise {
    _ => fail("expected refusal [\{refusal}]")
  }
}

///|
fn partial_edit(
  start : Int,
  end : Int,
  replacement : String,
) -> ParagraphTextEdit {
  { start, end, replacement, }
}

///|
test "partial: mid-text replacement inside one w:t" {
  assert_partial_edits(
    "<w:p><w:r><w:t>alpha beta gamma</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(6, 10, "BETA")],
    expected="alpha BETA gamma",
  )
}

///|
test "partial: a mid-text replacement is placed inside the w:t" {
  // The ordinary path, pinned for the same reason the three synthesis and
  // no-op placements are: `InsideText` is what "the text went where the text
  // already was" means, and nothing else in the suite says so.
  let body = "<w:p><w:r><w:t>alpha beta gamma</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(6, 10, "BETA"),
  ])
  assert_eq(receipt.logical_edits.length(), 1)
  guard receipt.logical_edits[0].placement is InsideText else {
    fail("expected an inside-text placement")
  }
  assert_eq(receipt.expected_projection, "alpha BETA gamma")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>alpha BETA gamma</w:t>"))
}

///|
test "partial: several edits in one w:t, adjacent and separated" {
  assert_partial_edits(
    "<w:p><w:r><w:t>one two three</w:t></w:r></w:p>",
    paragraph=0,
    [
      partial_edit(0, 3, "ONE"),
      partial_edit(3, 4, "-"),
      partial_edit(8, 13, "3"),
    ],
    expected="ONE-two 3",
  )
}

///|
test "partial: pure insertion and deletion" {
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 1, "X"), partial_edit(2, 2, "Y")],
    expected="aXbY",
  )
  assert_partial_edits(
    "<w:p><w:r><w:t>abcd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "")],
    expected="ad",
  )
}

///|
test "partial: equal-offset insertions concatenate in request order" {
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 1, "X"), partial_edit(1, 1, "Y")],
    expected="aXYb",
  )
}

///|
test "partial: insertion abutting a consuming edit stays ordered" {
  assert_partial_edits(
    "<w:p><w:r><w:t>abcd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 1, "X"), partial_edit(1, 3, "Z")],
    expected="aXZd",
  )
}

///|
test "partial: edits around entity boundaries preserve outside spellings" {
  // The w:t holds `a&amp;b&lt;c`; projection is `a&b<c`. Replacing `b`
  // touches neither entity, whose spellings must survive byte-identical.
  let body = "<w:p><w:r><w:t>a&amp;b&lt;c</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 3, "B")],
    expected="a&B<c",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(2, 3, "B"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("a&amp;B&lt;c"))
}

///|
test "partial: consuming a whole entity token is permitted" {
  assert_partial_edits(
    "<w:p><w:r><w:t>a&amp;b</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 2, " and ")],
    expected="a and b",
  )
}

///|
test "partial: replacement containing markup characters is escaped" {
  assert_partial_edits(
    "<w:p><w:r><w:t>plain</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 5, "a<b&c>d")],
    expected="a<b&c>d",
  )
}

///|
test "partial: logical no-op over a reference spelling never canonicalizes" {
  // `&#38;` projects `&`. Replacing that `&` with `&` is a logical no-op:
  // ZERO byte edits, so the reference spelling survives byte-identical.
  let body = "<w:p><w:r><w:t>x&#38;y</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 2, "&"),
  ])
  assert_eq(byte_edits.length(), 0)
  assert_eq(receipt.logical_edits.length(), 1)
  guard receipt.logical_edits[0].placement is LogicalNoOp else {
    fail("expected a logical no-op placement")
  }
  assert_eq(receipt.expected_projection, "x&y")
}

///|
test "partial: mid-entity boundary refuses as non-scalar" {
  // `&#128512;` projects one astral character = TWO UTF-16 units; the
  // mid-character offset is a surrogate half.
  assert_partial_refusal(
    "<w:p><w:r><w:t>a&#128512;b</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(2, 3, "x")],
    refusal="NonScalarBoundary",
  )
}

///|
test "partial: surrogate-half boundary in raw text refuses as non-scalar" {
  assert_partial_refusal(
    "<w:p><w:r><w:t>a😀b</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(2, 4, "x")],
    refusal="NonScalarBoundary",
  )
}

///|
test "partial: CDATA in the host refuses" {
  assert_partial_refusal(
    "<w:p><w:r><w:t><![CDATA[secret]]></w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "x")],
    refusal="CDataContext",
  )
}

///|
test "partial: request-shape refusals" {
  let body = "<w:p><w:r><w:t>abcdef</w:t></w:r></w:p>"
  assert_partial_refusal(
    body,
    paragraph=3,
    [partial_edit(0, 1, "x")],
    refusal="InvalidParagraph",
  )
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(4, 9, "x")],
    refusal="InvalidRange",
  )
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(3, 4, "x"), partial_edit(1, 2, "y")],
    refusal="UnorderedEdits",
  )
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(1, 4, "x"), partial_edit(3, 5, "y")],
    refusal="LogicalOverlap",
  )
}

///|
test "partial: a cross-w:t range plans with the start host and a trimmed end" {
  let body = "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    expected="aXd",
  )
  // The replacement lands in the START host; the end w:t keeps its tail.
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>aX</w:t><w:t>d</w:t>"))
}

///|
test "partial: a fully covered middle w:t is emptied in place" {
  let body = "<w:p><w:r><w:t>ab</w:t><w:t>mid</w:t><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 6, "Z")],
    expected="aZd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 6, "Z"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>aZ</w:t><w:t></w:t><w:t>d</w:t>"))
}

///|
test "partial: a whole atom deletes via a covering range" {
  let body = "<w:p><w:r><w:t>ab</w:t><w:tab/><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 3, "")],
    expected="abcd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(2, 3, ""),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>ab</w:t><w:t>cd</w:t>"))
}

///|
test "partial: an atom-start range synthesizes at the atom, inside seams" {
  // Replacement starting AT the atom consumes it and synthesizes a w:t in
  // its place — never appended to the preceding text host.
  let body = "<w:p><w:r><w:t>ab</w:t><w:tab/><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 4, "X")],
    expected="abXd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(2, 4, "X"),
  ])
  guard receipt.logical_edits[0].placement is AtomSynthesis else {
    fail("expected atom synthesis placement")
  }
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>ab</w:t><w:t xmlns:w="))
  assert_true(spliced.contains(">X</w:t><w:t>d</w:t>"))
}

///|
test "partial: splitting an atom refuses as non-scalar" {
  // Webdings 0x64 projects U+1F6E1 — an astral character occupying TWO
  // UTF-16 units — so a range covering only its first unit splits the atom.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:sym w:font=\"Webdings\" w:char=\"0064\"/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(2, 3, "x")],
    refusal="NonScalarBoundary",
  )
}

///|
test "partial: a transparent seam inside the range survives untouched" {
  // A bookmark between the two texts is a transparent seam: the range
  // crosses it, the plan must leave its bytes alone.
  let body = "<w:p><w:r><w:t>ab</w:t><w:bookmarkStart w:id=\"1\" w:name=\"b\"/><w:bookmarkEnd w:id=\"1\"/><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 3, "Y")],
    expected="aYd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, "Y"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(
    spliced.contains(
      "<w:t>aY</w:t><w:bookmarkStart w:id=\"1\" w:name=\"b\"/><w:bookmarkEnd w:id=\"1\"/><w:t>d</w:t>",
    ),
  )
}

///|
test "partial: a cross-run range plans, preserving both run shells" {
  let body = "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>ab</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    expected="aXd",
  )
  // The replacement carries the FIRST run's formatting by construction
  // (it lands in that run's w:t); the second run keeps its shell, rPr,
  // and trimmed text.
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:b/></w:rPr><w:t>aX</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>d</w:t></w:r>",
    ),
  )
}

///|
test "partial: a cross-run range spanning an empty middle run plans" {
  // The empty run between the endpoints contributes nothing but is still
  // gated and its shell survives byte-identical.
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:rPr><w:b/></w:rPr></w:r><w:r><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 3, "Y")],
    expected="aYd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, "Y"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(
    spliced.contains(
      "<w:t>aY</w:t></w:r><w:r><w:rPr><w:b/></w:rPr></w:r><w:r><w:t>d</w:t>",
    ),
  )
}

///|
test "partial: a cross-run range whose middle run sits in a field refuses" {
  // The interval reaches instruction-phase text: the field gate on the
  // involved contributions refuses before any placement — the strongest
  // available refusal for the shape.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:t>PAGE</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 5, "x")],
    refusal="PartialFieldInstruction",
  )
}

///|
test "partial: a cross-run edit ending at an atom consumes it whole" {
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:tab/><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 3, "Z")],
    expected="aZcd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, "Z"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  // The second run keeps its shell and text; only the tab is gone.
  assert_true(spliced.contains("<w:t>aZ</w:t></w:r><w:r><w:t>cd</w:t></w:r>"))
}

///|
test "partial: insertion at a boundary shared by two text hosts is ambiguous" {
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(2, 2, "x")],
    refusal="AmbiguousBoundary",
  )
}

///|
test "partial: field instruction refuses, field result is editable" {
  // Instruction text carried by `w:instrText` is SUPPRESSED in the
  // projection (zero width) and therefore not addressable by coordinates
  // at all; a `w:t` inside the instruction phase projects WITH the
  // FieldInstruction region, which is the reachable refusal shape.
  let instruction_body = "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:t>PAGE</w:t></w:r><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>7</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>"
  assert_partial_refusal(
    instruction_body,
    paragraph=0,
    [partial_edit(0, 1, "x")],
    refusal="PartialFieldInstruction",
  )
  // Criterion (d): the result run's text (`7`, projected after the
  // instruction) refuses too. The reader projects the CACHED value, so a
  // caller's read-back would confirm an edit that the next
  // recalculation discards.
  assert_partial_refusal(
    instruction_body,
    paragraph=0,
    [partial_edit(4, 5, "9")],
    refusal="RestrictedRegion",
  )
}

///|
test "partial: checkbox content control refuses" {
  // The control's FIRST text is rewritten into the glyph (suppressed +
  // visible marker, both zero width); a SECOND text projects normally and
  // is the addressable shape whose ancestry must refuse.
  assert_partial_refusal(
    "<w:p><w:sdt><w:sdtPr><w14:checkbox xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"/></w:sdtPr><w:sdtContent><w:r><w:t>first</w:t></w:r><w:r><w:t>extra</w:t></w:r></w:sdtContent></w:sdt></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "x")],
    refusal="PartialCheckboxControl",
  )
}

///|
test "partial: xml:space appears when the post-batch content needs it" {
  let body = "<w:p><w:r><w:t>abc</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 1, " "),
  ])
  assert_eq(receipt.expected_projection, " bc")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("xml:space=\"preserve\""))
  let reprojected = surgery_native_projection(spliced)
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[0].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), " bc")
}

///|
test "partial: an existing declaration is left byte-identical when unneeded" {
  // The edit removes the leading space; the existing declaration (which the
  // final content no longer needs) must not be touched or removed.
  let body = "<w:p><w:r><w:t xml:space=\"preserve\"> abc</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 1, ""),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("xml:space=\"preserve\""))
  assert_eq(byte_edits.length(), 1)
}

///|
test "partial: an untouched neighbouring w:t never gains the attribute" {
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // Edit only the FIRST w:t, giving it edge whitespace.
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 1, " "),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  // Exactly one declaration appears, on the edited host only, and the
  // untouched neighbour keeps its exact original tag.
  let mut count = 0
  for _piece in spliced.split("xml:space") {
    count += 1
  }
  assert_eq(count - 1, 1)
  assert_true(spliced.contains("<w:t>cd</w:t>"))
}

///|
test "partial: whole-content deletion leaves an emptied element in place" {
  let body = "<w:p><w:r><w:t>gone</w:t></w:r><w:r><w:t>stays</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(0, 4, "")],
    expected="stays",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 4, ""),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t></w:t>"))
}

///|
test "partial: an empty batch plans nothing" {
  let body = "<w:p><w:r><w:t>abc</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [])
  assert_eq(byte_edits.length(), 0)
  assert_eq(receipt.expected_projection, "abc")
  assert_eq(receipt.touched_source_count, 0)
}

///|
test "partial: replacement with a forbidden control character refuses typed" {
  assert_partial_refusal(
    "<w:p><w:r><w:t>abc</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "\u{01}")],
    refusal="InvalidReplacement",
  )
}

///|
test "partial: non-ASCII source offsets resolve through UTF-8 correctly" {
  assert_partial_edits(
    "<w:p><w:r><w:t>héllo wörld</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(6, 11, "mönde")],
    expected="héllo mönde",
  )
}

///|
test "partial: precedence is batch-wide by phase, not per edit" {
  let body = "<w:p><w:r><w:t>abcdef</w:t></w:r></w:p>"
  // A later edit's invalid range beats an earlier pair's misordering.
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(3, 4, "x"), partial_edit(1, 2, "y"), partial_edit(4, 9, "z")],
    refusal="InvalidRange",
  )
  // A later edit's structural defect beats an earlier edit's non-scalar
  // endpoint: the astral pair sits at offsets 1-3, the field text after it.
  assert_partial_refusal(
    "<w:p><w:r><w:t>a😀b</w:t></w:r><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:t>PAGE</w:t></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>",
    paragraph=0,
    [partial_edit(2, 3, "x"), partial_edit(5, 6, "y")],
    refusal="PartialFieldInstruction",
  )
}

///|
test "partial: crossing a visible barrier refuses as such" {
  // `ab<w:br/>cd` projects "abcd" with the break as a zero-width visible
  // barrier strictly inside [1,3): the plan has no representation for its
  // cost, so it refuses by name.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:br/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="VisibleBarrier",
  )
}

///|
test "partial: a joined paragraph refuses as multi-physical" {
  assert_partial_refusal(
    "<w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>first</w:t></w:r></w:p><w:p><w:r><w:t>second</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "x")],
    refusal="MultiPhysicalParagraph",
  )
}

///|
test "partial: a malformed field refuses" {
  // Text after an unmatched begin is still INSTRUCTION region (truncation
  // is discovered at story end); a `separate` with no begin is the shape
  // the classifier marks malformed outright.
  assert_partial_refusal(
    "<w:p><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>text</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "x")],
    refusal="PartialMalformedField",
  )
}

///|
test "partial: a truncated field's result refuses as classifier-refused" {
  // begin + separate + result but no end at story end: the result run keeps
  // FieldResult and carries the truncation refusal.
  assert_partial_refusal(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:instrText>PAGE</w:instrText></w:r><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>7</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "x")],
    refusal="RefusedField",
  )
}

///|
test "partial: a self-closing text host refuses in this increment" {
  assert_partial_refusal(
    "<w:p><w:r><w:t/></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 0, "x")],
    refusal="UnsupportedTextSource",
  )
}

///|
test "partial: a twice-projected host refuses as duplicate source" {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // Force the defect the guard exists for, exactly as the N0c1 oracle does.
  let paragraph = projection.paragraphs[0]
  let mut duplicated = false
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) && !duplicated {
      paragraph.contributions.push(contribution)
      duplicated = true
    }
  }
  assert_true(duplicated)
  try
    plan_paragraph_text_edits(projection, bytes, 0, [partial_edit(0, 1, "x")])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[DuplicateSource]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [DuplicateSource]")
  }
}

///|
test "partial: a run reused by another paragraph refuses" {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>one</w:t></w:r></w:p><w:p><w:r><w:t>two</w:t></w:r></w:p></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // Force the defect: paragraph 1 also claims paragraph 0's run.
  projection.paragraphs[1].runs.push(projection.paragraphs[0].runs[0])
  try
    plan_paragraph_text_edits(projection, bytes, 0, [partial_edit(0, 1, "x")])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[CrossParagraphSourceReuse]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [CrossParagraphSourceReuse]")
  }
}

///|
test "partial: two insertions before one atom keep request order" {
  // Both resolve to the same unique before-atom carrier and share one byte
  // anchor: the plan must keep X before Y by construction, not by an
  // unstable sort's accident.
  let body = "<w:p><w:r><w:tab/><w:t>ab</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(0, 0, "X"), partial_edit(0, 0, "Y")],
    expected="XY\tab",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 0, "X"),
    partial_edit(0, 0, "Y"),
  ])
  // One distinct carrier atom, two synthesis operations.
  assert_eq(receipt.touched_source_count, 1)
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  // Both insertions share one carrier and one anchor, so they compose into
  // ONE synthesized element with the replacements concatenated in request
  // order — the same rule equal-offset insertions into a `w:t` follow, and
  // the only shape that cannot collide when the carrier is a self-closing
  // run whose `/>` each synthesis would rewrite.
  assert_true(spliced.contains(">XY</w:t><w:tab/>"))
}

///|
test "partial: insertion after a trailing atom lands after it" {
  let body = "<w:p><w:r><w:t>ab</w:t><w:tab/></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(3, 3, "Z")],
    expected="ab\tZ",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(3, 3, "Z"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:tab/><w:t xmlns:w="))
  assert_true(spliced.contains(">Z</w:t></w:r>"))
}

///|
test "partial: an interior insertion into a twice-projected host refuses" {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>abc</w:t></w:r></w:p></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let paragraph = projection.paragraphs[0]
  let mut duplicated = false
  for contribution in paragraph.contributions {
    if contribution.kind is ProjectedText(FromText) && !duplicated {
      paragraph.contributions.push(contribution)
      duplicated = true
    }
  }
  assert_true(duplicated)
  try
    plan_paragraph_text_edits(projection, bytes, 0, [partial_edit(1, 1, "x")])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[DuplicateSource]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [DuplicateSource]")
  }
}

///|
test "partial: a no-op over CDATA still refuses as CDATA context" {
  // Replacing CDATA-backed text with itself is a logical no-op, but a
  // no-op suppresses byte planning, never validation.
  assert_partial_refusal(
    "<w:p><w:r><w:t><![CDATA[secret]]></w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 6, "secret")],
    refusal="CDataContext",
  )
}

///|
test "partial: consuming from a shared boundary edits the right-hand host" {
  let body = "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 3, "X")],
    expected="abXd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(2, 3, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>ab</w:t><w:t>Xd</w:t>"))
}

///|
test "partial: a barrier exactly at an endpoint is outside the range" {
  // `ab<w:br/>cd`: the break sits at offset 2. An edit consuming [2,4)
  // has the barrier AT its start — before the first consumed contribution
  // — and an edit consuming [0,2) has it AT its end. Both plan.
  let body = "<w:p><w:r><w:t>ab</w:t><w:br/><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 4, "XY")],
    expected="abXY",
  )
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(0, 2, "ZW")],
    expected="ZWcd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(2, 4, "XY"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>ab</w:t><w:br/><w:t>XY</w:t>"))
}

///|
test "partial: xml:space decides per touched host across one edit" {
  // One edit gives the START host trailing whitespace and fully covers the
  // middle host: the start host gains the declaration, the emptied middle
  // and the trimmed end must not.
  let body = "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t><w:t>ef</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 5, " "),
  ])
  assert_eq(receipt.expected_projection, "a f")
  assert_eq(receipt.touched_source_count, 3)
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  let mut declarations = 0
  for _piece in spliced.split("xml:space") {
    declarations += 1
  }
  assert_eq(declarations - 1, 1)
  assert_true(
    spliced.contains(
      "<w:t xml:space=\"preserve\">a </w:t><w:t></w:t><w:t>f</w:t>",
    ),
  )
  let reprojected = surgery_native_projection(spliced)
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[0].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), "a f")
}

///|
test "partial: an empty insertion is a validated no-op" {
  // Interior: plans nothing but still validates (zero byte edits).
  let body = "<w:p><w:r><w:t>abc</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 1, ""),
  ])
  assert_eq(byte_edits.length(), 0)
  guard receipt.logical_edits[0].placement is LogicalNoOp else {
    fail("expected a validated no-op")
  }
  // And validation is real: an empty insertion into CDATA still refuses.
  assert_partial_refusal(
    "<w:p><w:r><w:t><![CDATA[x]]></w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 1, "")],
    refusal="CDataContext",
  )
}

///|
test "partial: a field-poisoned atomless run between endpoints refuses" {
  // The middle run is a bare <w:r/> inside a field's instruction phase: it
  // produces no contribution at all, so only STRUCTURAL run derivation can
  // see it. (The begin/end markers around it are suppressed zero-width and
  // would refuse as SuppressedRegion; the run gate must fire first, on the
  // run's own field state.)
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r/><w:r><w:fldChar w:fldCharType=\"end\"/></w:r><w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="PartialFieldInstruction",
  )
}

///|
test "partial: a runless direct w:t refuses as unsupported" {
  // The tolerant reader admits a w:t sitting directly in the paragraph;
  // with no run shell it has no formatting or field state to gate, so it
  // is not a host.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:t>cd</w:t></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="UnsupportedTextSource",
  )
}

///|
test "partial: a start at run 1's exact end makes run 2 the carrier" {
  let body = "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>ab</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 3, "X")],
    expected="abXd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(2, 3, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  // Run 1 is untouched; run 2 carries the replacement under ITS rPr.
  assert_true(
    spliced.contains(
      "<w:r><w:rPr><w:b/></w:rPr><w:t>ab</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>Xd</w:t></w:r>",
    ),
  )
}

///|
test "partial: cross-run xml:space lands only on the start host" {
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, " "),
  ])
  assert_eq(receipt.expected_projection, "a d")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  let mut declarations = 0
  for _piece in spliced.split("xml:space") {
    declarations += 1
  }
  assert_eq(declarations - 1, 1)
  assert_true(
    spliced.contains(
      "<w:t xml:space=\"preserve\">a </w:t></w:r><w:r><w:t>d</w:t>",
    ),
  )
  let reprojected = surgery_native_projection(spliced)
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[0].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), "a d")
}

///|
test "partial: an edit crossing a hyperlink boundary refuses" {
  // Unlike a tracked insertion or a content control, a hyperlink is
  // restricted only at its EDGE. Text inside one is ordinary editable
  // text, and so is text outside; what cannot work is a range spanning
  // the edge, because the replacement lands at a single carrier and
  // would drag unlinked text into the link or leave linked text out.
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:hyperlink r:id=\"rId9\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:t>cd</w:t></w:r></w:hyperlink></w:p>"
  // Outside -> inside.
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    refusal="RestrictedRegion",
  )
  // Wholly INSIDE the link still edits. A name check on the ancestry
  // would have refused this, which is why the rule compares identities.
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(2, 4, "X")],
    expected="abX",
  )
  // Wholly OUTSIDE still edits too.
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(0, 2, "Y")],
    expected="Ycd",
  )
  // Inside -> outside, the direction a zero-width-contribution check
  // would miss: the reader emits a hyperlink's opening boundary but no
  // closing one, so only an exit crossing exposes that mistake.
  let trailing = "<w:p><w:hyperlink r:id=\"rId9\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:t>ab</w:t></w:r></w:hyperlink><w:r><w:t>cd</w:t></w:r></w:p>"
  assert_partial_refusal(
    trailing,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    refusal="RestrictedRegion",
  )
  // And link -> DIFFERENT link, which shares "inside a hyperlink" on
  // both endpoints and still must refuse.
  let two = "<w:p><w:hyperlink r:id=\"rId9\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:t>ab</w:t></w:r></w:hyperlink><w:hyperlink r:id=\"rId8\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:t>cd</w:t></w:r></w:hyperlink></w:p>"
  assert_partial_refusal(
    two,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    refusal="RestrictedRegion",
  )
}

///|
test "partial: an edit reaching a tracked insertion refuses" {
  // The old behaviour edited THROUGH the wrapper, preserving it. That
  // preserved the markup and falsified the record: the document would
  // then say Ada inserted words Ada never wrote, and accepting the
  // revision later bakes that in. This is not lost text or divergent
  // text -- it is misattributed text, which is why it refuses rather
  // than being handled more carefully.
  let body = "<w:p><w:r><w:t>ab</w:t></w:r><w:ins w:id=\"9\" w:author=\"Ada\" w:date=\"2001-01-01T00:00:00Z\"><w:r><w:t>cd</w:t></w:r></w:ins></w:p>"
  // Crossing in from outside...
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    refusal="RestrictedRegion",
  )
  // ...and wholly inside, which is why the class reads "touches" rather
  // than "crosses".
  assert_partial_refusal(
    body,
    paragraph=0,
    [partial_edit(2, 4, "X")],
    refusal="RestrictedRegion",
  )
  // The same paragraph WITHOUT the insertion still edits, so the refusal
  // is the wrapper's doing and not the geometry's.
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "X")],
    expected="aXd",
  )
}

///|
test "partial: a later run reused by another paragraph refuses" {
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>ab</w:t></w:r><w:r><w:t>cd</w:t></w:r></w:p><w:p><w:r><w:t>two</w:t></w:r></w:p></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  // Force the defect on the SECOND run of paragraph 0.
  projection.paragraphs[1].runs.push(projection.paragraphs[0].runs[1])
  try
    plan_paragraph_text_edits(projection, bytes, 0, [partial_edit(1, 3, "x")])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[CrossParagraphSourceReuse]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [CrossParagraphSourceReuse]")
  }
}

///|
test "partial: a nested run between an outer run's texts is gated" {
  // The reader tolerates nested runs; a nested <w:r/> between the outer
  // run's two texts registers AFTER the outer run, so only physical-span
  // derivation can see it inside the interval. A clean crossing plans —
  // the nested shell survives byte-identical — and a field-poisoned
  // nested run refuses through the run gate.
  let body = "<w:p><w:r><w:t>ab</w:t><w:r/><w:t>cd</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    expected="aXd",
  )
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 3, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("<w:t>aX</w:t><w:r/><w:t>d</w:t>"))
  // Poison the NESTED run's field state (the force-the-defect technique):
  // the byte-span gate must reach it even though no index range and no
  // contribution walk can.
  let poisoned = surgery_native_projection(source)
  let paragraph = poisoned.paragraphs[0]
  assert_eq(paragraph.runs.length(), 2)
  paragraph.runs[1].field_region = FieldInstruction
  try
    plan_paragraph_text_edits(poisoned, bytes, 0, [partial_edit(1, 3, "X")])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[PartialFieldInstruction]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [PartialFieldInstruction]")
  }
}

///|
test "partial: two insertions into an atomless run compose into one element" {
  // The exact regression the coalescer exists for: both insertions target
  // the run's single synthesis anchor, and a self-closing `<w:r/>` makes
  // that anchor the `/>` bytes themselves — emitting them separately
  // collides instead of composing. The generated suite cannot pin this
  // alone: it accepts any typed refusal, and the old defect refused with
  // InternalPlanConflict.
  let body = "<w:p><w:r/></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 0, "X"),
    partial_edit(0, 0, "Y"),
  ])
  assert_eq(byte_edits.length(), 1)
  assert_eq(receipt.expected_projection, "XY")
  guard receipt.logical_edits[0].placement is RunSynthesis else {
    fail("expected run synthesis")
  }
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains(">XY</w:t></w:r>"))
  let reprojected = surgery_native_projection(spliced)
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[0].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), "XY")
}

///|
test "partial: an insertion and a consuming edit at one atom anchor compose" {
  // The other mixed shape at a single anchor: a zero-width synthesis
  // before the atom and a consuming replacement of it must both land,
  // insertion first, without colliding.
  let body = "<w:p><w:r><w:tab/><w:t>ab</w:t></w:r></w:p>"
  assert_partial_edits(
    body,
    paragraph=0,
    [partial_edit(0, 0, "X"), partial_edit(0, 1, "Y")],
    expected="XYab",
  )
}

///|
test "partial: atomless synthesis refuses a run shared with another paragraph" {
  // The reader tolerates a nested `w:p`; its two logical paragraphs share
  // the OUTER run. Synthesizing into the empty one would write into the
  // other paragraph's text while the receipt described this one — the
  // projecting paths catch this through their contributions, but the
  // atomless path has none, so it needs its own check.
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:p><w:r><w:t>inner</w:t></w:r></w:p></w:r></w:p></w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let mut empty_index = -1
  for index, paragraph in projection.paragraphs {
    if paragraph.projection_end == paragraph.projection_start {
      empty_index = index
    }
  }
  guard empty_index >= 0 else { fail("expected an empty logical paragraph") }
  try
    plan_paragraph_text_edits(projection, bytes, empty_index, [
      partial_edit(0, 0, "X"),
    ])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[CrossParagraphSourceReuse]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [CrossParagraphSourceReuse]")
  }
}

///|
test "partial: a quoted attribute value is not mistaken for xml:space" {
  // `data='x xml:space = \"bogus\"'` satisfies the name-start and `=`
  // checks a naive scan makes, so a scan without quote state rewrites
  // INSIDE that value — corrupting an unrelated attribute and leaving
  // the element with no real declaration. The edit needs preservation,
  // so a correct plan must add a genuine attribute instead.
  let body = "<w:p><w:r><w:t data='x xml:space = \"bogus\"'>ab</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 1, " s"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  // The decoy value survives byte-identical...
  assert_true(spliced.contains("data='x xml:space = \"bogus\"'"))
  // ...and a REAL declaration is added to the element.
  assert_true(spliced.contains("xml:space=\"preserve\""))
  let reprojected = surgery_native_projection(spliced)
  let after = StringBuilder()
  for contribution in reprojected.paragraphs[0].contributions {
    after.write_string(contribution.value)
  }
  assert_eq(after.to_string(), " sb")
}

///|
test "partial: a run holding only visible non-text is not a synthesis carrier" {
  // The projecting-parts test alone would call this paragraph empty and
  // synthesize into it, but an offset cannot say whether the text belongs
  // before or after a zero-width break, and whole-run surgery refuses
  // VisibleNonText outright.
  assert_partial_refusal(
    "<w:p><w:r><w:br/></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 0, "X")],
    refusal="NoSynthesisCarrier",
  )
}

///|
test "partial: an atom-only no-op plans nothing" {
  let body = "<w:p><w:r><w:tab/></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, receipt) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 1, "\t"),
  ])
  assert_eq(byte_edits.length(), 0)
  guard receipt.logical_edits[0].placement is LogicalNoOp else {
    fail("expected a logical no-op")
  }
}

///|
test "partial: synthesis reproduces a default-namespace run's spelling" {
  // Every composition fixture binds WML as `w:`; an unprefixed run must
  // synthesize `<t xmlns="...">`, not `<w:t>`.
  let body = "<p><r><tab/></r></p>"
  let source = "<document xmlns=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><body>\{body}</body></document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(0, 1, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(
    spliced.contains(
      "<t xmlns=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">X</t>",
    ),
  )
}

///|
test "partial: an empty drawing is a hard barrier, not a seam" {
  // The reader routes w:drawing through the transparent-boundary path,
  // so an EMPTY one projects a single Transparent contribution — by kind
  // alone indistinguishable from a bookmark. The inventory calls it a
  // hard barrier, so a range may not span it, and a paragraph holding
  // one is not an empty synthesis carrier.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:drawing/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="VisibleBarrier",
  )
  assert_partial_refusal(
    "<w:p><w:r><w:drawing/></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 0, "X")],
    refusal="NoSynthesisCarrier",
  )
  // The same holds for an embedded object.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:object/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="VisibleBarrier",
  )
}

///|
test "partial: every VML drawing container is a hard barrier too" {
  // The reader dispatches five VML containers through the same
  // transparent path as w:drawing, so a WML-only predicate left them
  // looking like seams: a range could span one, and a run holding only
  // one could take synthesized text.
  for name in ["shape", "rect", "roundrect", "textbox", "group"] {
    let container = "<v:\{name}/>"
    assert_partial_refusal(
      "<w:p><w:r><w:t>ab</w:t>\{container}<w:t>cd</w:t></w:r></w:p>",
      paragraph=0,
      [partial_edit(1, 3, "x")],
      refusal="VisibleBarrier",
    )
    assert_partial_refusal(
      "<w:p><w:r>\{container}</w:r></w:p>",
      paragraph=0,
      [partial_edit(0, 0, "X")],
      refusal="NoSynthesisCarrier",
    )
    // And whole-run replacement refuses the run outright.
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body><w:p><w:r><w:t>a</w:t>\{container}</w:r></w:p></w:body></w:document>"
    let bytes = @utf8.encode(source)
    let projection = surgery_native_projection(source)
    try
      plan_whole_run_replacement(projection, bytes, 0, 0, "x") |> ignore
    catch {
      Unsupported(message~) =>
        assert_true(message.contains("visible non-text"), msg=message)
      _ => fail("expected an Unsupported refusal")
    } noraise {
      _ => fail("expected v:\{name} to refuse")
    }
  }
}

///|
test "whole-run replacement refuses a run holding an empty drawing" {
  // The same classification hole in N0c1: it ignores every Transparent
  // contribution, so a run whose only non-text content is an empty
  // drawing was replaced without accounting for the drawing at all.
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t><w:drawing/></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  try plan_whole_run_replacement(projection, bytes, 0, 0, "x") |> ignore catch {
    Unsupported(message~) =>
      assert_true(message.contains("visible non-text"), msg=message)
    _ => fail("expected an Unsupported refusal")
  } noraise {
    _ => fail("expected the empty drawing to refuse")
  }
}

///|
test "partial: an existing preserve declaration is left byte-identical" {
  // The locked rule ensures preservation by ADDING the attribute or by
  // replacing a `default` value — an existing `preserve` is untouched,
  // whatever quote style it uses. Rewriting it would put bytes the
  // caller never asked about inside the declared footprint.
  let body = "<w:p><w:r><w:t xml:space='preserve'> ab </w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 2, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("xml:space='preserve'"))
  assert_false(spliced.contains("xml:space=\"preserve\""))
  // A `default` declaration IS replaced, since the content needs
  // preservation and `default` would strip it.
  let default_body = "<w:p><w:r><w:t xml:space='default'>ab</w:t></w:r></w:p>"
  let default_source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{default_body}</w:body></w:document>"
  let default_bytes = @utf8.encode(default_source)
  let default_projection = surgery_native_projection(default_source)
  let (default_edits, _) = plan_paragraph_text_edits(
    default_projection,
    default_bytes,
    0,
    [partial_edit(0, 1, " s")],
  )
  let default_spliced = @utf8.decode(
    apply_run_surgery_edits(default_bytes, default_edits),
  )
  assert_true(default_spliced.contains("xml:space=\"preserve\""))
  assert_false(default_spliced.contains("xml:space='default'"))
}

///|
test "whole-run replacement leaves an existing preserve byte-identical" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t xml:space='preserve'> a </w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, " b ")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_true(spliced.contains("xml:space='preserve'"))
  assert_false(spliced.contains("xml:space=\"preserve\""))
}

///|
test "partial: a reference-spelled preserve is left byte-identical" {
  // XML resolves references inside an attribute value before the value
  // means anything, so `pre&#x73;erve` already SAYS preserve. Comparing
  // raw bytes would call it something else and rewrite the declaration,
  // which the locked rule forbids.
  let body =
    #|<w:p><w:r><w:t xml:space="pre&#x73;erve"> ab </w:t></w:r></w:p>
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes, 0, [
    partial_edit(1, 2, "X"),
  ])
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("xml:space=\"pre&#x73;erve\""))
  assert_false(spliced.contains("xml:space=\"preserve\""))
  // The decimal spelling of the same character, and a decimal reference
  // in a value that does NOT say preserve, which IS replaced.
  let decimal =
    #|<w:p><w:r><w:t xml:space="pre&#115;erve"> ab </w:t></w:r></w:p>
  let decimal_source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{decimal}</w:body></w:document>"
  let decimal_bytes = @utf8.encode(decimal_source)
  let (decimal_edits, _) = plan_paragraph_text_edits(
    surgery_native_projection(decimal_source),
    decimal_bytes,
    0,
    [partial_edit(1, 2, "X")],
  )
  let decimal_spliced = @utf8.decode(
    apply_run_surgery_edits(decimal_bytes, decimal_edits),
  )
  assert_true(decimal_spliced.contains("xml:space=\"pre&#115;erve\""))
  let other =
    #|<w:p><w:r><w:t xml:space="&#100;efault">ab</w:t></w:r></w:p>
  let other_source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{other}</w:body></w:document>"
  let other_bytes = @utf8.encode(other_source)
  let (other_edits, _) = plan_paragraph_text_edits(
    surgery_native_projection(other_source),
    other_bytes,
    0,
    [partial_edit(0, 1, " s")],
  )
  let other_spliced = @utf8.decode(
    apply_run_surgery_edits(other_bytes, other_edits),
  )
  assert_true(other_spliced.contains("xml:space=\"preserve\""))
  assert_false(other_spliced.contains("&#100;efault"))
}

///|
test "whole-run replacement leaves a reference-spelled preserve alone" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t xml:space="pre&#x73;erve"> a </w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let projection = surgery_native_projection(source)
  let edits = plan_whole_run_replacement(projection, bytes, 0, 0, " b ")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, edits))
  assert_true(spliced.contains("xml:space=\"pre&#x73;erve\""))
  assert_false(spliced.contains("xml:space=\"preserve\""))
}

///|
/// The whole restricted inventory, one paragraph shape per construct.
///
/// Each entry is addressable and projects the text named in the comment
/// -- that is what makes these regions RESTRICTED rather than invisible.
/// A construct that stopped being reachable would fail the paired
/// "reaches it" assertion rather than passing quietly as a refusal.
test "partial: every restricted construct refuses" {
  let mc = "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\""
  for
    probe in [
      // A content control that declares no checkbox: the general case,
      // which the checkbox refusal never covered.
      (
        "sdt", "<w:p><w:sdt><w:sdtPr><w:alias w:val=\"Client\"/></w:sdtPr><w:sdtContent><w:r><w:t>ab</w:t></w:r></w:sdtContent></w:sdt></w:p>",
      ),
      // Tracked insertion.
      (
        "ins", "<w:p><w:ins w:id=\"9\" w:author=\"Ada\" w:date=\"2001-01-01T00:00:00Z\"><w:r><w:t>ab</w:t></w:r></w:ins></w:p>",
      ),
      // The branch this reader projects is the one a consumer that
      // understands the Choice ignores.
      (
        "mc:Fallback",
        "<w:p><mc:AlternateContent \{mc}><mc:Choice Requires=\"wps\"><w:r><w:t>zz</w:t></w:r></mc:Choice><mc:Fallback><w:r><w:t>ab</w:t></w:r></mc:Fallback></mc:AlternateContent></w:p>",
      ),
      // Textbox content, which the first version of this list omitted --
      // an aggregate corpus threshold cannot show that each construct
      // individually reached the refusal, so each belongs here by name.
      (
        "txbxContent", "<w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>ab</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>",
      ),
    ] {
    let (name, body) = probe
    // It projects the text -- otherwise the refusal below proves nothing.
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{body}</w:body></w:document>"
    let projection = surgery_native_projection(source)
    let mut projected = ""
    for paragraph in projection.paragraphs {
      for contribution in paragraph.contributions {
        projected = projected + contribution.value
      }
    }
    assert_true(
      projected.contains("ab"),
      msg=name + " no longer projects its text, so its refusal proves nothing",
    )
    assert_partial_refusal(
      body,
      paragraph=projection.paragraphs.length() - 1,
      [partial_edit(0, 1, "X")],
      refusal="RestrictedRegion",
    )
  }
  // The same shape without any restricted wrapper still edits, so these
  // refusals are the wrappers' doing and not the geometry's.
  assert_partial_edits(
    "<w:p><w:r><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "X")],
    expected="Xb",
  )
}

///|
/// The partial half of the nested-atom blind spot.
///
/// Replacing the atom's projection replaces its WHOLE element span, so
/// the same nested insertion disappears. The ancestor checks cannot see
/// it: it is a descendant of the consumed element, not an ancestor.
test "partial: an atom carrying nested markup refuses" {
  let nested = "<w:p><w:r><w:tab><w:ins w:id=\"9\" w:author=\"Ada\" w:date=\"2001-01-01T00:00:00Z\"><w:r><w:t>cd</w:t></w:r></w:ins></w:tab><w:t>ab</w:t></w:r></w:p>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body>\{nested}</w:body></w:document>"
  let projection = surgery_native_projection(source)
  // The premise: the nested insertion projects nothing, so nothing in
  // the projection could have reported it.
  let mut projected = ""
  for contribution in projection.paragraphs[0].contributions {
    projected = projected + contribution.value
  }
  assert_false(projected.contains("cd"))
  // Replacing the atom's own position consumes its whole span.
  assert_partial_refusal(
    nested,
    paragraph=0,
    [partial_edit(0, 1, "X")],
    refusal="UnsupportedTextSource",
  )
  // The branches the first version of this trial missed. Guarding the
  // consuming branches one at a time is what let these through; the
  // guard now sits in the single validation loop every consumed element
  // passes, which runs BEFORE the no-op exit.
  //
  // Deletion, which took a different path from replacement:
  assert_partial_refusal(
    nested,
    paragraph=0,
    [partial_edit(0, 1, "")],
    refusal="UnsupportedTextSource",
  )
  // A LATER consumed atom, reached after a leading text part:
  let trailing = "<w:p><w:r><w:t>ab</w:t><w:tab><w:ins w:id=\"9\" w:author=\"Ada\" w:date=\"2001-01-01T00:00:00Z\"><w:r><w:t>cd</w:t></w:r></w:ins></w:tab></w:r></w:p>"
  assert_partial_refusal(
    trailing,
    paragraph=0,
    [partial_edit(1, 3, "X")],
    refusal="UnsupportedTextSource",
  )
  // And the identity replacement, which exits as a logical no-op: a
  // no-op suppresses byte planning, never validation.
  assert_partial_refusal(
    nested,
    paragraph=0,
    [partial_edit(0, 1, "\t")],
    refusal="UnsupportedTextSource",
  )
  // An ordinary EMPTY atom still replaces, deletes and no-ops, so the
  // guard has not simply refused every edit over a tab.
  assert_partial_edits(
    "<w:p><w:r><w:tab/><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "X")],
    expected="Xab",
  )
  assert_partial_edits(
    "<w:p><w:r><w:tab/><w:t>ab</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(0, 1, "")],
    expected="ab",
  )
}
