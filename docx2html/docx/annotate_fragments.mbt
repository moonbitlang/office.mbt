// L1 fragment builders: the byte fragments `docx annotate` splices into
// EXISTING documents. Per the L0 locked rule every fragment is
// namespace-SELF-CONTAINED — each top-level element declares its own
// xmlns:w — so correctness never depends on the destination document's
// bindings (which may be hostile or absent).

///|
/// The two anchor fragments for comment `id`: the range start (spliced
/// at the from-paragraph's content_start) and the range end plus the
/// reference run (spliced at the to-paragraph's close_tag_start) — the
/// same canonical shape the K1 writer emits, in self-contained form.
pub fn comment_anchor_fragments(id~ : String) -> (String, String) {
  let namespaces = { "w": WORDPROCESSINGML_NAMESPACE }
  let start = @xml.write_xml_fragment(
    @xml.xml_element("w:commentRangeStart", attributes={ "w:id": id }),
    namespaces~,
  )
  let end = @xml.write_xml_fragment(
      @xml.xml_element("w:commentRangeEnd", attributes={ "w:id": id }),
      namespaces~,
    ) +
    @xml.write_xml_fragment(
      @xml.xml_element("w:r", children=[
        XmlElement(
          @xml.xml_element("w:commentReference", attributes={ "w:id": id }),
        ),
      ]),
      namespaces~,
    )
  (start, end)
}

///|
/// The `w:comment` definition fragment for `spec` (whose anchored
/// range is ignored here — the splice layer owns placement). The body
/// is re-validated (the arrays stay caller-mutable) and serialized
/// through the same body writers as the packaging path, under the same
/// fail-closed guard against relationship-bearing content.
pub fn comment_definition_fragment(
  spec : CommentSpec,
  id~ : String,
) -> String raise DocxError {
  check_attribute_value("the comment id", id)
  check_comment_body(spec.body)
  let ctx : WriteContext = {
    used_styles: Set([]),
    uses_lists: false,
    next_relationship: 3,
    document_relationships: [],
    media: [],
    footnote_count: 0,
    endnote_count: 0,
  }
  let children : Array[XmlNode] = []
  for paragraph in spec.body {
    children.push(XmlElement(write_block(paragraph, ctx)))
  }
  if ctx.document_relationships.length() > 0 || ctx.media.length() > 0 {
    raise Unsupported(
      message="comment bodies are plain content: hyperlinks and images cannot be serialized into an annotate fragment",
    )
  }
  // Styles and list numbering resolve against the DESTINATION
  // document's parts, which annotate never rewrites — fail closed
  // rather than referencing styles the document may not define.
  if ctx.used_styles.size() > 0 || ctx.uses_lists {
    raise Unsupported(
      message="annotate comment bodies cannot use paragraph styles or lists (they would reference style and numbering definitions the existing document may not have)",
    )
  }
  let attributes : Map[String, String] = { "w:id": id, "w:author": spec.author }
  match spec.initials {
    Some(initials) => attributes["w:initials"] = initials
    None => ()
  }
  match spec.date {
    Some(date) => attributes["w:date"] = date
    None => ()
  }
  @xml.write_xml_fragment(
    @xml.xml_element("w:comment", attributes~, children~),
    namespaces={ "w": WORDPROCESSINGML_NAMESPACE },
  )
}

///|
/// Relationship types of annotation SIDECARS this tooling cannot keep
/// consistent when mutating comments (Word's modern comment identity
/// and people parts). Per the L0 matrix rule these are detected by
/// RELATIONSHIP TYPE from the main part — their presence makes
/// mutating commands fail closed. commentsExtended is NOT here: the
/// add operation never touches it (matrix row), and L2 owns it.
pub fn DocxAnnotatedResult::annotation_sidecars(
  self : DocxAnnotatedResult,
) -> Array[String] {
  self.sidecar_types.copy()
}
