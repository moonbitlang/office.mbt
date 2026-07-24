///|
fn projection_index_of(xml : String) -> StoryProjectionIndex raise {
  let bytes = @utf8.encode(xml)
  build_story_projection_index(
    "word/document.xml",
    bytes,
    token_map_budget(bytes.length(), bytes.length() + 1),
  )
}

///|
fn projection_reader_text(xml : String) -> String raise {
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  guard root.first("w:body") is Some(body) else {
    fail("reader oracle requires a body")
  }
  document(
    empty_body_reader({ relationships: [] }).read_children(body.children),
  ).to_raw_text()
}

///|
fn StoryProjectionIndex::reader_text(self : StoryProjectionIndex) -> String {
  let output = StringBuilder()
  for paragraph in self.logical_paragraphs {
    output.write_string(paragraph.projection)
    output.write_string("\n\n")
  }
  output.to_string()
}

///|
fn assert_projection_oracle(xml : String) -> StoryProjectionIndex raise {
  let indexed = projection_index_of(xml)
  assert_eq(indexed.reader_text(), projection_reader_text(xml))
  indexed
}

///|
fn projection_piece_count(
  paragraph : PhysicalParagraphProjection,
  class? : ProjectionClass,
  reason? : String,
) -> Int {
  let mut count = 0
  for piece in paragraph.pieces {
    if (class is None || class == Some(piece.class)) &&
      (reason is None || reason == piece.reason) {
      count += 1
    }
  }
  count
}

///|
fn assert_projection_refuses(xml : String, fragment : String) -> Unit raise {
  try projection_index_of(xml) |> ignore catch {
    ProjectionIndexError(message) => {
      assert_true(message.contains("word/document.xml#"))
      assert_true(message.contains(fragment))
    }
    _ => fail("unexpected projection-index error")
  } noraise {
    _ => fail("expected projection-index refusal containing: " + fragment)
  }
}

///|
test "projection index: hostile inline matrix is reader-exact and classified" {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:body><w:p><w:pPr><w:rPr><w:t>property</w:t><w:tab/></w:rPr></w:pPr><w:r><w:t>A&amp;😀</w:t></w:r><!-- seam --><?n0b seam?><w:r><w:tab/><w:noBreakHyphen/><w:softHyphen/><w:sym w:font="Wingdings" w:char="28"/><w:sym w:font="Dingwings" w:char="28"/><w:br/></w:r><w:proofErr><w:t>proof</w:t></w:proofErr><w:hyperlink><w:r><w:t>H</w:t></w:r></w:hyperlink><w:ins><w:r><w:t>I</w:t></w:r></w:ins><w:del><w:r><w:t>deleted</w:t></w:r></w:del><w:sdt><w:sdtPr/><w:sdtContent><w:r><w:t>S</w:t></w:r></w:sdtContent></w:sdt><w:sdt><w:sdtContent><w:r><w:noBreakHyphen/><w:t>checked</w:t><w:tab/><w:t>tail</w:t></w:r></w:sdtContent><w:sdtPr><w14:checkbox/></w:sdtPr></w:sdt><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:r><w:tab/><w:t>inner</w:t><w:t>after-inner</w:t></w:r></w:sdtContent></w:sdt><w:r><w:t>outer-tail</w:t></w:r></w:sdtContent></w:sdt><mc:AlternateContent><mc:Choice Requires="w14"><w:r><w:t>choice</w:t></w:r></mc:Choice><mc:Fallback><w:r><w:t>F</w:t></w:r></mc:Fallback></mc:AlternateContent><w:unknown><w:r><w:t>unknown</w:t></w:r></w:unknown></w:p></w:body></w:document>
  let indexed = assert_projection_oracle(xml)
  assert_eq(indexed.physical_paragraphs.length(), 1)
  let paragraph = indexed.physical_paragraphs[0]
  assert_eq(
    paragraph.output.to_string(),
    "A&😀\t‑­🕿HISchecked\ttail\touter-tailF",
  )
  assert_true(projection_piece_count(paragraph, class=EditableText) > 0)
  assert_true(projection_piece_count(paragraph, class=ProjectingAtom) >= 4)
  assert_true(projection_piece_count(paragraph, class=TransparentSeam) >= 3)
  assert_true(projection_piece_count(paragraph, class=HardBarrier) >= 3)
  assert_true(projection_piece_count(paragraph, class=RestrictedRegion) >= 4)
  assert_true(projection_piece_count(paragraph, class=SuppressedRegion) >= 2)
  assert_eq(projection_piece_count(paragraph, reason="checkbox-sdt-text"), 3)
  assert_eq(paragraph.runs[0].projection_start, 0)
  assert_eq(paragraph.runs[0].projection_end, 4)
  assert_true(paragraph.byte_start < paragraph.runs[0].byte_start)
  assert_true(paragraph.runs[0].byte_end <= paragraph.byte_end)
}

