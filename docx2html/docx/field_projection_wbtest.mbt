// N0b3 hostile oracles: field state advances at reader-visible carrier
// boundaries, persists across paragraphs in one story, resets between stories,
// and fails closed with source-pinned provenance.

///|
fn field_test_projection(
  source : String,
  field_budget? : ReaderFieldBudget,
) -> ReaderProjection raise DocxError {
  guard join_text_story(source) is Joined(story) else {
    raise Unsupported(message="field test: the story did not join")
  }
  guard segment_joined_reader_story(
      "word/document.xml",
      story,
      empty_body_reader({ relationships: [] }),
    )
    is SegmentedStory(output) else {
    raise Unsupported(message="field test: the story did not segment")
  }
  guard project_joined_reader_output(output) is Projected(projection) else {
    raise Unsupported(message="field test: the story did not project")
  }
  classify_reader_projection_fields(projection, budget?=field_budget)
  projection
}

///|
fn field_projection_text(projection : ReaderProjection) -> String {
  let output = StringBuilder()
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      output.write_string(contribution.value)
    }
    output.write_string("\n\n")
  }
  output.to_string()
}

///|
fn field_reader_text(source : String) -> String raise DocxError {
  let root = read_xml_string(source, namespace_map=office_namespace_map())
  let node = ReaderNode::of(root)
  let children = match node.first("w:body") {
    Some(body) => body.element_children()
    None => node.element_children()
  }
  document(
    reader_items_to_elements(
      empty_body_reader({ relationships: [] }).read_children(children),
    ),
  ).to_raw_text()
}

///|
fn field_contribution(
  projection : ReaderProjection,
  value : String,
) -> ReaderProjectionContribution raise {
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      if contribution.value == value {
        return contribution
      }
    }
  }
  fail("missing field contribution: " + value)
}

///|
fn assert_field_limit(
  source : String,
  budget : ReaderFieldBudget,
  expected : String,
) -> Unit raise {
  try field_test_projection(source, field_budget=budget) |> ignore catch {
    ResourceLimit(limit~, message~) => {
      let name = match limit {
        DocxXmlSourceUnits => "DocxXmlSourceUnits"
        DocxXmlTokens => "DocxXmlTokens"
        DocxXmlTokenLength => "DocxXmlTokenLength"
        DocxXmlMaterializedCharacters => "DocxXmlMaterializedCharacters"
        DocxXmlNestingDepth => "DocxXmlNestingDepth"
      }
      assert_true(name.contains(expected) || message.contains(expected))
    }
    _ => fail("unexpected field-classification limit error")
  } noraise {
    _ => fail("expected field-classification limit: " + expected)
  }
}

///|
test "field projection keeps nested story-wide ancestry and intervals" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
    #|<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> OU</w:instrText></w:r><w:r><w:instrText>T </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>A</w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> INNER </w:instrText></w:r></w:p>
    #|<w:p><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>B</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r><w:r><w:t>C</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
    #|</w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(field_projection_text(projection), field_reader_text(source))
  assert_eq(projection.field_index.fields.length(), 2)
  assert_eq(projection.field_index.refusals.length(), 0)
  let outer = projection.field_index.fields[0]
  let inner = projection.field_index.fields[1]
  assert_eq(outer.parent_identity, None)
  assert_eq(inner.parent_identity, Some(outer.identity))
  assert_eq(inner.story_identity, outer.story_identity)
  assert_eq(outer.instruction_text.to_string(), " OUT ")
  assert_eq(inner.instruction_text.to_string(), " INNER ")
  assert_true(outer.instruction.start.side is AfterCarrier)
  assert_true(outer.instruction.end.unwrap().side is BeforeCarrier)
  assert_true(outer.result.unwrap().start.side is AfterCarrier)
  assert_true(outer.result.unwrap().end.unwrap().side is BeforeCarrier)
  assert_true(outer.end_marker_identity is Some(_))
  assert_true(inner.end_marker_identity is Some(_))
  let a = field_contribution(projection, "A")
  let b = field_contribution(projection, "B")
  let c = field_contribution(projection, "C")
  assert_eq(a.field_identity, Some(outer.identity))
  assert_true(a.field_region is FieldResult)
  assert_eq(b.field_identity, Some(inner.identity))
  assert_true(b.field_region is FieldResult)
  assert_eq(c.field_identity, Some(outer.identity))
  assert_true(c.field_region is FieldResult)
}

