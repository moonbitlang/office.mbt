///|
fn import_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn import_lookup_for_test(
  doc : @pdflite.PdfDocument,
  object : @syntax.PdfObject,
  key : String,
) -> @syntax.PdfObject? {
  doc.lookup_direct(import_name_for_test(key), object)
}

///|
fn import_numbers_for_test(
  doc : @pdflite.PdfDocument,
  object : @syntax.PdfObject,
) -> Array[Double] raise @core.PdfError {
  match doc.direct(object) {
    PdfArray(items) => items.map(item => doc.get_number(item))
    _ => raise RectangleExpected
  }
}

///|
/// A two-page source document, written and read back so that its objects
/// are numbered and its streams are read lazily: page 1 is a plain letter
/// page; page 2 has a crop box, `/Rotate 90`, a font and an image
/// resource, a transparency group and a Flate-compressed content stream.
fn import_source_for_test() -> @pdflite.PdfDocument raise @core.PdfError {
  let doc = @pdflite.pdf_document_empty()
  let font = doc.add_object(
    PdfDictionary([
      (
        import_name_for_test("/Type"),
        PdfNameObject(import_name_for_test("/Font")),
      ),
      (
        import_name_for_test("/Subtype"),
        PdfNameObject(import_name_for_test("/Type1")),
      ),
      (
        import_name_for_test("/BaseFont"),
        PdfNameObject(import_name_for_test("/Helvetica")),
      ),
    ]),
  )
  let pixel = b"\xff\x00\x00"
  let image = doc.add_object(
    @syntax.pdf_stream(
      PdfDictionary([
        (
          import_name_for_test("/Type"),
          PdfNameObject(import_name_for_test("/XObject")),
        ),
        (
          import_name_for_test("/Subtype"),
          PdfNameObject(import_name_for_test("/Image")),
        ),
        (import_name_for_test("/Width"), PdfInteger(1)),
        (import_name_for_test("/Height"), PdfInteger(1)),
        (
          import_name_for_test("/ColorSpace"),
          PdfNameObject(import_name_for_test("/DeviceRGB")),
        ),
        (import_name_for_test("/BitsPerComponent"), PdfInteger(8)),
        (import_name_for_test("/Length"), PdfInteger(pixel.length())),
      ]),
      StreamGot(pixel),
    ),
  )
  let content = @pdflite.pdf_encode_stream_with_encoding(
    PdfStreamFlate,
    @pdflite.pdf_content_stream_of_ops([
      Op_q,
      Op_cm({ a: 10.0, b: 0.0, c: 0.0, d: 10.0, e: 20.0, f: 20.0, }),
      Op_Do(import_name_for_test("/Im1")),
      Op_Q,
      Op_BT,
      Op_Tf(import_name_for_test("/F1"), 12.0),
      Op_Tj(b"Imported"),
      Op_ET,
    ]),
  )
  let first = {
    ..import_blank_page_for_test(),
    content: [
      @pdflite.pdf_content_stream_of_ops([Op_re(0.0, 0.0, 10.0, 10.0), Op_f]),
    ],
  }
  let second = @page.PdfPage::{
    content: [PdfIndirect(doc.add_object(content))],
    mediabox: PdfArray([
      PdfInteger(0),
      PdfInteger(0),
      PdfInteger(200),
      PdfInteger(100),
    ]),
    resources: PdfDictionary([
      (
        import_name_for_test("/Font"),
        PdfDictionary([(import_name_for_test("/F1"), PdfIndirect(font))]),
      ),
      (
        import_name_for_test("/XObject"),
        PdfDictionary([(import_name_for_test("/Im1"), PdfIndirect(image))]),
      ),
    ]),
    rotate: Rotate90,
    rest: PdfDictionary([
      (
        import_name_for_test("/CropBox"),
        PdfArray([
          PdfInteger(10),
          PdfInteger(10),
          PdfInteger(110),
          PdfInteger(60),
        ]),
      ),
      (
        import_name_for_test("/Group"),
        PdfDictionary([
          (
            import_name_for_test("/S"),
            PdfNameObject(import_name_for_test("/Transparency")),
          ),
        ]),
      ),
    ]),
  }
  let root = doc.add_pagetree([first, second])
  ignore(doc.add_root(root, []))
  @pdflite.pdf_read_document_from_bytes(@pdflite.pdf_write_document(doc))
}

