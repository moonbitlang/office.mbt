///|
/// A one-page Carlito model showing `text`, one point of advance per code
/// unit.
fn text_model(text : String) -> @pagelayout.PageModel {
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
        text,
        advances_pt: Array::make(text.length(), 5.0),
        color: @pagelayout.black,
      }),
    ],
  })
  model
}

///|
/// The document with every stream decoded, as searchable text.
fn decompressed(bytes : Bytes) -> String raise {
  as_text(
    @pdflite.pdf_write_document(
      @pdflite.pdf_decompress_pdf(@pdflite.pdf_read_document_from_bytes(bytes)),
    ),
  )
}

///|
test "named destinations are in lexical byte order, not length order" {
  let model = text_model("x")
  for anchor in ["b", "ab", "a_long_name", "aa", "a", "B"] {
    model.pages[0].items.push(Anchor({ name: anchor, x_pt: 0, y_pt: 0, }))
  }
  let document = @pdflite.pdf_read_document_from_bytes(@pdf.render_pdf(model))
  guard document.lookup_chain(document.catalog(), [
      @core.pdf_name_of_bytes(b"/Names"),
      @core.pdf_name_of_bytes(b"/Dests"),
    ])
    is Some(tree) else {
    fail("no /Dests name tree")
  }
  let keys = @pdflite.pdf_read_name_tree(document, tree).map(entry => {
    let sb = StringBuilder()
    for byte in entry.0 {
      sb.write_char(byte.to_int().unsafe_to_char())
    }
    sb.to_string()
  })
  // Bytes::compare would give B, a, b, aa, ab, a_long_name
  inspect(keys.join(","), content="B,a,a_long_name,aa,ab,b")
}

///|
test "simple fonts carry a ToUnicode map beside their WinAnsi encoding" {
  let text = decompressed(@pdf.render_pdf(text_model("Hi’")))
  assert_true(text.contains("/TrueType"))
  assert_true(text.contains("/WinAnsiEncoding"))
  assert_true(text.contains("/ToUnicode"))
  // ’ is WinAnsi 0x92 and must map back to U+2019, not to U+0092
  assert_true(text.contains("<92> <2019>"))
  assert_true(text.contains("<48> <0048>"))
  assert_true(text.contains("3 beginbfchar"))
}

///|
test "outline entries keep their open or closed state" {
  let model = text_model("x")
  model.pages[0].items.push(Anchor({ name: "a", x_pt: 0, y_pt: 0, }))
  let entries : Array[@pdf.OutlineEntry] = [
    { title: "Open", level: 0, dest: Named("a"), open: true, },
    { title: "Child 1", level: 1, dest: Named("a"), open: false, },
    { title: "Child 2", level: 1, dest: Named("a"), open: false, },
    { title: "Closed", level: 0, dest: Named("a"), open: false, },
    { title: "Hidden", level: 1, dest: Named("a"), open: false, },
  ]
  let document = @pdflite.pdf_read_document_from_bytes(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(outline=entries)),
  )
  let marks = @pdflite.pdf_read_bookmarks(document)
  inspect(
    marks.map(mark => "\{mark.level}:\{mark.is_open}").join(" "),
    content="0:true 1:false 1:false 0:false 1:false",
  )
  let text = decompressed(
    @pdf.render_pdf(model, options=@pdf.RenderOptions::new(outline=entries)),
  )
  // the open parent counts its two visible children; the closed one hides
  // its only child
  assert_true(text.contains("/Count 2"))
  assert_true(text.contains("/Count -1"))
}

///|
test "the outline root counts its visible entries even when none is open" {
  let model = text_model("x")
  model.pages[0].items.push(Anchor({ name: "a", x_pt: 0, y_pt: 0, }))
  let document = @pdflite.pdf_read_document_from_bytes(
    @pdf.render_pdf(
      model,
      options=@pdf.RenderOptions::new(outline=[
        { title: "Only", level: 0, dest: Named("a"), open: false, },
        { title: "Also", level: 0, dest: Named("a"), open: false, },
        { title: "Hidden", level: 1, dest: Named("a"), open: false, },
      ]),
    ),
  )
  guard document.lookup_chain(document.catalog(), [
      @core.pdf_name_of_bytes(b"/Outlines"),
      @core.pdf_name_of_bytes(b"/Count"),
    ])
    is Some(PdfInteger(count)) else {
    fail("no /Count on the outline root")
  }
  inspect(count, content="2")
}

