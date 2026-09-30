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
    regular.glyph_id(cp).unwrap().to_string(radix=16).pad_start(4, '0')
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

///|
/// `program` with its `head` table's unitsPerEm replaced: every advance of
/// the face then measures `old / units_per_em` times as wide.
fn with_units_per_em(program : Bytes, units_per_em : Int) -> Bytes {
  let bytes = program.to_array()
  let tables = (bytes[4].to_int() << 8) | bytes[5].to_int()
  for i in 0..<tables {
    let record = 12 + i * 16
    let tag = Bytes::from_array(bytes[record:record + 4].to_owned())
    if tag == b"head" {
      let offset = (bytes[record + 8].to_int() << 24) |
        (bytes[record + 9].to_int() << 16) |
        (bytes[record + 10].to_int() << 8) |
        bytes[record + 11].to_int()
      bytes[offset + 18] = (units_per_em >> 8).to_byte()
      bytes[offset + 19] = (units_per_em & 0xFF).to_byte()
    }
  }
  Bytes::from_array(bytes)
}

///|
/// A paragraph of one run of `text` in `family` at 10pt.
fn one_run(family : String, text : String) -> @paragraph.ParagraphInput {
  {
    runs: [
      {
        text,
        style: {
          family,
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
}

///|
/// Checks that every placed run is measured with the face the renderer
/// draws its font with — the registry's face for the run's family and
/// style — and returns the runs as `family:text`.
fn drawn_as_measured(
  layout : @paragraph.ParagraphLayout,
  registry : @fonts.FontRegistry,
) -> String raise {
  let runs : Array[String] = []
  for line in layout.lines {
    for run in line.runs {
      let face = registry.face(
        registry.resolve_family(run.font.family),
        bold=run.font.bold,
        italic=run.font.italic,
      )
      for i in 0..<run.text.length() {
        let expected = face.advance_pt(run.text[i].to_int(), run.size_pt)
        if run.advances_pt[i] != expected {
          fail(
            "\{run.font.family} run measures code unit \{i} at \{run.advances_pt[i]}, draws it at \{expected}",
          )
        }
      }
      if line.height_pt < face.line_height_pt(run.size_pt) - 1.0e-9 {
        fail("line shorter than its \{run.font.family} run")
      }
      runs.push("\{run.font.family}:\{run.text}")
    }
  }
  runs.join(" ")
}

///|
test "fallback characters are measured with the registry's fallback face" {
  // a Noto Sans SC of the caller's own, twice as wide as the bundled one
  let noto = @fontoutlines.outline_sfnt("Noto Sans SC").unwrap()
  let registry = @fonts.FontRegistry::new()
  let wide = registry.register("Noto Sans SC", with_units_per_em(noto, 500))
  inspect(wide.advance_pt(0x4E2D, 10), content="20")
  let direct = @paragraph.layout_paragraph(
    one_run("Noto Sans SC", "中"),
    400,
    fonts=registry,
  )
  let fallback = @paragraph.layout_paragraph(
    one_run("Arial", "中"),
    400,
    fonts=registry,
  )
  // both name the same font, so both are measured in it
  inspect(drawn_as_measured(direct, registry), content="Noto Sans SC:中")
  inspect(drawn_as_measured(fallback, registry), content="Noto Sans SC:中")
  assert_eq(fallback.lines[0].runs[0].advances_pt, [20.0])
  assert_eq(fallback.lines[0].height_pt, direct.lines[0].height_pt)
  // and drawn in it: the declared width (2000/1000 em) is the advance, so
  // no displacement corrects it
  let run = fallback.lines[0].runs[0]
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
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  assert_false(decompressed(bytes).contains(" TJ"))
  let (shown, _) = extracted(bytes)
  inspect(shown, content="中")
}

///|
test "a registered fallback family without a glyph is not measured with the bundled one" {
  // "Noto Sans SC" is shadowed by a face with no ideographs at all
  let registry = @fonts.FontRegistry::new()
  ignore(registry.register("Noto Sans SC", sans()))
  let layout = @paragraph.layout_paragraph(
    one_run("Arial", "A中"),
    400,
    fonts=registry,
  )
  // 中 is not measured at the bundled ideograph's width and then drawn in
  // a face that lacks it: nothing the registry resolves covers it, so it
  // stays in the run's own face, measured and drawn as that face's .notdef
  inspect(drawn_as_measured(layout, registry), content="Liberation Sans:A中")
  // and the loss is reported by the registry that causes it, where the
  // bundle alone has nothing to report
  assert_eq(registry.uncovered("A中", "Arial"), [(0x4E2D, 1)])
  assert_eq(@fonts.uncovered("A中", "Arial"), [])
  // the registry's fallback is the registered face, in every style
  assert_true(
    physical_equal(
      registry.cjk_fallback(bold=true),
      registry.face("Noto Sans SC"),
    ),
  )
}

///|
test "metrics handed out by a sealed registry cannot change its output" {
  let registry = @fonts.FontRegistry::new()
  let face = registry.register("Own Sans", sans())
  let model = family_model("Own Sans", "AΩ", face)
  let render = fn() raise {
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(fonts=registry))
  }
  let before = render()
  let (_, codes) = extracted(before)
  inspect(codes, content="0024035b")
  // Writing `face.cmap['A'] = 0x25`, which turned these codes into
  // 0025035b and lost the A, no longer compiles: the glyph tables are
  // private. What every exposure path hands out reads the face...
  let exposed = [
    face,
    registry.face("Own Sans"),
    registry.face("Own Sans", bold=true),
    registry.registered_face("Own Sans").unwrap().metrics,
  ]
  for metrics in exposed {
    assert_true(physical_equal(metrics, face))
    assert_eq(metrics.glyph_id('A'.to_int()), Some(0x24))
    // ...and whatever is built from what it reads is the caller's own
    let copy : Map[Int, Int] = Map([])
    for codepoint, glyph in metrics.cmap_entries() {
      copy[codepoint] = glyph
    }
    copy['A'.to_int()] = 0x25
    assert_eq(metrics.glyph_id('A'.to_int()), Some(0x24))
  }
  // the bundled faces are shared the same way, process-wide
  let bundled = @fonts.face("Liberation Sans")
  let bundled_before = @pdf.render_pdf(
    family_model("Liberation Sans", "AΩ", bundled),
  )
  let copy : Map[Int, Int] = Map([])
  for codepoint, glyph in bundled.cmap_entries() {
    copy[codepoint] = glyph + 1
  }
  assert_true(
    @pdf.render_pdf(family_model("Liberation Sans", "AΩ", bundled)) ==
    bundled_before,
  )
  let after = render()
  assert_true(after == before)
  let (_, codes) = extracted(after)
  inspect(codes, content="0024035b")
}

///|
test "notdef_text keeps characters the face lacks in the text layer" {
  // Carlito has neither a han glyph nor a check mark
  let face = @fonts.face("Carlito")
  let model = family_model("Carlito", "ab中✔cd", face)
  // by default they are left out of the page, their advance kept
  let (plain, _) = extracted(@pdf.render_pdf(model))
  inspect(plain, content="abcd")
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(notdef_text=true),
  )
  // with the option the font goes composite and each missing character
  // gets a code of its own past the program's glyphs, drawn with glyph 0
  let text = as_text(bytes)
  assert_true(text.contains("/Type0"))
  assert_true(text.contains("/CIDToGIDMap"))
  let (kept, codes) = extracted(bytes)
  inspect(kept, content="ab中✔cd")
  // two-byte codes: Carlito's glyphs for a and b, then the new codes in
  // the order of their characters (✔ U+2714 before 中 U+4E2D)
  assert_eq(codes.length(), 6 * 4)
  let a = face.glyph_id('a'.to_int()).unwrap()
  assert_eq(codes[0:4].to_owned(), a.to_string(radix=16).pad_start(4, '0'))
  let hex = fn(digits : String) {
    digits.fold(init=0, (value, c) => {
      value * 16 +
      (if c >= 'a' {
        c.to_int() - 'a'.to_int() + 10
      } else {
        c.to_int() - '0'.to_int()
      })
    })
  }
  assert_eq(hex(codes[12:16].to_owned()) + 1, hex(codes[8:12].to_owned()))
}

///|
test "notdef_text leaves a font that needs no new codes as it was" {
  let face = @fonts.face("Carlito")
  let model = family_model("Carlito", "plain Latin", face)
  assert_eq(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(notdef_text=true)),
    @pdf.render_pdf(model),
  )
}

///|
test "typo_metrics declares the OS/2 typographic ascent, descent and cap height" {
  let registry = @fonts.FontRegistry::new()
  let face = registry.register("Own", sans())
  let model = family_model("Own", "Hi", face)
  let hhea = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(fonts=registry),
  )
  let typo = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(fonts=registry, typo_metrics=true),
  )
  // by default: hhea's ascent and descent (1854 and -434 of 2048 units),
  // and the ascent again for the cap height
  inspect(
    descriptor_metrics(hhea),
    content="/Ascent 905 /Descent -211 /CapHeight 905",
  )
  // Liberation Sans's OS/2 table: sTypoAscender 1491, sTypoDescender -431,
  // sCapHeight 1409, each truncated to thousandths of an em
  inspect(
    descriptor_metrics(typo),
    content="/Ascent 728 /Descent -210 /CapHeight 687",
  )
}