///|
/// A one-page document drawing `imported` under `/P1` at (`x`, `y`),
/// written and read back.
fn import_target_for_test(
  target : @pdflite.PdfDocument,
  imported : @pdflite.PdfImportedPage,
) -> @pdflite.PdfDocument raise @core.PdfError {
  let page = {
    ..import_blank_page_for_test(),
    resources: PdfDictionary([
      (
        import_name_for_test("/XObject"),
        PdfDictionary([
          (import_name_for_test("/P1"), PdfIndirect(imported.object)),
        ]),
      ),
    ]),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_q,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 72.0, f: 72.0, }),
        Op_Do(import_name_for_test("/P1")),
        Op_Q,
      ]),
    ],
  }
  let root = target.add_pagetree([page])
  ignore(target.add_root(root, []))
  @pdflite.pdf_read_document_from_bytes(@pdflite.pdf_write_document(target))
}

///|
/// The Form XObject `/P1` of the first page of `doc`.
fn import_form_for_test(
  doc : @pdflite.PdfDocument,
) -> @syntax.PdfObject raise @core.PdfError {
  let page = doc.pages_of_pagetree()[0]
  guard import_lookup_for_test(doc, page.resources, "/XObject")
    is Some(xobjects) else {
    raise DictionaryExpected
  }
  guard import_lookup_for_test(doc, xobjects, "/P1") is Some(form) else {
    raise DictionaryExpected
  }
  form
}

///|
test "import_page turns a rotated, cropped page into an upright Form XObject" {
  let source = import_source_for_test()
  assert_eq(source.page_display_size(1), (612.0, 792.0))
  // the crop box is 100 x 50; /Rotate 90 shows it 50 wide, 100 high
  assert_eq(source.page_display_size(2), (50.0, 100.0))
  let source_objects = source.object_numbers().length()
  let target = @pdflite.pdf_document_empty()
  let imported = target.import_page(source, 2)
  assert_eq(imported.width, 50.0)
  assert_eq(imported.height, 100.0)
  // the source is left as it was
  assert_eq(source.object_numbers().length(), source_objects)
  let written = import_target_for_test(target, imported)
  let form = import_form_for_test(written)
  assert_true(
    import_lookup_for_test(written, form, "/Subtype")
    is Some(PdfNameObject(subtype)) &&
    subtype == import_name_for_test("/Form"),
  )
  assert_eq(
    import_numbers_for_test(
      written,
      import_lookup_for_test(written, form, "/BBox").unwrap(),
    ),
    [10.0, 10.0, 110.0, 60.0],
  )
  // rotated clockwise, the crop box's lower-left corner at the origin
  assert_eq(
    import_numbers_for_test(
      written,
      import_lookup_for_test(written, form, "/Matrix").unwrap(),
    ),
    [0.0, -1.0, 1.0, 0.0, -10.0, 110.0],
  )
  // the content stream keeps its filter, and decodes to the page's content
  assert_true(
    import_lookup_for_test(written, form, "/Filter")
    is Some(PdfNameObject(filter)) &&
    filter == import_name_for_test("/FlateDecode"),
  )
  let decoded = @pdflite.pdf_decode_stream(written.direct(form)).stream_bytes()
  let expected = @pdflite.pdf_decode_stream(
    source.direct(source.pages_of_pagetree()[1].content[0]),
  )
  assert_eq(decoded, expected.stream_bytes())
  // the transparency group comes along
  assert_true(import_lookup_for_test(written, form, "/Group") is Some(_))
  // the resources, copied: the font and the image with its pixel data
  let resources = import_lookup_for_test(written, form, "/Resources").unwrap()
  let fonts = import_lookup_for_test(written, resources, "/Font").unwrap()
  let font = import_lookup_for_test(written, fonts, "/F1").unwrap()
  assert_true(
    import_lookup_for_test(written, font, "/BaseFont")
    is Some(PdfNameObject(base)) &&
    base == import_name_for_test("/Helvetica"),
  )
  let images = import_lookup_for_test(written, resources, "/XObject").unwrap()
  let image = written.direct(
    import_lookup_for_test(written, images, "/Im1").unwrap(),
  )
  assert_eq(image.stream_bytes(), b"\xff\x00\x00")
}

