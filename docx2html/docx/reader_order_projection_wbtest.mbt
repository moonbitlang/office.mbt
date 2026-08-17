// Reader-order oracles. These compare the projection with the current
// BodyReader -- its story text, its paragraph structure, and the byte spans and
// story intervals it claims -- and pin the divergences that remain open.

///|
fn current_reader_story_text(source : String) -> String raise DocxError {
  let root = read_xml_string(source, namespace_map=office_namespace_map())
  let children = match root.first("w:body") {
    Some(body) => body.children
    None => root.children
  }
  document(empty_body_reader({ relationships: [] }).read_children(children)).to_raw_text()
}

///|
fn current_reader_story_text_with(
  source : String,
  reader : BodyReader,
) -> String raise DocxError {
  let root = read_xml_string(source, namespace_map=office_namespace_map())
  let children = match root.first("w:body") {
    Some(body) => body.children
    None => root.children
  }
  document(reader.read_children(children)).to_raw_text()
}

///|
fn reader_order_projection_with_all_image_outputs(
  source : String,
) -> ReaderOrderProjection raise DocxError {
  let source_tree = scan_projection_source_tree(@utf8.encode(source))
  let elements = source_tree.elements()
  let reader_image_outputs = Array::make(elements.length(), false)
  for element in elements {
    if reader_order_is_image_output_element(element) {
      reader_image_outputs[element.identity] = true
    }
  }
  project_reader_order_from_source_tree(
    "word/document.xml",
    source_tree,
    reader_image_outputs~,
  )
}

///|
fn ReaderOrderParagraph::reader_text(self : ReaderOrderParagraph) -> String {
  let output = StringBuilder()
  for contribution in self.contributions {
    output.write_string(contribution.value)
  }
  output.to_string()
}

///|
fn provisional_story_text(projection : ReaderOrderProjection) -> String {
  let output = StringBuilder()
  for paragraph in projection.paragraphs {
    output.write_string(paragraph.reader_text())
    output.write_string("\n\n")
  }
  output.to_string()
}

///|
fn assert_reader_order_identity_mapping(
  projection : ReaderOrderProjection,
) -> Unit raise {
  let elements = projection.source_elements
  for paragraph in projection.paragraphs {
    for source in paragraph.sources {
      assert_true(source.identity >= 0 && source.identity < elements.length())
      let physical = elements[source.identity]
      assert_eq(source.source_span.byte_start, physical.byte_start)
      assert_eq(source.source_span.byte_end, physical.byte_end)
      for run in source.runs {
        assert_true(run.identity >= 0 && run.identity < elements.length())
        let physical_run = elements[run.identity]
        assert_eq(run.source_span.byte_start, physical_run.byte_start)
        assert_eq(run.source_span.byte_end, physical_run.byte_end)
      }
    }
    for contribution in paragraph.contributions {
      assert_true(
        contribution.source_identity >= 0 &&
        contribution.source_identity < elements.length(),
      )
      let physical = elements[contribution.source_identity]
      assert_true(
        contribution.source_span.byte_start >= physical.byte_start &&
        contribution.source_span.byte_end <= physical.byte_end &&
        contribution.source_span.byte_start <= contribution.source_span.byte_end,
      )
      assert_true(
        paragraph.sources.any(source => {
          source.identity == contribution.paragraph_identity
        }),
      )
      match contribution.run_identity {
        Some(run_identity) =>
          assert_true(
            paragraph.sources.any(source => {
              source.runs.any(run => run.identity == run_identity)
            }),
          )
        None => ()
      }
    }
  }
}

///|
fn assert_reader_order_refuses(
  source : String,
  budget : ReaderOrderBudget,
  expected : String,
) -> Unit raise {
  try
    scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
      reader_budget=budget,
    )
    |> ignore
  catch {
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
    Unsupported(message~) => assert_true(message.contains(expected))
    _ => fail("unexpected reader-order projection error")
  } noraise {
    _ => fail("expected reader-order refusal containing: " + expected)
  }
}

///|
test "reader order projects nested runs text atoms seams and barriers" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>outside body</w:t></w:r></w:p><w:body><w:p><w:r><w:t>A</w:t><w:r><w:t>N</w:t></w:r><w:tab/><w:noBreakHyphen/><w:softHyphen/><w:sym w:font="Wingdings" w:char="F0FC"/><w:br/><w:t>B</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>C</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>merged away</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:t>deleted row</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:r><w:t>D</w:t></w:r></w:p></w:body><w:body><w:p><w:r><w:t>second body</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  assert_eq(projection.paragraphs.length(), 3)
  assert_eq(projection.paragraphs[0].sources.length(), 1)
  assert_eq(projection.paragraphs[0].sources[0].runs.length(), 2)
  let contributions = projection.paragraphs[0].contributions
  assert_true(
    contributions.any(item => item.kind is TabAtom && item.value == "\t"),
  )
  assert_true(
    contributions.any(item => item.kind is SymbolAtom && item.value == "✓"),
  )
  assert_true(contributions.any(item => item.kind is HardBarrier))
  assert_true(
    contributions.any(item => {
      item.kind is TransparentSeam && item.run_identity is Some(_)
    }),
  )
}

///|
test "reader order emits textbox paragraphs after the primary paragraph" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:t>A</w:t></w:r><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>X</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r><w:r><w:t>B</w:t></w:r></w:p><w:p><w:r><w:t>C</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => {
      (paragraph.reader_text(), paragraph.from_text_box)
    }),
    content="[(\"AB\", false), (\"X\", true), (\"C\", false)]",
  )
}

