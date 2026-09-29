///|
/// The bundled Liberation Sans program for a style, as a caller's own font
/// file would be.
fn sans(bold? : Bool = false, italic? : Bool = false) -> Bytes {
  @fontoutlines.outline_sfnt("Liberation Sans", bold~, italic~).unwrap()
}

///|
/// `program` with its `glyf` and `loca` tables hidden (their directory
/// tags renamed), as a metrics-only sfnt carries them: every table the
/// metrics come from is intact, but there are no outlines to embed.
fn metrics_only(program : Bytes) -> Bytes {
  let bytes = program.to_array()
  let tables = (bytes[4].to_int() << 8) | bytes[5].to_int()
  for i in 0..<tables {
    let record = 12 + i * 16
    let tag = Bytes::from_array(bytes[record:record + 4].to_owned())
    if tag == b"glyf" || tag == b"loca" {
      bytes[record] = b'x'
    }
  }
  Bytes::from_array(bytes)
}

///|
/// A one-page model showing `text` in `family`, each code unit advancing
/// by the width `face` gives it at 10pt.
fn family_model(
  family : String,
  text : String,
  face : @fonts.FaceMetrics,
  bold? : Bool = false,
) -> @pagelayout.PageModel {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family, bold, italic: false, })
  let advances = text
    .iter()
    .map(c => face.advance_pt(c.to_int(), 10.0))
    .collect()
  model.pages.push({
    width_pt: 200,
    height_pt: 100,
    items: [
      Text({
        font,
        size_pt: 10,
        x_pt: 10,
        baseline_pt: 20,
        text,
        advances_pt: advances,
        color: @pagelayout.black,
      }),
    ],
  })
  model
}

///|
/// The text a reader extracts from every page, through each font's
/// `/ToUnicode` map (or its encoding), and the raw codes shown, in hex.
fn extracted(bytes : Bytes) -> (String, String) raise {
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let text = StringBuilder()
  let codes = StringBuilder()
  for page in document.pages_of_pagetree() {
    let fonts = document
      .lookup_direct(name("/Font"), page.resources)
      .unwrap_or(PdfDictionary([]))
    let mut extractor : @pdflite.PdfTextExtractor? = None
    let show = fn(shown : Bytes) raise {
      for byte in shown {
        codes.write_string(byte.to_int().to_string(radix=16).pad_start(2, '0'))
      }
      guard extractor is Some(e) else { fail("text before a font") }
      for codepoint in e.codepoints_of_text(shown) {
        text.write_char(codepoint.unsafe_to_char())
      }
    }
    for op in document.parse_content_ops(page.content) {
      match op {
        Op_Tf(font, _) =>
          match document.lookup_direct(font, fonts) {
            Some(dict) =>
              extractor = Some(document.text_extractor_of_font(dict))
            None => fail("unknown font resource")
          }
        Op_Tj(shown) => show(shown)
        Op_TJ(PdfArray(parts)) =>
          for part in parts {
            if part is PdfString(shown) {
              show(shown)
            }
          }
        _ => ()
      }
    }
  }
  (text.to_string(), codes.to_string())
}

///|
test "a registered face measures and embeds under its own name" {
  let registry = @fonts.FontRegistry::new()
  let program = @fontoutlines.outline_sfnt("Liberation Serif").unwrap()
  let face = registry.register("Spike Serif", program)
  inspect(registry.is_sealed(), content="false")
  inspect(registry.resolve_family("Spike Serif"), content="Spike Serif")
  inspect(registry.is_sealed(), content="true")
  inspect(registry.is_registered("Spike Serif"), content="true")
  // the package-level functions only know the bundle
  inspect(@fonts.resolve_family("Spike Serif"), content="Carlito")
  // the registered face is what `face` hands out, bold falling back to it
  assert_true(physical_equal(registry.face("Spike Serif", bold=true), face))
  let model = family_model("Spike Serif", "Hi", face)
  let text = as_text(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(fonts=registry)),
  )
  assert_true(text.contains("+SpikeSerif"))
  assert_true(text.contains("/FontFile2"))
  // without the registry the family is unknown and drawn in Carlito
  let bundled = as_text(@pdf.render_pdf(model))
  assert_true(bundled != text)
}

