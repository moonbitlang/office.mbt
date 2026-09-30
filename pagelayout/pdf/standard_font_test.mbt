///|
/// Helvetica's metrics as a caller would build them from its AFM: each
/// character WinAnsi encodes mapped to its code, widths by code.
fn helvetica_metrics() -> @fonts.FaceMetrics {
  let advances = Array::make(256, 556)
  advances[0x20] = 278
  advances[0x92] = 222
  advances[0x80] = 556
  let cmap : Map[Int, Int] = Map([])
  for code in 0x20..<0x7F {
    cmap[code] = code
  }
  cmap[0x2019] = 0x92
  cmap[0x20AC] = 0x80
  @fonts.FaceMetrics::new(
    family="Helvetica",
    units_per_em=1000,
    ascender=718,
    descender=-207,
    line_gap=231,
    advances~,
    cmap~,
  )
}

///|
test "a standard font is declared by name, WinAnsi-encoded, not embedded" {
  let registry = @fonts.FontRegistry::new()
  let metrics = helvetica_metrics()
  registry.register_standard("Helvetica", metrics, standard="Helvetica-Bold")
  // the face measures with the metrics given
  inspect(registry.face("Helvetica").advance_pt(0x20, 10.0), content="2.78")
  // a right single quote and a euro sign are in WinAnsi (0x92, 0x80);
  // a character WinAnsi lacks is dropped from the text
  let text = "It\u{2019}s \u{20AC}5\u{263A}"
  let model = family_model("Helvetica", text, metrics)
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  let pdf = as_text(bytes)
  assert_true(pdf.contains("/Type1"))
  assert_true(pdf.contains("/Helvetica-Bold"))
  assert_true(pdf.contains("/WinAnsiEncoding"))
  assert_false(pdf.contains("/FontFile"))
  assert_false(pdf.contains("/ToUnicode"))
  let (shown, codes) = extracted(bytes)
  inspect(shown, content="It\u{2019}s \u{20AC}5")
  inspect(
    codes,
    content=(
      #|49749273208035
    ),
  )
}

///|
test "a standard font takes a face of its own name, sealed like any other" {
  let registry = @fonts.FontRegistry::new()
  registry.register_standard(
    "Times-Roman",
    helvetica_metrics(),
    standard="Times-Roman",
  )
  let duplicate = try {
    registry.register_standard(
      "Times-Roman",
      helvetica_metrics(),
      standard="Times-Roman",
    )
    "registered"
  } catch {
    e => e.to_string()
  }
  inspect(duplicate, content="font already registered: Times-Roman|false|false")
  inspect(registry.is_registered("Times-Roman"), content="true")
}
