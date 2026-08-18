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
fn effect_paragraph_texts(items : Array[ReaderItem]) -> Array[String] {
  let paragraphs : Array[String] = []
  let buffer = StringBuilder()
  flatten_effect_paragraphs(items, paragraphs, buffer)
  paragraphs
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
          ReaderParagraph(sources=_, children~, extras~, properties=_) => {
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
  assert_eq(
    effect_paragraph_texts(reader_effect_items(source)),
    reader_paragraph_texts(source),
  )
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
    content="boundary(w:sdt) ; suppressed(w:t) ; nontext(w:t)",
  )
  assert_effect_partition_matches_reader(xml)
}

///|
test "reader effects: sdt checkbox without text synthesises at the control" {
  let xml =
    #|<w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:p><w:r><w:sdt><w:sdtPr><w14:checkbox/></w:sdtPr><w:sdtContent><w:tab/></w:sdtContent></w:sdt></w:r></w:p></w:body>
  inspect(
    effect_summaries(reader_effect_items(xml)),
    content="boundary(w:sdt) ; suppressed(w:sdtContent) ; nontext(w:sdt)",
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
