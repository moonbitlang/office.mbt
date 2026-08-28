// The write side of #95: header and footer STORIES for the document's single
// section. `write_docx_with_annotations` takes header/footer specs, serializes
// each into its own `word/headerN.xml` / `word/footerN.xml` part with a
// `w:hdr` / `w:ftr` root, wires each part as a relationship of the MAIN
// document part, and emits the matching `w:headerReference` /
// `w:footerReference` in `w:sectPr` — content types, relationships and
// references all derived from one list so they cannot drift apart.
//
// Two OOXML details this writer takes care of, because a document that
// silently ignores them looks broken in Word rather than failing loudly:
//   * a `first` variant only takes effect when the section carries
//     `w:titlePg` (emitted by `blank_section_properties`);
//   * an `even` variant only takes effect when `word/settings.xml` carries
//     `w:evenAndOddHeaders`, so the settings part is written when — and only
//     when — an even-page story exists.
//
// Story content is PLAIN, exactly like comment and note bodies: paragraphs
// and tables, no hyperlinks, images or note references. Those would need
// relationships in the STORY'S OWN `word/_rels/headerN.xml.rels`, which this
// writer does not emit; fail closed instead of emitting references that would
// dangle. FIELDS are allowed and are the point — a live `PAGE` field is what
// makes a footer a page number instead of static text.

///|
/// One header or footer story attached to the written document's section.
/// Construct with `header_footer_spec`, which fail-closes on everything the
/// story can get wrong in isolation.
pub struct HeaderFooterSpec {
  priv variant : String
  priv body : Array[DocumentElement]
}

///|
/// The OOXML header/footer reference types, in the CANONICAL emission order
/// this writer uses. Deterministic regardless of the order specs arrive in,
/// so `read(write(x))` sees a stable variant sequence.
let header_footer_variants : Array[String] = ["default", "first", "even"]

///|
/// Validates and builds one header/footer story. `variant` is the OOXML
/// reference type (`default`, `first` or `even`); the body is non-empty and
/// block-level (paragraphs and tables), plain content all the way down.
pub fn header_footer_spec(
  variant~ : String,
  body : Array[DocumentElement],
) -> HeaderFooterSpec raise DocxError {
  if !header_footer_variants.contains(variant) {
    raise Unsupported(
      message="unsupported header/footer variant '\{variant}' (default, first, or even)",
    )
  }
  check_story_body(body, what="header/footer")
  { variant, body, }
}

///|
/// The story body shape rules, applied at CONSTRUCTION for early attributable
/// errors and REPEATED at write time (the array stays caller-mutable):
/// non-empty, block-level, and plain content — no hyperlinks, images or note
/// references, which would need relationships the story part does not get.
fn check_story_body(
  body : Array[DocumentElement],
  what~ : String,
) -> Unit raise DocxError {
  if body.length() == 0 {
    raise Unsupported(
      message="a \{what} story needs a non-empty body (at least one paragraph)",
    )
  }
  for block in body {
    guard block is (Paragraph(..) | Table(..)) else {
      raise Unsupported(
        message="\{what} stories hold paragraphs and tables in this writer (got \{block_kind_name(block)})",
      )
    }
    check_story_content(block, what~)
  }
}

///|
fn check_story_content(
  element : DocumentElement,
  what~ : String,
) -> Unit raise DocxError {
  match element {
    Hyperlink(..) =>
      raise Unsupported(
        message="\{what} stories are plain content: hyperlinks cannot be serialized into a header/footer part (they would need relationships that part does not get)",
      )
    Image(_) =>
      raise Unsupported(
        message="\{what} stories are plain content: images cannot be serialized into a header/footer part (they would need relationships that part does not get)",
      )
    NoteReference(..) =>
      raise Unsupported(
        message="\{what} stories cannot carry note references (notes live in the main document story)",
      )
    CommentReference(_) =>
      raise Unsupported(
        message="\{what} stories cannot carry comment references",
      )
    Document(children~, ..)
    | Paragraph(children~, ..)
    | Run(children~, ..)
    | Table(children~, ..)
    | TableRow(children~, ..)
    | TableCell(children~, ..) =>
      for child in children {
        check_story_content(child, what~)
      }
    _ => ()
  }
}