///|
test "field classification is namespace resolved for Strict WML" {
  let source =
    #|<s:document xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main"><s:body><s:p>
    #|<s:r><s:fldChar s:fldCharType="begin"/></s:r><s:r><s:instrText> AUTHOR </s:instrText></s:r>
    #|<s:r><s:fldChar s:fldCharType="separate"/></s:r><s:r><s:t>Name</s:t></s:r><s:r><s:fldChar s:fldCharType="end"/></s:r>
    #|</s:p></s:body></s:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 0)
  let field = projection.field_index.fields[0]
  assert_eq(field.instruction_text.to_string(), " AUTHOR ")
  let name = field_contribution(projection, "Name")
  assert_eq(name.field_identity, Some(field.identity))
  assert_true(name.field_region is FieldResult)
}

///|
test "field transition owns the whole direct-child carrier" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:t>before</w:t><w:fldChar w:fldCharType="begin"/><w:t>after</w:t></w:r>
    #|<w:r><w:instrText> CODE&amp;😀 </w:instrText></w:r>
    #|<w:r><w:fldChar w:fldCharType="end"/></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.refusals.length(), 0)
  let field = projection.field_index.fields[0]
  assert_eq(field.instruction_text.to_string(), " CODE&😀 ")
  let before = field_contribution(projection, "before")
  let after = field_contribution(projection, "after")
  assert_eq(before.field_identity, Some(field.identity))
  assert_eq(after.field_identity, Some(field.identity))
  assert_true(before.field_region is FieldInstruction)
  assert_true(after.field_region is FieldInstruction)
  // The text physically preceding the descendant marker is nevertheless
  // classified after the direct run carrier's begin transition, matching the
  // reader's carrier-boundary observation.
  assert_true(
    before.source_span.byte_start <
    projection.scan.elements()[field.begin_marker_identity].byte_start,
  )
}

///|
/// Story identity for every root arm of `reader_field_story_identity`.
///
/// The footnote arm is pinned by "field state resets between note stories";
/// these are the other three. In the note and comment stories a field
/// spanning two containers must produce two refusals with DISTINCT story
/// identities -- one per container. The document arm is subtler: with two
/// `w:body` elements, the refusal's story identity is the body element (1);
/// with the arm broken the walk falls through to the root and reports 0,
/// which review measured surviving the entire suite before this test.
test "story identity is per container for every root kind" {
  let cases = [
    (
      "endnotes",
      (
        #|<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        #|<w:endnote w:id="1"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r></w:p></w:endnote>
        #|<w:endnote w:id="2"><w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:endnote>
        #|</w:endnotes>
      ),
      2,
      "5,1",
    ),
    (
      "comments",
      (
        #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        #|<w:comment w:id="1"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r></w:p></w:comment>
        #|<w:comment w:id="2"><w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:comment>
        #|</w:comments>
      ),
      2,
      "5,1",
    ),
  ]
  // The malformed two-body arm the legacy walker tolerated is gone:
  // native segmentation deliberately refuses a duplicate body, pinned by
  // "segmentation refuses structural surprises instead of narrowing".
  for case in cases {
    let (label, source, refusal_count, identities) = case
    let projection = field_test_projection(source)
    assert_eq((label, projection.field_index.fields.length()), (label, 1))
    assert_eq(
      (label, projection.field_index.refusals.length()),
      (label, refusal_count),
    )
    let ids : Array[String] = []
    for refusal in projection.field_index.refusals {
      ids.push(refusal.story_identity.to_string())
    }
    assert_eq((label, ids.join(",")), (label, identities))
  }
}

///|
test "field state resets between note stories" {
  let source =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:footnote w:id="1"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:t>A</w:t></w:r></w:p></w:footnote>
    #|<w:footnote w:id="2"><w:p><w:r><w:t>B</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:footnote>
    #|</w:footnotes>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 2)
  let field = projection.field_index.fields[0]
  let truncated = projection.field_index.refusals[0]
  let unmatched = projection.field_index.refusals[1]
  assert_true(
    truncated.kind is UnmatchedEnd || truncated.kind is TruncatedField,
  )
  assert_true(
    unmatched.kind is UnmatchedEnd || unmatched.kind is TruncatedField,
  )
  assert_true(truncated.kind != unmatched.kind)
  assert_true(truncated.story_identity != unmatched.story_identity)
  assert_eq(
    field.refusal_identity,
    Some(
      if truncated.kind is TruncatedField {
        truncated.identity
      } else {
        unmatched.identity
      },
    ),
  )
  assert_true(
    field_contribution(projection, "A").field_region is FieldInstruction,
  )
  assert_true(field_contribution(projection, "B").field_region is OutsideField)
}