///|
test "reader order discovers textboxes inside deleted revisions" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:t>A</w:t></w:r><w:del><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>X</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:del><w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => {
      (paragraph.reader_text(), paragraph.from_text_box)
    }),
    content="[(\"AB\", false), (\"X\", true)]",
  )
}

///|
test "reader order discovers pict block outputs inside deleted revisions" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>A</w:t></w:r><w:del><w:pict><w:r><w:p><w:r><w:t>X</w:t></w:r></w:p></w:r></w:pict></w:del><w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => {
      (paragraph.reader_text(), paragraph.from_text_box)
    }),
    content="[(\"AB\", false), (\"X\", true)]",
  )
}

///|
test "reader order preserves vMerge cells when malformed tables fail open" {
  let sources = [
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:p><w:r><w:t>Between</w:t></w:r></w:p><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:p><w:r><w:t>Between</w:t></w:r></w:p><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:ins><w:p><w:r><w:t>Between</w:t></w:r></w:p></w:ins><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:ins><w:p><w:r><w:t>Between</w:t></w:r></w:p></w:ins><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
  ]
  let projected : Array[Array[String]] = []
  for source in sources {
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    projected.push(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
    )
  }
  debug_inspect(
    projected,
    content=(
      #|[
      #|  ["A", "Between", "B"],
      #|  ["A", "Between", "B"],
      #|  ["A", "Between", "B"],
      #|  ["A", "Between", "B"],
      #|]
    ),
  )
}

///|
test "reader order detects flattened non-projection table outputs" {
  let sources = [
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:t>Direct table text</w:t><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:t>Direct row text</w:t><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
  ]
  for source in sources {
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_reader_order_identity_mapping(projection)
    debug_inspect(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
      content="[\"A\", \"B\"]",
    )
    assert_true(current_reader_story_text(source).contains("B"))
  }
}

///|
test "reader order skips deleted rows when deciding table fail-open" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:del/></w:trPr><w:p><w:r><w:t>Deleted malformed row</w:t></w:r></w:p></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Merged away</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"A\"]",
  )
}

///|
test "reader order classifies conditional empty table outputs like BodyReader" {
  let separators = [
    "<w:bookmarkStart w:name=\"_GoBack\"/>", "<w:br w:type=\"unsupported\"/>", "<w:sym w:font=\"Arial\" w:char=\"0041\"/>",
    "<w:hyperlink/>", "<w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>deleted prefix</w:t></w:r></w:p>",
    "<w:hyperlink><w:tr><w:tc><w:p><w:r><w:t>wrapped</w:t></w:r></w:p></w:tc></w:tr></w:hyperlink>",
    "<w:hyperlink w:anchor=\"x\"/>", "<w:hyperlink q:id=\"missing\"/>",
  ]
  let projected : Array[Array[String]] = []
  for separator in separators {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:q=\"http://purl.oclc.org/ooxml/officeDocument/relationships\"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val=\"restart\"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr>" +
      separator +
      "<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    projected.push(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
    )
  }
  debug_inspect(
    projected,
    content=(
      #|[
      #|  ["A"],
      #|  ["A"],
      #|  ["A"],
      #|  ["A"],
      #|  ["A"],
      #|  ["A", "wrapped"],
      #|  ["A", "B"],
      #|  ["A", "B"],
      #|]
    ),
  )
}

///|
test "reader order restores orphan merges after ignored physical origins" {
  let wrappers = [
    ("<w:customXml>", "</w:customXml>"),
    ("<w:unknown>", "</w:unknown>"),
    ("<w:pict>", "</w:pict>"),
    ("<w:tblPr>", "</w:tblPr>"),
    ("<x:unknown xmlns:x=\"urn:unknown\">", "</x:unknown>"),
  ]
  for wrapper in wrappers {
    let (opening, closing) = wrapper
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:tbl>" +
      opening +
      "<w:tr><w:tc><w:p><w:r><w:t>ignored origin</w:t></w:r></w:p></w:tc></w:tr>" +
      closing +
      "<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>orphan kept</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    debug_inspect(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
      content="[\"orphan kept\"]",
    )
  }
}

///|
test "reader order hides continuations found by merge recomputation" {
  let hidden_origins = [
    "<w:del><w:tc><w:tcPr><w:gridSpan w:val=\"2\"/></w:tcPr><w:p><w:r><w:t>deleted</w:t></w:r></w:p></w:tc></w:del>",
    "<mc:Choice><w:tc><w:tcPr><w:gridSpan w:val=\"2\"/></w:tcPr><w:p><w:r><w:t>ignored</w:t></w:r></w:p></w:tc></mc:Choice>",
  ]
  for hidden_origin in hidden_origins {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><w:body><w:tbl><w:tr>" +
      hidden_origin +
      "<w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>merged away</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    debug_inspect(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
      content="[\"A\"]",
    )
  }
}

///|
test "reader order ignores nested row and cell property containers" {
  let rows = [
    "<w:tr><w:tc><w:p><w:r><w:tcPr><w:vMerge/></w:tcPr><w:t>B</w:t></w:r></w:p></w:tc></w:tr>",
    "<w:tr><w:tc><w:p><w:r><w:t>B</w:t><w:trPr><w:del/></w:trPr></w:r></w:p></w:tc></w:tr>",
  ]
  for row in rows {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:tbl><w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr>" +
      row +
      "</w:tbl></w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    debug_inspect(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
      content="[\"A\", \"B\"]",
    )
  }
}