///|
test "pdf dates are written with an explicit zone offset" {
  inspect(@pdf.pdf_date(0L), content="D:19700101000000+00'00'")
  inspect(
    @pdf.pdf_date(1790665948L, offset_seconds=8 * 3600),
    content="D:20260929151228+08'00'",
  )
  inspect(
    @pdf.pdf_date(1790665948L, offset_seconds=-(5 * 3600 + 30 * 60)),
    content="D:20260929014228-05'30'",
  )
}

///|
test "information entries, open action, page mode, boxes and labels" {
  let model = text_model("x")
  model.pages.push({ width_pt: 300, height_pt: 150, items: [], })
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(
      info=@pdf.DocumentInfo::new(
        creator="Jane Doe",
        subject="",
        creation_date=@pdf.pdf_date(0L),
        mod_date=@pdf.pdf_date(0L),
      ),
      initial_zoom=FitH,
      page_mode=UseOutlines,
      display_doc_title=true,
      page_boxes=true,
      page_labels=["i", "1"],
    ),
  )
  let text = decompressed(bytes)
  assert_true(text.contains("/Creator (Jane Doe)"))
  // an empty text string is the bare byte order mark, not `()`
  assert_false(text.contains("/Subject ()"))
  assert_true(text.contains("/Subject (\\376\\377)"))
  assert_true(text.contains("/CreationDate (D:19700101000000+00'00')"))
  assert_true(text.contains("/ModDate (D:19700101000000+00'00')"))
  assert_true(text.contains("/PageMode /UseOutlines"))
  assert_true(text.contains("/DisplayDocTitle true"))
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  // the open action shows the first page at its full height
  guard document.catalog().lookup_immediate(name("/OpenAction"))
    is Some(PdfArray([PdfIndirect(page), PdfNameObject(fit), top])) else {
    fail("no [page /FitH top] open action")
  }
  inspect(page == document.page_reference_numbers()[0], content="true")
  inspect(name_text(fit), content="/FitH")
  inspect(number(top), content="100")
  // every box equals the media box of its own page
  let pages = document.pages_of_pagetree()
  let boxes = pages.map(page => {
    let media = page.mediabox
    let same = ["/CropBox", "/BleedBox", "/TrimBox", "/ArtBox"].map(key => {
      page.rest.lookup_immediate(name(key)) is Some(box) &&
      box_text(box) == box_text(media)
    })
    "\{box_text(media)} \{same.iter().all(x => x)}"
  })
  inspect(boxes.join("; "), content="0 0 200 100 true; 0 0 300 150 true")
  // one literal label per page, starting at that page
  let labels = @pdflite.pdf_read_page_labels(document).map(label => {
    let prefix = label.label_prefix.map(decoded).unwrap_or("-")
    "\{label.start_page}:\{prefix}:\{label.label_style.debug_name()}"
  })
  inspect(
    labels.join(" "),
    content="1:i:NoLabelPrefixOnly 2:1:NoLabelPrefixOnly",
  )
}

///|
/// A PDF name from its text, slash included.
fn name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@utf8.encode(text))
}

///|
/// A name's text, slash included.
fn name_text(n : @core.PdfName) -> String {
  as_text(n.bytes())
}

///|
/// A PDF number as text.
fn number(object : @syntax.PdfObject) -> String {
  match object {
    PdfInteger(i) => i.to_string()
    PdfReal(r) => r.to_string()
    _ => "?"
  }
}

///|
/// A box array as `x0 y0 x1 y1`.
fn box_text(object : @syntax.PdfObject) -> String {
  match object {
    PdfArray(items) => items.map(number).join(" ")
    _ => "?"
  }
}

///|
/// A PDF text string decoded (PDFDocEncoding or UTF-16BE).
fn decoded(bytes : Bytes) -> String raise {
  @utf8.decode(@pdflite.pdf_utf8_of_pdfdocstring(bytes))
}

