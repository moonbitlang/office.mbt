///|
// PDF standard fonts, measured with their real metrics.
//
// The metrics are built the way a caller builds them: from Adobe's AFM
// files for the core 14 fonts, here the copy pdflite carries (its data
// files keep Adobe's notice, which allows use and redistribution with the
// notice retained; Prawn ships the same AFM files with that notice as
// `data/fonts/MustRead.html`). Nothing of the AFM data is copied into
// this file beyond the handful of widths asserted below.

///|
/// The characters of WinAnsi's 0x80–0x9F range, by code (0: unused).
let winansi_high_chars : Array[Int] = [
  0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160,
  0x2039, 0x0152, 0, 0x017D, 0, 0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013,
  0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
]

///|
/// The width of WinAnsi `code` in `font`, in thousandths of an em: what a
/// viewer advances by, from the font's own AFM.
fn afm_width(font : @pdflite.PdfStandardFont, code : Int) -> Int {
  @pdflite.pdf_standard14_text_width(
    font,
    PdfWinAnsiEncoding,
    Bytes::from_array([code.to_byte()]),
  )
}

///|
/// The metrics of the standard font `name` as a caller builds them from
/// its AFM: each character WinAnsi encodes mapped to its code, the width of
/// each code the AFM's, and the AFM's ascender and descender.
fn standard_metrics(
  name : String,
  family? : String,
) -> @fonts.FaceMetrics raise {
  let font = @pdflite.pdf_standard_font_of_name("/" + name).unwrap()
  let advances = Array::make(256, 0)
  let cmap : Map[Int, Int] = Map([])
  for code in 0x20..<0x100 {
    let codepoint = if code >= 0x80 && code <= 0x9F {
      winansi_high_chars[code - 0x80]
    } else {
      code
    }
    if codepoint == 0 || code == 0x7F {
      continue
    }
    advances[code] = afm_width(font, code)
    cmap[codepoint] = code
  }
  // Helvetica's, for the vertical metrics (the test faces are Helvetica)
  @fonts.FaceMetrics::new(
    family=family.unwrap_or(name),
    units_per_em=1000,
    ascender=718,
    descender=-207,
    line_gap=231,
    advances~,
    cmap~,
  )
}

///|
/// The (code, x) of every code a viewer shows in a standard font, placing
/// each glyph by the font's own AFM widths (not by anything the renderer
/// was given) and by the `TJ` displacements.
fn viewer_positions(bytes : Bytes) -> Array[(Int, Double)] raise {
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let placed : Array[(Int, Double)] = []
  for page in document.pages_of_pagetree() {
    let fonts = document
      .lookup_direct(name("/Font"), page.resources)
      .unwrap_or(PdfDictionary([]))
    let mut font : @pdflite.PdfStandardFont? = None
    let mut size = 0.0
    let mut x = 0.0
    let show = fn(shown : Bytes) raise {
      guard font is Some(standard) else { fail("not a standard font") }
      for byte in shown {
        let code = byte.to_int()
        placed.push((code, x))
        x += afm_width(standard, code).to_double() * size / 1000.0
      }
    }
    for op in document.parse_content_ops(page.content) {
      match op {
        Op_Tf(resource, s) => {
          size = s
          guard document.lookup_direct(resource, fonts) is Some(dict) else {
            fail("unknown font resource")
          }
          font = match document.lookup_direct(name("/BaseFont"), dict) {
            Some(PdfNameObject(basefont)) =>
              @pdflite.pdf_standard_font_of_pdf_name(basefont)
            _ => None
          }
        }
        Op_Tm(matrix) => x = matrix.e
        Op_Tj(shown) => show(shown)
        Op_TJ(PdfArray(parts)) =>
          for part in parts {
            match part {
              PdfString(shown) => show(shown)
              PdfReal(adjust) => x -= adjust * size / 1000.0
              PdfInteger(adjust) => x -= adjust.to_double() * size / 1000.0
              _ => ()
            }
          }
        _ => ()
      }
    }
  }
  placed
}

///|
/// The x of every character of `model`'s first run, as the model places
/// it: the run's origin plus the advances before it.
fn model_positions(model : @pagelayout.PageModel) -> Array[Double] raise {
  guard model.pages[0].items[0] is Text(run) else { fail("expected text") }
  let xs : Array[Double] = []
  let mut x = run.x_pt
  for advance in run.advances_pt {
    xs.push(x)
    x += advance
  }
  xs
}

///|
/// Positions as text, to two decimals.
fn positions_text(xs : Array[Double]) -> String {
  xs.map(x => ((x * 100.0).round() / 100.0).to_string()).join(" ")
}

///|
test "the standard-font fixture carries the AFM's widths" {
  let bold = standard_metrics("Helvetica-Bold")
  // Adobe's Helvetica-Bold.afm: I 278, t 333, quoteright 278, s 556,
  // space 278, Euro 556, five 556
  let widths = "It\u{2019}s \u{20AC}5"
    .iter()
    .map(c => bold.advance_pt(c.to_int(), 1000.0).to_int().to_string())
    .collect()
  inspect(widths.join(" "), content="278 333 278 556 278 556 556")
  // and Helvetica's quoteright is narrower: the faces differ
  inspect(
    standard_metrics("Helvetica").advance_pt(0x2019, 1000.0),
    content="222",
  )
}

