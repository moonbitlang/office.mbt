// F1 of the content writers: serialize semantic body content — paragraphs
// and runs with their formatting — into a schema-valid document. The
// Mammoth AST is the INPUT model only (per the roadmap's write contract);
// the package/resource context is the builder. FAIL-CLOSED: any
// `DocumentElement` this writer does not yet support raises `Unsupported`
// rather than silently dropping content (tables land in F2, lists/numbering
// in F3, hyperlinks/images in F4).

///|
/// Serializes body content into a complete docx package. Supported today:
/// paragraphs (style id, alignment) containing runs (bold, italic,
/// underline, strikethrough, caps, super/subscript, font, size, highlight),
/// text, tabs, and line breaks. Headings use the `Heading1`..`Heading6`
/// style ids, which are emitted into the styles part so Word's outline and
/// this repo's own `outline` command both recognize them.
pub fn write_docx(body : Array[DocumentElement]) -> Bytes raise DocxError {
  let paragraphs : Array[XmlNode] = []
  let used_styles : Set[String] = Set([])
  for element in body {
    paragraphs.push(XmlElement(write_block(element, used_styles)))
  }
  paragraphs.push(XmlElement(blank_section_properties()))
  let document = @xml.write_xml_string(
    @xml.xml_element("w:document", children=[
      XmlElement(@xml.xml_element("w:body", children=paragraphs)),
    ]),
    namespaces={ "w": WORDPROCESSINGML_NAMESPACE },
  )
  let builder = @opc.PackageBuilder::new()
  build_docx_package(builder, document, styles_xml_for(used_styles)) catch {
    err =>
      raise Unsupported(
        message="could not assemble the document package: \{err}",
      )
  }
}

///|
const WORDPROCESSINGML_NAMESPACE : String = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

///|
fn build_docx_package(
  builder : @opc.PackageBuilder,
  document_xml : String,
  styles_xml : String,
) -> Bytes raise @opc.PackageBuildError {
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId1",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document_xml))
  builder.add_part("word/styles.xml", @utf8.encode(styles_xml))
  builder.build()
}

///|
fn write_block(
  element : DocumentElement,
  used_styles : Set[String],
) -> XmlElement raise DocxError {
  match element {
    Paragraph(children~, properties~) =>
      write_paragraph(children, properties, used_styles)
    other =>
      raise Unsupported(
        message="the paragraph writer cannot serialize this element yet: \{block_kind_name(other)} (tables arrive in F2, lists in F3, media in F4)",
      )
  }
}

///|
fn write_paragraph(
  children : Array[DocumentElement],
  properties : ParagraphProperties,
  used_styles : Set[String],
) -> XmlElement raise DocxError {
  let nodes : Array[XmlNode] = []
  let ppr_children : Array[XmlNode] = []
  match properties.style_id {
    Some(style_id) => {
      if !is_writable_style_id(style_id) {
        raise Unsupported(
          message="unsupported paragraph style id for the writer: '\{style_id}' (Heading1..Heading6 and Normal are supported)",
        )
      }
      used_styles.add(style_id)
      ppr_children.push(
        XmlElement(
          @xml.xml_element("w:pStyle", attributes={ "w:val": style_id }),
        ),
      )
    }
    None => ()
  }
  match properties.alignment {
    Some(alignment) => {
      // ST_Jc values that are BOTH reader-producible and SDK-schema-valid;
      // legacy 'justify' stays rejected (the SDK rejects it too).
      if !(alignment
        is ("left"
        | "center"
        | "right"
        | "both"
        | "start"
        | "end"
        | "distribute")) {
        raise Unsupported(
          message="unsupported paragraph alignment for the writer: '\{alignment}'",
        )
      }
      ppr_children.push(
        XmlElement(@xml.xml_element("w:jc", attributes={ "w:val": alignment })),
      )
    }
    None => ()
  }
  // Anything else the AST can carry on a paragraph is not writable yet —
  // fail closed rather than silently dropping reader-producible data.
  if properties.numbering is Some(_) {
    raise Unsupported(
      message="the paragraph writer cannot serialize list numbering yet (F3)",
    )
  }
  if properties.indent.start is Some(_) ||
    properties.indent.end is Some(_) ||
    properties.indent.first_line is Some(_) ||
    properties.indent.hanging is Some(_) {
    raise Unsupported(
      message="the paragraph writer cannot serialize indentation yet",
    )
  }
  if properties.style_id is None && properties.style_name is Some(_) {
    raise Unsupported(
      message="the paragraph writer needs a style id; a bare style name cannot be serialized",
    )
  }
  if ppr_children.length() > 0 {
    nodes.push(XmlElement(@xml.xml_element("w:pPr", children=ppr_children)))
  }
  for child in children {
    nodes.push(XmlElement(write_inline(child)))
  }
  @xml.xml_element("w:p", children=nodes)
}

