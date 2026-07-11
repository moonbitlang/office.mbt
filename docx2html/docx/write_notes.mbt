// K3 of the annotation writers: footnotes and endnotes on freshly
// written documents. Notes are supplied to `write_docx_with_annotations`
// as plain-content bodies and referenced from body runs via
// `note_reference(kind, index)` (0-based, exactly once per note); the
// writer emits word/footnotes.xml / word/endnotes.xml as MAIN-part
// relationships with the separator/continuationSeparator plumbing notes
// Word expects, the in-note footnoteRef/endnoteRef mark run at the head
// of each note's first paragraph, and positive w:id allocation (index+1)
// clear of the -1/0 plumbing ids.

///|
/// One footnote or endnote body: plain-content, paragraph-only, and no
/// note references of its own (notes do not nest). Construct with
/// `note_spec`.
pub struct NoteSpec {
  priv body : Array[DocumentElement]
}

///|
/// Validates and builds a `NoteSpec`. The body rules match comment
/// bodies (non-empty, paragraph-only, plain content) plus the no-nesting
/// rule; they are re-checked at write time because the arrays stay
/// caller-mutable. Which KIND the note is (footnote or endnote) is
/// decided by which array it is passed in, so one spec type serves both.
pub fn note_spec(body : Array[DocumentElement]) -> NoteSpec raise DocxError {
  check_annotation_body(body, what="note")
  { body, }
}

///|
/// Every supplied note must be referenced from the body EXACTLY once;
/// the walk also rejects references to notes that were never supplied
/// (by kind and range) before anything is serialized, so the error
/// carries the note index rather than surfacing mid-write.
fn check_note_references(
  body : Array[DocumentElement],
  footnote_count : Int,
  endnote_count : Int,
) -> Unit raise DocxError {
  let footnote_uses = Array::make(footnote_count, 0)
  let endnote_uses = Array::make(endnote_count, 0)
  fn walk(element : DocumentElement) -> Unit raise DocxError {
    match element {
      NoteReference(note_type~, note_id~) => {
        let uses = match note_type {
          "footnote" => footnote_uses
          "endnote" => endnote_uses
          other =>
            raise Unsupported(
              message="unknown note type '\{other}' (footnote or endnote)",
            )
        }
        match parse_note_index(note_id) {
          Some(index) if index < uses.length() => uses[index] += 1
          _ =>
            raise Unsupported(
              message="the \{note_type} reference '\{note_id}' does not name a supplied note (this write has \{uses.length()} \{note_type}(s); references are 0-based indexes)",
            )
        }
      }
      Document(children~, ..)
      | Paragraph(children~, ..)
      | Run(children~, ..)
      | Hyperlink(children~, ..)
      | Table(children~, ..)
      | TableRow(children~, ..)
      | TableCell(children~, ..) =>
        for child in children {
          walk(child)
        }
      _ => ()
    }
  }
  for element in body {
    walk(element)
  }
  for index, uses in footnote_uses {
    if uses == 0 {
      raise Unsupported(
        message="footnotes[\{index}] is never referenced from the body (each note needs exactly one reference run)",
      )
    }
    if uses > 1 {
      raise Unsupported(
        message="footnotes[\{index}] is referenced \{uses} times (each note needs exactly one reference run)",
      )
    }
  }
  for index, uses in endnote_uses {
    if uses == 0 {
      raise Unsupported(
        message="endnotes[\{index}] is never referenced from the body (each note needs exactly one reference run)",
      )
    }
    if uses > 1 {
      raise Unsupported(
        message="endnotes[\{index}] is referenced \{uses} times (each note needs exactly one reference run)",
      )
    }
  }
}

///|
/// Serializes word/footnotes.xml or word/endnotes.xml: the two plumbing
/// notes (separator id -1, continuationSeparator id 0 — the ids the
/// reader's scanner suppresses), then one content note per spec with
/// w:id = index+1 and the in-note mark run (w:footnoteRef/w:endnoteRef)
/// leading its first paragraph.
fn notes_part_xml(
  kind : String,
  notes : Array[NoteSpec],
  ctx : WriteContext,
) -> String raise DocxError {
  let element_name = if kind == "footnote" { "w:footnote" } else { "w:endnote" }
  let mark_name = if kind == "footnote" {
    "w:footnoteRef"
  } else {
    "w:endnoteRef"
  }
  let root_name = if kind == "footnote" { "w:footnotes" } else { "w:endnotes" }
  fn plumbing(note_type : String, id : String, mark : String) -> XmlNode {
    XmlElement(
      @xml.xml_element(
        element_name,
        attributes={ "w:type": note_type, "w:id": id },
        children=[
          XmlElement(
            @xml.xml_element("w:p", children=[
              XmlElement(
                @xml.xml_element("w:r", children=[
                  XmlElement(@xml.xml_element(mark)),
                ]),
              ),
            ]),
          ),
        ],
      ),
    )
  }
  let children : Array[XmlNode] = [
    plumbing("separator", "-1", "w:separator"),
    plumbing("continuationSeparator", "0", "w:continuationSeparator"),
  ]
  for index, note in notes {
    let mark_run : Array[XmlNode] = [
      XmlElement(
        @xml.xml_element("w:r", children=[
          XmlElement(@xml.xml_element(mark_name)),
        ]),
      ),
    ]
    let note_children : Array[XmlNode] = []
    for block_index, block in note.body {
      if block_index == 0 {
        guard block is Paragraph(children=paragraph_children, properties~) else {
          // Unreachable: note bodies were validated paragraph-only.
          raise Unsupported(message="note bodies are paragraph-only")
        }
        note_children.push(
          XmlElement(
            write_paragraph(
              paragraph_children,
              properties,
              ctx,
              leading=mark_run,
            ),
          ),
        )
      } else {
        note_children.push(XmlElement(write_block(block, ctx)))
      }
    }
    children.push(
      XmlElement(
        @xml.xml_element(
          element_name,
          attributes={ "w:id": (index + 1).to_string() },
          children=note_children,
        ),
      ),
    )
  }
  @xml.write_xml_string(@xml.xml_element(root_name, children~), namespaces={
    "w": WORDPROCESSINGML_NAMESPACE,
  })
}
