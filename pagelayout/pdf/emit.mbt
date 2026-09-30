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
// Every font is one face — bundled, or registered in a `@fonts.FontRegistry`
// — whose metrics the layout measured with and whose program, when it has
// one, is embedded. Both come from that single face (`pdf_face`), so what
// the dictionary declares and what the content stream shows agree.
//
// A font comes out one of three ways.
//
// A face with a TrueType program (every bundled face; a registered face
// whose bytes carry `glyf` and `loca`) whose text stays within WinAnsi is a
// simple TrueType font: WinAnsi encoding, `/Widths` from the same metrics
// the layout used, a `/ToUnicode` map, and a subset of the program. That is
// the smaller, more widely understood shape.
//
// The same face, once its text needs a character WinAnsi cannot encode
// that the face can draw (CJK, Greek, most symbols), is a Type0 composite
// font with Identity-H encoding over a CIDFontType2 descendant, again
// embedding a subset. A simple font's 8-bit encoding cannot address more
// than 256 codes, and under Identity-H a code *is* a glyph index into the
// embedded program — so this shape exists only with a program, since a
// reader that substituted a different face would draw whatever glyphs sat
// at those indices: mojibake, not a near miss.
//
// A face without a program (a registered metrics-only sfnt) is a simple
// TrueType font declared by name, with `/Widths` and no font file; the
// viewer substitutes the glyphs and characters outside WinAnsi are dropped.
// That costs glyph *shapes*, not layout: every run is positioned
// explicitly with `Tm`, and `/Widths` governs spacing per the spec.

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
/// The codepoint WinAnsi `code` stands for — the inverse of
/// `winansi_code` over the codes it produces. `/Widths` is indexed by code,
/// but the face measures codepoints, and the two differ in 0x80–0x9F:
/// looking up 0x92 itself would declare the width of a C1 control (the
/// face's .notdef) for a right single quote.
fn winansi_unicode(code : Int) -> Int {
  match code {
    0x85 => 0x2026
    0x91 => 0x2018
    0x92 => 0x2019
    0x93 => 0x201C
    0x94 => 0x201D
    0x95 => 0x2022
    0x96 => 0x2013
    0x97 => 0x2014
    _ => code
  }
}

///|
/// A font as the PDF needs it: the face that draws it, and that face's
/// program when it has one (see `pdf_face`).
priv struct PdfFace {
  spec : @pagelayout.FontSpec
  metrics : @fonts.FaceMetrics
  /// The complete sfnt of the face `metrics` describes, when it has
  /// TrueType outlines. A face without one is declared and not embedded,
  /// and the viewer substitutes.
  program : Bytes?
  /// Whether this font is written as a Type0 composite rather than a
  /// simple TrueType font. Decided from the characters the document
  /// actually uses, not from the family — see `needs_composite`.
  composite : Bool
  /// Whether `/Widths` truncates glyph widths to whole thousandths of an em
  /// (as Prawn does) rather than rounding them.
  truncate_widths : Bool
  /// Whether characters the face lacks are drawn as `.notdef` and kept in
  /// the text layer (`RenderOptions::notdef_text`).
  notdef_text : Bool
  /// Whether the descriptor takes the OS/2 typographic metrics
  /// (`RenderOptions::typo_metrics`).
  typo_metrics : Bool
  /// With `notdef_text`, in a composite font: the code (CID) of each
  /// character the face lacks, one no glyph the document shows takes, drawn
  /// with glyph 0 (see `notdef_cids`). Decided with the document's
  /// character set.
  notdef_cids : Map[Int, Int]
  /// The PDF standard font the face is (`Helvetica`, ...), when it is one
  /// (`@fonts.FontRegistry::register_standard`): a Type1 font declared by
  /// name, whose text is encoded in the whole of WinAnsi.
  standard : String?
}

///|
/// The characters of WinAnsi's 0x80–0x9F range, by code (0: unused).
let winansi_high : Array[Int] = [
  0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160,
  0x2039, 0x0152, 0, 0x017D, 0, 0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013,
  0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
]

///|
/// The WinAnsi code of `codepoint` over the whole encoding (a standard
/// font's text): ASCII, Latin-1 and the characters of 0x80–0x9F.
fn winansi_code_full(codepoint : Int) -> Int? {
  if (codepoint >= 0x20 && codepoint <= 0x7E) ||
    (codepoint >= 0xA0 && codepoint <= 0xFF) {
    return Some(codepoint)
  }
  for i, c in winansi_high {
    if c != 0 && c == codepoint {
      return Some(0x80 + i)
    }
  }
  None
}