///|
test "reader order flattens inline drawing and object children" {
  let inners = [
    "<w:drawing><w:r><w:t>D</w:t></w:r></w:drawing>", "<w:object><w:ins><w:r><w:t>O</w:t></w:r></w:ins></w:object>",
    "<w:object><v:shape><w:r><w:t>V</w:t></w:r></v:shape></w:object>", "<w:drawing><v:group><v:rect><w:r><w:t>G</w:t></w:r></v:rect></v:group></w:drawing>",
    "<w:object><v:roundrect><v:textbox><w:r><w:t>T</w:t></w:r></v:textbox></v:roundrect></w:object>",
  ]
  let projected : Array[String] = []
  for inner in inners {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body><w:p><w:r><w:t>A</w:t></w:r>" +
      inner +
      "<w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    projected.push(projection.paragraphs[0].reader_text())
  }
  debug_inspect(
    projected,
    content="[\"ADB\", \"AOB\", \"AVB\", \"AGB\", \"ATB\"]",
  )
}

///|
test "reader order preserves block descendants of flattened inline wrappers" {
  let cases = [
    "<w:r><w:t>A</w:t></w:r><w:drawing><w:p><w:r><w:t>D</w:t></w:r></w:p></w:drawing><w:r><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t><w:object><w:p><w:r><w:t>D</w:t></w:r></w:p><w:p><w:r><w:t>E</w:t></w:r></w:p></w:object><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t><w:object><w:tbl><w:tr><w:tc><w:p><w:r><w:t>T</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>U</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:object><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t></w:r><w:drawing><w:p/></w:drawing>", "<w:r><w:t>A</w:t></w:r><w:hyperlink w:anchor=\"target\"><w:p><w:r><w:t>H</w:t></w:r></w:p></w:hyperlink><w:r><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t></w:r><w:ins><w:p><w:r><w:t>I</w:t></w:r></w:p></w:ins><w:r><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t></w:r><w:smartTag><w:p><w:r><w:t>S</w:t></w:r></w:p></w:smartTag><w:r><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t></w:r><w:object><v:shape><w:p><w:r><w:t>V</w:t></w:r></w:p></v:shape></w:object><w:r><w:t>B</w:t></w:r>",
    "<w:r><w:t>A</w:t></w:r><w:drawing><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>D</w:t></w:r></w:p><w:r><w:t>M</w:t></w:r><w:p><w:r><w:t>E</w:t></w:r></w:p></w:drawing><w:r><w:t>B</w:t></w:r>",
  ]
  let projected : Array[Array[String]] = []
  for inner in cases {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body><w:p>" +
      inner +
      "</w:p></w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    projected.push(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
    )
  }
  debug_inspect(
    projected,
    content=(
      #|[
      #|  ["AD", "B"],
      #|  ["AD", "E", "B"],
      #|  ["AT", "U", "B"],
      #|  ["A", ""],
      #|  ["AH", "B"],
      #|  ["AI", "B"],
      #|  ["AS", "B"],
      #|  ["AV", "B"],
      #|  ["AMDE", "B"],
      #|]
    ),
  )
}

///|
test "reader order traverses block descendants of flow-level runs" {
  let sources = [
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:r><w:p><w:r><w:t>P</w:t></w:r></w:p></w:r><w:p><w:r><w:t>A</w:t></w:r></w:p></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:r><w:p><w:r><w:t>P</w:t></w:r></w:p></w:r><w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:r><w:p><w:r><w:t>X</w:t></w:r></w:p></w:r></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p></w:body></w:document>
    ),
  ]
  let projected : Array[Array[String]] = []
  for source in sources {
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(projection),
      current_reader_story_text(source),
    )
    assert_reader_order_identity_mapping(projection)
    projected.push(
      projection.paragraphs.map(paragraph => paragraph.reader_text()),
    )
  }
  debug_inspect(
    projected,
    content="[[\"P\", \"A\"], [\"P\", \"A\"], [\"\", \"X\"]]",
  )
}

///|
test "reader order preserves block output inside runs under pict" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:t>A</w:t><w:pict><w:r><w:p><w:r><w:t>P</w:t></w:r></w:p></w:r></w:pict><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"AB\", \"P\"]",
  )
}

///|
test "reader order restores every enclosing run after an inline block" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:r><w:p><w:r><w:t>P</w:t></w:r></w:p></w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"P\", \"B\"]",
  )
}

