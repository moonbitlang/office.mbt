///|
/// A one-page model with a Carlito run "AB" whose advances are `advances`.
fn run_model(advances : Array[Double]) -> @pagelayout.PageModel {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Carlito", bold: false, italic: false, })
  model.pages.push({
    width_pt: 200,
    height_pt: 100,
    items: [
      Text({
        font,
        size_pt: 10,
        x_pt: 10,
        baseline_pt: 20,
        text: "AB",
        advances_pt: advances,
        color: @pagelayout.black,
      }),
    ],
  })
  model
}

///|
test "advances matching the declared widths are shown with a plain Tj" {
  let face = @fonts.face("Carlito")
  let a = face.advance_pt('A'.to_int(), 1000.0).round() / 100.0
  let b = face.advance_pt('B'.to_int(), 1000.0).round() / 100.0
  let text = as_decoded_text(@pdf.render_pdf(run_model([a, b])))
  assert_true(text.contains("Tj"))
  assert_false(text.contains("TJ"))
}

///|
test "winansi codes above 0x7f declare the width of the character they encode" {
  // ’ is WinAnsi 0x92; its /Widths entry must be the width of U+2019, not
  // of whatever the face maps to codepoint 0x92
  let face = @fonts.face("Carlito")
  let model = run_model([
    face.advance_pt('A'.to_int(), 1000.0).round() / 100.0,
    face.advance_pt(0x2019, 1000.0).round() / 100.0,
  ])
  guard model.pages[0].items[0] is Text(run) else { fail("expected text") }
  model.pages[0].items[0] = Text({ ..run, text: "A’", })
  let text = as_decoded_text(@pdf.render_pdf(model))
  assert_false(text.contains("TJ"))
}

///|
test "truncated widths declare what Prawn measures" {
  let face = @fonts.face("Carlito")
  // a letter whose width in thousandths of an em has a fraction above one
  // half, so truncating and rounding differ
  let mut letter = 'A'
  for c in 'A'.to_int()..<='Z'.to_int() {
    let w = face.advance_pt(c, 1000.0)
    if w.round() != w.floor() {
      letter = c.unsafe_to_char()
      break
    }
  }
  let w = face.advance_pt(letter.to_int(), 1000.0)
  assert_true(w.round() != w.floor())
  let model = run_model([w.floor() / 100.0, w.floor() / 100.0])
  guard model.pages[0].items[0] is Text(run) else { fail("expected text") }
  model.pages[0].items[0] = Text({ ..run, text: "\{letter}\{letter}", })
  // placed by truncated widths: a plain Tj when they are declared,
  // displacements when the declared widths are rounded
  let truncated = as_decoded_text(@pdf.render_pdf(model, truncate_widths=true))
  assert_false(truncated.contains("TJ"))
  let rounded = as_decoded_text(@pdf.render_pdf(model))
  assert_true(rounded.contains("TJ"))
}

///|
test "an advance the layout widened becomes a TJ displacement" {
  let face = @fonts.face("Carlito")
  let a = face.advance_pt('A'.to_int(), 1000.0).round() / 100.0
  let b = face.advance_pt('B'.to_int(), 1000.0).round() / 100.0
  // 2pt extra after A at 10pt is -200 thousandths of text space
  let text = as_decoded_text(@pdf.render_pdf(run_model([a + 2.0, b])))
  assert_true(text.contains("TJ"))
  assert_true(text.contains("-200"))
}

///|
test "links, anchors and the outline reach the pdf" {
  let model = run_model([5.0, 5.0])
  model.pages[0].items.push(Anchor({ name: "target", x_pt: 0, y_pt: 10, }))
  model.pages[0].items.push(
    Link({ x_pt: 10, y_pt: 10, w_pt: 10, h_pt: 12, target: "#target", }),
  )
  model.pages[0].items.push(
    Link({
      x_pt: 30,
      y_pt: 10,
      w_pt: 10,
      h_pt: 12,
      target: "https://example.org",
    }),
  )
  let bytes = @pdf.render_pdf(
    model,
    outline=[
      { title: "Target", level: 0, anchor: "target", dest: None, open: false, },
    ],
    info=[("Title", "Links")],
  )
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let text = as_text(
    @pdflite.pdf_write_document(@pdflite.pdf_decompress_pdf(document)),
  )
  assert_true(text.contains("/Annots"))
  assert_true(text.contains("/Subtype/Link") || text.contains("/Subtype /Link"))
  assert_true(text.contains("(https://example.org)"))
  assert_true(text.contains("/Dests"))
  assert_true(text.contains("(target)"))
  assert_true(text.contains("/Outlines"))
  assert_true(text.contains("(Target)"))
  assert_true(text.contains("(Links)"))
}

///|
test "an outline entry can jump to an explicit destination" {
  let model = run_model([5.0, 5.0])
  let bytes = @pdf.render_pdf(model, outline=[
    { title: "Top", level: 0, anchor: "", dest: Some((0, 0, 0)), open: false, },
    {
      title: "Nowhere",
      level: 0,
      anchor: "",
      dest: Some((9, 0, 0)),
      open: false,
    },
  ])
  let text = as_text(
    @pdflite.pdf_write_document(
      @pdflite.pdf_decompress_pdf(@pdflite.pdf_read_document_from_bytes(bytes)),
    ),
  )
  // the top of the first page (100pt tall), with no named destination
  assert_true(text.contains("/XYZ 0 100 null"))
  assert_false(text.contains("/Dests"))
  // an entry whose page does not exist goes nowhere, but is kept
  assert_true(text.contains("(Nowhere)"))
}

///|
test "a registered face measures and embeds under its own name" {
  let program = @fontoutlines.outline_sfnt("Liberation Serif").unwrap()
  let face = @fonts.register_face("Spike Serif", program)
  @fontoutlines.register_outline("Spike Serif", program)
  inspect(@fonts.resolve_family("Spike Serif"), content="Spike Serif")
  inspect(@fonts.is_registered("Spike Serif"), content="true")
  // the registered face is what `face` hands out, bold falling back to it
  assert_true(physical_equal(@fonts.face("Spike Serif", bold=true), face))
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({
    family: "Spike Serif",
    bold: false,
    italic: false,
  })
  model.pages.push({
    width_pt: 200,
    height_pt: 100,
    items: [
      Text({
        font,
        size_pt: 10,
        x_pt: 10,
        baseline_pt: 20,
        text: "Hi",
        advances_pt: [5.0, 3.0],
        color: @pagelayout.black,
      }),
    ],
  })
  let text = as_text(@pdf.render_pdf(model))
  assert_true(text.contains("+SpikeSerif"))
  assert_true(text.contains("/FontFile2"))
}
