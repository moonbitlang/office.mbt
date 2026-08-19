// Field-classification parity (#434 PR 5b): the same field state machine,
// fed by the reader-native projection's carrier events, must classify
// exactly as the legacy pipeline on the shared valid domain -- field and
// refusal records identical, and text contributions carrying the same
// field annotations.

///|
fn field_region_label(region : ReaderOrderFieldRegion) -> String {
  match region {
    OutsideField => "outside"
    FieldInstruction => "instruction"
    FieldResult => "result"
    MalformedField => "malformed"
  }
}

///|
fn field_refusal_kind_label(kind : ReaderOrderFieldRefusalKind) -> String {
  match kind {
    AmbiguousCarrier => "ambiguous-carrier"
    UnknownTransition => "unknown-transition"
    UnmatchedSeparate => "unmatched-separate"
    UnmatchedEnd => "unmatched-end"
    DuplicateSeparate => "duplicate-separate"
    RepeatedMarker => "repeated-marker"
    RepeatedInstruction => "repeated-instruction"
    TruncatedField => "truncated-field"
  }
}

///|
fn projection_with_fields(source : String) -> ReaderProjection raise {
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  let node = story.root
  let children = match node.first("w:body") {
    Some(body) => body.element_children()
    None => node.element_children()
  }
  let items = empty_body_reader({ relationships: [] }).read_children(children)
  guard project_reader_items("word/document.xml", story.scan, items)
    is Projected(projection) else {
    fail("expected a projection")
  }
  classify_reader_projection_fields(projection)
  projection
}

///|
fn describe_field_index(index : ReaderOrderFieldIndex) -> String {
  let out : Array[String] = []
  for field in index.fields {
    let separate = match
      (field.separate_marker_identity, field.separate_carrier_identity) {
      (Some(marker), Some(carrier)) => "\{marker}/\{carrier}"
      _ => "-"
    }
    let end = match (field.end_marker_identity, field.end_carrier_identity) {
      (Some(marker), Some(carrier)) => "\{marker}/\{carrier}"
      _ => "-"
    }
    let parent = match field.parent_identity {
      Some(value) => "\{value}"
      None => "-"
    }
    let refusal = match field.refusal_identity {
      Some(value) => "\{value}"
      None => "-"
    }
    out.push(
      "field \{field.identity} story=\{field.story_identity} parent=\{parent} begin=\{field.begin_marker_identity}/\{field.begin_carrier_identity} sep=\{separate} end=\{end} instr=\{field.instruction_text.to_string()} refusal=\{refusal}",
    )
  }
  for refusal in index.refusals {
    let offending = match refusal.offending_identity {
      Some(value) => "\{value}"
      None => "-"
    }
    let field = match refusal.field_identity {
      Some(value) => "\{value}"
      None => "-"
    }
    out.push(
      "refusal \{refusal.identity} \{field_refusal_kind_label(refusal.kind)} story=\{refusal.story_identity} carrier=\{refusal.carrier_identity} offending=\{offending} field=\{field}",
    )
  }
  out.join("\n")
}

///|
fn legacy_text_annotations(projection : ReaderOrderProjection) -> String {
  let out : Array[String] = []
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      match contribution.kind {
        TextAtom | TabAtom | NoBreakHyphenAtom | SoftHyphenAtom | SymbolAtom => {
          let field = match contribution.field_identity {
            Some(value) => "\{value}"
            None => "-"
          }
          out.push(
            "\{contribution.source_identity}:\{field_region_label(contribution.field_region)}:\{field}",
          )
        }
        _ => ()
      }
    }
  }
  out.join(" ")
}

///|
fn reader_text_annotations(projection : ReaderProjection) -> String {
  let out : Array[String] = []
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      match contribution.kind {
        ProjectedText(_) => {
          let SourceElementId(source) = contribution.source
          let field = match contribution.field_identity {
            Some(value) => "\{value}"
            None => "-"
          }
          out.push(
            "\{source}:\{field_region_label(contribution.field_region)}:\{field}",
          )
        }
        _ => ()
      }
    }
  }
  out.join(" ")
}

///|
fn assert_field_parity(source : String) -> Unit raise {
  let legacy = field_test_projection(source)
  let ours = projection_with_fields(source)
  assert_eq(
    describe_field_index(ours.field_index),
    describe_field_index(legacy.field_index),
  )
  assert_eq(reader_text_annotations(ours), legacy_text_annotations(legacy))
}

///|
test "field parity on nested cross-paragraph fields" {
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> OU</w:instrText></w:r><w:r><w:instrText>T </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>A</w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> INNER </w:instrText></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>B</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r><w:r><w:t>C</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
}

///|
test "field parity on refusal shapes" {
  // unmatched end
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="end"/></w:r><w:r><w:t>A</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // duplicate separate
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> X </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>A</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
  // truncated field at story end
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> X </w:instrText></w:r><w:r><w:t>A</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // ambiguous carrier: two markers inside one direct child
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>A</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
}

///|
test "field parity across a nested block inside an open field" {
  // the field begins before a nested paragraph and ends after it: the
  // carrier-event interleaving (outer events, nested group at its
  // position, outer continues) must match the legacy walk exactly
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> X </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:p><w:r><w:t>nested</w:t></w:r></w:p><w:r><w:t>after</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
}

///|
test "field parity with deleted-paragraph joins" {
  // the field begins in a deleted paragraph and continues in the terminal
  // one: carriers of both physical paragraphs observe in order
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> X </w:instrText></w:r></w:p><w:p><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>joined</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
}

///|
test "field parity isolates textbox stories" {
  // field state resets at the textbox story boundary: an unterminated
  // begin inside the box must not leak into the main story's field
  assert_field_parity(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> X </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:t>boxed</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r><w:r><w:t>A</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
}
