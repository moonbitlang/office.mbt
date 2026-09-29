///|
/// A one-page model (100pt tall) whose only items are link regions to
/// `targets`, each 10×12pt, one after another along y = 10.
fn links_model(targets : Array[String]) -> @pagelayout.PageModel {
  let model = run_model([5.0, 5.0])
  model.pages[0].items.push(Anchor({ name: "target", x_pt: 0, y_pt: 10, }))
  for i, target in targets {
    model.pages[0].items.push(
      Link({
        x_pt: 10.0 + 20.0 * i.to_double(),
        y_pt: 10,
        w_pt: 10,
        h_pt: 12,
        target,
      }),
    )
  }
  model
}

///|
/// Every annotation of the first page, each described as its object kind
/// (indirect or not), subtype, rectangle, border and target.
fn annotations(bytes : Bytes) -> Array[String] raise {
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let page = document.pages_of_pagetree()[0]
  guard page.rest.lookup_immediate(name("/Annots")) is Some(PdfArray(annots)) else {
    return []
  }
  annots.map(annot => {
    let kind = if annot is PdfIndirect(_) { "indirect" } else { "direct" }
    let dict = document.direct(annot)
    let get = fn(key : String) {
      document.lookup_direct(name(key), dict).unwrap_or(PdfNull)
    }
    guard get("/Type") is PdfNameObject(type_) &&
      get("/Subtype") is PdfNameObject(subtype) else {
      return "\{kind} ?"
    }
    let target = match (get("/Dest"), get("/A")) {
      (PdfString(dest), _) => "dest " + as_text(dest)
      (_, PdfDictionary(_) as action) =>
        match
          (
            document.lookup_direct(name("/S"), action),
            document.lookup_direct(name("/URI"), action),
          ) {
          (Some(PdfNameObject(s)), Some(PdfString(uri))) =>
            "\{name_text(s)} \{as_text(uri)}"
          _ => "action ?"
        }
      _ => "?"
    }
    "\{kind} \{name_text(type_)}\{name_text(subtype)} [\{box_text(get("/Rect"))}] [\{box_text(get("/Border"))}] \{target}"
  })
}

///|
test "links become indirect annotations with exact geometry" {
  let model = links_model(["#target", "https://example.org"])
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(
      outline=[
        { title: "Target", level: 0, dest: Named("target"), open: false, },
      ],
      info=@pdf.DocumentInfo::new(title="Links"),
    ),
  )
  // the IR box (y 10 down, 12 tall) is y-flipped on the 100pt page
  inspect(
    annotations(bytes).join("\n"),
    content=(
      #|indirect /Annot/Link [10 78 20 90] [0 0 0] dest target
      #|indirect /Annot/Link [30 78 40 90] [0 0 0] /URI https://example.org
    ),
  )
  let text = decompressed(bytes)
  assert_true(text.contains("/Dests"))
  assert_true(text.contains("/Outlines"))
  assert_true(text.contains("(Target)"))
  assert_true(text.contains("/Title (Links)"))
}

///|
test "a page without links has no annotations" {
  inspect(
    annotations(@pdf.render_pdf(run_model([5.0, 5.0]))).length(),
    content="0",
  )
}

///|
test "uri targets are written as ascii uris" {
  let targets : Array[String] = []
  // an IRI: non-ASCII becomes percent-encoded UTF-8
  targets.push("https://example.org/café")
  targets.push("https://例え.jp/パス?q=値#frag")
  // already encoded input is kept as it is
  targets.push("https://example.org/a%20b%C3%A9")
  // characters a URI never holds
  targets.push("https://example.org/a b\"<>\\^`{|}")
  // a stray percent sign is escaped
  targets.push("https://example.org/100%")
  targets.push("https://example.org/%zz")
  // plain ASCII is untouched
  targets.push("mailto:someone@example.org?subject=Hi&body=x")
  // a named destination keeps its UTF-8 bytes
  targets.push("#café")
  let lines = annotations(@pdf.render_pdf(links_model(targets))).map(line => {
    line[line.find("]").unwrap() + 1:].to_owned()
  })
  inspect(
    lines.join("\n"),
    content=(
      #| [0 0 0] /URI https://example.org/caf%C3%A9
      #| [0 0 0] /URI https://%E4%BE%8B%E3%81%88.jp/%E3%83%91%E3%82%B9?q=%E5%80%A4#frag
      #| [0 0 0] /URI https://example.org/a%20b%C3%A9
      #| [0 0 0] /URI https://example.org/a%20b%22%3C%3E%5C%5E%60%7B%7C%7D
      #| [0 0 0] /URI https://example.org/100%25
      #| [0 0 0] /URI https://example.org/%25zz
      #| [0 0 0] /URI mailto:someone@example.org?subject=Hi&body=x
      #| [0 0 0] dest cafÃ©
    ),
  )
}

///|
test "an outline entry can jump to an explicit destination" {
  let model = run_model([5.0, 5.0])
  let bytes = @pdf.render_pdf(
    model,
    options=@pdf.RenderOptions::new(outline=[
      { title: "Top", level: 0, dest: Position(page=0, x=0, y=0), open: false, },
      {
        title: "Nowhere",
        level: 0,
        dest: Position(page=9, x=0, y=0),
        open: false,
      },
    ]),
  )
  let text = decompressed(bytes)
  // the top of the first page (100pt tall), with no named destination
  assert_true(text.contains("/XYZ 0 100 null"))
  assert_false(text.contains("/Dests"))
  // an entry whose page does not exist goes nowhere, but is kept
  assert_true(text.contains("(Nowhere)"))
}

///|
test "the first anchor of a name is its destination" {
  let model = run_model([5.0, 5.0])
  model.pages[0].items.push(Anchor({ name: "twice", x_pt: 1, y_pt: 10, }))
  model.pages[0].items.push(Anchor({ name: "twice", x_pt: 2, y_pt: 20, }))
  let document = @pdflite.pdf_read_document_from_bytes(@pdf.render_pdf(model))
  guard document.lookup_chain(document.catalog(), [
      name("/Names"),
      name("/Dests"),
    ])
    is Some(tree) else {
    fail("no /Dests name tree")
  }
  let entries = @pdflite.pdf_read_name_tree(document, tree)
  inspect(entries.length(), content="1")
  guard document.direct(entries[0].1) is PdfArray([_, _, x, y, _]) else {
    fail("not an /XYZ destination")
  }
  inspect("\{number(x)} \{number(y)}", content="1 90")
}
