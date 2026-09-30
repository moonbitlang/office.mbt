///|
/// One slide in presentation order. Indices are one-based, positional, and
/// unsuitable as persistent editing identities. Text excludes inherited
/// master/layout placeholders, charts, SmartArt, and embedded documents.
pub struct SlideSummary {
  index : Int
  part : String
  text : String
  notes : String
  shape_count : Int
}

///|
/// A bounded read-only view; coordinates are English Metric Units.
pub struct PresentationSummary {
  width_emu : Int64
  height_emu : Int64
  slides : ReadOnlyArray[SlideSummary]
}

///|
priv struct ReadBudget {
  maximum : Int
  mut used : Int
  text_limit : Int
  mut text_used : Int
  cancelled : () -> Bool
}

///|
fn ReadBudget::consume(self : ReadBudget) -> Unit raise {
  if (self.cancelled)() {
    raise @office.Cancelled
  }
  if self.used >= self.maximum {
    raise @office.ResourceLimit(
      kind="pptx_elements",
      limit=self.maximum,
      actual=self.used + 1,
    )
  }
  self.used += 1
}

///|
fn ReadBudget::paragraph_text(
  self : ReadBudget,
  paragraph : @slide.Paragraph,
) -> String raise {
  self.consume()
  // Reserve before concatenating. A notes part may be referenced by many
  // slides, so bounding unique XML alone does not bound retained output.
  let mut size = 1 // paragraph separator
  for content in paragraph.content {
    self.consume()
    size += match content {
      RunContent(run) => run.text.length()
      FieldContent(field) => field.text.length()
      Break(_) => 1
    }
  }
  if size > self.text_limit - self.text_used {
    raise @office.ResourceLimit(
      kind="pptx_text_chars",
      limit=self.text_limit,
      actual=self.text_used + size,
    )
  }
  self.text_used += size
  paragraph.plain_text()
}

///|
fn shape_text(
  shapes : Array[@slide.Shape],
  budget : ReadBudget,
) -> String raise {
  let paragraphs : Array[String] = []
  let pending = Array::makei(shapes.length(), i => {
    shapes[shapes.length() - 1 - i]
  })
  while !pending.is_empty() {
    budget.consume()
    let shape = pending.pop().unwrap()
    match shape {
      AutoShape(shape) =>
        if shape.text_body is Some(body) {
          for paragraph in body.paragraphs {
            paragraphs.push(budget.paragraph_text(paragraph))
          }
        }
      Group(group) =>
        for i = group.children.length() - 1; i >= 0; i = i - 1 {
          pending.push(group.children[i])
        }
      GraphicFrame(frame) =>
        if frame.content is TableContent(table) {
          for row in table.rows {
            for cell in row.cells {
              budget.consume()
              if cell.text_body is Some(body) {
                for paragraph in body.paragraphs {
                  paragraphs.push(budget.paragraph_text(paragraph))
                }
              }
            }
          }
        }
      _ => ()
    }
  }
  paragraphs.join("\n")
}

