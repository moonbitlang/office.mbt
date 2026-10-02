///|
test "empty document has one empty A4 page" {
  let bytes = @export.Document::new_with(plain_settings()).finish()
  let p = parse(bytes)
  inspect(p.doc.major, content="1")
  inspect(p.doc.minor, content="7")
  let pages = p.pages()
  inspect(pages.length(), content="1")
  inspect(
    p.show(pages[0]),
    content="<</Type /Page /Resources <<>> /MediaBox [0 0 595 842] /Parent R /Contents R>>",
  )
  inspect(p.show(p.catalog()), content="<</Type /Catalog /Pages R>>")
  inspect(
    p.show(p.path(p.catalog(), ["Pages"])),
    content="<</Type /Pages /Count 1 /Kids [R]>>",
  )
  inspect(p.content(pages[0]), content="")
  // The trailer has a file identifier (document ID and instance ID).
  debug_inspect(
    p.keys(p.trailer()),
    content=(
      #|["Size", "Root", "ID"]
    ),
  )
}

///|
test "the PDF version is written in the header" {
  let versions : Array[@export.PdfVersion] = [Pdf14, Pdf15, Pdf16, Pdf17, Pdf20]
  let headers = versions.map(v => {
    let bytes = @export.Document::new_with(settings_with(version=v)).finish()
    latin1(bytes[0:8])
  })
  inspect(
    headers.join(" "),
    content="%PDF-1.4 %PDF-1.5 %PDF-1.6 %PDF-1.7 %PDF-2.0",
  )
  inspect(
    versions.map(v => v.as_str()).join(", "),
    content="PDF 1.4, PDF 1.5, PDF 1.6, PDF 1.7, PDF 2.0",
  )
  debug_inspect(
    versions.map(v => v.deprecates_cid_set()),
    content=(
      #|[false, false, false, false, true]
    ),
  )
}

///|
test "pages keep their order, size, trim box and annotations-free resources" {
  let doc = @export.Document::new_with(plain_settings())
  let sizes = [(100.0, 200.0), (612.0, 792.0), (50.5, 20.25)]
  for i, wh in sizes {
    let mut settings = @export.PageSettings::from_wh(wh.0, wh.1).unwrap()
    if i == 1 {
      settings = settings.with_trim_box(
        @export.Rect::from_ltrb(10.0, 20.0, 602.0, 772.0).unwrap(),
      )
    }
    let page = doc.start_page_with(settings)
    inspect(page.index(), content="\{i}")
    page.surface().finish()
    page.finish()
  }
  let p = parse(doc.finish())
  let pages = p.pages()
  inspect(p.show(p.path(p.catalog(), ["Pages", "Count"])), content="3")
  inspect(
    pages.map(page => p.show(p.get(page, "MediaBox"))).join(" "),
    content=(
      #|[0 0 100 200] [0 0 612 792] [0 0 50.5 20.25]
    ),
  )
  // The trim box is flipped into PDF coordinates (origin at the bottom).
  inspect(p.show(p.get(pages[1], "TrimBox")), content="[10 20 602 772]")
  inspect(p.has(pages[0], "TrimBox"), content="false")
}

///|
test "page settings without a media box use the content bounding box" {
  let doc = @export.Document::new_with(plain_settings())
  let page = doc.start_page_with({
    ..@export.PageSettings::from_wh(100.0, 100.0).unwrap(),
    media_box: None,
  })
  let surface = page.surface()
  surface.draw_path(rect_path(10.0, 20.0, 30.0, 40.0))
  surface.finish()
  page.finish()
  let p = parse(doc.finish())
  // The bbox (10, 20)-(40, 60) in surface coordinates, flipped.
  inspect(p.show(p.get(p.page(0), "MediaBox")), content="[10 40 40 80]")
}