///|
/// The character WinAnsi `code` stands for, over the whole encoding.
fn winansi_unicode_full(code : Int) -> Int {
  if code >= 0x80 && code <= 0x9F && winansi_high[code - 0x80] != 0 {
    winansi_high[code - 0x80]
  } else {
    code
  }
}

///|
/// The WinAnsi code of `codepoint` in `face`'s simple font.
fn PdfFace::simple_code(self : PdfFace, codepoint : Int) -> Int? {
  if self.standard is Some(_) {
    winansi_code_full(codepoint)
  } else {
    winansi_code(codepoint)
  }
}

///|
/// The character `code` stands for in `face`'s simple font.
fn PdfFace::simple_unicode(self : PdfFace, code : Int) -> Int {
  if self.standard is Some(_) {
    winansi_unicode_full(code)
  } else {
    winansi_unicode(code)
  }
}

///|
/// The width the font dictionary declares for `codepoint`, in thousandths
/// of an em: rounded, or truncated when `truncate_widths`.
fn PdfFace::declared_width(self : PdfFace, codepoint : Int) -> Double {
  let width = self.metrics.advance_pt(codepoint, 1000.0)
  if self.truncate_widths {
    (width + 1.0e-9).floor()
  } else {
    width.round()
  }
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
///
/// With `notdef_text` the glyph test is dropped: a character the face
/// lacks is then drawn as `.notdef` under a code of its own (see
/// `notdef_cids`), placed by a displacement, so that it stays in the text.
///
/// And a face without a program never goes composite, whatever it can
/// draw: Identity-H codes are glyph indices into an embedded program, and
/// there is none to index.
fn needs_composite(face : PdfFace, codepoints : Array[Int]) -> Bool {
  if face.program is None {
    return false
  }
  for codepoint in codepoints {
    if winansi_code(codepoint) is None &&
      (face.metrics.has_char(codepoint) || face.notdef_text) {
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
/// CIDFontType2 descendant that embeds a subset of the face's program.
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
    let glyph = metrics.glyph_id(codepoint).unwrap_or(0)
    if glyph == 0 || seen.contains(glyph) {
      continue
    }
    seen[glyph] = ()
    widths.push((glyph, face.declared_width(codepoint)))
    tounicode.push((glyph, utf16be(codepoint)))
  }
  // the characters the face lacks, each under a code of its own (see
  // `notdef_cids`): its `.notdef` width and its character
  for codepoint, cid in face.notdef_cids {
    widths.push((cid, face.declared_width(codepoint)))
    tounicode.push((cid, utf16be(codepoint)))
  }
  // /W wants ascending CIDs so consecutive ones group into runs
  widths.sort_by(fn(left, right) { left.0.compare(right.0) })
  let basefont = name(
    "/" +
    subset_tag(index) +
    "+" +
    postscript_name(program).unwrap_or(pdf_name_body(face.spec.family)),
  )
  let descriptor = font_descriptor(
    face,
    Some(PdfFontFile2(fontfile)),
    Some(tounicode),
  )
  let number = document.write_font(
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
  if !face.notdef_cids.is_empty() {
    add_cid_to_gid_map(document, number, face.notdef_cids)
  }
  number
}

///|
/// The number of glyphs in a TrueType program (`maxp.numGlyphs`), or 0 when
/// it has no `maxp`.
fn glyph_count(program : Bytes) -> Int {
  match @pdflite.pdf_truetype_table(program, "maxp") {
    Some(maxp) if maxp.offset + 6 <= program.length() =>
      (program[maxp.offset + 4].to_int() << 8) |
      program[maxp.offset + 5].to_int()
    _ => 0
  }
}

///|
/// With `notdef_text`: a code for each character a composite font's face
/// lacks, so that each keeps its own `/ToUnicode` entry while drawing glyph
/// 0 (`/CIDToGIDMap`, see `add_cid_to_gid_map`). A character WinAnsi has
/// counts too: a composite font shows glyph indices, not WinAnsi codes, so
/// without a code of its own it would be glyph 0 with no text.
///
/// Identity-H codes are two bytes, so every code stays within
/// 0x0001–0xFFFF. They are numbered on from the program's last glyph and,
/// once those run out (a font can have 65,535 glyphs), carry on from 1
/// among the codes below it that no glyph the document shows takes: the
/// map sends those to glyph 0, and nothing else addresses them. Only a font
/// showing more than 65,535 distinct characters can use every code up; the
/// characters left over get none, and `emit_run_composite` spells them out
/// with `/ActualText` instead.
///
/// Characters in ascending order, so the codes are a function of the
/// character set.
fn notdef_cids(face : PdfFace, codepoints : Array[Int]) -> Map[Int, Int] {
  let cids : Map[Int, Int] = Map([])
  guard face.program is Some(program) else { return cids }
  let missing = codepoints.filter(codepoint => !face.metrics.has_char(codepoint))
  missing.sort()
  // the codes the document's own glyphs take (Identity: a code is a glyph)
  let taken : Set[Int] = Set([])
  for codepoint in codepoints {
    match face.metrics.glyph_id(codepoint) {
      Some(glyph) if glyph != 0 => taken.add(glyph)
      _ => ()
    }
  }
  let glyphs = glyph_count(program)
  let first = if glyphs < 1 { 1 } else { glyphs }
  // the `k`th candidate code: `first` up to 0xFFFF, then 1 up to `first`
  let candidate = fn(k : Int) {
    if first + k <= 0xFFFF {
      first + k
    } else {
      k - (0x10000 - first) + 1
    }
  }
  let mut k = 0
  for codepoint in missing {
    if cids.contains(codepoint) {
      continue
    }
    while k < 0xFFFF && taken.contains(candidate(k)) {
      k += 1
    }
    if k >= 0xFFFF {
      break
    }
    cids[codepoint] = candidate(k)
    k += 1
  }
  cids
}

///|
/// Give a composite font's CIDFont a `/CIDToGIDMap` stream: a code of
/// `notdef_cids` is glyph 0, any other code its own glyph (as `/Identity`
/// would have it).
fn add_cid_to_gid_map(
  document : @pdflite.PdfDocument,
  font : Int,
  notdef_cids : Map[Int, Int],
) -> Unit raise {
  let notdef : Set[Int] = Set([])
  let mut last = 0
  for _, cid in notdef_cids {
    notdef.add(cid)
    if cid > last {
      last = cid
    }
  }
  let map = Buffer()
  for cid in 0..<=last {
    let glyph = if notdef.contains(cid) { 0 } else { cid }
    map.write_byte((glyph >> 8).to_byte())
    map.write_byte((glyph & 0xFF).to_byte())
  }
  let bytes = map.contents()
  let stream = document.add_object(
    @pdflite.pdf_encode_stream_with_filter(
      @pdflite.PdfStreamFlate.filter_name(),
      @syntax.pdf_stream(
        PdfDictionary([(name("/Length"), PdfInteger(bytes.length()))]),
        StreamGot(bytes),
      ),
      only_if_smaller=true,
    ),
  )
  let type0 = document.lookup_object_or_null(font)
  guard type0.lookup_immediate(name("/DescendantFonts"))
    is Some(PdfArray(descendants)) &&
    descendants.get(0) is Some(PdfIndirect(cidfont)) else {
    return
  }
  let dictionary = document.lookup_object_or_null(cidfont)
  let updated = if dictionary.lookup_immediate(name("/CIDToGIDMap")) is Some(_) {
    dictionary.replace_dict_entry(name("/CIDToGIDMap"), PdfIndirect(stream))
  } else {
    dictionary.add_dict_entry(name("/CIDToGIDMap"), PdfIndirect(stream))
  }
  document.add_object_given_number(cidfont, updated)
}

///|
/// The signed 16-bit field at byte `at` of `program`'s OS/2 table, when the
/// table has it: a table of at least `version` (the field first appears in
/// that version; ttfunk reads none of a version's fields from an earlier
/// one) that is long enough to hold it, by its declared length as well as
/// by the file's. A version 0 table may end at byte 68, before the
/// typographic metrics, and whatever follows it there belongs to another
/// table.
fn os2_int16(program : Bytes, at : Int, version~ : Int) -> Int? {
  guard @pdflite.pdf_truetype_table(program, "OS/2") is Some(os2) &&
    os2.offset >= 0 &&
    os2.length >= at + 2 &&
    os2.offset + at + 2 <= program.length() else {
    return None
  }
  let u16 = fn(offset : Int) {
    (program[offset].to_int() << 8) | program[offset + 1].to_int()
  }
  guard u16(os2.offset) >= version else { return None }
  let value = u16(os2.offset + at)
  Some(if value >= 0x8000 { value - 0x10000 } else { value })
}

///|
/// The ascent, descent and cap height a font descriptor declares, in
/// thousandths of an em.
///
/// By default: `hhea`'s ascent and descent, and the ascent again for the
/// cap height.
///
/// With `typo_metrics`, as Prawn takes them through ttfunk: the OS/2
/// typographic ascent and descent where the program has them (a version 1
/// or later table, nonzero values), else `hhea`'s; and OS/2 `sCapHeight`
/// where the program has it (a version 2 or later table, a nonzero value),
/// else that ascent. All three are truncated toward zero, as Prawn's
/// `Integer()` does. (Prawn 2.4 declares `sCapHeight` in the font's own
/// units, unscaled; this scales it to thousandths of an em like every other
/// descriptor metric, as PDF 32000-1 Table 122 requires.)
fn descriptor_metrics(face : PdfFace) -> (Double, Double, Double) {
  let metrics = face.metrics
  let scale = 1000.0 / metrics.units_per_em.to_double()
  let mut ascent = metrics.ascender
  let mut descent = metrics.descender
  if !face.typo_metrics {
    let ascent = ascent.to_double() * scale
    return (ascent, descent.to_double() * scale, ascent)
  }
  let mut cap_height = None
  if face.program is Some(program) {
    // sTypoAscender and sTypoDescender
    if os2_int16(program, 68, version=1) is Some(typo_ascent) &&
      typo_ascent != 0 {
      ascent = typo_ascent
    }
    if os2_int16(program, 70, version=1) is Some(typo_descent) &&
      typo_descent != 0 {
      descent = typo_descent
    }
    // sCapHeight
    if os2_int16(program, 88, version=2) is Some(height) && height != 0 {
      cap_height = Some(height)
    }
  }
  // Ruby's Integer(): toward zero
  let truncate = fn(value : Int) {
    let value = value.to_double() * scale
    if value < 0.0 {
      -(-value).floor()
    } else {
      value.floor()
    }
  }
  let ascent = truncate(ascent)
  (
    ascent,
    truncate(descent),
    match cap_height {
      Some(height) => truncate(height)
      None => ascent
    },
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
  let (ascent, descent, capheight) = descriptor_metrics(face)
  {
    ascent,
    descent,
    avgwidth: 0,
    maxwidth: 0,
    // nonsymbolic (bit 6); italic adds bit 7
    flags: if face.spec.italic {
      0x20 | 0x40
    } else {
      0x20
    },
    fontbbox: { min_x: -1000, min_y: -500, max_x: 2000, max_y: 1500, },
    italicangle: if face.spec.italic {
      -12.0
    } else {
      0.0
    },
    capheight,
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
/// The font object for one interned IR font: a simple WinAnsi TrueType
/// font with a descriptor, a `/Widths` array from the same metrics the
/// layout measured with, a `/ToUnicode` map, and a subset of the face's
/// program when it has one.
fn font_object(
  document : @pdflite.PdfDocument,
  face : PdfFace,
  index : Int,
  codepoints : Array[Int],
) -> Int raise {
  // a standard font: declared by name, WinAnsi-encoded, nothing embedded
  // (its metrics are the viewer's own)
  match face.standard {
    Some(standard) =>
      match @pdflite.pdf_standard_font_of_name("/" + standard) {
        Some(font) =>
          return document.write_font(
            PdfFontStandard({ font, encoding: PdfWinAnsiEncoding, }),
          )
        None => ()
      }
    None => ()
  }
  let first = 32
  let last = 255
  let widths : Array[Int] = []
  for code = first; code <= last; code = code + 1 {
    // advance_pt at 1000pt is exactly the 1/1000-em width PDF wants
    widths.push(face.declared_width(winansi_unicode(code)).to_int())
  }
  // A face with a program is embedded so the page renders the shapes it
  // was laid out with. Without one the font is only declared,
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
          postscript_name(program).unwrap_or(
            pdf_name_body(face.spec.family) + style_suffix(face.spec),
          ),
        ),
      )
    None => (None, name(base_font_name(face.spec)))
  }
  let descriptor = font_descriptor(face, fontfile, None)
  let number = document.write_font(
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
  // `/Encoding /WinAnsiEncoding` already names the characters, but only a
  // reader that knows WinAnsi and the standard glyph names can use that;
  // a `/ToUnicode` map states them outright. (pdflite's own simple-font
  // ToUnicode writer numbers codes for its re-encoding embedder and drops
  // `/Encoding`, so the map is added to the written dictionary here.)
  let cmap = document.add_object(
    @pdflite.pdf_encode_stream_with_filter(
      @pdflite.PdfStreamFlate.filter_name(),
      simple_tounicode_stream(codepoints),
      only_if_smaller=true,
    ),
  )
  document.add_object_given_number(
    number,
    document
    .lookup_object_or_null(number)
    .add_dict_entry(name("/ToUnicode"), PdfIndirect(cmap)),
  )
  number
}

///|
/// A ToUnicode CMap for a simple WinAnsi font: every code the document
/// shows in it, mapped to the character that code stands for.
fn simple_tounicode_stream(codepoints : Array[Int]) -> @syntax.PdfObject {
  let codes : Array[Int] = []
  for codepoint in codepoints {
    match winansi_code(codepoint) {
      Some(code) => if !codes.contains(code) { codes.push(code) }
      None => ()
    }
  }
  codes.sort()
  let hex = fn(value : Int, digits : Int) {
    let text = value.to_string(radix=16).to_upper()
    "0".repeat(digits - text.length()) + text
  }
  let sb = StringBuilder()
  sb.write_string(
    "/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n" +
    "/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n" +
    "/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n" +
    "1 begincodespacerange\n<00> <FF>\nendcodespacerange\n",
  )
  // at most 100 entries per bfchar section
  let mut start = 0
  while start < codes.length() {
    let stop = if start + 100 < codes.length() {
      start + 100
    } else {
      codes.length()
    }
    sb.write_string("\{stop - start} beginbfchar\n")
    for i in start..<stop {
      let code = codes[i]
      sb.write_string("<\{hex(code, 2)}> <\{hex(winansi_unicode(code), 4)}>\n")
    }
    sb.write_string("endbfchar\n")
    start = stop
  }
  sb.write_string(
    "endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n",
  )
  let bytes = @utf8.encode(sb.to_string())
  @syntax.pdf_stream(
    PdfDictionary([(name("/Length"), PdfInteger(bytes.length()))]),
    StreamGot(bytes),
  )
}

///|
/// The PostScript name (`name` table, name ID 6) of an sfnt font program,
/// which is what a PDF's `/BaseFont` should carry: `NotoSerif-Bold`,
/// `mplus1mn-regular`. None when the program has no usable one.
fn postscript_name(program : Bytes) -> String? {
  let u16 = fn(offset : Int) -> Int {
    if offset < 0 || offset + 2 > program.length() {
      -1
    } else {
      (program[offset].to_int() << 8) | program[offset + 1].to_int()
    }
  }
  let u32 = fn(offset : Int) -> Int {
    if offset < 0 || offset + 4 > program.length() {
      -1
    } else {
      (u16(offset) << 16) | u16(offset + 2)
    }
  }
  let tables = u16(4)
  let mut table = -1
  for i in 0..<tables {
    let record = 12 + i * 16
    if u32(record) == 0x6E616D65 { // 'name'
      table = u32(record + 8)
      break
    }
  }
  if table < 0 {
    return None
  }
  let count = u16(table + 2)
  let strings = table + u16(table + 4)
  let mut windows : String? = None
  let mut mac : String? = None
  for i in 0..<count {
    let record = table + 6 + i * 12
    if u16(record + 6) != 6 {
      continue
    }
    let platform = u16(record)
    let length = u16(record + 8)
    let offset = strings + u16(record + 10)
    if offset < 0 || length < 0 || offset + length > program.length() {
      continue
    }
    let sb = StringBuilder()
    if platform == 3 && windows is None {
      for j = 0; j + 1 < length; j = j + 2 {
        sb.write_char(u16(offset + j).unsafe_to_char())
      }
      windows = Some(sb.to_string())
    } else if platform == 1 && mac is None {
      for j in 0..<length {
        sb.write_char(program[offset + j].to_int().unsafe_to_char())
      }
      mac = Some(sb.to_string())
    }
  }
  guard (match windows {
      Some(w) => Some(w)
      None => mac
    })
    is Some(raw) else {
    return None
  }
  // a PDF name keeps to printable ASCII without delimiters
  let sb = StringBuilder()
  for c in raw {
    if c > ' ' && c <= '~' && !"()<>[]{}/%#".contains_char(c) {
      sb.write_char(c)
    }
  }
  let cleaned = sb.to_string()
  if cleaned.is_empty() {
    None
  } else {
    Some(cleaned)
  }
}

///|
/// Subset a font program to the characters used and add it as a
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
