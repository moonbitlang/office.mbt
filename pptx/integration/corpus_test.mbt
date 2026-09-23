// Modified for office.mbt: root workspace tooling and fixture paths.
// Tier-1 reader-losslessness on real Office output (ADR-011).
//
// The Tier-2 Open XML SDK validator proves the corpus files are
// schema-valid, but not that *our reader* preserves them. These tests
// close that gap on every backend, without file I/O: a few
// `pptx/fixtures/poi/` files are embedded as generated base64
// sources (`corpus_*_embed_test.mbt`, emitted by
// `scripts/embed_pptx_corpus.py`), and each is driven through
//
//   parse → serialise (via the package-level writers) → re-parse
//
// asserting model equality between the two parses — any field the
// reader silently drops (instead of typing or capturing into
// `extension`, ADR-004) breaks equality here.

// --- base64 decoding of the embedded corpus ---

///|
/// Decode the fixed-width base64 chunks emitted by
/// `scripts/embed_pptx_corpus.py`. `expected_len` is the original byte
/// length recorded at generation time; a mismatch aborts (a truncated
/// or corrupted embed must never masquerade as a parser finding).
fn corpus_bytes(chunks : Array[String], expected_len : Int) -> FixedArray[Byte] {
  let out = FixedArray::make(expected_len, b'\x00')
  let mut acc = 0
  let mut bits = 0
  let mut pos = 0
  for chunk in chunks {
    for c in chunk {
      let v = match c {
        'A'..='Z' => c.to_int() - 'A'.to_int()
        'a'..='z' => c.to_int() - 'a'.to_int() + 26
        '0'..='9' => c.to_int() - '0'.to_int() + 52
        '+' => 62
        '/' => 63
        _ => -1 // '=' padding — carries no data
      }
      if v >= 0 {
        acc = (acc << 6) | v
        bits = bits + 6
        if bits >= 8 {
          bits = bits - 8
          out[pos] = ((acc >> bits) & 0xFF).to_byte()
          pos = pos + 1
        }
      }
    }
  }
  if pos != expected_len {
    abort("corpus embed decoded \{pos} bytes, expected \{expected_len}")
  }
  out
}

// --- shared invariant ---

///|
/// The reader-losslessness invariant for one embedded corpus file:
/// every parser-bearing part parses, is re-serialised through its
/// package-level writer, and re-parses to an equal model after a full
/// package save → reopen. Returns the `parse_everything` counts so
/// callers can assert the file exercised what it was picked for.
fn assert_reader_lossless(
  bytes : FixedArray[Byte],
) -> (Int, Int, Int, Int, Int, Int, Int) raise {
  let pkg_in = @opc.Package::open(bytes)
  let counts = parse_everything(pkg_in)
  let pkg_re = re_serialize_all(@opc.Package::open(bytes))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  for p in parts_of(pkg_in, ct_theme) {
    let re = @theme.Theme::parse(pkg_out.require_part(p.name).bytes())
    debug_inspect(@theme.Theme::parse(p.bytes()) == re, content="true")
  }
  for p in parts_of(pkg_in, ct_slide_master) {
    let re = @slide_master.SlideMaster::parse(
      pkg_out.require_part(p.name).bytes(),
    )
    debug_inspect(
      @slide_master.SlideMaster::parse(p.bytes()) == re,
      content="true",
    )
  }
  for p in parts_of(pkg_in, ct_slide_layout) {
    let re = @slide_master.SlideLayout::parse(
      pkg_out.require_part(p.name).bytes(),
    )
    debug_inspect(
      @slide_master.SlideLayout::parse(p.bytes()) == re,
      content="true",
    )
  }
  for p in parts_of(pkg_in, ct_slide) {
    let re = @slide.Slide::parse(pkg_out.require_part(p.name).bytes())
    debug_inspect(@slide.Slide::parse(p.bytes()) == re, content="true")
  }
  for p in parts_of(pkg_in, ct_notes_slide) {
    let re = @notes.NotesSlide::parse(pkg_out.require_part(p.name).bytes())
    debug_inspect(@notes.NotesSlide::parse(p.bytes()) == re, content="true")
  }
  for p in parts_of(pkg_in, ct_comment_authors) {
    let re = @comments.CommentAuthorList::parse(
      pkg_out.require_part(p.name).bytes(),
    )
    debug_inspect(
      @comments.CommentAuthorList::parse(p.bytes()) == re,
      content="true",
    )
  }
  for p in parts_of(pkg_in, ct_comments) {
    let re = @comments.CommentList::parse(pkg_out.require_part(p.name).bytes())
    debug_inspect(@comments.CommentList::parse(p.bytes()) == re, content="true")
  }
  counts
}

// --- testPPT.pptx: baseline theme + master + layouts + 3 slides ---

///|
test "corpus testPPT: parse → serialise → re-parse is lossless" {
  let (themes, masters, layouts, slides, _, _, _) = assert_reader_lossless(
    corpus_testppt(),
  )
  debug_inspect(themes, content="1")
  debug_inspect(masters, content="1")
  debug_inspect(layouts, content="11")
  debug_inspect(slides, content="3")
}