///|
/// A one-page model with `n` pages.
fn pages_model(n : Int) -> @pagelayout.PageModel {
  let model = text_model("x")
  for _ in 1..<n {
    model.pages.push({ width_pt: 200, height_pt: 100, items: [], })
  }
  model
}

///|
test "each initial zoom is its own destination" {
  let open_action = fn(zoom : @pdf.InitialZoom) raise {
    let document = @pdflite.pdf_read_document_from_bytes(
      @pdf.render_pdf(
        text_model("x"),
        options=@pdf.RenderOptions::new(initial_zoom=zoom),
      ),
    )
    guard document.catalog().lookup_immediate(name("/OpenAction"))
      is Some(PdfArray([_, PdfNameObject(fit), .. rest])) else {
      fail("no open action")
    }
    [name_text(fit), ..rest.map(number)].join(" ")
  }
  inspect(open_action(Fit), content="/Fit")
  inspect(open_action(FitH), content="/FitH 100")
  inspect(open_action(FitV), content="/FitV 0")
}

///|
test "every page mode is written as its name" {
  let modes : Array[(@pdf.PageMode, String)] = [
    (UseNone, "/UseNone"),
    (UseOutlines, "/UseOutlines"),
    (UseThumbs, "/UseThumbs"),
    (FullScreen, "/FullScreen"),
    (UseOC, "/UseOC"),
    (UseAttachments, "/UseAttachments"),
  ]
  for entry in modes {
    let document = @pdflite.pdf_read_document_from_bytes(
      @pdf.render_pdf(
        text_model("x"),
        options=@pdf.RenderOptions::new(page_mode=entry.0),
      ),
    )
    guard document.catalog().lookup_immediate(name("/PageMode"))
      is Some(PdfNameObject(mode)) else {
      fail("no page mode")
    }
    assert_eq(name_text(mode), entry.1)
  }
}

///|
test "page labels must name every page or none" {
  let render = fn(labels : Array[String]) {
    try {
      ignore(
        @pdf.render_pdf(
          pages_model(3),
          options=@pdf.RenderOptions::new(page_labels=labels),
        ),
      )
      "ok"
    } catch {
      e => e.to_string()
    }
  }
  inspect(render([]), content="ok")
  inspect(render(["a", "b", "c"]), content="ok")
  inspect(
    render(["a", "b"]),
    content="invalid PDF render options: 2 page labels for 3 pages",
  )
  inspect(
    render(["a", "b", "c", "d"]),
    content="invalid PDF render options: 4 page labels for 3 pages",
  )
}

///|
test "text strings round-trip through Unicode and PDFDocEncoding" {
  // ASCII, Latin-1, a control that PDFDocEncoding redefines (U+0018 is
  // breve there), DEL, tab and newline, an astral character, and CJK
  let samples = [
    "plain", "café", "a\u{18}b", "del\u{7F}", "tab\tnew\nline", "𝄞 clef", "中文",
  ]
  let model = pages_model(samples.length())
  let document = @pdflite.pdf_read_document_from_bytes(
    @pdf.render_pdf(
      model,
      options=@pdf.RenderOptions::new(
        page_labels=samples,
        outline=samples.mapi((i, s) => {
          title: s,
          level: 0,
          dest: Position(page=i, x=0, y=0),
          open: false,
        }),
        info=@pdf.DocumentInfo::new(title=samples.join("|"), custom=[
          ("Motto", "Ünïcödé"),
        ]),
      ),
    ),
  )
  let labels = @pdflite.pdf_read_page_labels(document).map(label => {
    decoded(label.label_prefix.unwrap())
  })
  assert_eq(labels, samples)
  let titles = @pdflite.pdf_read_bookmarks(document).map(mark => {
    decoded(mark.text)
  })
  assert_eq(titles, samples)
  guard document.lookup_chain(document.trailer_dict(), [
      name("/Info"),
      name("/Title"),
    ])
    is Some(PdfString(title)) else {
    fail("no title")
  }
  assert_eq(decoded(title), samples.join("|"))
  guard document.lookup_chain(document.trailer_dict(), [
      name("/Info"),
      name("/Motto"),
    ])
    is Some(PdfString(motto)) else {
    fail("no custom entry")
  }
  assert_eq(decoded(motto), "Ünïcödé")
}

