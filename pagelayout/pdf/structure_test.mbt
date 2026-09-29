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
    { title: "Open", level: 0, anchor: "a", dest: None, open: true, },
    { title: "Child 1", level: 1, anchor: "a", dest: None, open: false, },
    { title: "Child 2", level: 1, anchor: "a", dest: None, open: false, },
    { title: "Closed", level: 0, anchor: "a", dest: None, open: false, },
    { title: "Hidden", level: 1, anchor: "a", dest: None, open: false, },
  ]
  let document = @pdflite.pdf_read_document_from_bytes(
    @pdf.render_pdf(model, outline=entries),
  )
  let marks = @pdflite.pdf_read_bookmarks(document)
  inspect(
    marks.map(mark => "\{mark.level}:\{mark.is_open}").join(" "),
    content="0:true 1:false 1:false 0:false 1:false",
  )
  let text = decompressed(@pdf.render_pdf(model, outline=entries))
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
    @pdf.render_pdf(model, outline=[
      { title: "Only", level: 0, anchor: "a", dest: None, open: false, },
      { title: "Also", level: 0, anchor: "a", dest: None, open: false, },
      { title: "Hidden", level: 1, anchor: "a", dest: None, open: false, },
    ]),
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
  model.pages.push({ width_pt: 200, height_pt: 100, items: [], })
  let bytes = @pdf.render_pdf(
    model,
    info=[
      ("Creator", "Jane Doe"),
      ("Subject", ""),
      ("CreationDate", @pdf.pdf_date(0L)),
      ("ModDate", @pdf.pdf_date(0L)),
    ],
    initial_zoom=FitH,
    page_mode="UseOutlines",
    display_doc_title=true,
    page_boxes=true,
    page_labels=["1", "2"],
  )
  let text = decompressed(bytes)
  assert_true(text.contains("(Jane Doe)"))
  // an empty text string is the bare byte order mark, not `()`
  assert_false(text.contains("/Subject ()"))
  assert_true(text.contains("/Subject (\\376\\377)"))
  assert_true(text.contains("/CreationDate (D:19700101000000+00'00')"))
  assert_true(text.contains("/ModDate"))
  assert_true(text.contains("/OpenAction"))
  assert_true(text.contains("/FitH 100"))
  assert_true(text.contains("/PageMode /UseOutlines"))
  assert_true(text.contains("/DisplayDocTitle true"))
  for key in ["/CropBox", "/BleedBox", "/TrimBox", "/ArtBox"] {
    assert_true(text.contains(key))
  }
  assert_true(text.contains("/PageLabels"))
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let labels = @pdflite.pdf_read_page_labels(document)
  inspect(labels.length(), content="2")
}

///|
test "without the options, the catalog stays as before" {
  let text = decompressed(@pdf.render_pdf(text_model("x")))
  assert_false(text.contains("/OpenAction"))
  assert_false(text.contains("/PageLabels"))
  assert_false(text.contains("/CropBox"))
  assert_false(text.contains("/PageMode"))
}