///|
test "reader order only traverses story containers from their root context" {
  let document_source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>A</w:t></w:r></w:p><w:body><w:p><w:r><w:t>body</w:t></w:r></w:p></w:body><w:hdr><w:p><w:r><w:t>header</w:t></w:r></w:p></w:hdr><w:ftr><w:p><w:r><w:t>footer</w:t></w:r></w:p></w:ftr><w:footnotes><w:p><w:r><w:t>notes</w:t></w:r></w:p></w:footnotes><w:endnotes><w:p><w:r><w:t>endnotes</w:t></w:r></w:p></w:endnotes><w:comments><w:p><w:r><w:t>comments</w:t></w:r></w:p></w:comments><w:footnote><w:p><w:r><w:t>footnote</w:t></w:r></w:p></w:footnote><w:endnote><w:p><w:r><w:t>endnote</w:t></w:r></w:p></w:endnote><w:comment><w:p><w:r><w:t>comment</w:t></w:r></w:p></w:comment><w:p><w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let document_projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(document_source),
  )
  assert_eq(
    provisional_story_text(document_projection),
    current_reader_story_text(document_source),
  )
  assert_reader_order_identity_mapping(document_projection)
  debug_inspect(
    document_projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"A\", \"B\"]",
  )
  let footnotes_source =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:t>plumbing</w:t></w:r></w:p></w:footnote><w:footnote w:id="1"><w:p><w:r><w:t>N</w:t></w:r></w:p></w:footnote></w:footnotes>
  let footnotes_projection = scan_reader_order_projection(
    "word/footnotes.xml",
    @utf8.encode(footnotes_source),
  )
  assert_reader_order_identity_mapping(footnotes_projection)
  debug_inspect(
    footnotes_projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"N\"]",
  )
  let comments_source =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="1"><w:p><w:r><w:t>C</w:t></w:r></w:p></w:comment></w:comments>
  let comments_projection = scan_reader_order_projection(
    "word/comments.xml",
    @utf8.encode(comments_source),
  )
  assert_reader_order_identity_mapping(comments_projection)
  debug_inspect(
    comments_projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"C\"]",
  )
  let nested_story_sources : Array[(String, String)] = [
    (
      "word/footnotes.xml",
      (
        #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:wrapper><w:footnote w:id="1"><w:p><w:r><w:t>nested footnote</w:t></w:r></w:p></w:footnote></w:wrapper></w:footnotes>
      ),
    ),
    (
      "word/endnotes.xml",
      (
        #|<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:wrapper><w:endnote w:id="1"><w:p><w:r><w:t>nested endnote</w:t></w:r></w:p></w:endnote></w:wrapper></w:endnotes>
      ),
    ),
    (
      "word/comments.xml",
      (
        #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:wrapper><w:comment w:id="1"><w:p><w:r><w:t>nested comment</w:t></w:r></w:p></w:comment></w:wrapper></w:comments>
      ),
    ),
  ]
  for entry in nested_story_sources {
    let (part_name, source) = entry
    let projection = scan_reader_order_projection(
      part_name,
      @utf8.encode(source),
    )
    assert_reader_order_identity_mapping(projection)
    assert_eq(projection.paragraphs.length(), 0)
  }
}

///|
test "reader order image outputs preserve malformed table fail-open behavior" {
  let drawings = [
    (
      #|<w:drawing><wp:inline><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>
    ),
    (
      #|<w:drawing><wp:anchor><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:anchor></w:drawing>
    ),
    (
      #|<w:drawing><v:shape><v:imagedata r:id="rImage"/></v:shape></w:drawing>
    ),
    (
      #|<w:drawing><wp:inline xmlns:wp="http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing" xmlns:a="http://purl.oclc.org/ooxml/drawingml/main" xmlns:pic="http://purl.oclc.org/ooxml/drawingml/picture" xmlns:r="http://purl.oclc.org/ooxml/officeDocument/relationships"><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rImage"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>
    ),
  ]
  let with_images : Array[Array[String]] = []
  for drawing in drawings {
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\" xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val=\"restart\"/></w:tcPr><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr>" +
      drawing +
      "<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>"
    let without_image = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(
      provisional_story_text(without_image),
      current_reader_story_text(source),
    )
    let with_image = reader_order_projection_with_all_image_outputs(source)
    assert_eq(
      provisional_story_text(with_image),
      current_reader_story_text_with(source, drawing_image_reader()),
    )
    assert_reader_order_identity_mapping(with_image)
    with_images.push(
      with_image.paragraphs.map(paragraph => paragraph.reader_text()),
    )
  }
  debug_inspect(
    with_images,
    content=(
      #|[["A", "B"], ["A", "B"], ["A", "B"], ["A", "B"]]
    ),
  )
}

///|
test "reader order validates image output context cardinality" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let source_tree = scan_projection_source_tree(@utf8.encode(source))
  try
    project_reader_order_from_source_tree("word/document.xml", source_tree, reader_image_outputs=[])
    |> ignore
  catch {
    Unsupported(message~) =>
      assert_true(
        message.contains("must match the retained source element count"),
      )
    _ => fail("unexpected reader-order image context error")
  } noraise {
    _ => fail("expected a reader-order image context cardinality error")
  }
}

///|
test "reader order keeps nested table merge semantics when outer table fails open" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Outer A</w:t></w:r></w:p></w:tc></w:tr><w:p><w:r><w:t>Between</w:t></w:r></w:p><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Outer B</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Nested A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Nested merged away</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:t>Nested deleted row</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:tc></w:tr></w:tbl></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"Outer A\", \"Between\", \"Outer B\", \"Nested A\"]",
  )
}

///|
test "reader order rebuilds nested merges through transparent row and cell wrappers" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Outer A</w:t></w:r></w:p></w:tc></w:tr><w:p><w:r><w:t>Between</w:t></w:r></w:p><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Outer B</w:t></w:r></w:p><w:tbl><w:ins><w:tr><w:smartTag><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>Nested A</w:t></w:r></w:p></w:tc></w:smartTag></w:tr></w:ins><w:smartTag><w:tr><w:ins><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Nested merged away</w:t></w:r></w:p></w:tc></w:ins></w:tr></w:smartTag></w:tbl></w:tc></w:tr></w:tbl></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"Outer A\", \"Between\", \"Outer B\", \"Nested A\"]",
  )
}

///|
test "reader order keeps deleted paragraph-mark prefixes as physical contributors" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>A</w:t></w:r><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>discarded box</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p><w:proofErr/><w:p><w:r><w:t>B</w:t></w:r></w:p><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>trailing</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  assert_eq(projection.paragraphs.length(), 1)
  assert_eq(projection.paragraphs[0].reader_text(), "AB")
  assert_eq(projection.paragraphs[0].sources.length(), 2)
  let elements = projection.source_elements
  debug_inspect(
    projection.paragraphs[0].sources.map(source => {
      elements[source.identity].physical_path(elements)
    }),
    content="[\"/w:document[1]/w:body[1]/w:p[1]\", \"/w:document[1]/w:body[1]/w:p[2]\"]",
  )
  assert_false(
    projection.paragraphs.any(paragraph => {
      paragraph.reader_text().contains("discarded") ||
      paragraph.reader_text().contains("trailing")
    }),
  )
}

