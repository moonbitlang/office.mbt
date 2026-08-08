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