///|
test "textbox fields do not leak across story boundaries" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> OUT</w:instrText></w:r>
    #|<w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> INNER </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>inside</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
    #|</w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r>
    #|<w:r><w:instrText> TAIL </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>outside</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 2)
  assert_eq(projection.field_index.refusals.length(), 0)
  let outer = projection.field_index.fields[0]
  let inner = projection.field_index.fields[1]
  assert_true(outer.story_identity != inner.story_identity)
  assert_eq(outer.instruction_text.to_string(), " OUT TAIL ")
  assert_eq(inner.instruction_text.to_string(), " INNER ")
  assert_true(
    field_contribution(projection, "outside").field_region is FieldResult,
  )
  assert_true(
    field_contribution(projection, "inside").field_region is FieldResult,
  )
}

///|
test "malformed field transitions retain deterministic refusal provenance" {
  let cases : Array[(String, ReaderFieldRefusalKind)] = [
    (
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="separate"/></w:r></w:p></w:body></w:document>
      ),
      UnmatchedSeparate,
    ),
    (
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
      ),
      UnmatchedEnd,
    ),
    (
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="mystery"/></w:r></w:p></w:body></w:document>
      ),
      UnknownTransition,
    ),
    (
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
      ),
      AmbiguousCarrier,
    ),
    (
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r></w:p></w:body></w:document>
      ),
      DuplicateSeparate,
    ),
  ]
  for item in cases {
    let (source, expected) = item
    let projection = field_test_projection(source)
    assert_eq(projection.field_index.refusals.length(), 1)
    let refusal = projection.field_index.refusals[0]
    assert_eq(refusal.kind, expected)
    assert_true(refusal.carrier_identity >= 0)
    assert_true(refusal.offending_identity is Some(_))
    assert_true(refusal.source_span.byte_start < refusal.source_span.byte_end)
  }
}

///|
test "a marker observed through two reader carriers fails closed" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:p><w:r><w:fldChar w:fldCharType="begin"/><w:t>X</w:t></w:r></w:p><w:r><w:fldChar w:fldCharType="end"/></w:r><w:r><w:t>after</w:t></w:r></w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedMarker)
  assert_eq(
    projection.field_index.fields[0].refusal_identity,
    Some(refusal.identity),
  )
  let x = field_contribution(projection, "X")
  assert_true(x.field_region is MalformedField)
  assert_eq(x.field_refusal, Some(refusal.identity))
  let after = field_contribution(projection, "after")
  assert_true(after.field_region is MalformedField)
  assert_eq(after.field_refusal, Some(refusal.identity))
}