///|
test "reader order drops deleted paragraphs visited as paragraph children" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>A</w:t></w:r><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>D</w:t></w:r></w:p><w:p><w:r><w:t>P</w:t></w:r></w:p><w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(
    provisional_story_text(projection),
    current_reader_story_text(source),
  )
  assert_reader_order_identity_mapping(projection)
  debug_inspect(
    projection.paragraphs.map(paragraph => paragraph.reader_text()),
    content="[\"AP\", \"B\"]",
  )
}

///|
test "reader order normalizes transitional prefixes and strict defaults" {
  let transitional =
    #|<x:hdr xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><x:p><x:r><x:t>Q</x:t><x:tab/></x:r></x:p></x:hdr>
  let strict =
    #|<hdr xmlns="http://purl.oclc.org/ooxml/wordprocessingml/main"><p><r><t>Q</t><tab/></r></p></hdr>
  let transitional_projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(transitional),
  )
  let strict_projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(strict),
  )
  assert_eq(
    provisional_story_text(transitional_projection),
    current_reader_story_text(transitional),
  )
  assert_eq(
    provisional_story_text(strict_projection),
    current_reader_story_text(strict),
  )
  debug_inspect(
    (
      transitional_projection.paragraphs.map(paragraph => {
        paragraph.reader_text()
      }),
      strict_projection.paragraphs.map(paragraph => paragraph.reader_text()),
      transitional_projection.paragraphs[0].sources[0].identity,
      strict_projection.paragraphs[0].sources[0].identity,
    ),
    content="([\"Q\\t\"], [\"Q\\t\"], 1, 1)",
  )
  assert_reader_order_identity_mapping(transitional_projection)
  assert_reader_order_identity_mapping(strict_projection)
}

///|
test "reader order retains physical coordinates without premature logical intervals" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>A&amp;😀</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  let paragraph = projection.paragraphs[0]
  // N0b2's coordinate-bearing data is only the OPC part, N0b1 identities,
  // and physical byte spans. Logical paths/UTF-16 intervals do not exist here.
  let text_atom = paragraph.contributions[1]
  debug_inspect(
    (
      projection.source_part,
      paragraph.sources[0].identity,
      paragraph.sources[0].source_span.byte_start,
      paragraph.sources[0].source_span.byte_end,
      text_atom.source_identity,
      text_atom.paragraph_identity,
      text_atom.run_identity,
      text_atom.source_span.byte_start,
      text_atom.source_span.byte_end,
    ),
    content="(\"word/document.xml\", 2, 91, 134, 4, 2, Some(3), 106, 116)",
  )
}

///|
test "reader order budgets bound cumulative visits depth text and contributors" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>A</w:t></w:r></w:p></w:body></w:document>
  // Exact witnesses: five source identities across seven metered full-tree
  // passes + two visible projection nodes, then root/body/p + the pPr lookup
  // + main r/t + textbox discovery r/t = 45 cumulative visits. Output retains
  // paragraph, p, run, seam, and atom.
  let accepted = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
    reader_budget=reader_order_budget(
      max_node_visits=45,
      max_projected_chars=1,
      max_retained_contributors=5,
      max_depth=5,
    ),
  )
  assert_eq(accepted.paragraphs[0].reader_text(), "A")
  assert_reader_order_refuses(
    source,
    reader_order_budget(
      max_node_visits=44,
      max_projected_chars=1,
      max_retained_contributors=5,
      max_depth=5,
    ),
    "DocxXmlTokens",
  )
  assert_reader_order_refuses(
    source,
    reader_order_budget(
      max_node_visits=45,
      max_projected_chars=1,
      max_retained_contributors=5,
      max_depth=4,
    ),
    "DocxXmlNestingDepth",
  )
  assert_reader_order_refuses(
    source,
    reader_order_budget(
      max_node_visits=45,
      max_projected_chars=0,
      max_retained_contributors=5,
      max_depth=5,
    ),
    "DocxXmlMaterializedCharacters",
  )
  assert_reader_order_refuses(
    source,
    reader_order_budget(
      max_node_visits=45,
      max_projected_chars=1,
      max_retained_contributors=4,
      max_depth=5,
    ),
    "DocxXmlTokens",
  )
}

///|
/// A checkbox content control, which the projection now mirrors.
///
/// `BodyReader::read_structured_document_tag` applies a second transform after
/// selecting the content: when the first `w:sdtPr` carries a `w14:checkbox`,
/// `replace_first_text_with_checkbox` swaps the first non-empty text for a
/// checkbox element. The checkbox carries no text of its own, so the story
/// loses that text while the paragraph around it survives.
///
/// This test previously pinned the divergence and said that when the transform
/// landed the correct change was to assert equality rather than relax it. That
/// is what happened.
test "a checkbox content control replaces its first text" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body><w:sdt><w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr><w:sdtContent><w:p><w:r><w:t>hello</w:t></w:r></w:p></w:sdtContent></w:sdt></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  inspect(current_reader_story_text(source), content="\n\n")
  inspect(provisional_story_text(projection), content="\n\n")
}

