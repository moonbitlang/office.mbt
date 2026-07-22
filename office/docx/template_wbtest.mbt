///|
/// Codex #208 round-1 findings: every brace-pair detector must be
/// split-proof — the grammar spans run boundaries, so per-node contains
/// checks silently pass split placeholders into published output.
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
    allow_missing: false,
  }
}

///|
test "a brace pair split across runs is still scanned" {
  let state = template_wb_state()
  state.scan_paragraph("/body", "word/document.xml", "p[1]", [
    @document.run([@document.text("{")]),
    @document.run([@document.text("{k}}")]),
  ])
  assert_eq(state.report.placeholders_found, 1)
  assert_eq(state.report.replaced, 1)
  assert_eq(state.edits.length(), 2)
}

///|
test "an opaque run's text after the opaque child is still inspected" {
  let (pure, text) = docx_pure_text_run([
    @document.tab(),
    @document.text("{{k}}"),
  ])
  assert_false(pure)
  assert_eq(text, "{{k}}")
  let state = template_wb_state()
  state.scan_paragraph("/body", "word/document.xml", "p[1]", [
    @document.run([@document.tab(), @document.text("{{k}}")]),
  ])
  assert_eq(state.report.unsupported_total, 1)
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
test "a placeholder ending exactly before a hyperlink does not cross" {
  let state = template_wb_state()
  state.scan_region("/body", "word/document.xml", "/docx/body/p[1]", [
    { run_path: "p[1]/r[1]", parent: "", text: "{{k}}" },
    { run_path: "p[1]/hyperlink[1]/r[1]", parent: "hyperlink[1]", text: "x" },
  ])
  assert_eq(state.report.unsupported_total, 0)
  assert_eq(state.report.replaced, 1)
  // a genuine crossing still refuses
  let crossing = template_wb_state()
  crossing.scan_region("/body", "word/document.xml", "/docx/body/p[1]", [
    { run_path: "p[1]/r[1]", parent: "", text: "{{k" },
    { run_path: "p[1]/hyperlink[1]/r[1]", parent: "hyperlink[1]", text: "}}" },
  ])
  assert_eq(crossing.report.unsupported_total, 1)
  assert_eq(crossing.report.replaced, 0)
}