///|
test "typo_metrics takes the ascent for the cap height where OS/2 has none" {
  let render = fn(program : Bytes) raise {
    let registry = @fonts.FontRegistry::new()
    let face = registry.register("Own", program)
    descriptor_metrics(
      @pdf.render_pdf(
        family_model("Own", "Hi", face),
        options=@pdf.RenderOptions::new(fonts=registry, typo_metrics=true),
      ),
    )
  }
  // sCapHeight first appears in version 2 (as Prawn reads it, through
  // ttfunk): a version 1 table has the typographic ascent, not a cap height
  inspect(
    render(with_os2(sans(), version=1)),
    content="/Ascent 728 /Descent -210 /CapHeight 728",
  )
  // nor does a version 2 table that ends before it
  inspect(
    render(with_os2(sans(), length=88)),
    content="/Ascent 728 /Descent -210 /CapHeight 728",
  )
}

///|
/// `program` with `codepoint` unmapped (mapped to glyph 0) in its format 4
/// `cmap` subtables, where it must be a segment of its own that maps by
/// `idDelta`, as U+2026 is in Liberation Sans.
fn without_char(program : Bytes, codepoint : Int) -> Bytes {
  let bytes = program.to_array()
  let u16 = fn(at : Int) { (bytes[at].to_int() << 8) | bytes[at + 1].to_int() }
  let u32 = fn(at : Int) { (u16(at) << 16) | u16(at + 2) }
  for i in 0..<u16(4) {
    let record = 12 + i * 16
    if Bytes::from_array(bytes[record:record + 4].to_owned()) != b"cmap" {
      continue
    }
    let cmap = u32(record + 8)
    for k in 0..<u16(cmap + 2) {
      let subtable = cmap + u32(cmap + 4 + k * 8 + 4)
      if u16(subtable) != 4 {
        continue
      }
      let seg_x2 = u16(subtable + 6)
      for s in 0..<(seg_x2 / 2) {
        let end = subtable + 14 + s * 2
        let start = subtable + 16 + seg_x2 + s * 2
        let delta = subtable + 16 + 2 * seg_x2 + s * 2
        if u16(start) == codepoint && u16(end) == codepoint {
          // (codepoint + idDelta) mod 65536 = 0
          let value = (0x10000 - codepoint) & 0xFFFF
          bytes[delta] = (value >> 8).to_byte()
          bytes[delta + 1] = (value & 0xFF).to_byte()
        }
      }
    }
  }
  Bytes::from_array(bytes)
}

