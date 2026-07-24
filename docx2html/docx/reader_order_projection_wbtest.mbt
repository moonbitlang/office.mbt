// N0b2 reader-order oracles. These compare the provisional physical mapping
// with the current BodyReader while pinning the absence of final logical
// coordinates and field/SDT/Markup Compatibility transforms.

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