///|
fn write_inline(element : DocumentElement) -> XmlElement raise DocxError {
  match element {
    Run(children~, properties~) => write_run(children, properties)
    other =>
      raise Unsupported(
        message="the paragraph writer cannot serialize this inline element yet: \{block_kind_name(other)}",
      )
  }
}

///|
fn write_run(
  children : Array[DocumentElement],
  properties : RunProperties,
) -> XmlElement raise DocxError {
  let nodes : Array[XmlNode] = []
  // CT_RPr is an ENFORCED sequence — the Microsoft SDK rejects out-of-order
  // children. Emission order here must stay: rFonts, b, i, caps, smallCaps,
  // strike, sz, szCs, highlight, u, vertAlign.
  let rpr : Array[XmlNode] = []
  if properties.style_id is Some(_) || properties.style_name is Some(_) {
    raise Unsupported(
      message="the run writer cannot serialize character styles yet",
    )
  }
  match properties.font {
    Some(font) =>
      rpr.push(
        XmlElement(
          @xml.xml_element("w:rFonts", attributes={
            "w:ascii": font,
            "w:hAnsi": font,
          }),
        ),
      )
    None => ()
  }
  if properties.is_bold {
    rpr.push(XmlElement(@xml.xml_element("w:b")))
  }
  if properties.is_italic {
    rpr.push(XmlElement(@xml.xml_element("w:i")))
  }
  if properties.is_all_caps {
    rpr.push(XmlElement(@xml.xml_element("w:caps")))
  }
  if properties.is_small_caps {
    rpr.push(XmlElement(@xml.xml_element("w:smallCaps")))
  }
  if properties.is_strikethrough {
    rpr.push(XmlElement(@xml.xml_element("w:strike")))
  }
  match properties.font_size {
    Some(points) => {
      // The reader halves w:sz (half-points → points); the writer doubles
      // back, so read(write(x)) preserves the value exactly.
      let half_points = (points * 2).to_string()
      rpr.push(
        XmlElement(
          @xml.xml_element("w:sz", attributes={ "w:val": half_points }),
        ),
      )
      rpr.push(
        XmlElement(
          @xml.xml_element("w:szCs", attributes={ "w:val": half_points }),
        ),
      )
    }
    None => ()
  }
  match properties.highlight {
    Some(highlight) =>
      rpr.push(
        XmlElement(
          @xml.xml_element("w:highlight", attributes={ "w:val": highlight }),
        ),
      )
    None => ()
  }
  if properties.is_underline {
    rpr.push(
      XmlElement(@xml.xml_element("w:u", attributes={ "w:val": "single" })),
    )
  }
  match properties.vertical_alignment {
    Baseline => ()
    Superscript =>
      rpr.push(
        XmlElement(
          @xml.xml_element("w:vertAlign", attributes={ "w:val": "superscript" }),
        ),
      )
    Subscript =>
      rpr.push(
        XmlElement(
          @xml.xml_element("w:vertAlign", attributes={ "w:val": "subscript" }),
        ),
      )
  }
  if rpr.length() > 0 {
    nodes.push(XmlElement(@xml.xml_element("w:rPr", children=rpr)))
  }
  for child in children {
    match child {
      Text(text) => {
        // A literal CR would be normalized (i.e. mutated) by conformant
        // consumers, and a literal LF is crafted-file territory — fail
        // closed; line breaks are written with `line_break()`.
        if text.find("\r") is Some(_) || text.find("\n") is Some(_) {
          raise Unsupported(
            message="the run writer cannot serialize raw line-break characters in text; use line_break()",
          )
        }
        let attributes : Map[String, String] = Map([])
        if text.has_prefix(" ") ||
          text.has_suffix(" ") ||
          text.has_prefix("\t") ||
          text.has_suffix("\t") {
          attributes["xml:space"] = "preserve"
        }
        nodes.push(
          XmlElement(
            @xml.xml_element("w:t", attributes~, children=[XmlText(text)]),
          ),
        )
      }
      Tab => nodes.push(XmlElement(@xml.xml_element("w:tab")))
      Break(Line) => nodes.push(XmlElement(@xml.xml_element("w:br")))
      other =>
        raise Unsupported(
          message="the run writer cannot serialize this content yet: \{block_kind_name(other)}",
        )
    }
  }
  @xml.xml_element("w:r", children=nodes)
}

