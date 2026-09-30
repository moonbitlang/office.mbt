///|
test "UTF-16 XML parts preserve presentation, slide and notes text" {
  let original = @presentation.Presentation::new()
  original.add_slide_mut(0) |> ignore
  let title = "中文 😀"
  let box = @slide.AutoShape::textbox(
    id=2,
    name="Title",
    x=Emu(0),
    y=Emu(0),
    cx=Emu(100000),
    cy=Emu(100000),
    title,
  )
  original.update_slide_mut(0, original.slide_at(0).with_shape(AutoShape(box)))
  original.set_notes_mut(0, title)
  for big in [false, true] {
    for bom in [false, true] {
      let deck = @presentation.Presentation::open(original.save())
      let pkg = deck.opc_package()
      for part in pkg.parts() {
        if part.name.has_suffix(".xml") || part.name.has_suffix(".rels") {
          let encoding = if bom {
            "UTF-16"
          } else if big {
            "UTF-16BE"
          } else {
            "UTF-16LE"
          }
          let text = part.text().replace(old="UTF-8", new=encoding)
          let bytes = @utf16.encode(
            text,
            endianness=if big { Big } else { Little },
            bom~,
          )
          pkg.replace_part(
            @opc.Part::new(part.name, part.content_type, bytes.to_fixedarray()),
          )
          |> ignore
        }
      }
      let reopened = @presentation.Presentation::open(deck.save())
      debug_inspect(reopened.slide_count(), content="1")
      let slide = reopened.slide_at(0)
      let text = match slide.shapes[0] {
        AutoShape(shape) => shape.text_body.unwrap().paragraphs[0].plain_text()
        _ => "unexpected shape"
      }
      debug_inspect(text, content="\"中文 😀\"")
      let part = reopened
        .opc_package()
        .require_part("/ppt/notesSlides/notesSlide1.xml")
      let notes = @notes.NotesSlide::parse(part.bytes())
      let notes_text = match notes.shapes[0] {
        AutoShape(shape) => shape.text_body.unwrap().paragraphs[0].plain_text()
        _ => "unexpected notes shape"
      }
      debug_inspect(notes_text, content="\"中文 😀\"")
      debug_inspect(reopened.slide_w() == original.slide_w(), content="true")
    }
  }
}

///|
test "XML decoding rejects malformed UTF-16" {
  debug_inspect(
    try {
      @xml.decode_xml_bytes(b"\xff\xfe\x3c") |> ignore
      "accepted"
    } catch {
      Malformed(message) => message
      _ => "unexpected"
    },
    content="\"invalid UTF-8 or UTF-16 XML text\"",
  )
  debug_inspect(
    try {
      @oxml.bytes_to_string(b"\xfe\xff\x00".to_fixedarray()) |> ignore
      "accepted"
    } catch {
      InvalidUtf16 => "invalid UTF-16"
      _ => "unexpected"
    },
    content="\"invalid UTF-16\"",
  )
}
