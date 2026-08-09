///|
/// The corpus lives in docx2html's stress fixtures — real reports and
/// technical manuals of several megabytes each. Paths are relative to
/// the pagelayout module root, which is where `moon test` runs.
let corpus : Array[(String, String)] = [
  (
    "reports-004f20", "../docx2html/tests/stress/fixtures/docxcorp-reports-en-004f20c73314.docx",
  ),
  (
    "reports-015012", "../docx2html/tests/stress/fixtures/docxcorp-reports-en-015012bf8890.docx",
  ),
  (
    "technical-028db", "../docx2html/tests/stress/fixtures/docxcorp-technical-en-028db84b4b91.docx",
  ),
]

///|
async fn render(path : String) -> @pagelayout.PageModel {
  let bytes = @afs.read_file(path).binary()
  @docx.render_docx(bytes)
}

///|
async test "the corpus documents carry their headers and footers" {
  // the technical manual references header and footer parts through
  // _rels; every page must carry them
  let bytes = @afs.read_file(corpus[2].1).binary()
  let doc = @docx.read_docx(bytes)
  assert_true(doc.furniture.header.length() > 0)
  let model = @paginate.paginate(
    doc.blocks,
    section=doc.section,
    furniture=doc.furniture,
  )
  debug_inspect(model.validate(), content="[]")
  assert_eq(@corpus.geometry_violations(model).length(), 0)
}

///|
async test "every corpus document renders to a structurally valid model" {
  for entry in corpus {
    let (name, path) = entry
    let model = render(path)
    // the IR's own invariants: advances match text, font indices resolve,
    // sizes positive, colours in range, no contradictory rects
    let violations = model.validate()
    if violations.length() > 0 {
      println("\{name}: \{violations.length()} violation(s)")
      for v in violations {
        println("   \{v}")
      }
    }
    assert_eq(violations.length(), 0)
    assert_true(model.pages.length() > 0)
    assert_true(model.fonts.length() > 0)
  }
}

///|
async test "every glyph run lands inside its page" {
  for entry in corpus {
    let (name, path) = entry
    let model = render(path)
    let violations = @corpus.geometry_violations(model)
    if violations.length() > 0 {
      println("\{name}: \{violations.length()} geometry violation(s)")
      for v in violations[0:5] {
        println("   \{v}")
      }
    }
    assert_eq(violations.length(), 0)
  }
}

///|
/// Content completeness, the invariant that catches silent loss: a
/// document's rendered text must be at least as long as the text its
/// paragraphs contain. Measured against counts taken from the packages
/// themselves (see the module comment) — these are floors, not exact
/// values, so ordinary layout changes do not churn the test but dropping
/// a table, a list, or a run does fail it.
async test "no corpus document silently loses text" {
  let floors : ReadOnlyArray[Int] = [2000, 7900, 107000]
  for i, entry in corpus {
    let (name, path) = entry
    let model = render(path)
    let length = @corpus.text_length(model)
    if length < floors[i] {
      println("\{name}: rendered \{length} chars, expected >= \{floors[i]}")
    }
    assert_true(length >= floors[i])
  }
}

///|
/// The corpus exercises the constructs hand-written fixtures tend to
/// miss. This pins that they are actually present, so the floors above
/// are guarding real structure rather than a wall of body text.
async test "the corpus exercises tables, lists and multiple faces" {
  let model = render(corpus[2].1)
  // a 49-page technical manual: many pages, many faces
  assert_true(model.pages.length() > 20)
  assert_true(model.fonts.length() >= 4)
  // tables paint cell borders and shading as rects
  let mut rects = 0
  for page in model.pages {
    for item in page.items {
      if item is Rect(_) {
        rects += 1
      }
    }
  }
  assert_true(rects > 0)
}

///|
/// Characters the engine cannot draw, per document, asked of the face
/// each run is actually set in.
fn dropped_characters(model : @pagelayout.PageModel) -> Int {
  let mut total = 0
  for page in model.pages {
    for item in page.items {
      guard item is Text(run) else { continue }
      guard model.fonts.get(run.font) is Some(spec) else { continue }
      for
        entry in @fonts.uncovered(
          run.text,
          spec.family,
          bold=spec.bold,
          italic=spec.italic,
        ) {
        total += entry.1
      }
    }
  }
  total
}

///|
async test "the corpus loses only the characters we have accounted for" {
  // A floor on character count cannot see this: the systematic review
  // drops 62 GRADE symbols out of thousands of characters, which is a
  // rounding error against any floor but is the whole certainty column
  // of the table. These numbers are the known coverage gap — no bundled
  // face has U+2A01, and none has the mathematical italics — so a change
  // here means either the gap closed or a new one opened, and both are
  // worth stopping for.
  let expected : ReadOnlyArray[Int] = [62, 0, 20]
  for i, entry in corpus {
    let (name, path) = entry
    let dropped = dropped_characters(render(path))
    if dropped != expected[i] {
      println("\{name}: \{dropped} characters dropped, expected \{expected[i]}")
    }
    assert_eq(dropped, expected[i])
  }
}
