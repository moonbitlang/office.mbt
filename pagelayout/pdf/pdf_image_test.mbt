///|
/// A two-page PDF to draw as an image: page 1 is 300 x 200 with a red
/// square, page 2 is 400 x 100 with a blue band.
fn pdf_image_source() -> Bytes raise {
  let model = @pagelayout.PageModel::new()
  model.pages.push({
    width_pt: 300,
    height_pt: 200,
    items: [
      Rect({
        x_pt: 10,
        y_pt: 10,
        w_pt: 50,
        h_pt: 50,
        fill: Some(@pagelayout.Color::rgb(255, 0, 0)),
        stroke: None,
        stroke_w_pt: 0,
      }),
    ],
  })
  model.pages.push({
    width_pt: 400,
    height_pt: 100,
    items: [
      Rect({
        x_pt: 0,
        y_pt: 40,
        w_pt: 400,
        h_pt: 20,
        fill: Some(@pagelayout.Color::rgb(0, 0, 255)),
        stroke: None,
        stroke_w_pt: 0,
      }),
    ],
  })
  @pdf.render_pdf(model)
}

///|
/// A one-page model, 500 x 100, holding `items`.
fn pdf_image_model(
  items : Array[@pagelayout.PageItem],
) -> @pagelayout.PageModel {
  let model = @pagelayout.PageModel::new()
  model.pages.push({ width_pt: 500, height_pt: 100, items, })
  model
}

///|
fn pdf_image_item(
  data : Bytes,
  mime : String,
  x_pt? : Double = 10,
  y_pt? : Double = 20,
  w_pt? : Double = 200,
  h_pt? : Double = 50,
) -> @pagelayout.PageItem {
  Image({ x_pt, y_pt, w_pt, h_pt, data, mime, })
}

///|
/// The Form XObjects the first page's resources name.
fn pdf_image_forms(bytes : Bytes) -> Array[@syntax.PdfObject] raise {
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let page = document.pages_of_pagetree()[0]
  let xobject_key = @core.pdf_name_of_bytes(b"/XObject")
  guard document.lookup_direct(xobject_key, page.resources)
    is Some(PdfDictionary(entries)) else {
    return []
  }
  entries.map(entry => document.direct(entry.1))
}

///|
test "a PDF page drawn as an image becomes a Form XObject scaled into its box" {
  let source = pdf_image_source()
  let bytes = @pdf.render_pdf(
    pdf_image_model([pdf_image_item(source, "application/pdf; page=2")]),
  )
  // page 2 is 400 x 100: the 200 x 50 box at (10, 20) halves it, and its
  // bottom edge is 100 - 20 - 50 = 30 up from the page's
  let content = as_decoded_text(bytes)
  assert_true(content.contains("0.5 0 0 0.5 10 30 cm"))
  let forms = pdf_image_forms(bytes)
  assert_eq(forms.length(), 1)
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let form = forms[0]
  assert_true(
    document.lookup_direct(@core.pdf_name_of_bytes(b"/Subtype"), form)
    is Some(PdfNameObject(subtype)) &&
    subtype == @core.pdf_name_of_bytes(b"/Form"),
  )
  // the imported page's own drawing: the blue band
  let drawn = as_text(@pdflite.pdf_decode_stream(form).stream_bytes())
  assert_true(drawn.contains("0 0 1 rg"))
  assert_true(drawn.contains("re"))
}

///|
test "a PDF image without a page parameter draws the first page" {
  let source = pdf_image_source()
  let bytes = @pdf.render_pdf(
    pdf_image_model([pdf_image_item(source, "application/pdf", w_pt=150)]),
  )
  // page 1 is 300 x 200: half its width, a quarter of its height
  assert_true(as_decoded_text(bytes).contains("0.5 0 0 0.25 10 30 cm"))
  let drawn = as_text(
    @pdflite.pdf_decode_stream(pdf_image_forms(bytes)[0]).stream_bytes(),
  )
  assert_true(drawn.contains("1 0 0 rg"))
}

///|
test "each page of a PDF image is imported once" {
  let source = pdf_image_source()
  let bytes = @pdf.render_pdf(
    pdf_image_model([
      pdf_image_item(source, "application/pdf; page=1"),
      pdf_image_item(source, "application/pdf; page=2"),
      pdf_image_item(source, "Application/PDF ; Page=\"2\"", y_pt=0),
      pdf_image_item(source, "application/pdf; page=2", y_pt=0),
    ]),
  )
  // pages 1 and 2, and page 2 again under a media type spelled
  // differently (the cache is keyed by bytes and type)
  assert_eq(pdf_image_forms(bytes).length(), 3)
}

///|
test "PDF images that cannot be drawn are skipped and reported" {
  let source = pdf_image_source()
  let items = [
    pdf_image_item(source, "application/pdf; page=3"),
    pdf_image_item(source, "application/pdf; page=0"),
    pdf_image_item(source, "application/pdf; page=two"),
    pdf_image_item(b"%PDF-1.7 not really", "application/pdf"),
    pdf_image_item(source, "application/pdf; page=1"),
  ]
  let model = pdf_image_model(items)
  let bytes = @pdf.render_pdf(model)
  // only the drawable one is in the document
  assert_eq(pdf_image_forms(bytes).length(), 1)
  assert_eq(@pdflite.pdf_read_document_from_bytes(bytes).endpage(), 1)
  assert_eq(@pdf.unembeddable_images(model), [
    ("PDF without the page to draw", 3),
    ("PDF this backend cannot read", 1),
  ])
}

///|
test "a PDF page whose crop box lies outside its media box is not drawn" {
  // no xref table: the reader reconstructs it
  let source = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /CropBox [300 300 400 400] >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"
  let model = pdf_image_model([pdf_image_item(source, "application/pdf")])
  assert_eq(pdf_image_forms(@pdf.render_pdf(model)).length(), 0)
  assert_eq(@pdf.unembeddable_images(model), [
    ("PDF page this backend cannot import", 1),
  ])
}

///|
/// A PDF file with a valid classic xref table whose page tree never ends:
/// the root holds its `/Kids` array by reference, and that array holds a
/// direct node listing the same array.
fn pdf_image_self_listing_source() -> Bytes {
  let objects = [
    "<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids 3 0 R /Count 1 >>",
    "[<< /Type /Pages /Kids 3 0 R /Count 1 >>]",
  ]
  let text = StringBuilder()
  text.write_string("%PDF-1.4\n")
  let offsets = []
  for i, body in objects {
    offsets.push(text.to_string().length())
    text.write_string("\{i + 1} 0 obj\n\{body}\nendobj\n")
  }
  let xref = text.to_string().length()
  text.write_string("xref\n0 \{objects.length() + 1}\n0000000000 65535 f \n")
  for offset in offsets {
    let digits = offset.to_string()
    text.write_string("0".repeat(10 - digits.length()) + digits + " 00000 n \n")
  }
  text.write_string(
    "trailer\n<< /Size \{objects.length() + 1} /Root 1 0 R >>\nstartxref\n\{xref}\n%%EOF\n",
  )
  @utf8.encode(text.to_string())
}

///|
test "a PDF image whose page tree never ends is skipped and reported" {
  let model = pdf_image_model([
    pdf_image_item(pdf_image_self_listing_source(), "application/pdf"),
  ])
  let bytes = @pdf.render_pdf(model)
  assert_eq(pdf_image_forms(bytes).length(), 0)
  assert_eq(@pdflite.pdf_read_document_from_bytes(bytes).endpage(), 1)
  assert_eq(@pdf.unembeddable_images(model), [
    ("PDF this backend cannot read", 1),
  ])
}