///|
test "a registry is sealed by its first lookup and never replaces a face" {
  let registry = @fonts.FontRegistry::new()
  ignore(registry.register("Own", sans()))
  let duplicate = try {
    ignore(registry.register("Own", sans(bold=true)))
    "registered"
  } catch {
    e => e.to_string()
  }
  inspect(duplicate, content="font already registered: Own|false|false")
  ignore(registry.face("Own", bold=true))
  let late = try {
    ignore(registry.register("Own", sans(bold=true), bold=true))
    "registered"
  } catch {
    e => e.to_string()
  }
  inspect(
    late,
    content="font registry already in use; cannot register Own|true|false",
  )
  // an explicit seal works the same way
  let closed = @fonts.FontRegistry::new()
  closed.seal()
  let refused = try {
    ignore(closed.register("Other", sans()))
    false
  } catch {
    @fonts.FontRegistryError::Sealed(_) => true
    _ => false
  }
  assert_true(refused)
}

///|
test "documents with their own registries do not see each other's faces" {
  let serif = @fontoutlines.outline_sfnt("Liberation Serif").unwrap()
  let first = @fonts.FontRegistry::new()
  let first_face = first.register("Body", sans())
  let second = @fonts.FontRegistry::new()
  ignore(second.register("Body", serif))
  let model = family_model("Body", "Hello", first_face)
  let render = fn(registry) raise {
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(fonts=registry))
  }
  let before = render(first)
  // rendering another document with another face under the same family
  // changes nothing for this one
  let other = render(second)
  assert_true(before != other)
  assert_true(render(first) == before)
}