///|
fn blank_section_properties() -> XmlElement {
  @xml.xml_element("w:sectPr", children=[
    XmlElement(
      @xml.xml_element("w:pgSz", attributes={ "w:w": "12240", "w:h": "15840" }),
    ),
    XmlElement(
      @xml.xml_element("w:pgMar", attributes={
        "w:top": "1440",
        "w:right": "1440",
        "w:bottom": "1440",
        "w:left": "1440",
        "w:header": "720",
        "w:footer": "720",
        "w:gutter": "0",
      }),
    ),
  ])
}

///|
fn is_writable_style_id(style_id : String) -> Bool {
  if style_id == "Normal" {
    return true
  }
  style_id.has_prefix("Heading") &&
  style_id.length() == 8 &&
  style_id[7] is ('1'..='6')
}

///|
/// Styles part: docDefaults + Normal, plus a definition for every heading
/// style the body used (name + outline level, based on Normal), so Word's
/// navigation pane and this repo's heading detection both work on the
/// output.
fn styles_xml_for(used_styles : Set[String]) -> String {
  let styles : Array[XmlNode] = [
    XmlElement(
      @xml.xml_element("w:docDefaults", children=[
        XmlElement(
          @xml.xml_element("w:rPrDefault", children=[
            XmlElement(
              @xml.xml_element("w:rPr", children=[
                XmlElement(
                  @xml.xml_element("w:sz", attributes={ "w:val": "24" }),
                ),
                XmlElement(
                  @xml.xml_element("w:szCs", attributes={ "w:val": "24" }),
                ),
              ]),
            ),
          ]),
        ),
        XmlElement(@xml.xml_element("w:pPrDefault")),
      ]),
    ),
    XmlElement(
      @xml.xml_element(
        "w:style",
        attributes={
          "w:type": "paragraph",
          "w:default": "1",
          "w:styleId": "Normal",
        },
        children=[
          XmlElement(
            @xml.xml_element("w:name", attributes={ "w:val": "Normal" }),
          ),
        ],
      ),
    ),
  ]
  for level in 1..<=6 {
    let style_id = "Heading\{level}"
    if !used_styles.contains(style_id) {
      continue
    }
    styles.push(
      XmlElement(
        @xml.xml_element(
          "w:style",
          attributes={ "w:type": "paragraph", "w:styleId": style_id },
          children=[
            XmlElement(
              @xml.xml_element("w:name", attributes={
                "w:val": "heading \{level}",
              }),
            ),
            XmlElement(
              @xml.xml_element("w:basedOn", attributes={ "w:val": "Normal" }),
            ),
            XmlElement(
              @xml.xml_element("w:pPr", children=[
                XmlElement(
                  @xml.xml_element("w:outlineLvl", attributes={
                    "w:val": (level - 1).to_string(),
                  }),
                ),
              ]),
            ),
          ],
        ),
      ),
    )
  }
  @xml.write_xml_string(@xml.xml_element("w:styles", children=styles), namespaces={
    "w": WORDPROCESSINGML_NAMESPACE,
  })
}

///|
fn block_kind_name(element : DocumentElement) -> String {
  match element {
    Document(..) => "document"
    Paragraph(..) => "paragraph"
    Run(..) => "run"
    Text(_) => "text"
    Tab => "tab"
    Checkbox(_) => "checkbox"
    Hyperlink(..) => "hyperlink"
    NoteReference(..) => "note reference"
    CommentReference(_) => "comment reference"
    Image(_) => "image"
    Table(..) => "table"
    TableRow(..) => "table row"
    TableCell(..) => "table cell"
    Break(_) => "break"
    BookmarkStart(_) => "bookmark"
  }
}