///|
test "corpus testPPT: real slide text survives the round-trip" {
  let pkg = @opc.Package::open(corpus_testppt())
  let slide = @slide.Slide::parse(
    pkg.require_part("/ppt/slides/slide1.xml").bytes(),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  let mut text = ""
  for s in reparsed.shapes {
    match s {
      AutoShape(sp) =>
        match sp.text_body {
          Some(tb) => text = text + tb.plain_text()
          None => ()
        }
      _ => ()
    }
  }
  debug_inspect(text.contains("Attachment Test"), content="true")
}

// --- table_test.pptx: a real Office table ---

///|
test "corpus table_test: parse → serialise → re-parse is lossless" {
  let (_, _, _, slides, _, _, _) = assert_reader_lossless(corpus_table_test())
  debug_inspect(slides, content="1")
}

///|
test "corpus table_test: the table lifts to the typed model" {
  let pkg = @opc.Package::open(corpus_table_test())
  let slide = @slide.Slide::parse(
    pkg.require_part("/ppt/slides/slide1.xml").bytes(),
  )
  let mut cols = 0
  let mut rows = 0
  for s in slide.shapes {
    match s {
      GraphicFrame(gf) =>
        match gf.content {
          TableContent(t) => {
            cols = t.grid.length()
            rows = t.rows.length()
          }
          _ => ()
        }
      _ => ()
    }
  }
  debug_inspect(cols, content="3")
  debug_inspect(rows, content="6")
}

// --- with_japanese.pptx: CJK + astral-plane (surrogate pair) text ---

///|
test "corpus with_japanese: parse → serialise → re-parse is lossless" {
  let (_, _, _, slides, _, _, _) = assert_reader_lossless(
    corpus_with_japanese(),
  )
  debug_inspect(slides, content="1")
}

///|
test "corpus with_japanese: CJK and surrogate-pair text survive UTF round-trips" {
  let pkg = @opc.Package::open(corpus_with_japanese())
  let slide = @slide.Slide::parse(
    pkg.require_part("/ppt/slides/slide1.xml").bytes(),
  )
  let reparsed = @slide.Slide::parse(slide.serialize())
  let mut text = ""
  fn collect(shapes : Array[@slide.Shape]) {
    for s in shapes {
      match s {
        AutoShape(sp) =>
          match sp.text_body {
            Some(tb) => text = text + tb.plain_text()
            None => ()
          }
        Group(g) => collect(g.children)
        _ => ()
      }
    }
  }

  collect(reparsed.shapes)
  // Real Japanese content (CJK, BMP)…
  debug_inspect(
    text.contains("ゾルゲと尾崎、淡々と最期"),
    content="true",
  )
  // …and Gothic script (U+10330 block — UTF-16 surrogate pairs), the
  // hardest case for the UTF-8 ↔ UTF-16 boundary in the XML layer.
  debug_inspect(text.contains("𐌲𐌿𐍄𐌹𐍃𐌺"), content="true")
}

///|
test "corpus with_japanese: the theme names the font CJK actually renders in" {
  // The file's runs carry `<a:latin typeface="+mn-lt"/>`-style theme
  // references and an empty `<a:ea typeface=""/>`, so neither the run nor the
  // `ea` slot names the face Japanese text uses — only the `script="Jpan"`
  // entry does. This is the case G2 exists for, checked against a real file.
  let pkg = @opc.Package::open(corpus_with_japanese())
  let theme = @theme.Theme::parse(
    pkg.require_part("/ppt/theme/theme1.xml").bytes(),
  )
  let scheme = theme.font_scheme
  debug_inspect(scheme.minor_font.ea, content="\"\"")
  debug_inspect(
    scheme.minor_font.typeface_for_script("Jpan"),
    content="\"ＭＳ Ｐゴシック\"",
  )
  debug_inspect(
    scheme.minor_font.typeface_for_script("Hans"),
    content="\"宋体\"",
  )
  // A run following the theme resolves through it rather than yielding "+mn-lt".
  let themed = @slide.RunProperties::default().with_font("+mn-lt")
  debug_inspect(
    @slide.resolve_run_fonts(themed, scheme).latin,
    content="\"Calibri\"",
  )
  debug_inspect(
    @slide.resolve_run_font_for_script(themed, scheme, "Jpan"),
    content="\"ＭＳ Ｐゴシック\"",
  )
}

///|
test "corpus testPPT: app.xml merge preserves the vt subtrees" {
  let prs = @presentation.Presentation::open(corpus_testppt())
  // The real Office part carries statistics and vt: vectors we must
  // not disturb when editing the typed fields.
  debug_inspect(
    prs.app_properties().company.unwrap(),
    content="\"Pegasystems\"",
  )
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_company("moon-pptx tests"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(
    reopened.app_properties().company.unwrap(),
    content="\"moon-pptx tests\"",
  )
  let xml = @oxml.bytes_to_string(
    @opc.Package::open(prs.save()).require_part("/docProps/app.xml").bytes(),
  )
  // Office's statistics and both vt: vectors are still intact.
  debug_inspect(xml.contains("<TotalTime>1</TotalTime>"), content="true")
  debug_inspect(
    xml.contains("<vt:lpstr>Attachment Test</vt:lpstr>"),
    content="true",
  )
  debug_inspect(
    xml.contains("<vt:vector size=\"4\" baseType=\"variant\">"),
    content="true",
  )
  debug_inspect(
    xml.contains("<AppVersion>12.0000</AppVersion>"),
    content="true",
  )
  debug_inspect(!xml.contains("Pegasystems"), content="true")
}
