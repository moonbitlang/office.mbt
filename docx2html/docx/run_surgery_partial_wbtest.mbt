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
    projection,
    bytes[:],
    paragraph,
    edits,
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
  let after = StringBuilder::new()
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
    plan_paragraph_text_edits(projection, bytes[:], paragraph, edits) |> ignore
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
  { start, end, replacement }
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
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes[:], 0, [
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
  let (byte_edits, receipt) = plan_paragraph_text_edits(
    projection,
    bytes[:],
    0,
    [partial_edit(1, 2, "&")],
  )
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
test "partial: cross-contribution range refuses in this increment" {
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="UnsupportedTextSource",
  )
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
  // The result run's text (`7`, projected after the instruction) is fair
  // game, exactly as in whole-run surgery.
  assert_partial_edits(
    instruction_body,
    paragraph=0,
    [partial_edit(4, 5, "9")],
    expected="PAGE9",
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
  let (byte_edits, receipt) = plan_paragraph_text_edits(
    projection,
    bytes[:],
    0,
    [partial_edit(0, 1, " ")],
  )
  assert_eq(receipt.expected_projection, " bc")
  let spliced = @utf8.decode(apply_run_surgery_edits(bytes, byte_edits))
  assert_true(spliced.contains("xml:space=\"preserve\""))
  let reprojected = surgery_native_projection(spliced)
  let after = StringBuilder::new()
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
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes[:], 0, [
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
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes[:], 0, [
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
  let (byte_edits, _) = plan_paragraph_text_edits(projection, bytes[:], 0, [
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
  let (byte_edits, receipt) = plan_paragraph_text_edits(
    projection,
    bytes[:],
    0,
    [],
  )
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
test "partial: ranges crossing visible or suppressed content refuse as unhosted" {
  // `ab<w:br/>cd` projects "abcd" with a zero-width visible barrier between
  // offsets 2 and 2 of the second w:t... between the two texts. No single
  // text contribution contains [1,3), so this increment refuses it as an
  // unhosted range — the cross-contribution seam B2a will open.
  assert_partial_refusal(
    "<w:p><w:r><w:t>ab</w:t><w:br/><w:t>cd</w:t></w:r></w:p>",
    paragraph=0,
    [partial_edit(1, 3, "x")],
    refusal="UnsupportedTextSource",
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
    plan_paragraph_text_edits(projection, bytes[:], 0, [partial_edit(0, 1, "x")])
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
    plan_paragraph_text_edits(projection, bytes[:], 0, [partial_edit(0, 1, "x")])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("[CrossParagraphSourceReuse]"), msg=message)
    _ => fail("expected a typed refusal")
  } noraise {
    _ => fail("expected refusal [CrossParagraphSourceReuse]")
  }
}
