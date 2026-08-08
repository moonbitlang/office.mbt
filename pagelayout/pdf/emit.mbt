///|
// PDF backend: page-model IR to a real PDF via pdflite.
//
// Two things make this mostly transcription. The IR already carries
// absolute positions and per-character advances, so nothing is
// re-measured; and pdflite exposes PDF operators as a typed enum, so no
// bytes are hand-assembled. The genuine work is the coordinate flip
// (the IR is y-down from the page's top-left, PDF is y-up from the
// bottom-left) and font resources.
//
// Fonts come out one of two ways, depending on whether the family has a
// bundled font program in `pagelayout/fontoutlines`.
//
// Families without one — the Latin faces, whose metrics-only sfnts carry
// no `glyf` or `loca` — are written as simple TrueType dictionaries with
// a descriptor, a `/Widths` array from the same metrics the layout used,
// and no font file. Viewers substitute the glyphs. That costs glyph
// *shapes*, not layout: every run is positioned explicitly with `Tm`, and
// `/Widths` governs spacing per the spec, so line breaks and page
// geometry match the SVG backend regardless of what the viewer picks.
//
// Families with a bundled program are written as Type0 composite fonts
// with Identity-H encoding over a CIDFontType2 descendant, embedding a
// subset of that program. This is the only path that renders CJK at all,
// for two reasons. A simple font's WinAnsi encoding is 8-bit, so it
// cannot address more than 256 codes. And substitution, which is
// harmless for Latin, is fatal here: under Identity-H a code *is* a
// glyph index into the embedded program, so a reader that picked a
// different face would draw whatever glyphs happened to sit at those
// indices — mojibake, not a near miss.

///|
/// WinAnsi is an 8-bit encoding: a simple font can only address 256
/// codes. Characters outside it (CJK, most symbols) need a composite
/// Type0 font, which needs embedded outlines — see the module comment.
fn winansi_code(codepoint : Int) -> Int? {
  if codepoint >= 0x20 && codepoint <= 0x7E {
    // ASCII maps directly
    Some(codepoint)
  } else {
    match codepoint {
      0x2018 => Some(0x91) // left single quote
      0x2019 => Some(0x92)
      0x201C => Some(0x93) // left double quote
      0x201D => Some(0x94)
      0x2013 => Some(0x96) // en dash
      0x2014 => Some(0x97) // em dash
      0x2022 => Some(0x95) // bullet
      0x2026 => Some(0x85) // ellipsis
      0x00A0 => Some(0x20) // nbsp renders as a space
      _ =>
        if codepoint >= 0xA0 && codepoint <= 0xFF {
          Some(codepoint)
        } else {
          None
        }
    }
  }
}

///|
/// A font as the PDF needs it: which bundled face, and the font program
/// to embed when the family has one bundled.
priv struct PdfFace {
  spec : @pagelayout.FontSpec
  metrics : @fonts.FaceMetrics
  /// The complete bundled sfnt, for families that ship outlines. A face
  /// without one is declared and not embedded, and the viewer substitutes.
  program : Bytes?
  /// Whether this font is written as a Type0 composite rather than a
  /// simple TrueType font. Decided from the characters the document
  /// actually uses, not from the family — see `needs_composite`.
  composite : Bool
}

///|
/// Whether this font is written as a Type0 composite.
fn PdfFace::is_composite(self : PdfFace) -> Bool {
  self.composite
}

///|
/// A font goes composite exactly when it can draw something WinAnsi
/// cannot address — a codepoint outside the encoding that this face has a
/// glyph for. That is what CJK requires and what nothing else does: a
/// simple font is smaller, more widely understood, and spaces text from
/// `/Widths` rather than a `/W` array, so it stays the default wherever it
/// suffices.
///
/// Both halves matter. Without the encoding test every face would go
/// composite needlessly; without the glyph test a face would go composite
/// for a character it renders as `.notdef` anyway, and the run would then
/// be spaced by that glyph's width instead of being broken around it at
/// the advance the layout chose.
fn needs_composite(face : PdfFace, codepoints : Array[Int]) -> Bool {
  for codepoint in codepoints {
    if winansi_code(codepoint) is None && face.metrics.has_char(codepoint) {
      return true
    }
  }
  false
}