///|
test "page labels are written as a number tree" {
  let doc = @export.Document::new_with(plain_settings())
  let labels = [
    @export.PageLabel::new(Some(LowerRoman), None, Some(1)),
    // Like krilla, a label only continues the previous range if its offset
    // is one less than the previous offset, so equal labels on consecutive
    // pages start new ranges (redundant, but equivalent).
    @export.PageLabel::new(Some(LowerRoman), None, Some(1)),
    @export.PageLabel::new(Some(Arabic), Some("A-"), Some(1)),
    @export.PageLabel::default(),
  ]
  for label in labels {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(10.0, 10.0).unwrap().with_page_label(label),
    )
    page.surface().finish()
    page.finish()
  }
  let p = parse(doc.finish())
  let nums = p.items(p.path(p.catalog(), ["PageLabels", "Nums"]))
  inspect(
    nums.map(n => p.show(n)).join("\n"),
    content=(
      #|0
      #|<</Type /PageLabel /S /r /St 1>>
      #|1
      #|<</Type /PageLabel /S /r /St 1>>
      #|2
      #|<</Type /PageLabel /S /D /P (A-) /St 1>>
      #|3
      #|<</Type /PageLabel>>
    ),
  )
  // pdflite's reader understands the labels.
  let read = @pdflite.pdf_read_page_labels(p.doc)
  inspect(
    read.length(),
    content=(
      #|4
    ),
  )
}

///|
test "page label ranges merge on a decreasing offset (krilla quirk)" {
  // krilla compares the previous offset with the next offset plus one, so a
  // page whose offset is one *less* than the previous one is folded into the
  // previous range. This mirrors krilla; viewers then number the second page
  // 3 instead of 1.
  let doc = @export.Document::new_with(plain_settings())
  for offset in [2, 1] {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(10.0, 10.0)
      .unwrap()
      .with_page_label(@export.PageLabel::new(Some(Arabic), None, Some(offset))),
    )
    page.surface().finish()
    page.finish()
  }
  let p = parse(doc.finish())
  let nums = p.items(p.path(p.catalog(), ["PageLabels", "Nums"]))
  inspect(
    nums.map(n => p.show(n)).join(" "),
    content=(
      #|0 <</Type /PageLabel /S /D /St 2>>
    ),
  )
}

///|
test "no page labels without labelled pages" {
  let doc = @export.Document::new_with(plain_settings())
  for _ in 0..<2 {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(10.0, 10.0).unwrap(),
    )
    page.surface().finish()
    page.finish()
  }
  let p = parse(doc.finish())
  inspect(p.has(p.catalog(), "PageLabels"), content="false")
}

///|
test "metadata is written to the document information dictionary" {
  let doc = @export.Document::new_with(plain_settings())
  doc.set_metadata(
    @export.Metadata::new()
    .title("Report")
    .description("A summary")
    .keywords(["pdf", "test"])
    .authors(["Ann", "Bob"])
    .creator("typst")
    .producer("pdflite")
    .language("en-US")
    .creation_date(
      @export.DateTime::new(2024)
      .month(3)
      .day(5)
      .hour(14)
      .minute(7)
      .second(9)
      .utc_offset_hour(-5)
      .utc_offset_minute(30),
    ),
  )
  let p = parse(doc.finish())
  inspect(
    p.show_deep(p.get(p.trailer(), "Info")),
    content="<</Title (Report) /Subject (A summary) /Keywords (pdf, test) /Author (Ann, Bob) /Creator (typst) /Producer (pdflite) /ModDate (D:20240305140709-05'30) /CreationDate (D:20240305140709-05'30)>>",
  )
  inspect(p.show(p.get(p.catalog(), "Lang")), content="(en-US)")
}

///|
test "metadata setters ignore empty values and clamp dates" {
  let m = @export.Metadata::new().title("").creator("").keywords([]).authors([])
  inspect(
    (m.title, m.creator, m.keywords, m.authors) is (None, None, None, None),
    content="true",
  )
  debug_inspect(
    @export.DateTime::new(12345)
    .month(13)
    .day(0)
    .hour(24)
    .minute(-1)
    .second(60)
    .utc_offset_hour(30),
    content=(
      #|{
      #|  year: 9999,
      #|  month: Some(12),
      #|  day: Some(1),
      #|  hour: Some(23),
      #|  minute: Some(0),
      #|  second: Some(59),
      #|  utc_offset_hour: Some(23),
      #|  utc_offset_minute: 0,
      #|}
    ),
  )
  // Partial dates are completed with defaults and UTC.
  let doc = @export.Document::new_with(plain_settings())
  doc.set_metadata(
    @export.Metadata::new().title("T").creation_date(@export.DateTime::new(99)),
  )
  let p = parse(doc.finish())
  inspect(
    p.show(p.path(p.trailer(), ["Info", "CreationDate"])),
    content="(D:00990101000000Z)",
  )
}

