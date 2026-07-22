///|
/// The v3 unified-stream nets: one scan per paragraph over rendering-
/// adjacent pieces with per-piece rewritability. Every shape the review
/// rounds probed is pinned here, positives and negatives.
fn template_wb_state() -> DocxMergeState {
  {
    report: {
      placeholders_found: 0,
      replaced: 0,
      escapes_applied: 0,
      distinct_keys_used: 0,
      missing: [],
      unused: [],
      malformed: [],
      unsupported: [],
      locations: [],
      locations_truncated: false,
      missing_total: 0,
      malformed_total: 0,
      unsupported_total: 0,
      unused_total: 0,
      stories_scanned: [],
      changed: false,
    },
    values: { "k": @template.TextValue("VALUE") },
    used_keys: Set::new(),
    budget: Ref::new(1_000_000),
    edits: [],
    checks: [],
    allow_missing: false,
  }
}

///|
fn wb_scan(
  state : DocxMergeState,
  children : Array[@document.DocumentElement],
) -> Unit raise {
  state.scan_paragraph("/body", "word/document.xml", "p[1]", children)
}

///|
test "split placeholders substitute across two and three runs" {
  let two = template_wb_state()
  wb_scan(two, [
    @document.run([@document.text("{")]),
    @document.run([@document.text("{k}}")]),
  ])
  assert_eq(two.report.replaced, 1)
  assert_eq(two.edits.length(), 2)
  let three = template_wb_state()
  wb_scan(three, [
    @document.run([@document.text("{")]),
    @document.run([@document.text("{k}")]),
    @document.run([@document.text("}")]),
  ])
  assert_eq(three.report.replaced, 1)
  assert_eq(three.report.unsupported_total, 0)
}

///|
test "brace pairs in unrewritable content refuse in every split shape" {
  // whole pair inside an opaque run's text
  let opaque = template_wb_state()
  wb_scan(opaque, [@document.run([@document.tab(), @document.text("{{k}}")])])
  assert_eq(opaque.report.unsupported_total, 1)
  assert_eq(opaque.report.replaced, 0)
  // pair split across bare sibling texts (renders adjacently)
  let bare = template_wb_state()
  wb_scan(bare, [@document.text("{"), @document.text("{k}}")])
  assert_eq(bare.report.unsupported_total, 1)
  // pair starting in a REWRITABLE run and ending in bare text
  let mixed = template_wb_state()
  wb_scan(mixed, [@document.run([@document.text("{{k")]), @document.text("}}")])
  assert_eq(mixed.report.unsupported_total, 1)
  assert_eq(mixed.edits.length(), 0)
  // complex field: a hyperlink nested INSIDE a run — descendant text is
  // rendered but never rewritable
  let field = template_wb_state()
  wb_scan(field, [
    @document.run([
      @document.Hyperlink(
        children=[@document.run([@document.text("{{k}}")])],
        href=Some("https://example.com/"),
        anchor=None,
        target_frame=None,
      ),
    ]),
  ])
  assert_eq(field.report.unsupported_total, 1)
  assert_eq(field.report.replaced, 0)
}

///|
test "separators and zero-width elements follow rendering semantics" {
  // a pair split around a tab is NOT a pair (the tab renders between)
  let tabbed = template_wb_state()
  wb_scan(tabbed, [
    @document.run([@document.text("{"), @document.tab(), @document.text("{k}}")]),
  ])
  assert_eq(tabbed.report.unsupported_total, 0)
  assert_eq(tabbed.report.replaced, 0)
  // a bookmark renders NOTHING: the pair around it is real and, sitting
  // in rewritable runs both sides, substitutes
  let bookmark = template_wb_state()
  wb_scan(bookmark, [
    @document.run([@document.text("{")]),
    @document.BookmarkStart("mark"),
    @document.run([@document.text("{k}}")]),
  ])
  assert_eq(bookmark.report.replaced, 1)
  assert_eq(bookmark.report.unsupported_total, 0)
  // a note reference renders a visible mark: braces around it never pair
  let marked = template_wb_state()
  wb_scan(marked, [
    @document.run([@document.text("{")]),
    @document.NoteReference(note_type="footnote", note_id="1"),
    @document.run([@document.text("{k}}")]),
  ])
  assert_eq(marked.report.replaced, 0)
  assert_eq(marked.report.unsupported_total, 0)
}