///|
test "a repeated end marker refuses the field it already closed" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:t>before</w:t><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:p><w:r><w:fldChar w:fldCharType="end"/><w:t>nested</w:t></w:r></w:p>
    #|<w:r><w:t>after</w:t></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let field = projection.field_index.fields[0]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedMarker)
  assert_eq(refusal.field_identity, Some(field.identity))
  assert_eq(field.refusal_identity, Some(refusal.identity))
  let before = field_contribution(projection, "before")
  assert_eq(before.field_identity, Some(field.identity))
  assert_eq(before.field_refusal, Some(refusal.identity))
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "an instruction observed through two reader carriers fails closed" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:p><w:r><w:instrText> CODE </w:instrText></w:r><w:r><w:t>nested</w:t></w:r></w:p>
    #|<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>after</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let field = projection.field_index.fields[0]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedInstruction)
  assert_eq(field.instruction_text.to_string(), " CODE ")
  assert_eq(field.refusal_identity, Some(refusal.identity))
  let offending = refusal.offending_identity.unwrap()
  assert_eq(projection.scan.elements()[offending].local_name, "instrText")
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "a repeated child instruction refuses its closed owner and open parent" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:p><w:r><w:instrText> CHILD </w:instrText><w:t>nested</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
    #|<w:r><w:t>after</w:t></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 2)
  assert_eq(projection.field_index.refusals.length(), 1)
  let parent = projection.field_index.fields[0]
  let child = projection.field_index.fields[1]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedInstruction)
  assert_eq(refusal.field_identity, Some(child.identity))
  assert_eq(parent.refusal_identity, Some(refusal.identity))
  assert_eq(child.refusal_identity, Some(refusal.identity))
  assert_eq(parent.instruction_text.to_string(), "")
  assert_eq(child.instruction_text.to_string(), " CHILD ")
  let offending = refusal.offending_identity.unwrap()
  assert_eq(projection.scan.elements()[offending].local_name, "instrText")
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "a repeated instruction refuses its only field after it closes" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:r><w:p><w:r><w:instrText> CODE </w:instrText><w:t>nested</w:t></w:r></w:p><w:fldChar w:fldCharType="end"/></w:r>
    #|<w:r><w:t>after</w:t></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let field = projection.field_index.fields[0]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedInstruction)
  assert_eq(refusal.field_identity, Some(field.identity))
  assert_eq(field.refusal_identity, Some(refusal.identity))
  assert_eq(field.instruction_text.to_string(), " CODE ")
  let offending = refusal.offending_identity.unwrap()
  assert_eq(projection.scan.elements()[offending].local_name, "instrText")
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "a repeated child instruction refuses a result-region parent" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:r><w:fldChar w:fldCharType="separate"/></w:r>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:r><w:p><w:r><w:instrText> CHILD </w:instrText><w:t>nested</w:t></w:r></w:p><w:fldChar w:fldCharType="end"/></w:r>
    #|<w:r><w:t>after</w:t></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 2)
  assert_eq(projection.field_index.refusals.length(), 1)
  let parent = projection.field_index.fields[0]
  let child = projection.field_index.fields[1]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedInstruction)
  assert_eq(refusal.field_identity, Some(child.identity))
  assert_eq(parent.refusal_identity, Some(refusal.identity))
  assert_eq(child.refusal_identity, Some(refusal.identity))
  assert_eq(parent.instruction_text.to_string(), "")
  assert_eq(child.instruction_text.to_string(), " CHILD ")
  let offending = refusal.offending_identity.unwrap()
  assert_eq(projection.scan.elements()[offending].local_name, "instrText")
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "an initially untargeted repeated instruction refuses the later field" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/><w:p><w:r><w:instrText> OUTSIDE </w:instrText><w:t>nested</w:t></w:r></w:p></w:r>
    #|<w:r><w:t>after</w:t></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let field = projection.field_index.fields[0]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedInstruction)
  assert_eq(refusal.field_identity, None)
  assert_eq(field.refusal_identity, Some(refusal.identity))
  assert_eq(field.instruction_text.to_string(), "")
  let offending = refusal.offending_identity.unwrap()
  assert_eq(projection.scan.elements()[offending].local_name, "instrText")
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "a repeated self-closing instruction refuses its field" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:p><w:r><w:instrText/><w:t>nested</w:t></w:r></w:p>
    #|<w:r><w:t>after</w:t></w:r>
    #|</w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let field = projection.field_index.fields[0]
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is RepeatedInstruction)
  assert_eq(refusal.field_identity, Some(field.identity))
  assert_eq(field.refusal_identity, Some(refusal.identity))
  assert_eq(field.instruction_text.to_string(), "")
  let offending = refusal.offending_identity.unwrap()
  assert_eq(projection.scan.elements()[offending].local_name, "instrText")
  for value in ["nested", "after"] {
    let contribution = field_contribution(projection, value)
    assert_true(contribution.field_region is MalformedField)
    assert_eq(contribution.field_refusal, Some(refusal.identity))
  }
}

///|
test "truncated fields mark prior contributions with the final refusal" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:t>X</w:t></w:r></w:p></w:body></w:document>
  let projection = field_test_projection(source)
  assert_eq(projection.field_index.fields.length(), 1)
  assert_eq(projection.field_index.refusals.length(), 1)
  let refusal = projection.field_index.refusals[0]
  assert_true(refusal.kind is TruncatedField)
  let contribution = field_contribution(projection, "X")
  assert_eq(contribution.field_identity, Some(0))
  assert_eq(contribution.field_refusal, Some(refusal.identity))
}

