// The reader-effect stream (#434 PR 2c). Every decision site that produces,
// passes through, or suppresses story content records what it decided;
// these tests pin the classification per dispatch outcome, the transform
// rewrites, and the agreement between the stream's `ProjectsText` partition
// and the erased reader's own paragraph texts.

///|
/// Read a body fragment and return the raw carrier items, effects included.
fn reader_effect_items(source : String) -> Array[ReaderItem] raise DocxError {
  let root = read_xml_string(source, namespace_map=office_namespace_map())
  let node = ReaderNode::of(root)
  let children = match node.first("w:body") {
    Some(body) => body.element_children()
    None => node.element_children()
  }
  empty_body_reader({ relationships: [] }).read_children(children)
}

///|
fn effect_summary(effect : ReaderEffect) -> String {
  match effect {
    ProjectsText(source~, kind~, value~) => {
      let kind_label = match kind {
        FromText => "text"
        FromTab => "tab"
        FromNoBreakHyphen => "noBreakHyphen"
        FromSoftHyphen => "softHyphen"
        FromSymbol => "symbol"
      }
      "\{kind_label}(\{source.name()})=\{value}"
    }
    ProjectsVisibleNonText(source~) => "nontext(\{source.name()})"
    TransparentBoundary(source~) => "boundary(\{source.name()})"
    Suppressed(source~) => "suppressed(\{source.name()})"
  }
}

///|
fn effect_summaries(items : Array[ReaderItem]) -> String {
  collect_reader_effects(items).map(effect_summary).join(" ; ")
}

///|
/// The `ProjectsText` partition: paragraph texts derived from effects alone,
/// mirroring `flatten_reader_paragraphs` over the carrier -- a shared buffer
/// that each `ReaderParagraph` closes, extras walked as the siblings they
/// erase into.
fn effect_paragraph_texts(items : Array[ReaderItem]) -> (Array[String], String) {
  let paragraphs : Array[String] = []
  let buffer = StringBuilder()
  flatten_effect_paragraphs(items, paragraphs, buffer)
  (paragraphs, buffer.to_string())
}

///|
fn flatten_effect_paragraphs(
  items : Array[ReaderItem],
  paragraphs : Array[String],
  buffer : StringBuilder,
) -> Unit {
  for item in items {
    match item {
      Trace(_) => ()
      New(tree) => {
        for effect in tree.local_effects {
          match effect {
            ProjectsText(source=_, kind=_, value~) => buffer.write_string(value)
            _ => ()
          }
        }
        match tree.shape {
          ReaderParagraph(inputs=_, children~, extras~, properties=_) => {
            flatten_effect_paragraphs(children, paragraphs, buffer)
            paragraphs.push(buffer.to_string())
            buffer.reset()
            flatten_effect_paragraphs(extras, paragraphs, buffer)
          }
          ReaderRun(children~, properties=_) =>
            flatten_effect_paragraphs(children, paragraphs, buffer)
          ReaderHyperlink(children~, ..) =>
            flatten_effect_paragraphs(children, paragraphs, buffer)
          ReaderTable(children~, properties=_) =>
            flatten_effect_paragraphs(children, paragraphs, buffer)
          ReaderTableRow(children~, is_header=_) =>
            flatten_effect_paragraphs(children, paragraphs, buffer)
          ReaderTableCell(children~, ..) =>
            flatten_effect_paragraphs(children, paragraphs, buffer)
          ReaderText(_)
          | ReaderTab
          | ReaderCheckbox(_)
          | ReaderNoteReference(..)
          | ReaderCommentReference(_)
          | ReaderImage(_)
          | ReaderBreak(_)
          | ReaderBookmarkStart(_) => ()
        }
      }
    }
  }
}