///|
test "a metrics-only face is declared, never composite, and extracts cleanly" {
  let registry = @fonts.FontRegistry::new()
  let face = registry.register("Metrics Only", metrics_only(sans()))
  inspect(
    registry.registered_face("Metrics Only").unwrap().program is None,
    content="true",
  )
  // the face can draw Ω, but has no program to address it in
  assert_true(face.has_char(0x3A9))
  let bytes = @pdf.render_pdf(
    family_model("Metrics Only", "AΩ", face),
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  let text = decompressed(bytes)
  assert_false(text.contains("/Type0"))
  assert_false(text.contains("/FontFile2"))
  assert_true(text.contains("/BaseFont /MetricsOnly"))
  // one-byte WinAnsi codes; Ω is dropped rather than shown as garbage
  let (shown, codes) = extracted(bytes)
  inspect(shown, content="A")
  inspect(codes, content="41")
}

///|
test "a missing style is measured and drawn with the regular face" {
  let registry = @fonts.FontRegistry::new()
  let regular = registry.register("Own Sans", sans())
  // bold is requested; only regular is registered
  assert_true(physical_equal(registry.face("Own Sans", bold=true), regular))
  let bytes = @pdf.render_pdf(
    family_model("Own Sans", "AΩ", regular, bold=true),
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  assert_true(decompressed(bytes).contains("/Type0"))
  let (shown, codes) = extracted(bytes)
  inspect(shown, content="AΩ")
  // Identity-H codes are the regular program's glyph ids
  let hex = fn(cp : Int) {
    regular.cmap.get(cp).unwrap().to_string(radix=16).pad_start(4, '0')
  }
  assert_eq(codes, hex('A'.to_int()) + hex(0x3A9))
}

///|
test "a bold-only family renders regular text with its bold face" {
  let registry = @fonts.FontRegistry::new()
  let bold = registry.register("Only Bold", sans(bold=true), bold=true)
  assert_true(physical_equal(registry.face("Only Bold"), bold))
  let model = family_model("Only Bold", "AΩ", bold)
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  let (shown, _) = extracted(bytes)
  inspect(shown, content="AΩ")
  // exactly as if the bold bytes had been registered as the regular face
  let as_regular = @fonts.FontRegistry::new()
  ignore(as_regular.register("Only Bold", sans(bold=true)))
  assert_true(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(fonts=as_regular)) ==
    bytes,
  )
}

///|
test "bundled faces keep their programs through the style fallback" {
  // Noto Sans SC ships regular only: bold CJK is measured and embedded as
  // the regular face, composite, and extracts as written
  let face = @fonts.face("Noto Sans SC", bold=true)
  inspect(face.bold, content="false")
  let bytes = @pdf.render_pdf(family_model("SimSun", "中文", face, bold=true))
  let (shown, _) = extracted(bytes)
  inspect(shown, content="中文")
}

///|
test "a composite run the layout moved shows two-byte codes with displacements" {
  let face = @fonts.face("Noto Sans SC")
  let model = family_model("SimSun", "中文", face)
  guard model.pages[0].items[0] is Text(run) else { fail("expected text") }
  // 3pt extra after the first ideograph at 10pt is -300 thousandths
  model.pages[0].items[0] = Text({
    ..run,
    advances_pt: [run.advances_pt[0] + 3.0, run.advances_pt[1]],
  })
  let bytes = @pdf.render_pdf(model)
  let document = @pdflite.pdf_decompress_pdf(
    @pdflite.pdf_read_document_from_bytes(bytes),
  )
  let page = document.pages_of_pagetree()[0]
  let shows = document
    .parse_content_ops(page.content)
    .filter_map(op => {
      match op {
        Op_TJ(PdfArray(parts)) =>
          Some(
            parts
            .map(part => {
              match part {
                PdfString(s) => "<\{s.length()} bytes>"
                other => number(other)
              }
            })
            .join(" "),
          )
        Op_Tj(_) => Some("Tj")
        _ => None
      }
    })
  inspect(shows.join("; "), content="<2 bytes> -300 <2 bytes>")
  let (shown, _) = extracted(bytes)
  inspect(shown, content="中文")
}

///|
test "a simple font's ToUnicode map splits into blocks of at most 100" {
  // every printable WinAnsi character: 95 ASCII plus the Latin-1 range and
  // the typographic punctuation, well over one block
  let sb = StringBuilder()
  for c in 0x20..<0x7F {
    sb.write_char(c.unsafe_to_char())
  }
  for c in 0xA1..<=0xFF {
    sb.write_char(c.unsafe_to_char())
  }
  for c in [0x2018, 0x2019, 0x201C, 0x201D, 0x2013, 0x2014, 0x2022, 0x2026] {
    sb.write_char(c.unsafe_to_char())
  }
  let text = sb.to_string()
  let face = @fonts.face("Carlito")
  let bytes = @pdf.render_pdf(family_model("Carlito", text, face))
  let decoded_text = decompressed(bytes)
  assert_true(decoded_text.contains("100 beginbfchar"))
  // 95 + 95 + 8 distinct codes: 100, then 98
  assert_true(decoded_text.contains("98 beginbfchar"))
  let (shown, _) = extracted(bytes)
  assert_eq(shown, text)
}

///|
test "paragraph layout measures with the registry it is given" {
  let registry = @fonts.FontRegistry::new()
  let face = registry.register(
    "House Mono",
    @fontoutlines.outline_sfnt("Liberation Mono").unwrap(),
  )
  let input = @paragraph.ParagraphInput::{
    runs: [
      {
        text: "iiii",
        style: {
          family: "House Mono",
          size_pt: 10,
          bold: false,
          italic: false,
          color: @pagelayout.black,
        },
        field: NotAField,
      },
    ],
    style: @paragraph.ParagraphStyle::default(),
  }
  let advances = fn(layout : @paragraph.ParagraphLayout) {
    layout.lines[0].runs[0].advances_pt
  }
  // monospaced with the registry; Carlito's narrow i without it
  let registered = advances(
    @paragraph.layout_paragraph(input, 400, fonts=registry),
  )
  assert_eq(registered, Array::make(4, face.advance_pt('i'.to_int(), 10)))
  let bundled = advances(@paragraph.layout_paragraph(input, 400))
  assert_eq(
    bundled,
    Array::make(4, @fonts.face("Carlito").advance_pt('i'.to_int(), 10)),
  )
}