///|
test "notdef_text keeps a WinAnsi character the face lacks in a composite font" {
  // the face lacks the ellipsis (a WinAnsi character) and the han glyph
  // (which is not, and makes the font composite): both keep codes of their
  // own and their text
  let registry = @fonts.FontRegistry::new()
  let face = registry.register("Own", without_char(sans(), 0x2026))
  assert_false(face.has_char(0x2026))
  let model = family_model("Own", "a\u{2026}中b", face)
  let (plain, _) = extracted(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(fonts=registry)),
  )
  // by default the font stays simple, which keeps the ellipsis through
  // its WinAnsi code
  inspect(plain, content="a\u{2026}b")
  let (kept, _) = extracted(
    @pdf.render_pdf(
      model,
      options=@pdf.RenderOptions::new(fonts=registry, notdef_text=true),
    ),
  )
  inspect(kept, content="a\u{2026}中b")
}

///|
/// `program` grown to `count` glyphs, as a font with that many would carry
/// them: the new glyphs are empty (`loca` repeats the end of `glyf`) and
/// take the last advance (`hmtx` gains only left side bearings). The tables
/// are laid out afresh; their checksums go stale, which nothing here reads.
fn with_glyph_count(program : Bytes, count : Int) -> Bytes {
  let u16 = fn(bytes : ArrayView[Byte], at : Int) {
    (bytes[at].to_int() << 8) | bytes[at + 1].to_int()
  }
  let source = program.to_array()
  let u32 = fn(at : Int) { (u16(source, at) << 16) | u16(source, at + 2) }
  let table_count = u16(source, 4)
  let tags : Array[Bytes] = []
  let bodies : Array[Array[Byte]] = []
  for i in 0..<table_count {
    let record = 12 + i * 16
    tags.push(Bytes::from_array(source[record:record + 4].to_owned()))
    let offset = u32(record + 8)
    bodies.push(source[offset:offset + u32(record + 12)].to_owned())
  }
  let body = fn(tag : Bytes) {
    for i, t in tags {
      if t == tag {
        return bodies[i]
      }
    }
    abort("no \{tag} table")
  }
  let maxp = body(b"maxp")
  let glyphs = u16(maxp, 4)
  maxp[4] = (count >> 8).to_byte()
  maxp[5] = (count & 0xFF).to_byte()
  let entry = if u16(body(b"head"), 50) == 0 { 2 } else { 4 }
  let loca = body(b"loca")
  let last = loca[glyphs * entry:(glyphs + 1) * entry].to_owned()
  loca.truncate((glyphs + 1) * entry)
  for _ in glyphs..<count {
    loca.append(last)
  }
  let long_metrics = u16(body(b"hhea"), 34)
  let hmtx = body(b"hmtx")
  hmtx.truncate(long_metrics * 4 + (glyphs - long_metrics) * 2)
  for _ in 0..<((count - glyphs) * 2) {
    hmtx.push(b'\x00')
  }
  let out = source[0:12 + table_count * 16].to_owned()
  let put32 = fn(at : Int, value : Int) {
    for k in 0..<4 {
      out[at + k] = ((value >> (24 - 8 * k)) & 0xFF).to_byte()
    }
  }
  for i, table in bodies {
    let record = 12 + i * 16
    put32(record + 8, out.length())
    put32(record + 12, table.length())
    out.append(table)
    while out.length() % 4 != 0 {
      out.push(b'\x00')
    }
  }
  Bytes::from_array(out)
}