///|
/// Rejects duplicate variants within one kind: a section may declare each of
/// default/first/even at most once (the reader raises on a repeat, so a
/// duplicate here would produce a package our own reader refuses).
fn check_header_footer_variants(
  specs : Array[HeaderFooterSpec],
  kind~ : String,
) -> Unit raise DocxError {
  let seen : Array[String] = []
  for index, spec in specs {
    if seen.contains(spec.variant) {
      raise Unsupported(
        message="\{kind}s[\{index}] repeats the '\{spec.variant}' variant; a section declares each variant at most once",
      )
    }
    seen.push(spec.variant)
    check_story_body(spec.body, what=kind) catch {
      Unsupported(message~) =>
        raise Unsupported(message="\{kind}s[\{index}]: \{message}")
      err => raise err
    }
  }
}

///|
/// Serializes the header/footer stories of one kind into their parts and the
/// matching `sectPr` references, allocating one MAIN-part relationship each.
/// Returns the parts (`(part name under word/, xml)`, in allocation order)
/// and the reference elements, in the canonical variant order.
///
/// Story bodies reuse the body writers and the shared `WriteContext` (styles
/// and numbering are package-wide), then a relationship/media delta guard
/// catches anything that slipped past `check_story_body` through an alias.
fn write_header_footer_parts(
  specs : Array[HeaderFooterSpec],
  ctx : WriteContext,
  kind~ : String,
) -> (Array[(String, String)], Array[XmlNode]) raise DocxError {
  let parts : Array[(String, String)] = []
  let references : Array[XmlNode] = []
  if specs.length() == 0 {
    return (parts, references)
  }
  let root_name = if kind == "header" { "w:hdr" } else { "w:ftr" }
  let relationship_type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/" +
    kind
  for variant in header_footer_variants {
    for spec in specs {
      guard spec.variant == variant else { continue }
      let relationships_before = ctx.document_relationships.length()
      let media_before = ctx.media.length()
      let blocks : Array[XmlNode] = []
      for block in spec.body {
        blocks.push(XmlElement(write_block(block, ctx)))
      }
      if ctx.document_relationships.length() > relationships_before ||
        ctx.media.length() > media_before {
        raise Unsupported(
          message="\{kind} stories are plain content: hyperlinks and images cannot be serialized into a \{kind} part (they would need relationships that part does not get)",
        )
      }
      let part_name = "\{kind}\{parts.length() + 1}.xml"
      parts.push(
        (
          part_name,
          @xml.write_xml_string(@xml.xml_element(root_name, children=blocks), namespaces={
            "w": WORDPROCESSINGML_NAMESPACE,
          }),
        ),
      )
      let id = ctx.allocate_relationship(
        relationship_type,
        part_name,
        external=false,
      )
      references.push(
        XmlElement(
          @xml.xml_element("w:\{kind}Reference", attributes={
            "w:type": variant,
            "r:id": id,
          }),
        ),
      )
    }
  }
  (parts, references)
}

///|
/// `word/settings.xml` carrying `w:evenAndOddHeaders`, written only when an
/// even-page story exists: without it Word ignores the `even` variant
/// entirely and renders the default story on every page.
fn even_and_odd_headers_settings_xml() -> String {
  @xml.write_xml_string(
    @xml.xml_element("w:settings", children=[
      XmlElement(@xml.xml_element("w:evenAndOddHeaders")),
    ]),
    namespaces={ "w": WORDPROCESSINGML_NAMESPACE },
  )
}

///|
fn has_variant(specs : Array[HeaderFooterSpec], variant : String) -> Bool {
  for spec in specs {
    if spec.variant == variant {
      return true
    }
  }
  false
}
