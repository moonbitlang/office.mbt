///|
/// The writer cannot serialize unknown styles or bookmarks, so their
/// residual paths are exercised directly against the mapping functions
/// (real files from Word carry both; our writer never emits them).
test "inexpressible paragraph content residualizes and text degrades" {
  let residual : Array[DumpResidual] = []
  let params = docx_paragraph_params(
    [
      @document.BookmarkStart("m"),
      @document.run([@document.text("styled away")]),
    ],
    @document.paragraph_properties(
      style_id=Some("FancyQuote"),
      alignment=Some("weird"),
    ),
    3,
    residual,
  )
  // the text is kept, the style/alignment/bookmark are disclosed
  let rendered = Json::object(params).stringify()
  assert_true(rendered.contains("styled away"))
  assert_false(rendered.contains("FancyQuote"))
  assert_false(rendered.contains("weird"))
  let codes = residual.map(entry => entry.code)
  assert_true(codes.contains("docx.paragraph_style_dropped"))
  assert_true(codes.contains("docx.alignment_dropped"))
  assert_true(codes.contains("docx.bookmark_dropped"))
  assert_eq(codes.length(), 3)
}

///|
test "run styles and unserializable text residualize" {
  let residual : Array[DumpResidual] = []
  let styled = docx_run_spec(
    [@document.text("kept")],
    @document.run_properties(style_id=Some("Emphasis")),
    0,
    residual,
  )
  assert_true(styled is Some(_))
  assert_true(
    residual.map(entry => entry.code).contains("docx.run_style_dropped"),
  )
  let bad : Array[DumpResidual] = []
  let dropped = docx_run_spec(
    [@document.text("line\nbreak")],
    @document.run_properties(),
    0,
    bad,
  )
  assert_true(dropped is None)
  assert_true(bad.map(entry => entry.code).contains("docx.text_unserializable"))
}

///|
/// The batch parser rejects empty tables and cell-less rows; both must
/// residualize instead of aborting the dump in the self-check.
test "degenerate tables residualize instead of aborting" {
  let residual : Array[DumpResidual] = []
  let empty = docx_table_params(
    [],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    residual,
  )
  assert_true(empty is None)
  assert_true(
    residual.map(entry => entry.code).contains("docx.empty_table_dropped"),
  )
  let mixed : Array[DumpResidual] = []
  let params = docx_table_params(
    [
      @document.TableRow(children=[], is_header=true),
      @document.TableRow(
        children=[
          @document.TableCell(
            children=[
              @document.paragraph([@document.run([@document.text("x")])]),
            ],
            col_span=1,
            row_span=1,
          ),
        ],
        is_header=false,
      ),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    mixed,
  )
  // the empty header row drops; the survivor is a body row, so no
  // header_rows param may claim it
  guard params is Some(params) else { fail("expected a table op") }
  let rendered = Json::object(params).stringify()
  assert_false(rendered.contains("header_rows"))
  assert_true(mixed.map(entry => entry.code).contains("docx.empty_row_dropped"))
}

///|
/// Word nests images and note references inside runs; the run walk must
/// disclose them under their specific codes.
test "run-nested images and references get specific residual codes" {
  let residual : Array[DumpResidual] = []
  let spec = docx_run_spec(
    [
      @document.text("kept"),
      @document.NoteReference(note_type="footnote", note_id="1"),
      @document.CommentReference("7"),
    ],
    @document.run_properties(),
    0,
    residual,
  )
  assert_true(spec is Some(_))
  let codes = residual.map(entry => entry.code)
  assert_true(codes.contains("docx.note_reference_dropped"))
  assert_true(codes.contains("docx.comment_reference_dropped"))
}

///|
/// Kimi round-1 findings: parser-rejected values must residualize with
/// the content kept, never abort the dump. Each emitted shape is proven
/// against the real parser.
test "parser-hostile values residualize and the ops still parse" {
  let residual : Array[DumpResidual] = []
  // an unresolved hyperlink keeps its text as plain runs
  let runs : Array[Json] = []
  docx_inline_specs(
    [
      @document.Hyperlink(
        children=[@document.run([@document.text("dead link text")])],
        href=None,
        anchor=None,
        target_frame=None,
      ),
    ],
    0,
    runs,
    residual,
    allow_links=true,
  )
  assert_eq(runs.length(), 1)
  assert_false(runs[0].stringify().contains("\"link\":"))
  assert_true(runs[0].stringify().contains("dead link text"))
  // out-of-range font sizes keep the run, drop the size
  let tiny = docx_run_spec(
    [@document.text("small")],
    @document.run_properties(font_size=Some(0)),
    0,
    residual,
  )
  guard tiny is Some(tiny) else { fail("expected a run") }
  assert_false(tiny.stringify().contains("size"))
  let huge = docx_run_spec(
    [@document.text("big")],
    @document.run_properties(font_size=Some(2000)),
    0,
    residual,
  )
  guard huge is Some(huge) else { fail("expected a run") }
  assert_false(huge.stringify().contains("size"))
  // a non-enum highlight keeps the run, drops the highlight
  let tinted = docx_run_spec(
    [@document.text("tinted")],
    @document.run_properties(highlight=Some("teal")),
    0,
    residual,
  )
  guard tinted is Some(tinted) else { fail("expected a run") }
  assert_false(tinted.stringify().contains("teal"))
  let codes = residual.map(entry => entry.code)
  assert_true(codes.contains("docx.link_unresolved"))
  assert_true(codes.contains("docx.font_size_dropped"))
  assert_true(codes.contains("docx.highlight_dropped"))
  // spans beyond the writer's bounds drop to residuals
  let spans : Array[DumpResidual] = []
  let cell = (col : Int, row : Int) => {
    @document.TableCell(
      children=[@document.paragraph([@document.run([@document.text("c")])])],
      col_span=col,
      row_span=row,
    )
  }
  let params = docx_table_params(
    [
      @document.TableRow(children=[cell(64, 1)], is_header=false),
      @document.TableRow(children=[cell(1, 5)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    spans,
  )
  guard params is Some(params) else { fail("expected a table op") }
  let rendered = Json::object(params).stringify()
  assert_false(rendered.contains("col_span"))
  assert_false(rendered.contains("row_span"))
  assert_eq(
    spans.filter(entry => entry.code == "docx.cell_span_dropped").length(),
    2,
  )
  // every degraded shape still parses through the real batch parser
  let ops : Array[Json] = [
    Json::object({
      "op": Json::string("paragraph"),
      "params": Json::object({ "runs": Json::array(runs) }),
    }),
    Json::object({
      "op": Json::string("paragraph"),
      "params": Json::object({ "runs": Json::array([tiny, huge, tinted]) }),
    }),
    Json::object({ "op": Json::string("table"), "params": Json::object(params) }),
  ]
  ignore(
    @docx_batch.parse_batch(
      Json::object({
        "schema": Json::string("docx.batch/2"),
        "ops": Json::array(ops),
      }),
    ),
  )
}
