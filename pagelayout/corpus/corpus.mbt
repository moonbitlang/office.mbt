///|
// Reality check against real-world Word documents rather than fixtures
// this engine's own author wrote.
//
// Every hand-written fixture encodes its author's beliefs about the
// format, so a test suite built only from them measures self-consistency,
// not correctness. Two bugs in this engine passed their own tests for
// exactly that reason: a list-indent guard that Word's stock
// `ListParagraph` style would have defeated (the fixture used no style),
// and a bullet that only rendered because the fixture hand-wrote U+2022
// instead of Word's Symbol-font private-use codepoint.
//
// These tests render the multi-megabyte corpus documents already in the
// repository (docx2html's stress fixtures — real reports and technical
// manuals, not synthesized) and assert reference-free invariants: the
// engine must not crash, must produce a structurally valid page model,
// must keep every glyph inside the page, and must not silently lose
// text. Nothing here asserts a layout *matches Word* — that is a
// deliberately different question (see docs/page-layout-engine.md).

///|
/// Total characters across every glyph run of a model.
pub fn text_length(model : @pagelayout.PageModel) -> Int {
  let mut total = 0
  for page in model.pages {
    for item in page.items {
      if item is Text(run) {
        total += run.text.length()
      }
    }
  }
  total
}

///|
/// Every glyph run's text, concatenated in page order.
pub fn text_of(model : @pagelayout.PageModel) -> String {
  let sb = StringBuilder()
  for page in model.pages {
    for item in page.items {
      if item is Text(run) {
        sb.write_string(run.text)
      }
    }
  }
  sb.to_string()
}

///|
/// Reference-free geometry invariant: every glyph run sits within its
/// page, and every baseline is below the top edge. Returns one message
/// per violation. Content may legitimately sit outside the *margins*
/// (headers, hanging indents, tables wider than the measure), so this
/// checks the page box rather than the content box.
pub fn geometry_violations(model : @pagelayout.PageModel) -> Array[String] {
  let out : Array[String] = []
  for p, page in model.pages {
    for i, item in page.items {
      guard item is Text(run) else { continue }
      if run.baseline_pt <= 0.0 || run.baseline_pt > page.height_pt {
        out.push(
          "page \{p} item \{i}: baseline \{run.baseline_pt} outside page",
        )
      }
      if run.x_pt < 0.0 || run.x_pt > page.width_pt {
        out.push("page \{p} item \{i}: x \{run.x_pt} outside page")
      }
    }
  }
  out
}
