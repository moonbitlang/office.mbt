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
// Fonts are declared, not embedded. The bundled faces in
// `pagelayout/fonts` are metrics-only sfnts — head/hhea/maxp/hmtx/cmap/
// OS-2/post with no `glyf` or `loca` — because layout needs advances,
// not outlines, and stripping them keeps the repository small. A PDF
// `/FontFile2` needs the outlines, so each font is written as a simple
// TrueType dictionary with a descriptor, a `/Widths` array taken from
// the same metrics the layout used, and no font file. Viewers substitute
// the glyphs.
//
// That costs glyph *shapes*, not layout: every run is positioned
// explicitly with `Tm`, and `/Widths` governs spacing per the spec, so
// line breaks and page geometry are identical to the SVG backend
// regardless of what the viewer substitutes. Embedding real outlines
// (and with them CJK via Type0/Identity-H) needs full font programs
// bundled — a separate, deliberate size decision.

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
/// A font as the PDF needs it: which bundled face, and the widths of
/// every code it uses.
priv struct PdfFace {
  spec : @pagelayout.FontSpec
  metrics : @fonts.FaceMetrics
}

///|
fn name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@utf8.encode(text))
}

///|
/// The font object for one interned IR font: a simple TrueType font with
/// a descriptor and a `/Widths` array from the same metrics the layout
/// measured with, and no embedded program.
fn font_object(document : @pdflite.PdfDocument, face : PdfFace) -> Int raise {
  let metrics = face.metrics
  let scale = 1000.0 / metrics.units_per_em.to_double()
  let first = 32
  let last = 255
  let widths : Array[Int] = []
  for code = first; code <= last; code = code + 1 {
    // advance_pt at 1000pt is exactly the 1/1000-em width PDF wants
    widths.push(metrics.advance_pt(code, 1000.0).round().to_int())
  }
  let descriptor : @pdflite.PdfFontDescriptor = {
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
    // the bundled faces carry metrics without outlines, so there is no
    // program to embed; pdflite writes a substitutable font
    fontfile: None,
    charset: None,
    tounicode: None,
  }
  document.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(name(base_font_name(face.spec))),
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
/// `/BaseFont` names carry the style, as PDF expects: `Carlito-BoldItalic`.
fn base_font_name(spec : @pagelayout.FontSpec) -> String {
  let sb = StringBuilder()
  sb.write_string("/")
  for c in spec.family {
    // PDF names may not contain spaces
    if c == ' ' {
      continue
    }
    sb.write_char(c)
  }
  if spec.bold && spec.italic {
    sb.write_string("-BoldItalic")
  } else if spec.bold {
    sb.write_string("-Bold")
  } else if spec.italic {
    sb.write_string("-Italic")
  }
  sb.to_string()
}