///|
test "escapes touching unrewritable content refuse" {
  // the backslash sits after a tab inside an opaque run; the braces sit
  // in a rewritable run — rewriting only half would corrupt
  let split_escape = template_wb_state()
  wb_scan(split_escape, [
    @document.run([@document.tab(), @document.text("\\")]),
    @document.run([@document.text("{{k}}")]),
  ])
  // the stream reads \{{k}} — one escape then "k}}" text; the escape
  // covers the opaque backslash piece
  assert_eq(split_escape.report.unsupported_total, 1)
  assert_eq(split_escape.report.replaced, 0)
  assert_eq(split_escape.report.escapes_applied, 0)
  // a fully rewritable escape still applies
  let fine = template_wb_state()
  wb_scan(fine, [@document.run([@document.text("a \\{{ b")])])
  assert_eq(fine.report.escapes_applied, 1)
  assert_eq(fine.edits.length(), 1)
}

///|
test "hyperlink parents and zero-width boundaries" {
  // placeholder immediately before a hyperlink substitutes
  let before = template_wb_state()
  wb_scan(before, [
    @document.run([@document.text("{{k}}")]),
    @document.Hyperlink(
      children=[@document.run([@document.text("tail")])],
      href=Some("https://example.com/"),
      anchor=None,
      target_frame=None,
    ),
  ])
  assert_eq(before.report.replaced, 1)
  assert_eq(before.report.unsupported_total, 0)
  // hyperlink placeholder immediately before a direct run substitutes
  let inside = template_wb_state()
  wb_scan(inside, [
    @document.Hyperlink(
      children=[@document.run([@document.text("{{k}}")])],
      href=Some("https://example.com/"),
      anchor=None,
      target_frame=None,
    ),
    @document.run([@document.text("tail")]),
  ])
  assert_eq(inside.report.replaced, 1)
  assert_eq(inside.report.unsupported_total, 0)
  // an EMPTY run between the placeholder and following content covers
  // nothing and cannot fake a crossing
  let empty_between = template_wb_state()
  wb_scan(empty_between, [
    @document.run([@document.text("{{k}}")]),
    @document.Hyperlink(
      children=[@document.run([])],
      href=Some("https://example.com/"),
      anchor=None,
      target_frame=None,
    ),
    @document.run([@document.text("tail")]),
  ])
  assert_eq(empty_between.report.replaced, 1)
  assert_eq(empty_between.report.unsupported_total, 0)
  // a genuine crossing still refuses
  let crossing = template_wb_state()
  wb_scan(crossing, [
    @document.run([@document.text("{{k")]),
    @document.Hyperlink(
      children=[@document.run([@document.text("}}")])],
      href=Some("https://example.com/"),
      anchor=None,
      target_frame=None,
    ),
  ])
  assert_eq(crossing.report.unsupported_total, 1)
  assert_eq(crossing.report.replaced, 0)
}

///|
test "split placeholders in out-of-scope stories are flagged" {
  let state = template_wb_state()
  state.flag_out_of_scope("footnotes", [
    (
      "1",
      [
        @document.paragraph([
          @document.run([@document.text("{")]),
          @document.run([@document.text("{k}")]),
          @document.run([@document.text("}")]),
        ]),
      ],
    ),
  ])
  assert_eq(state.report.unsupported_total, 1)
  // a bookmark between the braces is zero-width there too
  let marked = template_wb_state()
  marked.flag_out_of_scope("footnotes", [
    (
      "1",
      [
        @document.paragraph([
          @document.run([@document.text("{")]),
          @document.BookmarkStart("m"),
          @document.run([@document.text("{k}}")]),
        ]),
      ],
    ),
  ])
  assert_eq(marked.report.unsupported_total, 1)
  // paragraph boundaries never pair
  let clean = template_wb_state()
  clean.flag_out_of_scope("footnotes", [
    (
      "1",
      [
        @document.paragraph([@document.run([@document.text("tail {")])]),
        @document.paragraph([@document.run([@document.text("{k}} head")])]),
      ],
    ),
  ])
  assert_eq(clean.report.unsupported_total, 0)
}

///|
/// Codex #208 round-4: an escape whose backslash and braces sit in
/// different hyperlink parents would migrate the literal outside the
/// link — it must refuse like a crossing match.
test "escapes crossing hyperlink parents refuse" {
  let state = template_wb_state()
  wb_scan(state, [
    @document.run([@document.text("\\")]),
    @document.Hyperlink(
      children=[@document.run([@document.text("{{k}}")])],
      href=Some("https://example.com/"),
      anchor=None,
      target_frame=None,
    ),
  ])
  assert_eq(state.report.escapes_applied, 0)
  assert_true(state.report.unsupported_total >= 1)
  assert_eq(state.edits.length(), 0)
}
