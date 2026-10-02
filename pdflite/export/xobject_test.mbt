///|
/// An external XObject drawing a 10x10 square; `calls` counts how often it
/// is written.
fn square_xobject(key : String, calls : Ref[Int]) -> @export.ExternalXObject {
  {
    key,
    bbox: @export.Rect::from_xywh(0.0, 0.0, 10.0, 10.0).unwrap(),
    write: (root, new_ref, put) => {
      calls.val += 1
      let resources = new_ref()
      put(resources, Plain(Dict([("ProcSet", Arr([Name("PDF")]))])))
      put(
        root,
        Stream(
          [
            ("Type", Name("XObject")),
            ("Subtype", Name("Form")),
            ("BBox", Arr([Int(0), Int(0), Int(10), Int(10)])),
            // A small coefficient survives (pdf-writer writes f32s with
            // their shortest digits).
            (
              "Matrix",
              Arr([Int(1), Real(0.000001), Int(0), Int(1), Int(0), Int(0)]),
            ),
            ("Resources", Ref(resources)),
            // A stale length (e.g. copied from the source file) is replaced.
            ("Length", Int(999)),
          ],
          b"0 0 10 10 re f",
        ),
      )
    },
  }
}

///|
test "external XObjects are written once per key and drawn by reference" {
  let calls = Ref(0)
  let other_calls = Ref(0)
  let doc = @export.Document::new_with(plain_settings())
  for i in 0..<2 {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
    )
    let s = page.surface()
    s.push_transform(@export.Transform::from_translate(5.0, 5.0))
    s.draw_external_xobject(square_xobject("a", calls))
    s.pop()
    s.draw_external_xobject(square_xobject("a", calls))
    if i == 1 {
      s.draw_external_xobject(square_xobject("b", other_calls))
    }
    // The page tree is the parent of all pages.
    inspect(s.page_tree_ref() > 0, content="true")
    s.finish()
    page.finish()
  }
  let p = parse(doc.finish())
  debug_inspect(
    (calls.val, other_calls.val),
    content=(
      #|(1, 1)
    ),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 5 95 cm
      #|/x0 Do
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/x0 Do
      #|Q
      #|
    ),
  )
  let x0 = p.path(p.page(0), ["Resources", "XObject", "x0"])
  inspect(
    p.show(x0),
    content=(
      #|stream<</Type /XObject /Subtype /Form /BBox [0 0 10 10] /Matrix [1 0.000001 0 1 0 0] /Resources R /Length 14>>
    ),
  )
  inspect(latin1(p.stream_data(x0)), content="0 0 10 10 re f")
  inspect(
    p.show_deep(p.get(x0, "Resources")),
    content=(
      #|<</ProcSet [/PDF]>>
    ),
  )
  // Both pages refer to the same object.
  let raw = (page : @syntax.PdfObject) => {
    guard p.path(page, ["Resources", "XObject"]) is PdfDictionary(entries) else {
      fail("no XObjects")
    }
    entries.map(e => e.1)
  }
  inspect(raw(p.page(0))[0] == raw(p.page(1))[0], content="true")
  inspect(raw(p.page(1)).length(), content="2")
  // The page tree reference handed out is the real one.
  let doc2 = @export.Document::new_with(plain_settings())
  let page = doc2.start_page_with(
    @export.PageSettings::from_wh(10.0, 10.0).unwrap(),
  )
  let s = page.surface()
  let tree_ref = s.page_tree_ref()
  s.finish()
  page.finish()
  let p2 = parse(doc2.finish())
  guard p2.catalog() is PdfDictionary(entries) else { fail("no catalog") }
  inspect(entries.iter().any(e => e.1 == PdfIndirect(tree_ref)), content="true")
}

///|
test "external XObjects are embedded PDFs for the validators" {
  inspect(
    export_result(() => {
      one_page(
        s => s.draw_external_xobject(square_xobject("a", Ref(0))),
        settings=settings_with(a=Some(A2_B)),
      )
    }),
    content=(
      #|Validation: EmbeddedPDF by PDF/A-2b
    ),
  )
}
