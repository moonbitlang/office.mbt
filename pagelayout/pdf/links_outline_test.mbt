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
  let truncated = as_decoded_text(
    @pdf.render_pdf(
      model,
      options=@pdf.RenderOptions::new(truncate_widths=true),
    ),
  )
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