///|
/// The effect stream's text partition agrees with the erased reader's own
/// paragraph partition (which `reader_paragraph_texts` itself checks against
/// `to_raw_text`).
fn assert_effect_partition_matches_reader(source : String) -> Unit raise {
  let items = reader_effect_items(source)
  let (paragraphs, trailing) = effect_paragraph_texts(items)
  assert_eq(paragraphs, reader_paragraph_texts(source))
  // `reader_paragraph_texts` asserts the erased side leaves no text after
  // the last paragraph; a phantom trailing contribution on the effect side
  // would otherwise vanish here unchecked
  assert_eq(trailing, "")
  // the production collector must carry the same text in the same order as
  // the tree walk above -- a dropped or reordered `ProjectsText` in
  // `collect_reader_effects` would otherwise stay invisible here. (Non-text
  // kinds are pinned per decision site by the witnesses in this file.)
  let collected = StringBuilder()
  for effect in collect_reader_effects(items) {
    if effect is ProjectsText(source=_, kind=_, value~) {
      collected.write_string(value)
    }
  }
  let walked = StringBuilder()
  for text in paragraphs {
    walked.write_string(text)
  }
  walked.write_string(trailing)
  assert_eq(collected.to_string(), walked.to_string())
}

///|
test "reader effects classify the atom kinds" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>A</w:t><w:tab/><w:noBreakHyphen/><w:softHyphen/><w:sym w:font="Symbol" w:char="64"/></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="text(w:t)=A ; tab(w:tab)=\t ; noBreakHyphen(w:noBreakHyphen)=‑ ; softHyphen(w:softHyphen)=­ ; symbol(w:sym)=δ",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects mark visible non-text outputs" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:br/><w:br w:type="page"/><w:footnoteReference w:id="1"/><w:endnoteReference w:id="2"/><w:commentReference w:id="3"/></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="nontext(w:br) ; nontext(w:br) ; nontext(w:footnoteReference) ; nontext(w:endnoteReference) ; nontext(w:commentReference)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects mark boundaries at markers and pass-through containers" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:bookmarkStart w:id="0" w:name="here"/><w:bookmarkStart w:id="1" w:name="_GoBack"/><w:bookmarkEnd w:id="0"/><w:hyperlink w:anchor="here"><w:r><w:t>A</w:t></w:r></w:hyperlink><w:ins><w:r><w:t>B</w:t></w:r></w:ins></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:pPr) ; boundary(w:bookmarkStart) ; boundary(w:bookmarkStart) ; boundary(w:bookmarkEnd) ; boundary(w:hyperlink) ; text(w:t)=A ; boundary(w:ins) ; text(w:t)=B",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects record suppression decisions" {
  // a pict, a deleted run, an unmapped symbol, an unsupported break, and a
  // trailing deleted paragraph with nothing to join
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:pict><v:shape xmlns:v="urn:schemas-microsoft-com:vml"/></w:pict><w:del><w:r><w:t>gone</w:t></w:r></w:del><w:sym w:font="Dingwings" w:char="28"/><w:br w:type="mystery"/></w:r></w:p><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>tail</w:t></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="suppressed(w:pict) ; suppressed(w:del) ; suppressed(w:sym) ; suppressed(w:br) ; suppressed(w:p)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects select the alternate fallback and suppress choices" {
  // the tolerant parser splices literal child `mc:AlternateContent` at parse
  // time; the reader arm is the root-level and constructed-tree path, so the
  // witness drives it at the root like "docx body reader uses mc fallback
  // content like Mammoth"
  let xml =
    #|<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><mc:Choice Requires="wps"><w:t>choice</w:t></mc:Choice><mc:Fallback><w:t>fallback</w:t></mc:Fallback></mc:AlternateContent>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  inspect(
    effect_summaries(
      empty_body_reader({ relationships: [] }).read_element(
        ReaderNode::of(root),
      ),
    ),
    content="boundary(mc:AlternateContent) ; suppressed(mc:Choice) ; text(w:t)=fallback",
  )
}