///|
/// Reads a PPTX through Office's bounded ZIP and XML checks before invoking
/// the presentation parser. Strict OOXML is identifiable but not yet supported
/// by the presentation engine, so it is rejected rather than returning no slides.
pub fn read_presentation(
  bytes : Bytes,
  max_elements? : Int = 50_000,
  max_text_chars? : Int = 16 * 1024 * 1024,
  cancelled? : () -> Bool = () => false,
) -> PresentationSummary raise {
  guard max_elements > 0 && max_elements <= 200_000 else {
    raise @office.InvalidPackage(
      "PPTX max_elements must be between 1 and 200000",
    )
  }
  guard max_text_chars > 0 && max_text_chars <= 16 * 1024 * 1024 else {
    raise @office.InvalidPackage(
      "PPTX max_text_chars must be between 1 and 16777216",
    )
  }
  @office.detect_format("input.pptx", bytes, cancelled~) |> ignore
  let presentation = @presentation.Presentation::open(
    FixedArray::makei(bytes.length(), i => bytes[i]),
  )
  let pkg = presentation.opc_package()
  // A shared XML budget also caps nested structures before the typed parser
  // sees them. The Office detector has already bounded decompression.
  let xml_budget = @xml.xml_read_budget(
    max_source_units=64 * 1024 * 1024,
    max_tokens=max_elements,
    max_materialized_chars=64 * 1024 * 1024,
    max_token_chars=16 * 1024 * 1024,
    cancelled~,
  )
  for entry in pkg.parts() {
    let content_type = entry.content_type.to_lower()
    if content_type.has_suffix("+xml") ||
      content_type == "application/xml" ||
      content_type == "text/xml" {
      let bytes = Bytes::from_array(entry.bytes())
      let encoding : @xml.XmlSourceEncoding = match bytes {
        [0xff, 0xfe, ..] => Utf16LittleEndianWithBom
        [0xfe, 0xff, ..] => Utf16BigEndianWithBom
        [b'<', 0x00, ..] => Utf16LittleEndian
        [0x00, b'<', ..] => Utf16BigEndian
        _ => Utf8
      }
      @xml.read_xml_string_strict_encoded_limited(
        @ooxml_xml.decode_xml_bytes(bytes),
        encoding,
        xml_budget,
      )
      |> ignore
    }
  }
  let roots = pkg.relationships_for("/").by_type(@opc.rt_office_document)
  guard roots is [root] else {
    raise @office.InvalidPackage(
      "PPTX reading currently requires Transitional OOXML",
    )
  }
  let main = @opc.resolve_target("/", root.target, root.target_mode)
  let part = @presentation.PresentationPart::parse(
    pkg.require_part(main).bytes(),
  )
  let relationships = pkg.relationships_for(main)
  let budget = ReadBudget::{
    maximum: max_elements,
    used: 0,
    text_limit: max_text_chars,
    text_used: 0,
    cancelled,
  }
  let slides : Array[SlideSummary] = []
  let seen : Map[String, Bool] = Map([])
  for i, id in part.sld_ids {
    budget.consume()
    let relationship = relationships
      .by_id(id.r_id)
      .unwrap_or_else(() => {
        raise @office.InvalidPackage("PPTX slide has no relationship")
      })
    guard relationship.rel_type == @opc.rt_slide &&
      relationship.target_mode is Internal else {
      raise @office.InvalidPackage(
        "PPTX slide relationship must be an internal slide",
      )
    }
    let name = @opc.resolve_target(
      main,
      relationship.target,
      relationship.target_mode,
    )
    guard !seen.contains(name) else {
      raise @office.InvalidPackage("PPTX slide is listed more than once")
    }
    seen[name] = true
    let slide_part = pkg.require_part(name)
    guard slide_part.content_type == @oxml.ct_slide else {
      raise @office.InvalidPackage(
        "PPTX slide target has the wrong content type",
      )
    }
    let slide = @slide.Slide::parse(slide_part.bytes())
    let text = shape_text(slide.shapes, budget)
    let notes_rels = pkg.relationships_for(name).by_type(@opc.rt_notes_slide)
    let notes = match notes_rels {
      [] => ""
      [rel] if rel.target_mode is Internal => {
        let note_name = @opc.resolve_target(name, rel.target, rel.target_mode)
        let notes_part = pkg.require_part(note_name)
        guard notes_part.content_type == @oxml.ct_notes_slide else {
          raise @office.InvalidPackage(
            "PPTX notes target has the wrong content type",
          )
        }
        let note = @notes.NotesSlide::parse(notes_part.bytes())
        shape_text(note.shapes, budget)
      }
      _ =>
        raise @office.InvalidPackage(
          "PPTX slide must have at most one internal notes part",
        )
    }
    slides.push({
      index: i + 1,
      part: name,
      text,
      notes,
      shape_count: slide.shapes.length(),
    })
  }
  {
    width_emu: presentation.slide_w().value(),
    height_emu: presentation.slide_h().value(),
    slides: ReadOnlyArray::from_array(slides),
  }
}