///|
/// One of the two checkbox shapes still unmirrored: an *inline* control whose
/// content yields no text at all. The other is a control wrapping a table
/// cell, pinned below.
///
/// With no text to replace, the reader discards the content entirely and
/// returns a bare checkbox, so the content's paragraph never reaches the
/// story. At block level the projection does the same. Inline it cannot yet,
/// because walking the content splits the enclosing paragraph, and that split
/// flushes the text preceding the control into the same completed paragraph as
/// the control's own -- so dropping by index takes content the control never
/// owned. Undoing the split is a larger change than the slice that landed the
/// rest of this transform.
///
/// Measured rather than reasoned about, and narrower than what it replaced:
/// every checkbox control used to diverge.
test "an inline checkbox control with no text still diverges" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body><w:p><w:r><w:t>x</w:t></w:r><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:p><w:r><w:tab/></w:r></w:p></w:sdtContent></w:sdt></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  inspect(current_reader_story_text(source), content="x\n\n")
  inspect(provisional_story_text(projection), content="x\t\n\n\n\n")
}

///|
/// A textbox inside a deleted table row, where the table sits inside a
/// paragraph. Pre-existing divergence, unrelated to any content-control work.
///
/// The reader suppresses a deleted row's content but still finds textboxes
/// inside it, because `read_paragraph_extra_elements` recurses physically
/// through the enclosing paragraph and reaches the row regardless. This
/// projection loses that textbox. The same table at block level agrees --
/// nothing emits it there, because no paragraph extras pass covers it -- so
/// the divergence needs the table nested inside a paragraph, which tolerant
/// input allows and real documents occasionally contain.
///
/// Verified present on `main` before the content-control work, and reachable
/// only once the generator began placing blocks inside paragraphs. Pinned here
/// so it is visible while it waits for its own fix.
test "a textbox in a deleted row inside a paragraph still diverges" {
  let textbox =
    #|<w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>A</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict>
  let table = "<w:tbl><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r>\{textbox}<w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body><w:p><w:r><w:t>x</w:t></w:r>\{table}</w:p></w:body></w:document>"
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  // The reader finds the textbox through the paragraph's physical extras pass.
  inspect(current_reader_story_text(source), content="x\n\nA\n\n")
  // The projection does not.
  inspect(provisional_story_text(projection), content="x\n\n")
}

///|
/// The second no-text checkbox shape still unmirrored: one wrapping a table
/// cell.
///
/// The vMerge prepass decides which rows and cells exist before the walk runs,
/// and it does not know about the checkbox transform. So it sees the cell the
/// control declares, while the reader has already replaced the whole content
/// with a bare checkbox and has no cell there at all.
///
/// Teaching the prepass this rule means giving it its own answer to "does this
/// content yield any text", separate from the walk's. An approximation that
/// disagreed with the walk would trade one divergence for a subtler one, so it
/// is left until the prepass and the walk can share that answer.
///
/// Predicted by review before it was measured, which is why it is here rather
/// than waiting to be found.
test "a no-text checkbox control wrapping a cell still diverges" {
  let checkbox =
    #|<w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr>
  let under =
    #|<w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>under</w:t></w:r></w:p></w:tc>
  let body = "<w:tbl><w:tr><w:sdt>\{checkbox}<w:sdtContent><w:tc><w:p><w:r><w:tab/></w:r></w:p></w:tc></w:sdtContent></w:sdt></w:tr><w:tr>\{under}</w:tr></w:tbl>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body>\{body}</w:body></w:document>"
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  inspect(current_reader_story_text(source), content="under\n\n")
  inspect(provisional_story_text(projection), content="")
}

///|
/// Checkbox shapes that one boolean and one atom kind got wrong.
///
/// Nested controls each contribute a transform, applied inside out, so a
/// content control two deep inside checkbox controls loses its first *two*
/// texts -- the inner replaces the first, then the outer replaces the first
/// still standing in the result. Tracking that with a single flag replaced one
/// text and then discarded the outer control wholesale.
///
/// And "text" is every element `read_element` turns into one, not just `w:t`.
/// A soft hyphen, a non-breaking hyphen and a supported symbol all become text
/// and are all replaceable; a tab does not and is not. Recognising only `w:t`
/// made a control holding just a soft hyphen look textless, so the projection
/// discarded a paragraph the reader keeps.
///
/// All six measured against the reader.
test "checkbox controls nest, and every reader text kind is replaceable" {
  let properties =
    #|<w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr>
  let control = fn(content : String) -> String {
    "<w:sdt>\{properties}<w:sdtContent>\{content}</w:sdtContent></w:sdt>"
  }
  let run = fn(inner : String) -> String { "<w:p><w:r>\{inner}</w:r></w:p>" }
  let cases = [
    // both texts go: the inner transform takes the first, the outer the second
    (control(control(run("<w:t>a</w:t><w:t>b</w:t>"))), "\n\n"),
    // each of these is a text to the reader, so the paragraph survives
    (control(run("<w:softHyphen/>")), "\n\n"),
    (control(run("<w:noBreakHyphen/>")), "\n\n"),
    (control(run("<w:sym w:font=\"Wingdings\" w:char=\"F0FC\"/>")), "\n\n"),
    // a tab is not, so the control is textless and its content is discarded
    (control(run("<w:tab/>")), ""),
  ]
  for case in cases {
    let (body, expected) = case
    let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body>\{body}</w:body></w:document>"
    let projection = scan_reader_order_projection(
      "word/document.xml",
      @utf8.encode(source),
    )
    assert_eq(current_reader_story_text(source), expected)
    assert_eq(provisional_story_text(projection), expected)
  }
}