///|
/// A subset font's `/BaseFont` carries a six-letter tag so two subsets of
/// the same face cannot collide in a reader's cache. pdflite's own tag
/// generator counts a process-global, which would make the same document
/// render differently on a second call; this derives the tag from the
/// font's position in the model instead, so the output stays a function
/// of the input.
fn subset_tag(index : Int) -> String {
  let sb = StringBuilder()
  let mut remaining = index
  for _ in 0..<6 {
    sb.write_char(('A'.to_int() + remaining % 26).unsafe_to_char())
    remaining = remaining / 26
  }
  sb.to_string()
}

///|
/// A composite font: a Type0 with Identity-H encoding over a
/// CIDFontType2 descendant that embeds a subset of the bundled program.
///
/// Identity-H means a code *is* a glyph index, which is why the program
/// has to travel with the document — the indices are meaningless against
/// any other face. pdflite's subsetter keeps the original glyph ids
/// (unused glyphs become zero-length entries), so no CID remapping is
/// needed and `/CIDToGIDMap` stays `/Identity`.
fn composite_font_object(
  document : @pdflite.PdfDocument,
  face : PdfFace,
  program : Bytes,
  index : Int,
  codepoints : Array[Int],
) -> Int raise {
  let metrics = face.metrics
  let fontfile = embedded_program(document, program, codepoints)
  // widths and ToUnicode are keyed by CID, which here is the glyph id
  let widths : Array[(Int, Double)] = []
  let tounicode : Array[(Int, @core.PdfBytes)] = []
  let seen : Map[Int, Unit] = Map([])
  for codepoint in codepoints {
    let glyph = metrics.cmap.get(codepoint).unwrap_or(0)
    if glyph == 0 || seen.contains(glyph) {
      continue
    }
    seen[glyph] = ()
    widths.push((glyph, metrics.advance_pt(codepoint, 1000.0).round()))
    tounicode.push((glyph, utf16be(codepoint)))
  }
  // /W wants ascending CIDs so consecutive ones group into runs
  widths.sort_by(fn(left, right) { left.0.compare(right.0) })
  let basefont = name(
    "/" + subset_tag(index) + "+" + pdf_name_body(face.spec.family),
  )
  let descriptor = font_descriptor(
    face,
    Some(PdfFontFile2(fontfile)),
    Some(tounicode),
  )
  document.write_font(
    PdfFontCIDKeyed({
      basefont,
      composite: {
        // Identity ordering: the CIDs are this font's own glyph ids, not
        // positions in a registered character collection
        cid_system_info: {
          registry: b"Adobe",
          ordering: b"Identity",
          supplement: 0,
        },
        cid_basefont: basefont,
        cid_fontdescriptor: descriptor,
        cid_widths: widths,
        cid_widths2: [],
        // ideographs are full-width, so the default covers most CIDs
        cid_default_width: 1000,
        cid_default_width2: [],
      },
      encoding: PdfPredefinedCMap(name("/Identity-H")),
    }),
  )
}

///|
/// The descriptor both font shapes share. Simple and composite fonts
/// differ only in whether a program and a ToUnicode map accompany them;
/// every metric below is the one the layout measured with.
fn font_descriptor(
  face : PdfFace,
  fontfile : @pdflite.PdfFontFile?,
  tounicode : Array[(Int, @core.PdfBytes)]?,
) -> @pdflite.PdfFontDescriptor {
  let metrics = face.metrics
  let scale = 1000.0 / metrics.units_per_em.to_double()
  {
    ascent: metrics.ascender.to_double() * scale,
    descent: metrics.descender.to_double() * scale,
    avgwidth: 0,
    maxwidth: 0,
    // nonsymbolic (bit 6); italic adds bit 7
    flags: if face.spec.italic {
      0x20 | 0x40
    } else {
      0x20
    },
    fontbbox: { min_x: -1000, min_y: -500, max_x: 2000, max_y: 1500 },
    italicangle: if face.spec.italic {
      -12.0
    } else {
      0.0
    },
    capheight: metrics.ascender.to_double() * scale,
    xheight: 0,
    stemv: if face.spec.bold {
      160.0
    } else {
      80.0
    },
    fontfile,
    charset: None,
    tounicode,
  }
}

