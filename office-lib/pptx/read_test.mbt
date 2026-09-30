///|
fn deck_bytes() -> Bytes raise {
  let presentation = @presentation.Presentation::new()
  for text in ["First", "Second"] {
    presentation.add_slide_mut(0) |> ignore
    let i = presentation.slide_count() - 1
    let shape = @slide.AutoShape::textbox(
      id=2,
      name="Title",
      x=Emu(0),
      y=Emu(0),
      cx=Emu(100000),
      cy=Emu(100000),
      text,
    )
    presentation.update_slide_mut(
      i,
      presentation.slide_at(i).with_shape(AutoShape(shape)),
    )
    presentation.set_notes_mut(i, text + " notes")
  }
  presentation.move_slide_mut(1, 0)
  Bytes::from_array(presentation.save())
}

///|
test "PPTX identity and presentation order include associated notes" {
  let bytes = deck_bytes()
  debug_inspect(@office.detect_format("demo.PPTX", bytes), content="Pptx")
  let result = @pptx.read_presentation(bytes)
  debug_inspect(
    result.slides.map(s => (s.index, s.text, s.notes)),
    content=(
      #|<ReadOnlyArray:
      #|  [(1, "Second", "Second notes"), (2, "First", "First notes")]>
    ),
  )
  debug_inspect(result.width_emu > 0 && result.height_emu > 0, content="true")
  debug_inspect(
    @office.detect_format("demo.docx", bytes).name() catch {
      FormatMismatch(expected~, actual~) =>
        expected.name() + ":" + actual.name()
      _ => "unexpected"
    },
    content=(
      #|"docx:pptx"
    ),
  )
}

///|
test "PPTX reads refuse exhausted budgets and cancellation" {
  let bytes = deck_bytes()
  debug_inspect(
    try {
      @pptx.read_presentation(bytes, max_elements=1) |> ignore
      false
    } catch {
      _ => true
    },
    content="true",
  )
  debug_inspect(
    try {
      @pptx.read_presentation(bytes, cancelled=() => true) |> ignore
      false
    } catch {
      @office.Cancelled => true
      _ => false
    },
    content="true",
  )
}

///|
test "PPTX text visits groups and tables in stored order" {
  let presentation = @presentation.Presentation::new()
  presentation.add_slide_mut(0) |> ignore
  let box = @slide.AutoShape::textbox(
    id=3,
    name="Nested",
    x=Emu(0),
    y=Emu(0),
    cx=Emu(100000),
    cy=Emu(100000),
    "Group text",
  )
  let group : @slide.GroupShape = {
    id: 2,
    name: "Group",
    transform: None,
    child_offset: None,
    child_extent: None,
    children: [AutoShape(box)],
    hyperlink: None,
    extension: [],
  }
  let table = @slide.Table::of_rows(
    [
      @slide.TableRow::of_cells(
        [@slide.TableCell::of_text("A"), @slide.TableCell::of_text("B")],
        height=Emu(100000),
      ),
    ],
    col_widths=[Emu(100000), Emu(100000)],
  )
  let frame = @slide.GraphicFrame::of_table(
    id=4,
    name="Table",
    x=Emu(0),
    y=Emu(0),
    cx=Emu(200000),
    cy=Emu(100000),
    table,
  )
  presentation.update_slide_mut(
    0,
    presentation
    .slide_at(0)
    .with_shape(Group(group))
    .with_shape(GraphicFrame(frame)),
  )
  let summary = @pptx.read_presentation(Bytes::from_array(presentation.save()))
  debug_inspect(
    (summary.slides[0].text, summary.slides[0].shape_count),
    content="(\"Group text\\nA\\nB\", 2)",
  )
}

///|
test "PPTX reading rejects a slide relationship with the wrong type" {
  let bytes = deck_bytes()
  let presentation = @presentation.Presentation::open(
    FixedArray::makei(bytes.length(), i => bytes[i]),
  )
  let pkg = presentation.opc_package()
  let original = pkg.require_part("/ppt/_rels/presentation.xml.rels")
  let text = original.text().replace(old=@opc.rt_slide, new=@opc.rt_image)
  let encoded = @utf8.encode(text)
  pkg.replace_part(
    @opc.Part::new(
      original.name,
      original.content_type,
      FixedArray::makei(encoded.length(), i => encoded[i]),
    ),
  )
  |> ignore
  debug_inspect(
    try {
      @pptx.read_presentation(Bytes::from_array(presentation.save())) |> ignore
      false
    } catch {
      @office.InvalidPackage(_) => true
      _ => false
    },
    content=(
      #|false
    ),
  )
}

///|
test "PPTX extraction has an aggregate text budget independent of XML size" {
  debug_inspect(
    try {
      @pptx.read_presentation(deck_bytes(), max_text_chars=5) |> ignore
      "accepted"
    } catch {
      @office.ResourceLimit(kind~, ..) => kind
      _ => "unexpected"
    },
    content="\"pptx_text_chars\"",
  )
}