///|
test "a standard font is declared by name, WinAnsi-encoded, not embedded" {
  let registry = @fonts.FontRegistry::new()
  let metrics = standard_metrics("Helvetica-Bold")
  registry.register_standard("Helvetica", metrics, standard="Helvetica-Bold")
  |> ignore
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
  // the metrics are the font's own, so the natural widths place every
  // glyph: one plain Tj, no displacement
  assert_false(as_decoded_text(bytes).contains("TJ"))
  // and a viewer drawing with the font's own widths puts every glyph
  // where the model does (the € 4.45pt earlier with made-up widths)
  let expected = model_positions(model)
  let viewer = viewer_positions(bytes)
  inspect(
    positions_text(viewer.map(p => p.1)),
    content="10 12.78 16.11 18.89 24.45 27.23 32.79",
  )
  inspect(
    positions_text(expected[0:7].to_owned()),
    content="10 12.78 16.11 18.89 24.45 27.23 32.79",
  )
}

///|
test "kerning given as the run's advances is drawn where the model puts it" {
  let registry = @fonts.FontRegistry::new()
  let metrics = standard_metrics("Helvetica")
  registry.register_standard("Helvetica", metrics, standard="Helvetica")
  |> ignore
  // Helvetica's AFM kerns A V by -70: "AV" at 10pt is 13.34pt unkerned,
  // 12.64pt kerned; the kerned advance of A is 6.67 - 0.70
  let model = family_model("Helvetica", "AVA", metrics)
  guard model.pages[0].items[0] is Text(run) else { fail("expected text") }
  model.pages[0].items[0] = Text({
    ..run,
    advances_pt: [5.97, run.advances_pt[1], run.advances_pt[2]],
  })
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  let content = as_decoded_text(bytes)
  assert_true(content.contains("TJ"))
  assert_true(content.contains("70"))
  let viewer = viewer_positions(bytes)
  inspect(positions_text(viewer.map(p => p.1)), content="10 15.97 22.64")
  inspect(positions_text(model_positions(model)), content="10 15.97 22.64")
}

///|
test "a standard font registered under an alias is laid out and drawn as that alias" {
  // Helvetica's metrics, registered as the family "Body"
  let registry = @fonts.FontRegistry::new()
  let helvetica = standard_metrics("Helvetica")
  inspect(helvetica.family, content="Helvetica")
  let body = registry.register_standard("Body", helvetica, standard="Helvetica")
  // the face takes the registered identity, as `register` gives it
  inspect(body.family, content="Body")
  assert_true(physical_equal(registry.face("Body"), body))
  inspect(body.advance_pt('H'.to_int(), 10.0), content="7.22")
  let layout = @paragraph.layout_paragraph(
    one_run("Body", "Hi"),
    400,
    fonts=registry,
  )
  let run = layout.lines[0].runs[0]
  // the run names the registered family, not the metrics' own name
  inspect(run.font.family, content="Body")
  inspect(drawn_as_measured(layout, registry), content="Body:Hi")
  let model = @pagelayout.PageModel::new()
  let font = model.add_font(run.font)
  model.pages.push({
    width_pt: 200,
    height_pt: 100,
    items: [
      Text({
        font,
        size_pt: run.size_pt,
        x_pt: 10,
        baseline_pt: 20,
        text: run.text,
        advances_pt: run.advances_pt,
        color: @pagelayout.black,
      }),
    ],
  })
  let pdf = as_text(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(fonts=registry)),
  )
  // so the renderer draws the registered standard font, not a bundled one
  assert_true(pdf.contains("/Type1"))
  assert_true(pdf.contains("/BaseFont /Helvetica"))
  assert_false(pdf.contains("/FontFile"))
}

///|
test "a standard font name must be one of the twelve Latin faces" {
  let attempt = fn(standard : String) {
    let registry = @fonts.FontRegistry::new()
    try {
      registry.register_standard(
        "Body",
        standard_metrics("Helvetica"),
        standard~,
      )
      |> ignore
      "registered"
    } catch {
      e => e.to_string()
    }
  }
  inspect(attempt("Courier-BoldOblique"), content="registered")
  // a misspelling
  inspect(
    attempt("Helvetcia"),
    content="not a PDF standard font: Helvetcia (expected Helvetica, Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique, Times-Roman, Times-Bold, Times-Italic, Times-BoldItalic, Courier, Courier-Bold, Courier-Oblique or Courier-BoldOblique)",
  )
  // an alias pdflite reads, but not a PostScript name
  inspect(
    attempt("Arial"),
    content="not a PDF standard font: Arial (expected Helvetica, Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique, Times-Roman, Times-Bold, Times-Italic, Times-BoldItalic, Courier, Courier-Bold, Courier-Oblique or Courier-BoldOblique)",
  )
  // the symbolic fonts have built-in encodings, not WinAnsi
  inspect(
    attempt("Symbol"),
    content="unsupported PDF standard font: Symbol (a symbolic font, not WinAnsi-encoded)",
  )
  inspect(
    attempt("ZapfDingbats"),
    content="unsupported PDF standard font: ZapfDingbats (a symbolic font, not WinAnsi-encoded)",
  )
}

///|
test "a standard font takes a face of its own name, sealed like any other" {
  let registry = @fonts.FontRegistry::new()
  registry.register_standard(
    "Times-Roman",
    standard_metrics("Times-Roman"),
    standard="Times-Roman",
  )
  |> ignore
  let duplicate = try {
    registry.register_standard(
      "Times-Roman",
      standard_metrics("Times-Roman"),
      standard="Times-Roman",
    )
    |> ignore
    "registered"
  } catch {
    e => e.to_string()
  }
  inspect(duplicate, content="font already registered: Times-Roman|false|false")
  inspect(registry.is_registered("Times-Roman"), content="true")
  let too_late = try {
    registry.register_standard(
      "Courier",
      standard_metrics("Courier"),
      standard="Courier",
    )
    |> ignore
    "registered"
  } catch {
    e => e.to_string()
  }
  inspect(
    too_late,
    content="font registry already in use; cannot register Courier|false|false",
  )
}