///|
test "field classification limits cover depth text work and retained state" {
  let nested =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r>
    #|<w:r><w:fldChar w:fldCharType="end"/></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
    #|</w:p></w:body></w:document>
  let exact_depth = field_test_projection(
    nested,
    field_budget=reader_field_budget(max_transitions=4, max_field_depth=2),
  )
  assert_eq(exact_depth.field_index.fields.length(), 2)
  assert_field_limit(
    nested,
    reader_field_budget(max_transitions=3),
    "DocxXmlTokens",
  )
  assert_field_limit(
    nested,
    reader_field_budget(max_field_depth=1),
    "DocxXmlNestingDepth",
  )

  let instruction =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
    #|<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText>A&amp;😀</w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>
    #|</w:p></w:body></w:document>
  let exact_text = field_test_projection(
    instruction,
    field_budget=reader_field_budget(max_instruction_chars=4),
  )
  assert_eq(
    exact_text.field_index.fields[0].instruction_text.to_string(),
    "A&😀",
  )
  assert_field_limit(
    instruction,
    reader_field_budget(max_instruction_chars=3),
    "DocxXmlMaterializedCharacters",
  )
  assert_field_limit(
    instruction,
    reader_field_budget(max_work=0),
    "DocxXmlTokens",
  )
  assert_field_limit(
    instruction,
    reader_field_budget(max_retained_state=0),
    "DocxXmlTokens",
  )
}

///|
/// Renders the composition contracts DIRECTLY: every non-empty
/// contribution as value@region[field], then the carrier-event stream
/// as paragraph/carrier identity pairs. What the deleted parity suite
/// held against the legacy walk, these pins hold against drift.
fn describe_field_composition(projection : ReaderProjection) -> String {
  let out = StringBuilder()
  for index, paragraph in projection.paragraphs {
    out.write_string("p\{index}:")
    for contribution in paragraph.contributions {
      if contribution.value.length() > 0 {
        let region = match contribution.field_region {
          OutsideField => "-"
          FieldInstruction => "I"
          FieldResult => "R"
          MalformedField => "M"
        }
        let field = match contribution.field_identity {
          Some(identity) => "[\{identity}]"
          None => ""
        }
        out.write_string(" \{contribution.value}@\{region}\{field}")
      }
    }
    out.write_string("\n")
  }
  out.write_string("carriers:")
  for event in projection.field_carriers {
    out.write_string(" \{event.paragraph_identity}/\{event.carrier_identity}")
  }
  out.to_string()
}

///|
/// The carriers list is authoritative: a complex HYPERLINK field wraps
/// its result items in synthetic hyperlinks sourced at the field-begin
/// carrier, so item sources cannot decide the event set -- a physical
/// hyperlink carrier inside the result must still emit, and its text
/// must classify as FieldResult.
test "a physical hyperlink carrier in the result classifies as FieldResult" {
  let projection = field_test_projection(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://e" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:hyperlink w:anchor="x"><w:r><w:t>L</w:t></w:r></w:hyperlink><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
  inspect(
    describe_field_composition(projection),
    content=(
      #|p0: L@R[0]
      #|carriers: 2/3 2/5 2/7 2/9 2/12
    ),
  )
}

///|
/// A field beginning in a deleted paragraph continues in the terminal
/// one: carriers of BOTH physical paragraphs observe in order, and the
/// joined result text classifies inside the field.
test "a field spanning a deleted-paragraph join keeps its carriers in order" {
  let projection = field_test_projection(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> X </w:instrText></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>joined</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
  inspect(
    describe_field_composition(projection),
    content=(
      #|p0: joined@R[0]
      #|carriers: 2/3 2/6 2/8 10/11 10/13 10/15
    ),
  )
}

///|
/// The hardest composition: a complex HYPERLINK field whose result wraps
/// a NESTED PARAGRAPH in a synthetic hyperlink sourced at the begin
/// carrier. Emit-before-visit must hold -- the outer paragraph's carrier
/// for the nested paragraph fires before the nested group -- and the
/// nested instrText's repeated observation lands as the machine
/// classified it.
test "a hyperlink result wrapping a nested paragraph keeps carrier order" {
  let projection = field_test_projection(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://e" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:p><w:r><w:instrText> GHOST </w:instrText><w:t>inner</w:t></w:r></w:p><w:r><w:t>after</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
  inspect(
    describe_field_composition(projection),
    content=(
      #|p0: inner@M
      #|p1: after@M
      #|carriers: 2/3 2/5 2/7 2/9 9/10 2/13 2/15
    ),
  )
}