///|
test "import_page follows each rotation" {
  for
    case in [
      (@page.Rotate0, (100.0, 50.0), [1.0, 0.0, 0.0, 1.0, -10.0, -10.0]),
      (Rotate180, (100.0, 50.0), [-1.0, 0.0, 0.0, -1.0, 110.0, 60.0]),
      (Rotate270, (50.0, 100.0), [0.0, 1.0, -1.0, 0.0, 60.0, -10.0]),
    ] {
    let (rotate, size, matrix) = case
    let source = @pdflite.pdf_document_empty()
    let page = {
      ..import_blank_page_for_test(),
      mediabox: PdfArray([
        PdfInteger(0),
        PdfInteger(0),
        PdfInteger(200),
        PdfInteger(100),
      ]),
      rotate,
      rest: PdfDictionary([
        (
          import_name_for_test("/CropBox"),
          PdfArray([
            PdfInteger(10),
            PdfInteger(10),
            PdfInteger(110),
            PdfInteger(60),
          ]),
        ),
      ]),
    }
    let root = source.add_pagetree([page])
    ignore(source.add_root(root, []))
    let target = @pdflite.pdf_document_empty()
    let imported = target.import_page(source, 1)
    assert_eq((imported.width, imported.height), size)
    let written = import_target_for_test(target, imported)
    let form = import_form_for_test(written)
    assert_eq(
      import_numbers_for_test(
        written,
        import_lookup_for_test(written, form, "/Matrix").unwrap(),
      ),
      matrix,
    )
  }
}

///|
test "import_page joins several content streams into one" {
  let source = @pdflite.pdf_document_empty()
  let page = {
    ..import_blank_page_for_test(),
    content: [
      @pdflite.pdf_content_stream_of_ops([Op_q]),
      @pdflite.pdf_encode_stream_with_encoding(
        PdfStreamFlate,
        @pdflite.pdf_content_stream_of_ops([Op_re(0.0, 0.0, 5.0, 5.0), Op_f]),
      ),
      @pdflite.pdf_content_stream_of_ops([Op_Q]),
    ],
  }
  let root = source.add_pagetree([page])
  ignore(source.add_root(root, []))
  let target = @pdflite.pdf_document_empty()
  let imported = target.import_page(source, 1)
  let written = import_target_for_test(target, imported)
  let form = import_form_for_test(written)
  let ops = written.parse_content_ops_with_resources(PdfDictionary([]), [
    written.direct(form),
  ])
  assert_eq(ops, [Op_q, Op_re(0.0, 0.0, 5.0, 5.0), Op_f, Op_Q])
}

///|
test "import_page does not follow references back into the page tree" {
  let source = @pdflite.pdf_document_empty()
  // a resource that points at its own page (as marked-content properties
  // can), which must not drag the source's page tree along
  let props = source.add_object(PdfDictionary([]))
  let page = {
    ..import_blank_page_for_test(),
    resources: PdfDictionary([
      (
        import_name_for_test("/Properties"),
        PdfDictionary([(import_name_for_test("/MC0"), PdfIndirect(props))]),
      ),
    ]),
  }
  let root = source.add_pagetree([page])
  ignore(source.add_root(root, []))
  let page_object = source
    .object_numbers()
    .filter(n => {
      import_lookup_for_test(source, source.lookup_object_or_null(n), "/Type")
      is Some(PdfNameObject(t)) &&
      t == import_name_for_test("/Page")
    })[0]
  source.add_object_given_number(
    props,
    PdfDictionary([(import_name_for_test("/Pg"), PdfIndirect(page_object))]),
  )
  let target = @pdflite.pdf_document_empty()
  let imported = target.import_page(source, 1)
  // the form and the properties dictionary, nothing else
  assert_eq(target.object_numbers().length(), 2)
  let form = target.lookup_object_or_null(imported.object)
  let resources = import_lookup_for_test(target, form, "/Resources").unwrap()
  let properties = import_lookup_for_test(target, resources, "/Properties").unwrap()
  let mc0 = import_lookup_for_test(target, properties, "/MC0").unwrap()
  assert_true(import_lookup_for_test(target, mc0, "/Pg") is None)
}

///|
test "import_page reports a missing page" {
  let source = import_source_for_test()
  let target = @pdflite.pdf_document_empty()
  for page_number in [0, 3, -1] {
    let result = import_error_for_test(() => {
      target.import_page(source, page_number)
    })
    assert_true(result is Some(BadPageSpecification(_)))
    assert_true(
      import_error_for_test(() => source.page_display_size(page_number))
      is Some(BadPageSpecification(_)),
    )
  }
  // nothing was copied
  assert_eq(target.object_numbers().length(), 0)
}