///|
/// Every contribution's interval indexes the *reader's* story text, and
/// slicing there yields exactly what the contribution says it produced.
///
/// This is the claim surgery depends on. An interval that is merely
/// self-consistent with the projection's own text proves nothing -- the
/// projection built both. Slicing the reader's output instead makes the
/// index answer for itself against the engine it models.
fn assert_reader_order_intervals_index_the_reader(
  source : String,
) -> Unit raise {
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  let story = current_reader_story_text(source)
  let mut expected_paragraph = 0
  // Absolute placement, not just internal consistency. Without this the
  // property passes on a projection that has lost a paragraph entirely: the
  // surviving intervals stay self-consistent and the missing tail is never
  // inspected. The first paragraph starts at zero, each next one two units
  // past the previous one's end, and after the last the running offset has to
  // land exactly on the end of the reader's story.
  let mut expected_start = 0
  for paragraph in projection.paragraphs {
    assert_eq(paragraph.logical_index, expected_paragraph)
    expected_paragraph = expected_paragraph + 1
    assert_eq(paragraph.projection_start, expected_start)
    assert_true(paragraph.projection_end >= paragraph.projection_start)
    assert_true(paragraph.projection_end <= story.length())
    let mut previous_end = paragraph.projection_start
    // run identity -> the index it was assigned, to check that the mapping is
    // a bijection onto a dense range rather than merely non-negative
    let seen_runs : Map[Int, Int] = Map([])
    let used_indices : Map[Int, Int] = Map([])
    for contribution in paragraph.contributions {
      // contiguous and in order: no gaps, no overlaps, no reordering
      assert_eq(contribution.projection_start, previous_end)
      assert_eq(
        contribution.projection_end - contribution.projection_start,
        contribution.value.length(),
      )
      previous_end = contribution.projection_end
      // and the bytes there really are this contribution's text
      assert_eq(
        story
        .view(
          start_offset=contribution.projection_start,
          end_offset=contribution.projection_end,
        )
        .to_owned(),
        contribution.value,
      )
      // run indices are dense and assigned by first appearance
      match contribution.run_identity {
        Some(identity) => {
          assert_true(contribution.logical_run_index >= 0)
          // one index per run, and one run per index
          match seen_runs.get(identity) {
            Some(assigned) =>
              assert_eq(contribution.logical_run_index, assigned)
            None => {
              assert_true(
                used_indices.get(contribution.logical_run_index) is None,
              )
              // the next index, so the order is first appearance and not some
              // other permutation a uniqueness check alone would accept
              assert_eq(contribution.logical_run_index, seen_runs.length())
              seen_runs[identity] = contribution.logical_run_index
              used_indices[contribution.logical_run_index] = identity
            }
          }
        }
        None => assert_eq(contribution.logical_run_index, -1)
      }
    }
    assert_eq(previous_end, paragraph.projection_end)
    // dense from zero: with n distinct runs the indices are exactly 0..n-1, so
    // a path like `p[i]/r[j]` names one run and every run has a path
    for index in 0..<seen_runs.length() {
      assert_true(used_indices.get(index) is Some(_))
    }
    // and every run the paragraph *declares* has a path, not only the ones
    // that happened to contribute. An atomless `<w:r/>` contributes nothing
    // but a seam, and run synthesis in N0c has to be able to address it.
    for source in paragraph.sources {
      for run in source.runs {
        assert_true(seen_runs.get(run.identity) is Some(_))
      }
    }
    // The units the offset skips have to *be* the separator. Advancing past
    // them without looking left a hole: for a story "abcd\n\n" a projection
    // split as ["ab", ""] satisfies every check above -- starts 0 and 4,
    // slices match, final offset 6 -- while projecting "ab\n\n\n\n".
    assert_eq(
      story
      .view(
        start_offset=paragraph.projection_end,
        end_offset=paragraph.projection_end + 2,
      )
      .to_owned(),
      "\n\n",
    )
    // Literal 2, not the constant the implementation uses. Sharing it made the
    // oracle move with the code: setting the constant to 3 left this check
    // green, because both sides agreed with each other and neither agreed with
    // the reader.
    expected_start = paragraph.projection_end + 2
  }
  // Every paragraph accounted for. The reader writes the separator after each
  // one, including the last, so the running offset ends on the story length --
  // which is what makes a dropped paragraph visible here.
  assert_eq(expected_start, story.length())
  // And the total: what the projection projects is what the reader read. With
  // this, no arrangement of individually-consistent intervals can describe a
  // different story than the one they are indexing.
  assert_eq(provisional_story_text(projection), story)
  // Deliberately *not* compared against the reader's `Paragraph` element count
  // here. The two shapes differ by design, though not for the reason it first
  // looks: `read_paragraph_elements` appends text-box extras as *siblings* of
  // the carrier paragraph, not inside it. The mismatch comes from nested
  // blocks -- a `w:tbl` inside a `w:p` leaves the reader with one `Paragraph`
  // element whose children serialise as several paragraphs of story, while
  // `consume_inline_block_output` splits the carrier into separate projected
  // paragraphs. Counting `Paragraph` elements without mirroring
  // `to_raw_text`'s whole recursion undercounts: measured on a generated
  // document, four against five projected, with identical flat text.
  //
  // The risk that comparison was meant to cover -- a projection splitting one
  // reader paragraph whose own text contains the separator -- is covered
  // directly by "a separator inside one paragraph does not split it" below,
  // where the count is known from the source rather than from either side's
  // output.
}