///|
test "trapped is a name and dates are checked" {
  let render = fn(info : @pdf.DocumentInfo) {
    try {
      let bytes = @pdf.render_pdf(
        text_model("x"),
        options=@pdf.RenderOptions::new(info~),
      )
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      match
        document.lookup_chain(document.trailer_dict(), [
          name("/Info"),
          name("/Trapped"),
        ]) {
        Some(PdfNameObject(value)) => "name " + name_text(value)
        Some(_) => "not a name"
        None => "absent"
      }
    } catch {
      e => e.to_string()
    }
  }
  inspect(render(@pdf.DocumentInfo::new(trapped=Yes)), content="name /True")
  inspect(render(@pdf.DocumentInfo::new(trapped=No)), content="name /False")
  inspect(
    render(@pdf.DocumentInfo::new(trapped=Unknown)),
    content="name /Unknown",
  )
  inspect(render(@pdf.DocumentInfo::new(title="t")), content="absent")
  // a standard key cannot sneak in as a custom string
  inspect(
    render(@pdf.DocumentInfo::new(custom=[("Trapped", "False")])),
    content="invalid PDF render options: info key Trapped is a standard entry; set DocumentInfo's field instead",
  )
  inspect(
    render(@pdf.DocumentInfo::new(custom=[("", "x")])),
    content="invalid PDF render options: info entry with an empty key",
  )
  // dates: any prefix of the full form, with or without a zone
  for
    date in [
      "D:2026", "D:20260929", "D:20260929151228", "D:20260929151228Z", "D:20260929151228+08'00'",
      "D:20260929151228-05'30", "D:20260929151228+08",
    ] {
    assert_eq(render(@pdf.DocumentInfo::new(creation_date=date)), "absent")
  }
  inspect(
    render(@pdf.DocumentInfo::new(mod_date="2026-09-29")),
    content="invalid PDF render options: info ModDate is not a PDF date (D:YYYYMMDDHHmmSS+HH'mm'): 2026-09-29",
  )
  for
    date in [
      "D:26", "D:2026092", "D:20260929+", "D:20260929151228+8", "D:2026x",
    ] {
    assert_true(
      render(@pdf.DocumentInfo::new(creation_date=date)).has_prefix("invalid"),
    )
  }
}

///|
test "outline entries resolve named, positioned and missing destinations" {
  let model = pages_model(2)
  model.pages[1].items.push(Anchor({ name: "there", x_pt: 5, y_pt: 20, }))
  let document = @pdflite.pdf_read_document_from_bytes(
    @pdf.render_pdf(
      model,
      options=@pdf.RenderOptions::new(outline=[
        { title: "named", level: 0, dest: Named("there"), open: false, },
        {
          title: "positioned",
          level: 0,
          dest: Position(page=1, x=10, y=30),
          open: false,
        },
        { title: "no anchor", level: 0, dest: Named("nowhere"), open: false, },
        {
          title: "no page",
          level: 0,
          dest: Position(page=7, x=0, y=0),
          open: false,
        },
      ]),
    ),
  )
  let second = document.page_reference_numbers()[1]
  let marks = @pdflite.pdf_read_bookmarks(document).map(mark => {
    let target = match mark.target {
      DestString(n) => "named " + as_text(n)
      DestXYZ(TargetPageObject(p), Some(x), Some(y), None) =>
        "p\{if p == second { 2 } else { 0 }} \{x} \{y}"
      DestNull => "none"
      _ => "other"
    }
    "\{decoded(mark.text)}: \{target}"
  })
  inspect(
    marks.join("; "),
    content="named: p2 5 80; positioned: p2 10 70; no anchor: none; no page: none",
  )
}

///|
test "without the options, the catalog stays as before" {
  let text = decompressed(@pdf.render_pdf(text_model("x")))
  assert_false(text.contains("/OpenAction"))
  assert_false(text.contains("/PageLabels"))
  assert_false(text.contains("/CropBox"))
  assert_false(text.contains("/PageMode"))
}