///|
test "import_page reports a document without pages" {
  let source = @pdflite.pdf_document_empty()
  let root = source.add_pagetree([])
  ignore(source.add_root(root, []))
  let source = @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document(source),
  )
  assert_eq(source.endpage(), 0)
  let target = @pdflite.pdf_document_empty()
  assert_true(
    import_error_for_test(() => target.import_page(source, 1))
    is Some(BadPageSpecification(_)),
  )
}

///|
test "import_page rejects malformed and empty page boxes" {
  for
    mediabox in [
      @syntax.PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(100)]),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0), PdfInteger(100)]),
      PdfArray([
        PdfInteger(0),
        PdfInteger(0),
        PdfNameObject(import_name_for_test("/Wide")),
        PdfInteger(100),
      ]),
      PdfString(b"letter"),
    ] {
    let source = @pdflite.pdf_document_empty()
    let page = { ..import_blank_page_for_test(), mediabox, }
    let root = source.add_pagetree([page])
    ignore(source.add_root(root, []))
    let target = @pdflite.pdf_document_empty()
    let result = import_error_for_test(() => target.import_page(source, 1))
    assert_true(
      result is Some(RectangleExpected | BadRectangle | NumberExpected),
    )
  }
}

///|
test "import_page falls back to the media box for a crop box outside it" {
  let source = @pdflite.pdf_document_empty()
  let page = {
    ..import_blank_page_for_test(),
    rest: PdfDictionary([
      (
        import_name_for_test("/CropBox"),
        PdfArray([
          PdfInteger(1000),
          PdfInteger(1000),
          PdfInteger(1100),
          PdfInteger(1100),
        ]),
      ),
    ]),
  }
  let root = source.add_pagetree([page])
  ignore(source.add_root(root, []))
  assert_eq(source.page_display_size(1), (612.0, 792.0))
}

///|
test "import_page refuses an encrypted document" {
  let source = import_source_for_test()
  source.set_trailer_dict(
    source
    .trailer_dict()
    .add_dict_entry(import_name_for_test("/Encrypt"), PdfDictionary([])),
  )
  let target = @pdflite.pdf_document_empty()
  assert_true(
    import_error_for_test(() => target.import_page(source, 1))
    is Some(HardError(_)),
  )
}

///|
test "import_page imports a page whose contents are not streams as blank" {
  let source = @pdflite.pdf_document_empty()
  let page = { ..import_blank_page_for_test(), content: [PdfInteger(7)], }
  let root = source.add_pagetree([page])
  ignore(source.add_root(root, []))
  let target = @pdflite.pdf_document_empty()
  // the page tree reader drops contents that are not streams, so this
  // page is blank rather than an error
  let imported = target.import_page(source, 1)
  let form = target.lookup_object_or_null(imported.object)
  assert_eq(form.stream_bytes(), b"")
}

///|
test "import_page survives garbage after a valid header" {
  let garbage = b"%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 x y] /Contents 4 0 R >> endobj\n4 0 obj << /Length 999 >> stream\nq Q"
  let source = @pdflite.pdf_read_document_from_bytes(garbage) catch {
    _ => return
  }
  // whatever the reader recovered, the box is not a rectangle
  let target = @pdflite.pdf_document_empty()
  assert_true(
    import_error_for_test(() => target.import_page(source, 1)) is Some(_),
  )
}

///|
/// The error `body` raises, or None when it returns.
fn[T] import_error_for_test(
  body : () -> T raise @core.PdfError,
) -> @core.PdfError? {
  try body() catch {
    error => Some(error)
  } noraise {
    _ => None
  }
}

///|
/// A blank US Letter page.
fn import_blank_page_for_test() -> @page.PdfPage {
  {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    mediabox: PdfArray([
      PdfInteger(0),
      PdfInteger(0),
      PdfInteger(612),
      PdfInteger(792),
    ]),
  }
}

///|
test "import_page on truncated documents raises or imports, never aborts" {
  let source = import_source_for_test()
  let bytes = @pdflite.pdf_write_document(source)
  for cut in [16, bytes.length() / 4, bytes.length() / 2, bytes.length() - 40] {
    let truncated = bytes[:cut].to_owned()
    let source = @pdflite.pdf_read_document_from_bytes(truncated) catch {
      _ => continue
    }
    for page_number in [1, 2] {
      let target = @pdflite.pdf_document_empty()
      ignore(
        import_error_for_test(() => target.import_page(source, page_number)),
      )
    }
  }
}