///|
test "projection index: alternate prefixes and Strict default WML are exact" {
  let transitional =
    #|<x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><x:body><x:p><x:r><x:t>alt</x:t><x:tab/><x:sym x:font="Symbol" x:char="41"/></x:r></x:p></x:body></x:document>
  let strict =
    #|<document xmlns="http://purl.oclc.org/ooxml/wordprocessingml/main" xmlns:s="http://purl.oclc.org/ooxml/wordprocessingml/main"><body><p><r><t>strict</t><noBreakHyphen/><sym s:font="Symbol" s:char="42"/></r></p></body></document>
  let alternate = assert_projection_oracle(transitional)
  let defaulted = assert_projection_oracle(strict)
  assert_eq(alternate.logical_paragraphs[0].projection, "alt\tΑ")
  assert_eq(defaulted.logical_paragraphs[0].projection, "strict‑Β")
}

///|
test "projection index: story-wide nested field results remain restricted" {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:t>pre</w:t></w:r><w:r><w:instrText> OUTER </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>outer</w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>inner</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p><w:p><w:r><w:t>tail</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
  let indexed = assert_projection_oracle(xml)
  assert_eq(indexed.logical_paragraphs.length(), 2)
  assert_eq(indexed.logical_paragraphs[0].projection, "preouterinner")
  assert_eq(indexed.logical_paragraphs[1].projection, "tail")
  assert_eq(
    projection_piece_count(
      indexed.physical_paragraphs[0],
      class=RestrictedRegion,
    ),
    8,
  )
  assert_eq(
    projection_piece_count(
      indexed.physical_paragraphs[1],
      class=RestrictedRegion,
    ),
    2,
  )
}

///|
test "projection index: malformed and ambiguous complex fields fail closed" {
  let prefix =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p>
  let suffix = "</w:p></w:body></w:document>"
  let marker = fn(kind : String) -> String {
    "<w:r><w:fldChar w:fldCharType=\"" + kind + "\"/></w:r>"
  }
  assert_projection_refuses(prefix + marker("end") + suffix, "end has no open")
  assert_projection_refuses(
    prefix +
    marker("begin") +
    marker("separate") +
    marker("separate") +
    marker("end") +
    suffix,
    "invalid complex-field separator",
  )
  assert_projection_refuses(
    prefix + marker("begin") + suffix,
    "remains open at story end",
  )
  assert_projection_refuses(
    prefix +
    "<w:hyperlink><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:hyperlink>" +
    suffix,
    "ambiguous field markers",
  )
}

///|
test "projection index: deleted paragraph marks map physical prefixes to one logical paragraph" {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>A</w:t></w:r></w:p><w:p><w:r><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let indexed = assert_projection_oracle(xml)
  assert_eq(indexed.physical_paragraphs.length(), 2)
  assert_eq(indexed.logical_paragraphs.length(), 1)
  assert_eq(indexed.logical_paragraphs[0].projection, "AB")
  assert_eq(indexed.logical_paragraphs[0].physical_paths, ["p[1]", "p[2]"])
  assert_true(indexed.logical_paragraphs[0].restricted)
  assert_eq(indexed.physical_paragraphs[0].logical_path, Some("p[1]"))
  assert_eq(indexed.physical_paragraphs[1].logical_path, Some("p[1]"))
}

///|
test "projection index: deleted paragraph prefixes stay within their reader parent" {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>A</w:t></w:r></w:p><w:sdt><w:sdtContent><w:p><w:r><w:t>S</w:t></w:r></w:p></w:sdtContent></w:sdt><w:p><w:r><w:t>B</w:t></w:r></w:p><w:sdt><w:sdtContent><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>D</w:t></w:r></w:p></w:sdtContent></w:sdt><w:p><w:r><w:t>C</w:t></w:r></w:p></w:body></w:document>
  let indexed = assert_projection_oracle(xml)
  assert_eq(indexed.logical_paragraphs.map(paragraph => paragraph.projection), [
    "S", "AB", "C",
  ])
  assert_eq(indexed.physical_paragraphs[0].logical_path, Some("p[2]"))
  assert_eq(indexed.physical_paragraphs[3].logical_path, None)
}

///|
test "projection index: textbox paragraphs are isolated and restricted" {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:t>A</w:t><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>X</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict><w:t>B</w:t></w:r></w:p></w:body></w:document>
  let indexed = assert_projection_oracle(xml)
  assert_eq(indexed.logical_paragraphs.length(), 2)
  assert_eq(indexed.logical_paragraphs[0].projection, "AB")
  assert_eq(indexed.logical_paragraphs[1].projection, "X")
  assert_true(indexed.physical_paragraphs[1].textbox)
  assert_true(indexed.logical_paragraphs[1].restricted)
}