///|
test "reader effects suppress every non-first sdt content" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:sdt><w:sdtContent><w:t>first</w:t></w:sdtContent><w:sdtContent><w:t>second</w:t></w:sdtContent></w:sdt></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:sdt) ; text(w:t)=first ; suppressed(w:sdtContent)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects: checkbox replacement suppresses the text it replaces" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:p><w:r><w:sdt><w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr><w:sdtContent><w:t>replaced</w:t></w:sdtContent></w:sdt></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:sdt) ; boundary(w:sdtPr) ; suppressed(w:t) ; nontext(w:t)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects: sdt checkbox without text synthesises at the control" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:p><w:r><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:tab/></w:sdtContent></w:sdt></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:sdt) ; boundary(w:sdtPr) ; suppressed(w:sdtContent) ; nontext(w:sdt)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects: vmerge continuation cells suppress in place" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>top</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>under</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:tcPr) ; text(w:t)=top ; suppressed(w:tc)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects: complex field checkbox and hyperlink synthesis" {
  let checkbox_xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> FORMCHECKBOX </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(checkbox_xml)),
    content="boundary(w:fldChar) ; suppressed(w:instrText) ; nontext(w:r) ; boundary(w:fldChar)",
  )
  assert_effect_partition_matches_reader(checkbox_xml)
  let hyperlink_xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://example.com" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>link</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(hyperlink_xml)),
    content="boundary(w:fldChar) ; suppressed(w:instrText) ; boundary(w:fldChar) ; boundary(w:r) ; text(w:t)=link ; boundary(w:fldChar)",
  )
  assert_effect_partition_matches_reader(hyperlink_xml)
}

///|
/// A marker inside an open HYPERLINK field returns only a trace; wrapping it
/// would fabricate an empty hyperlink element the erased reader never
/// produced. The trace passes through unwrapped, in place.
test "reader effects: traces inside an open hyperlink field are not wrapped" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://example.com" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:bookmarkEnd w:id="0"/><w:r><w:t>link</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body>
  let items = reader_effect_items(xml)
  for element in reader_items_to_elements(items) {
    guard element is Paragraph(children~, ..) else {
      fail("expected a paragraph")
    }
    for child in children {
      if child is Hyperlink(children=[], ..) {
        fail("an empty hyperlink was fabricated around a trace")
      }
    }
  }
  inspect(
    effect_summaries(items),
    content="boundary(w:fldChar) ; suppressed(w:instrText) ; boundary(w:fldChar) ; boundary(w:bookmarkEnd) ; boundary(w:r) ; text(w:t)=link ; boundary(w:fldChar)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
/// The erased pipeline wrapped each ERASED element in the open field's
/// hyperlink, so a tolerated nested paragraph -- one item, but paragraph
/// plus extras when erased -- becomes one hyperlink per erased sibling,
/// never one hyperlink swallowing them all.
test "reader effects: open field wraps a paragraph's extras as separate hyperlinks" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://e" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>X</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body>
  let items = reader_effect_items(xml)
  // outer paragraph: three field-marker runs, the wrapped empty carrier,
  // the wrapped textbox extra, the end run; then the OUTER paragraph's own
  // extras pass re-homes the textbox once more, unwrapped -- exactly the
  // erased pipeline's shape
  guard reader_items_to_elements(items)
    is [
      Paragraph(
        children=[
          Run(children=[], ..),
          Run(children=[], ..),
          Run(children=[], ..),
          Hyperlink(
            children=[Paragraph(children=[Run(children=[], ..)], ..)],
            ..
          ),
          Hyperlink(
            children=[Paragraph(children=[Run(children=[Text("X")], ..)], ..)],
            ..
          ),
          Run(children=[], ..),
        ],
        ..
      ),
      Paragraph(children=[Run(children=[Text("X")], ..)], ..),
    ] else {
    fail("expected one hyperlink per erased sibling")
  }
  assert_effect_partition_matches_reader(xml)
}