///|
/// The source codes of every `bfchar` and `bfrange` entry in the
/// `/ToUnicode` maps of `text` (a decompressed PDF), as written in hex.
fn tounicode_codes(text : String) -> Array[String] {
  let codes : Array[String] = []
  let mut inside = false
  for line in text.split("\n") {
    let line = line.trim()
    if line.has_suffix("beginbfchar") || line.has_suffix("beginbfrange") {
      inside = true
    } else if line == "endbfchar" || line == "endbfrange" {
      inside = false
    } else if inside && line.has_prefix("<") {
      guard line.find(">") is Some(end) else { continue }
      codes.push(line[1:end].to_owned())
    }
  }
  codes
}

///|
test "notdef_text keeps codes within the two-byte codespace of a full font" {
  // a font with 65,535 glyphs, the most there can be: the codes past its
  // last glyph run out after one (0xFFFF), so the second missing character
  // takes a code the document leaves unused
  let registry = @fonts.FontRegistry::new()
  let face = registry.register("Full", with_glyph_count(sans(), 65535))
  assert_false(face.has_char(0x4E2D))
  assert_false(face.has_char(0x2714))
  let bytes = @pdf.render_pdf(
    family_model("Full", "a中✔b", face),
    options=@pdf.RenderOptions::new(fonts=registry, notdef_text=true),
  )
  let (kept, codes) = extracted(bytes)
  inspect(kept, content="a中✔b")
  // four distinct two-byte codes, none of them glyph 0
  let shown = [codes[0:4], codes[4:8], codes[8:12], codes[12:16]].map(code => {
    code.to_owned()
  })
  assert_eq(codes.length(), 16)
  assert_false(shown.contains("0000"))
  assert_eq(Set::from_array(shown).length(), 4)
  // and the ToUnicode map names no code outside <0000><FFFF>
  let cmap = tounicode_codes(decompressed(bytes))
  assert_false(cmap.is_empty())
  for code in cmap {
    assert_true(code.length() <= 4, msg="ToUnicode code <\{code}>")
  }
}