///|
test "non-ASCII metadata is written as UTF-16 text strings" {
  let doc = @export.Document::new_with(plain_settings())
  doc.set_metadata(@export.Metadata::new().title("Café ✓"))
  let p = parse(doc.finish())
  inspect(
    p.show(p.path(p.trailer(), ["Info", "Title"])),
    content=(
      #|<FEFF00430061006600E900202713>
    ),
  )
}

///|
test "PDF 2.0 keeps only dates in the information dictionary" {
  let doc = @export.Document::new_with(settings_with(version=Pdf20))
  doc.set_metadata(
    @export.Metadata::new()
    .title("Report")
    .creation_date(@export.DateTime::new(2020).month(1).day(2)),
  )
  let p = parse(doc.finish())
  inspect(
    p.show_deep(p.get(p.trailer(), "Info")),
    content="<</ModDate (D:20200102000000Z) /CreationDate (D:20200102000000Z)>>",
  )
}

///|
test "text direction and display doc title go to the viewer preferences" {
  let doc = @export.Document::new_with(plain_settings())
  doc.set_metadata(@export.Metadata::new().text_direction(RightToLeft))
  let p = parse(doc.finish())
  inspect(
    p.show(p.get(p.catalog(), "ViewerPreferences")),
    content="<</Direction /R2L>>",
  )
}

///|
test "XMP metadata stream" {
  let doc = @export.Document::new_with({
    ..plain_settings(),
    xmp_metadata: true,
  })
  doc.set_metadata(
    @export.Metadata::new()
    .title("A <b> & c")
    .authors(["Ann"])
    .language("de")
    .creation_date(
      @export.DateTime::new(2024).month(3).day(5).utc_offset_hour(2),
    ),
  )
  let p = parse(doc.finish())
  let meta = p.get(p.catalog(), "Metadata")
  inspect(
    p.show(p.resolve(meta)),
    content=(
      #|stream<</Type /Metadata /Subtype /XML /Length 1185>>
    ),
  )
  let xmp = @utf8.decode(p.stream_data(meta))
  let checks = [
    "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">A &lt;b&gt; &amp; c</rdf:li></rdf:Alt></dc:title>",
    "<dc:creator><rdf:Seq><rdf:li>Ann</rdf:li></rdf:Seq></dc:creator>", "<dc:language><rdf:Bag><rdf:li>de</rdf:li></rdf:Bag></dc:language>",
    "<xmp:CreateDate>2024-03-05T00:00:00+02:00</xmp:CreateDate>", "<xmpTPg:NPages>1</xmpTPg:NPages>",
    "<pdf:PDFVersion>1.7</pdf:PDFVersion>",
  ]
  debug_inspect(
    checks.map(c => contains(xmp, c)),
    content=(
      #|[true, true, true, true, true, true]
    ),
  )
  inspect(xmp.has_prefix("<?xpacket begin=\"\u{FEFF}\""), content="true")
}

///|
test "the document ID is derived from the metadata" {
  let make = (id : String?, pages : Int) => {
    let doc = @export.Document::new_with(plain_settings())
    let mut m = @export.Metadata::new().title("T")
    if id is Some(id) {
      m = m.document_id(id)
    }
    doc.set_metadata(m)
    for _ in 0..<pages {
      let page = doc.start_page_with(
        @export.PageSettings::from_wh(10.0, 10.0).unwrap(),
      )
      page.surface().finish()
      page.finish()
    }
    let p = parse(doc.finish())
    let ids = p.items(p.get(p.trailer(), "ID")).map(i => p.show(i))
    (ids[0], ids[1])
  }
  let (doc_a, inst_a) = make(Some("id"), 1)
  let (doc_b, inst_b) = make(Some("id"), 2)
  let (doc_c, inst_c) = make(None, 1)
  // Same document ID, but different instances.
  inspect(doc_a == doc_b, content="true")
  inspect(inst_a == inst_b, content="false")
  // Without a document ID (or title and authors), both are the instance ID.
  inspect(doc_c == inst_c, content="true")
  inspect(doc_a.length(), content="18")
}