///|
test "intervals index the reader's story text" {
  let sources = [
    // plain text, and an astral character, which is two UTF-16 units
    "<w:p><w:r><w:t>hello</w:t></w:r></w:p>", "<w:p><w:r><w:t>a\u{1F600}b</w:t></w:r></w:p>",
    // several runs, so run indices have to be assigned by first appearance
     "<w:p><w:r><w:t>one</w:t></w:r><w:r><w:t>two</w:t></w:r><w:r><w:t>three</w:t></w:r></w:p>",
    // more than one paragraph, so the separator has to be accounted for
     "<w:p><w:r><w:t>first</w:t></w:r></w:p><w:p><w:r><w:t>second</w:t></w:r></w:p>",
    // a checkbox control, whose replaced text must occupy an empty interval
     "<w:sdt><w:sdtPr><w14:checkbox><w14:checked w14:val=\"1\"/></w14:checkbox></w:sdtPr><w:sdtContent><w:p><w:r><w:t>replaced</w:t><w:t>kept</w:t></w:r></w:p></w:sdtContent></w:sdt>",
    // atoms that are not text
     "<w:p><w:r><w:t>a</w:t><w:tab/><w:softHyphen/><w:t>b</w:t></w:r></w:p>",
  ]
  for body in sources {
    assert_reader_order_intervals_index_the_reader(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body>\{body}</w:body></w:document>",
    )
  }
}

///|
/// The interval property has to be able to fail.
///
/// Its first version checked that intervals were contiguous and that each one
/// sliced the reader's text correctly, but never where the first paragraph
/// started or where the last one ended. That passes on a projection which has
/// lost a paragraph outright: the surviving intervals stay self-consistent and
/// the missing tail is never looked at. Review caught it.
///
/// #427 is a document where the projection does lose a paragraph, so it makes
/// a ready-made negative case: the property must reject it. The generated
/// corpus excludes the shape deliberately, which is why the suite stays green
/// while this divergence is still open.
test "the interval property rejects a projection that lost a paragraph" {
  let textbox =
    #|<w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>A</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict>
  let table = "<w:tbl><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r>\{textbox}<w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let source = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:v=\"urn:schemas-microsoft-com:vml\"><w:body><w:p><w:r><w:t>x</w:t></w:r>\{table}</w:p></w:body></w:document>"
  let mut rejected = false
  try assert_reader_order_intervals_index_the_reader(source) catch {
    _ => rejected = true
  } noraise {
    _ => ()
  }
  assert_true(rejected)
}

///|
/// A paragraph whose own text contains the separator must not be split.
///
/// `"a\n\nb"` in a single `w:t` serialises exactly like two paragraphs holding
/// `"a"` and `"b"`, so flat story equality cannot tell them apart. A projection
/// that split the first would invent a `p[1]` that surgery could address and
/// the reader has never heard of.
///
/// The expected counts come from the source, not from either side's output.
test "a separator inside one paragraph does not split it" {
  let document = fn(body : String) -> String {
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\{body}</w:body></w:document>"
  }
  let joined = document("<w:p><w:r><w:t>a&#10;&#10;b</w:t></w:r></w:p>")
  let split = document(
    "<w:p><w:r><w:t>a</w:t></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r></w:p>",
  )
  // identical stories
  assert_eq(current_reader_story_text(joined), "a\n\nb\n\n")
  assert_eq(current_reader_story_text(split), "a\n\nb\n\n")
  // and distinguishable structures
  let one = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(joined),
  )
  let two = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(split),
  )
  assert_eq(one.paragraphs.length(), 1)
  assert_eq(two.paragraphs.length(), 2)
  assert_reader_order_intervals_index_the_reader(joined)
  assert_reader_order_intervals_index_the_reader(split)
}

///|
/// An atomless run still has an address.
///
/// `<w:r/>` contributes no text, only the seam the walk opens for it. The run
/// oracle derives its expectations from `paragraph.sources[*].runs`, which is
/// the implementation's own output -- so a regression dropping such a run from
/// both that list and the contributions would make every check vacuous rather
/// than failing. The count here comes from the source instead.
///
/// N0c synthesises a `w:t` into exactly this kind of run, so losing its address
/// would lose the ability to write into it.
test "an atomless run is still addressable" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r/><w:r><w:t>x</w:t></w:r><w:r/></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  assert_eq(projection.paragraphs.length(), 1)
  let paragraph = projection.paragraphs[0]
  // three runs in the source, so three distinct addresses, numbered in order
  let indices : @sorted_set.SortedSet[Int] = SortedSet([])
  for contribution in paragraph.contributions {
    if contribution.run_identity is Some(_) {
      indices.add(contribution.logical_run_index)
    }
  }
  assert_eq(indices.to_array(), [0, 1, 2])
  assert_reader_order_intervals_index_the_reader(source)
}

///|
/// A physical run does *not* always contribute to exactly one logical
/// paragraph, which is worth stating because the opposite is the natural
/// assumption and surgery depends on knowing better.
///
/// `consume_inline_block_output` re-opens the runs that were active when a
/// nested block split the carrier paragraph, so a run whose content straddles
/// that block appears in both halves. Found by asserting the opposite and
/// watching it fail after 57 generated documents.
///
/// So `p[i]/r[j]` names a run *within a paragraph*, not a physical run
/// uniquely, and an edit addressed that way has to refuse when the run reaches
/// further -- which is what `plan_whole_run_replacement` does.
test "a run whose content straddles a nested block spans two paragraphs" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>before</w:t><w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:t>after</w:t></w:r></w:p></w:body></w:document>
  let projection = scan_reader_order_projection(
    "word/document.xml",
    @utf8.encode(source),
  )
  let owner : Map[Int, Array[Int]] = Map([])
  for index, paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      match contribution.run_identity {
        Some(identity) => {
          let seen = owner.get(identity).unwrap_or([])
          if !seen.contains(index) {
            seen.push(index)
          }
          owner[identity] = seen
        }
        None => ()
      }
    }
  }
  let mut shared = 0
  for pair in owner {
    let (_, paragraphs) = pair
    if paragraphs.length() > 1 {
      shared = shared + 1
    }
  }
  assert_true(shared >= 1)
}