///|
test "notdef_text spells out characters past the codespace as ActualText" {
  // 65,536 characters Liberation Sans lacks and one it has: the 65,535
  // codes besides 0 less the one `a` uses leave the last two (U+30000 and
  // U+30001) with none
  let face = @fonts.face("Liberation Sans")
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({
    family: "Liberation Sans",
    bold: false,
    italic: false,
  })
  let text = StringBuilder()
  let advances : Array[Double] = []
  text.write_char('a')
  advances.push(face.advance_pt('a'.to_int(), 10))
  for codepoint in 0x20002..<0x30002 {
    assert_false(face.has_char(codepoint))
    text.write_char(codepoint.unsafe_to_char())
    advances.push(face.advance_pt(codepoint, 10))
    advances.push(0)
  }
  model.pages.push({
    width_pt: 200,
    height_pt: 100,
    items: [
      Text({
        font,
        size_pt: 10,
        x_pt: 10,
        baseline_pt: 20,
        text: text.to_string(),
        advances_pt: advances,
        color: @pagelayout.black,
      }),
    ],
  })
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(notdef_text=true),
  )
  // every code the map names is a two-byte one
  for code in tounicode_codes(decompressed(bytes)) {
    assert_true(code.length() <= 4, msg="ToUnicode code <\{code}>")
  }
  // the two left without a code show glyph 0 inside a marked-content span
  // whose /ActualText carries the character
  let document = @pdflite.pdf_decompress_pdf(
    @pdflite.pdf_read_document_from_bytes(bytes),
  )
  let page = document.pages_of_pagetree()[0]
  let spans : Array[String] = []
  let mut open = false
  for op in document.parse_content_ops(page.content) {
    match op {
      Op_BDC(tag, PdfDictionary(_) as properties) => {
        guard document.lookup_direct(name("/ActualText"), properties)
          is Some(PdfString(actual)) else {
          fail("span without /ActualText")
        }
        spans.push("\{name_text(tag)} \{actual}")
        open = true
      }
      Op_Tj(shown) if open => spans.push("Tj \{shown}")
      Op_TJ(PdfArray(parts)) if open =>
        for part in parts {
          if part is PdfString(shown) {
            spans.push("TJ \{shown}")
          }
        }
      Op_EMC => {
        spans.push("EMC")
        open = false
      }
      _ => ()
    }
  }
  inspect(
    spans.join("; "),
    content=(
      #|/Span b"\xfe\xff\xd8\x80\xdc\x00"; TJ b"\x00\x00"; EMC; /Span b"\xfe\xff\xd8\x80\xdc\x01"; TJ b"\x00\x00"; EMC
    ),
  )
  // everything else keeps its own code and its text
  let (kept, _) = extracted(bytes)
  let expected = text.to_string()
  let with_codes = 1 + 65534 * 2
  assert_true(kept[:with_codes] == expected[:with_codes])
  // (this reader ignores /ActualText and sees glyph 0's code)
  assert_eq(kept[with_codes:].iter().map(Char::to_int).collect(), [0, 0])
}