///|
/// A row deleted through `w:trPr/w:del` is a suppression decision.
test "reader effects: deleted table rows leave a suppression trace" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tbl><w:tr><w:trPr><w:del/></w:trPr><w:tc><w:p><w:r><w:t>gone</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>kept</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="suppressed(w:tr) ; text(w:t)=kept",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
/// An `w:instrText` sitting directly under the paragraph is consumed as
/// instruction text; the skip is recorded.
test "reader effects: a direct paragraph-level instrText is suppressed" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:instrText> PAGE </w:instrText><w:r><w:t>A</w:t></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="suppressed(w:instrText) ; text(w:t)=A",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
/// An image element that resolves to no image is a suppression at that
/// site: an unresolved relationship, and a blip the drawing reader cannot
/// read.
test "reader effects: unresolved images leave suppression traces" {
  let vml_xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:p><w:r><w:pict><v:shape><v:imagedata r:id="rIdMissing"/></v:shape></w:pict></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(vml_xml)),
    // the pict body is suppressed at its arm; the paragraph-level pict
    // extras pass then reaches the imagedata, whose unresolved relationship
    // suppresses again at that site
    content="suppressed(w:pict) ; suppressed(v:imagedata)",
  )
  let drawing_xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:p><w:r><w:drawing><wp:inline><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rIdMissing"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(drawing_xml)),
    content="boundary(w:drawing) ; suppressed(a:blip)",
  )
  assert_effect_partition_matches_reader(vml_xml)
  assert_effect_partition_matches_reader(drawing_xml)
}

///|
/// Rejections are recorded where they sit: with tolerated child order
/// `Fallback(A), Choice(B), Fallback(C)`, only the first fallback
/// contributes and everything else is suppressed in place.
test "reader effects: alternate content rejections stay in document order" {
  let xml =
    #|<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><mc:Fallback><w:t>A</w:t></mc:Fallback><mc:Choice Requires="wps"><w:t>B</w:t></mc:Choice><mc:Fallback><w:t>C</w:t></mc:Fallback></mc:AlternateContent>
  let root = read_xml_string(xml, namespace_map=office_namespace_map())
  let items = empty_body_reader({ relationships: [] }).read_element(
    ReaderNode::of(root),
  )
  inspect(
    effect_summaries(items),
    content="boundary(mc:AlternateContent) ; text(w:t)=A ; suppressed(mc:Choice) ; suppressed(mc:Fallback)",
  )
  debug_inspect(reader_items_to_elements(items), content="[Text(\"A\")]")
}

///|
/// The pict extras pass makes its own alternate-content selection; its
/// rejections are recorded at that site too.
test "reader effects: pict extras record their own alternate rejections" {
  // constructed by hand: the tolerant parser splices literal child `mc:`
  // constructs before the reader ever sees them
  let pict_alternate = xml_element("w:p", children=[
    XmlElement(
      xml_element("w:r", children=[
        XmlElement(
          xml_element("w:pict", children=[
            XmlElement(
              manual_alternate_content(
                xml_element("v:shape", children=[
                  XmlElement(manual_word_text_box_element("Choice")),
                ]),
                xml_element("v:shape", children=[
                  XmlElement(manual_word_text_box_element("Fallback")),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let items = empty_body_reader({ relationships: [] }).read_element(
    ReaderNode::of(pict_alternate),
  )
  inspect(
    effect_summaries(items),
    content="suppressed(w:pict) ; boundary(mc:AlternateContent) ; suppressed(mc:Choice) ; text(w:t)=Fallback",
  )
}

///|
/// A drawing container with no blips materialises nothing; the decision is
/// recorded at the container.
test "reader effects: a drawing without blips is suppressed at its container" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"><w:p><w:r><w:drawing><wp:inline/></w:drawing></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:drawing) ; suppressed(wp:inline)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
/// A deleted paragraph that never joins a successor is suppressed AT ITS
/// POSITION, even when non-paragraph content follows it.
test "reader effects: unjoined deleted paragraphs suppress in document order" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>tail</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>kept</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="suppressed(w:p) ; text(w:t)=kept",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
/// A stray non-content child of a control is rejected where it sits, the
/// same name-blind rule alternate content follows.
test "reader effects: sdt rejects stray non-content children in place" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:sdt><w:r><w:t>dropped</w:t></w:r><w:sdtContent><w:t>kept</w:t></w:sdtContent></w:sdt></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:sdt) ; suppressed(w:r) ; text(w:t)=kept",
  )
  assert_effect_partition_matches_reader(xml)
}