///|
/// A codepoint as UTF-16BE, the encoding a ToUnicode CMap maps to.
fn utf16be(codepoint : Int) -> Bytes {
  if codepoint > 0xFFFF {
    let value = codepoint - 0x10000
    let high = 0xD800 + (value >> 10)
    let low = 0xDC00 + (value & 0x3FF)
    Bytes::from_array([
      (high >> 8).to_byte(),
      (high & 0xFF).to_byte(),
      (low >> 8).to_byte(),
      (low & 0xFF).to_byte(),
    ])
  } else {
    Bytes::from_array([(codepoint >> 8).to_byte(), (codepoint & 0xFF).to_byte()])
  }
}

///|
fn name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@utf8.encode(text))
}

///|
/// The font object for one interned IR font: a simple TrueType font with
/// a descriptor and a `/Widths` array from the same metrics the layout
/// measured with, and no embedded program.
fn font_object(
  document : @pdflite.PdfDocument,
  face : PdfFace,
  index : Int,
  codepoints : Array[Int],
) -> Int raise {
  let metrics = face.metrics
  let first = 32
  let last = 255
  let widths : Array[Int] = []
  for code = first; code <= last; code = code + 1 {
    // advance_pt at 1000pt is exactly the 1/1000-em width PDF wants
    widths.push(metrics.advance_pt(code, 1000.0).round().to_int())
  }
  // A face with a bundled program is embedded so the page renders the
  // shapes it was laid out with. Without one the font is only declared,
  // and the viewer substitutes — harmless for Latin, since every run is
  // positioned explicitly and `/Widths` governs spacing.
  let (fontfile, basefont) : (@pdflite.PdfFontFile?, @core.PdfName) = match
    face.program {
    Some(program) =>
      (
        Some(PdfFontFile2(embedded_program(document, program, codepoints))),
        name(
          "/" +
          subset_tag(index) +
          "+" +
          pdf_name_body(face.spec.family) +
          style_suffix(face.spec),
        ),
      )
    None => (None, name(base_font_name(face.spec)))
  }
  let descriptor = font_descriptor(face, fontfile, None)
  document.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(basefont),
      firstchar: first,
      lastchar: last,
      widths,
      fontdescriptor: Some(descriptor),
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
  )
}

///|
/// Subset a bundled program to the characters used and add it as a
/// flate-compressed `/FontFile2` stream. `/Length1` is the *uncompressed*
/// program length, so it is taken before the stream is encoded.
fn embedded_program(
  document : @pdflite.PdfDocument,
  program : Bytes,
  codepoints : Array[Int],
) -> Int raise {
  let subset = @pdflite.pdf_truetype_subset_font(program, codepoints)
  let stream = @syntax.pdf_stream(
    PdfDictionary([
      (name("/Length"), PdfInteger(subset.length())),
      (name("/Length1"), PdfInteger(subset.length())),
    ]),
    StreamGot(subset),
  )
  document.add_object(
    @pdflite.pdf_encode_stream_with_filter(
      @pdflite.PdfStreamFlate.filter_name(),
      stream,
      only_if_smaller=true,
    ),
  )
}

///|
/// A family name with the characters a PDF name may not carry removed.
fn pdf_name_body(family : String) -> String {
  let sb = StringBuilder()
  for c in family {
    // PDF names may not contain spaces
    if c == ' ' {
      continue
    }
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// `/BaseFont` names carry the style, as PDF expects: `Carlito-BoldItalic`.
fn base_font_name(spec : @pagelayout.FontSpec) -> String {
  "/" + pdf_name_body(spec.family) + style_suffix(spec)
}

///|
/// The style half of a `/BaseFont` name, as PDF expects it.
fn style_suffix(spec : @pagelayout.FontSpec) -> String {
  if spec.bold && spec.italic {
    "-BoldItalic"
  } else if spec.bold {
    "-Bold"
  } else if spec.italic {
    "-Italic"
  } else {
    ""
  }
}