///|
/// `program` with its `OS/2` table's declared length and version replaced
/// (the bytes stay where they are).
fn with_os2(program : Bytes, length? : Int, version? : Int) -> Bytes {
  let bytes = program.to_array()
  let tables = (bytes[4].to_int() << 8) | bytes[5].to_int()
  for i in 0..<tables {
    let record = 12 + i * 16
    if Bytes::from_array(bytes[record:record + 4].to_owned()) != b"OS/2" {
      continue
    }
    if length is Some(length) {
      bytes[record + 12] = 0
      bytes[record + 13] = 0
      bytes[record + 14] = (length >> 8).to_byte()
      bytes[record + 15] = (length & 0xFF).to_byte()
    }
    if version is Some(version) {
      let offset = (bytes[record + 8].to_int() << 24) |
        (bytes[record + 9].to_int() << 16) |
        (bytes[record + 10].to_int() << 8) |
        bytes[record + 11].to_int()
      bytes[offset] = (version >> 8).to_byte()
      bytes[offset + 1] = (version & 0xFF).to_byte()
    }
  }
  Bytes::from_array(bytes)
}

///|
/// The `/Ascent`, `/Descent` and `/CapHeight` the (only) font descriptor
/// of a PDF declares.
fn descriptor_metrics(bytes : Bytes) -> String {
  let text = as_text(bytes)
  ["/Ascent", "/Descent", "/CapHeight"]
  .map(key => {
    guard text.find(key + " ") is Some(at) else { return "\{key} ?" }
    let value = StringBuilder()
    for c in text[at + key.length() + 1:] {
      if c != '-' && c != '.' && (c < '0' || c > '9') {
        break
      }
      value.write_char(c)
    }
    "\{key} \{value}"
  })
  .join(" ")
}

///|
test "typo_metrics reads the OS/2 metrics only where the table has them" {
  let render = fn(program : Bytes) raise {
    let registry = @fonts.FontRegistry::new()
    let face = registry.register("Own", program)
    descriptor_metrics(
      @pdf.render_pdf(
        family_model("Own", "Hi", face),
        options=@pdf.RenderOptions::new(fonts=registry, typo_metrics=true),
      ),
    )
  }
  // Liberation Sans: hhea 1854/-434, OS/2 typographic 1491/-431 (2048/em)
  assert_true(render(sans()).has_prefix("/Ascent 728 /Descent -210"))
  // a table that ends at byte 68, as a version 0 table may, has no
  // sTypoAscender or sTypoDescender: hhea's, truncated, as ttfunk does
  inspect(
    render(with_os2(sans(), length=68)),
    content="/Ascent 905 /Descent -211 /CapHeight 905",
  )
  // nor does ttfunk read them from a version 0 table of any length
  inspect(
    render(with_os2(sans(), version=0)),
    content="/Ascent 905 /Descent -211 /CapHeight 905",
  )
}

///|
test "notdef_text needs an embedded program" {
  // a metrics-only face is a simple font declared by name: it has no glyph
  // indices to give codes past, so characters it lacks are still dropped,
  // and the characters outside WinAnsi it has too
  let registry = @fonts.FontRegistry::new()
  let face = registry.register("Metrics Only", metrics_only(sans()))
  let bytes = @pdf.render_pdf(
    family_model("Metrics Only", "a中✔Ωb", face),
    options=@pdf.RenderOptions::new(fonts=registry, notdef_text=true),
  )
  assert_false(as_text(bytes).contains("/Type0"))
  let (shown, _) = extracted(bytes)
  inspect(shown, content="ab")
}