///|
test "content streams are compressed by default" {
  let settings = { ..plain_settings(), compress_content_streams: true, }
  let bytes = one_page(
    s => s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0)),
    settings~,
  )
  let p = parse(bytes)
  let contents = p.resolve(p.get(p.page(0), "Contents"))
  inspect(
    p.show(contents),
    content=(
      #|stream<</Filter /FlateDecode /Length 48>>
    ),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "embedded files" {
  let doc = @export.Document::new_with(plain_settings())
  let file = @export.EmbeddedFile::{
    path: "data.txt",
    mime_type: Some("text/plain"),
    description: Some("Some data"),
    association_kind: Data,
    data: b"hello world",
    compress: Some(false),
    location: None,
    modification_date: Some(@export.DateTime::new(2021).month(6)),
  }
  inspect(doc.embed_file(file) is Some(_), content="true")
  // A second file with the same path is rejected.
  inspect(doc.embed_file(file) is None, content="true")
  inspect(
    doc.embed_file({ ..file, path: "a.bin", mime_type: None, compress: None, })
    is Some(_),
    content="true",
  )
  let p = parse(doc.finish())
  let names = p.items(p.path(p.catalog(), ["Names", "EmbeddedFiles", "Names"]))
  // Sorted by path.
  inspect(p.show(names[0]), content="(a.bin)")
  inspect(p.show(names[2]), content="(data.txt)")
  inspect(
    p.show_deep(names[3]),
    content=(
      #|<</Type /Filespec /F (data.txt) /UF (data.txt) /EF <</F stream<</Type /EmbeddedFile /Subtype /text/plain /Params <</Size 11 /ModDate (D:20210601000000Z)>> /Length 11>> /UF stream<</Type /EmbeddedFile /Subtype /text/plain /Params <</Size 11 /ModDate (D:20210601000000Z)>> /Length 11>>>> /Desc (Some data)>>
    ),
  )
  let stream = p.path(names[3], ["EF", "F"])
  inspect(
    p.show(stream),
    content=(
      #|stream<</Type /EmbeddedFile /Subtype /text/plain /Params <</Size 11 /ModDate (D:20210601000000Z)>> /Length 11>>
    ),
  )
  inspect(latin1(p.stream_data(stream)), content="hello world")
  inspect(
    p.show(p.path(names[1], ["EF", "F"])),
    content=(
      #|stream<</Type /EmbeddedFile /Params <</Size 11 /ModDate (D:20210601000000Z)>> /Filter /FlateDecode /Length 19>>
    ),
  )
  // No associated files outside PDF 2.0 and PDF/A-3.
  inspect(p.has(p.catalog(), "AF"), content="false")
}

///|
test "PDF/A-3 embedded files are associated files" {
  let doc = @export.Document::new_with(settings_with(a=Some(A3_B)))
  doc.set_metadata(
    @export.Metadata::new().creation_date(@export.DateTime::new(2024)),
  )
  doc.embed_file({
    path: "source.csv",
    mime_type: Some("text/csv"),
    description: Some("Source data"),
    association_kind: Source,
    data: b"a,b",
    compress: None,
    location: None,
    modification_date: Some(@export.DateTime::new(2024)),
  })
  |> ignore
  let p = parse(doc.finish())
  let af = p.items(p.get(p.catalog(), "AF"))
  inspect(af.length(), content="1")
  inspect(p.show(p.get(af[0], "AFRelationship")), content="/Source")
  // Validators force XMP metadata.
  let xmp = latin1(p.stream_data(p.get(p.catalog(), "Metadata")))
  inspect(
    contains(
      xmp, "<pdfaid:part>3</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance>",
    ),
    content="true",
  )
}

///|
test "embedded file validation" {
  let file = @export.EmbeddedFile::{
    path: "x",
    mime_type: None,
    description: None,
    association_kind: Unspecified,
    data: b"x",
    compress: None,
    location: Some(7UL),
    modification_date: None,
  }
  let run = (a : @export.Archival) => {
    export_result(fn() {
      let doc = @export.Document::new_with(settings_with(a=Some(a)))
      doc.set_metadata(
        @export.Metadata::new().creation_date(@export.DateTime::new(2024)),
      )
      doc.embed_file(file) |> ignore
      doc.finish()
    })
  }
  inspect(
    run(A2_B),
    content=(
      #|Validation: EmbeddedFile(Existence) by PDF/A-2b
    ),
  )
  inspect(
    run(A3_B),
    content=(
      #|Validation: EmbeddedFile(MissingDate) by PDF/A-3b; EmbeddedFile(MissingDescription) by PDF/A-3b; EmbeddedFile(MissingMimeType) by PDF/A-3b
    ),
  )
  inspect(
    run(A4F),
    content=(
      #|ok
    ),
  )
}
