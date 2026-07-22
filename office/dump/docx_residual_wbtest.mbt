///|
/// The writer cannot serialize unknown styles or bookmarks, so their
/// residual paths are exercised directly against the mapping functions
/// (real files from Word carry both; our writer never emits them).
fn wb_ctx(residual : Array[DumpResidual]) -> DocxDumpContext {
  {
    assets: {},
    total_asset_bytes: Ref::new(0),
    residual,
    footnote_bodies: {},
    endnote_bodies: {},
    used_notes: Set::new(),
    image_verdicts: {},
  }
}

///|
fn wb_run_specs(
  children : Array[@document.DocumentElement],
  properties : @document.RunProperties,
  residual : Array[DumpResidual],
) -> Array[Json] {
  let out : Array[Json] = []
  docx_run_specs(
    children,
    properties,
    0,
    wb_ctx(residual),
    out,
    in_note_body=false,
    plain=false,
  )
  out
}

///|
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
    wb_ctx(residual),
    in_note_body=false,
    plain=false,
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
  let styled = wb_run_specs(
    [@document.text("kept")],
    @document.run_properties(style_id=Some("Emphasis")),
    residual,
  )
  assert_eq(styled.length(), 1)
  assert_true(
    residual.map(entry => entry.code).contains("docx.run_style_dropped"),
  )
  let bad : Array[DumpResidual] = []
  let dropped = wb_run_specs(
    [@document.text("line\nbreak")],
    @document.run_properties(),
    bad,
  )
  assert_eq(dropped.length(), 0)
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
    wb_ctx(residual),
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
    wb_ctx(mixed),
  )
  // the empty header row drops; the survivor is a body row, so no
  // header_rows param may claim it
  guard params is Some(params) else { fail("expected a table op") }
  let rendered = Json::object(params).stringify()
  assert_false(rendered.contains("header_rows"))
  assert_true(mixed.map(entry => entry.code).contains("docx.empty_row_dropped"))
}

///|
test "comment references are silent in body, disclosed in bodies" {
  // in body content the comment op regenerates the reference run, so
  // the inline reference itself needs no residual and must not force an
  // empty segment (that would grow the paragraph every replay cycle)
  let residual : Array[DumpResidual] = []
  let specs = wb_run_specs(
    [@document.text("kept"), @document.CommentReference("7")],
    @document.run_properties(),
    residual,
  )
  assert_eq(specs.length(), 1)
  assert_eq(residual.length(), 0)
  let mark_only = wb_run_specs(
    [@document.CommentReference("7")],
    @document.run_properties(),
    residual,
  )
  assert_eq(mark_only.length(), 0)
  assert_eq(residual.length(), 0)
  // inside a comment body there is no op to regenerate it
  let plain_res : Array[DumpResidual] = []
  let out : Array[Json] = []
  docx_run_specs(
    [@document.CommentReference("7")],
    @document.run_properties(),
    0,
    wb_ctx(plain_res),
    out,
    in_note_body=false,
    plain=true,
  )
  assert_true(
    plain_res
    .map(entry => entry.code)
    .contains("docx.comment_reference_dropped"),
  )
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
    wb_ctx(residual),
    allow_links=true,
    in_note_body=false,
    plain=false,
  )
  assert_eq(runs.length(), 1)
  assert_false(runs[0].stringify().contains("\"link\":"))
  assert_true(runs[0].stringify().contains("dead link text"))
  // out-of-range font sizes keep the run, drop the size
  let tiny_specs = wb_run_specs(
    [@document.text("small")],
    @document.run_properties(font_size=Some(0)),
    residual,
  )
  guard tiny_specs is [tiny] else { fail("expected a run") }
  assert_false(tiny.stringify().contains("size"))
  let huge_specs = wb_run_specs(
    [@document.text("big")],
    @document.run_properties(font_size=Some(2000)),
    residual,
  )
  guard huge_specs is [huge] else { fail("expected a run") }
  assert_false(huge.stringify().contains("size"))
  // a non-enum highlight keeps the run, drops the highlight
  let tinted_specs = wb_run_specs(
    [@document.text("tinted")],
    @document.run_properties(highlight=Some("teal")),
    residual,
  )
  guard tinted_specs is [tinted] else { fail("expected a run") }
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
    wb_ctx(spans),
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

///|
/// P4b: an image inside a formatted run hoists as a run-position spec
/// between the split text segments, carrying its payload as an asset.
test "run-nested images hoist and capture assets" {
  let residual : Array[DumpResidual] = []
  let ctx = wb_ctx(residual)
  let out : Array[Json] = []
  let payload : Bytes = b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0d\x49\x44\x41\x54\x78\x9c\x63\xf8\xcf\xc0\xf0\x1f\x00\x05\x00\x01\xff\x89\x99\x3d\x1d\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82"
  docx_run_specs(
    [
      @document.text("before"),
      @document.Image(@document.Image::{
        content_type: "image/png",
        alt_text: Some("logo"),
        data: payload,
      }),
      @document.text("after"),
    ],
    @document.run_properties(is_bold=true),
    0,
    ctx,
    out,
    in_note_body=false,
    plain=false,
  )
  assert_eq(out.length(), 3)
  assert_true(out[0].stringify().contains("before"))
  assert_true(out[0].stringify().contains("\"bold\":true"))
  assert_true(out[1].stringify().contains("\"image\":"))
  assert_true(out[1].stringify().contains("sha256-"))
  assert_true(out[1].stringify().contains("image/png"))
  assert_true(out[1].stringify().contains("logo"))
  assert_true(out[2].stringify().contains("after"))
  assert_true(out[2].stringify().contains("\"bold\":true"))
  assert_eq(ctx.assets.size(), 1)
  assert_eq(residual.length(), 0)
  // dedup: the same payload again adds no asset
  let out2 : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/png",
        alt_text: None,
        data: payload,
      }),
    ],
    @document.run_properties(),
    1,
    ctx,
    out2,
    in_note_body=false,
    plain=false,
  )
  assert_eq(ctx.assets.size(), 1)
  // a conflicting content type on the duplicate is disclosed
  let out3 : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/jpeg",
        alt_text: None,
        data: payload,
      }),
    ],
    @document.run_properties(),
    2,
    ctx,
    out3,
    in_note_body=false,
    plain=false,
  )
  assert_true(
    residual
    .map(entry => entry.code)
    .contains("docx.image_content_type_conflict"),
  )
  // a missing content type residualizes (an asset id has no extension
  // for the parser to infer from)
  let out4 : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "",
        alt_text: None,
        data: payload,
      }),
    ],
    @document.run_properties(),
    3,
    ctx,
    out4,
    in_note_body=false,
    plain=false,
  )
  assert_eq(out4.length(), 1) // the forced empty segment for the run
  assert_true(
    residual
    .map(entry => entry.code)
    .contains("docx.image_content_type_unsupported"),
  )
  // a type outside the writable set is disclosed WITH its carried asset
  let tiff : Array[DumpResidual] = []
  let ctx_tiff = wb_ctx(tiff)
  let out5 : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/tiff",
        alt_text: None,
        data: payload,
      }),
    ],
    @document.run_properties(),
    0,
    ctx_tiff,
    out5,
    in_note_body=false,
    plain=false,
  )
  guard tiff is [entry] else { fail("expected one residual") }
  assert_eq(entry.code, "docx.image_content_type_unsupported")
  assert_true(entry.asset is Some(_))
  assert_eq(ctx_tiff.assets.size(), 1)
}

///|
/// P4b: note references pull their stored bodies in as note specs;
/// unknown ids and notes inside note bodies residualize.
test "note references dump their bodies with honest edge handling" {
  let residual : Array[DumpResidual] = []
  let ctx : DocxDumpContext = {
    assets: {},
    total_asset_bytes: Ref::new(0),
    residual,
    footnote_bodies: {
      "1": [
        @document.paragraph([
          @document.run(
            [@document.text("the footnote")],
            properties=@document.run_properties(is_italic=true),
          ),
        ]),
      ],
    },
    endnote_bodies: {},
    used_notes: Set::new(),
    image_verdicts: {},
  }
  let out : Array[Json] = []
  docx_run_specs(
    [
      @document.text("ref"),
      @document.NoteReference(note_type="footnote", note_id="1"),
    ],
    @document.run_properties(),
    0,
    ctx,
    out,
    in_note_body=false,
    plain=false,
  )
  assert_eq(out.length(), 2)
  assert_true(out[1].stringify().contains("\"footnote\":"))
  assert_true(out[1].stringify().contains("the footnote"))
  assert_true(out[1].stringify().contains("\"italic\":true"))
  assert_true(ctx.used_notes.contains("footnote:1"))
  // an unknown id residualizes
  let out2 : Array[Json] = []
  docx_run_specs(
    [@document.NoteReference(note_type="footnote", note_id="9")],
    @document.run_properties(),
    1,
    ctx,
    out2,
    in_note_body=false,
    plain=false,
  )
  assert_true(
    residual.map(entry => entry.code).contains("docx.note_body_missing"),
  )
  // a note reference inside a note body is forbidden by the grammar
  let out3 : Array[Json] = []
  docx_run_specs(
    [@document.NoteReference(note_type="footnote", note_id="1")],
    @document.run_properties(),
    2,
    ctx,
    out3,
    in_note_body=true,
    plain=false,
  )
  assert_true(
    residual.map(entry => entry.code).contains("docx.note_reference_dropped"),
  )
  // the emitted paragraph parses through the real batch parser
  ignore(
    @docx_batch.parse_batch(
      Json::object({
        "schema": Json::string("docx.batch/2"),
        "ops": Json::array([
          Json::object({
            "op": Json::string("paragraph"),
            "params": Json::object({ "runs": Json::array(out) }),
          }),
        ]),
      }),
    ),
  )
}

///|
/// Kimi #203 round-1 finding 1: note bodies are plain content in the
/// batch grammar — a hyperlink or image inside a footnote must keep its
/// text / disclose the image, never abort the dump.
test "links and images inside note bodies degrade honestly" {
  let residual : Array[DumpResidual] = []
  let ctx : DocxDumpContext = {
    assets: {},
    total_asset_bytes: Ref::new(0),
    residual,
    footnote_bodies: {
      "1": [
        @document.paragraph([
          @document.run([@document.text("see ")]),
          @document.Hyperlink(
            children=[@document.run([@document.text("the source")])],
            href=Some("https://example.com/"),
            anchor=None,
            target_frame=None,
          ),
          @document.run([
            @document.Image(@document.Image::{
              content_type: "image/png",
              alt_text: None,
              data: b"\x89",
            }),
          ]),
        ]),
      ],
    },
    endnote_bodies: {},
    used_notes: Set::new(),
    image_verdicts: {},
  }
  let out : Array[Json] = []
  docx_run_specs(
    [@document.NoteReference(note_type="footnote", note_id="1")],
    @document.run_properties(),
    0,
    ctx,
    out,
    in_note_body=false,
    plain=false,
  )
  guard out is [spec] else { fail("expected one note spec") }
  let rendered = spec.stringify()
  assert_true(rendered.contains("the source"))
  assert_false(rendered.contains("\"link\":"))
  assert_false(rendered.contains("\"image\":"))
  let codes = residual.map(entry => entry.code)
  assert_true(codes.contains("docx.link_dropped"))
  assert_true(codes.contains("docx.annotation_image_dropped"))
  // no asset captured for the disclosed-in-note image
  assert_eq(ctx.assets.size(), 0)
  // and the emitted op parses through the real batch parser
  ignore(
    @docx_batch.parse_batch(
      Json::object({
        "schema": Json::string("docx.batch/2"),
        "ops": Json::array([
          Json::object({
            "op": Json::string("paragraph"),
            "params": Json::object({ "runs": Json::array(out) }),
          }),
        ]),
      }),
    ),
  )
}

///|
/// Kimi #203 round-2 finding: an unsupported-type occurrence capturing a
/// payload FIRST must not poison a later supported-type occurrence of
/// the same bytes into an unwritable op — document order cannot decide
/// between an op and an abort.
test "dedup-first unsupported type cannot poison a later supported use" {
  let residual : Array[DumpResidual] = []
  let ctx = wb_ctx(residual)
  let payload : Bytes = "shared-payload-bytes"
  // first occurrence: TIFF — carried as an asset, disclosed, no op
  let out1 : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/tiff",
        alt_text: None,
        data: payload,
      }),
    ],
    @document.run_properties(),
    0,
    ctx,
    out1,
    in_note_body=false,
    plain=false,
  )
  assert_eq(out1.length(), 1) // the forced empty segment only
  assert_false(out1[0].stringify().contains("\"image\":"))
  // second occurrence: same bytes declared PNG — dedup resolves to the
  // stored TIFF entry, so the op would carry an unwritable type; it must
  // residualize instead
  let out2 : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/png",
        alt_text: None,
        data: payload,
      }),
    ],
    @document.run_properties(),
    1,
    ctx,
    out2,
    in_note_body=false,
    plain=false,
  )
  for spec in out2 {
    assert_false(spec.stringify().contains("\"image\":"))
  }
  assert_eq(ctx.assets.size(), 1)
  let unsupported = residual.filter(entry => {
    entry.code == "docx.image_content_type_unsupported"
  })
  assert_eq(unsupported.length(), 2)
  guard unsupported[1].asset is Some(_) else {
    fail("the poisoned occurrence must reference the carried asset")
  }
}

///|
/// PR5 writer-oracle layers: a payload the writer cannot sniff (valid
/// declared type, garbage bytes) residualizes as unwritable with its
/// asset carried; the verdict is cached per asset so a second reference
/// runs no second probe (observable through the single residual pair).
test "unsniffable image payloads residualize via the writer oracle" {
  let residual : Array[DumpResidual] = []
  let ctx = wb_ctx(residual)
  let out : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/png",
        alt_text: None,
        data: "definitely-not-a-png",
      }),
    ],
    @document.run_properties(),
    0,
    ctx,
    out,
    in_note_body=false,
    plain=false,
  )
  assert_eq(out.length(), 1) // forced empty segment only, no image spec
  assert_false(out[0].stringify().contains("\"image\":"))
  let unwritable = residual.filter(entry => {
    entry.code == "docx.image_unwritable"
  })
  guard unwritable is [entry] else { fail("expected one unwritable residual") }
  assert_true(entry.asset is Some(_))
  assert_eq(ctx.assets.size(), 1)
  assert_eq(ctx.image_verdicts.size(), 1)
}

///|
/// PR5 grid gate: rows past 63 effective columns or non-uniform row
/// widths residualize the table — the writer would reject both, and a
/// dump must never emit what its own replay cannot write.
test "table grid geometry the writer rejects residualizes" {
  let cell = (span : Int) => {
    @document.TableCell(
      children=[@document.paragraph([@document.run([@document.text("c")])])],
      col_span=span,
      row_span=1,
    )
  }
  // 32 + 32 = 64 effective columns in one row
  let overflow : Array[DumpResidual] = []
  let wide = docx_table_params(
    [@document.TableRow(children=[cell(32), cell(32)], is_header=false)],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(overflow),
  )
  assert_true(wide is None)
  assert_true(
    overflow.map(entry => entry.code).contains("docx.table_grid_unsupported"),
  )
  // rows of width 2 and width 1 — the writer rejects narrower rows
  let uneven : Array[DumpResidual] = []
  let ragged = docx_table_params(
    [
      @document.TableRow(children=[cell(1), cell(1)], is_header=false),
      @document.TableRow(children=[cell(1)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(uneven),
  )
  assert_true(ragged is None)
  assert_true(
    uneven.map(entry => entry.code).contains("docx.table_grid_unsupported"),
  )
  // a uniform two-column table still emits
  let fine : Array[DumpResidual] = []
  let ok = docx_table_params(
    [
      @document.TableRow(children=[cell(1), cell(1)], is_header=false),
      @document.TableRow(children=[cell(2)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(fine),
  )
  assert_true(ok is Some(_))
  assert_eq(
    fine.filter(entry => entry.code == "docx.table_grid_unsupported").length(),
    0,
  )
}

///|
/// Kimi #204 round-1 findings: the grid gate must mirror the writer's
/// PLACEMENT semantics — pending vertical merges cover columns in the
/// rows below, so merge-covered "ragged" tables are writable and must
/// emit, while a row the reader left empty under an active merge is
/// inexpressible and must residualize the table.
test "vmerge tables gate by placement, not raw widths" {
  let cell = (col : Int, row : Int) => {
    @document.TableCell(
      children=[@document.paragraph([@document.run([@document.text("c")])])],
      col_span=col,
      row_span=row,
    )
  }
  // A(row_span 2) + B over C: row 2's single cell is covered by A's
  // pending merge — the writer accepts this; the dump must emit it
  let merged : Array[DumpResidual] = []
  let ok = docx_table_params(
    [
      @document.TableRow(children=[cell(1, 2), cell(1, 1)], is_header=false),
      @document.TableRow(children=[cell(1, 1)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(merged),
  )
  guard ok is Some(params) else { fail("a merge-covered table must emit") }
  assert_true(Json::object(params).stringify().contains("row_span"))
  assert_eq(
    merged.filter(entry => entry.code == "docx.table_grid_unsupported").length(),
    0,
  )
  // a full-continuation row (reader strips its cells) under an active
  // merge cannot exist in the batch grammar: whole table residualizes
  let stripped : Array[DumpResidual] = []
  let dropped = docx_table_params(
    [
      @document.TableRow(children=[cell(1, 2), cell(1, 2)], is_header=false),
      @document.TableRow(children=[], is_header=false),
      @document.TableRow(children=[cell(1, 1), cell(1, 1)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(stripped),
  )
  assert_true(dropped is None)
  assert_true(
    stripped.map(entry => entry.code).contains("docx.table_grid_unsupported"),
  )
  // an empty row with NO active merge still just drops
  let plain : Array[DumpResidual] = []
  let survives = docx_table_params(
    [
      @document.TableRow(children=[], is_header=false),
      @document.TableRow(children=[cell(1, 1)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(plain),
  )
  assert_true(survives is Some(_))
  assert_true(plain.map(entry => entry.code).contains("docx.empty_row_dropped"))
  // truly ragged (no merge coverage) still residualizes
  let ragged : Array[DumpResidual] = []
  let rejected = docx_table_params(
    [
      @document.TableRow(children=[cell(1, 1), cell(1, 1)], is_header=false),
      @document.TableRow(children=[cell(1, 1)], is_header=false),
    ],
    @document.TableProperties::{ style_id: None, style_name: None },
    0,
    wb_ctx(ragged),
  )
  assert_true(rejected is None)
  assert_true(
    ragged.map(entry => entry.code).contains("docx.table_grid_unsupported"),
  )
}

///|
/// Kimi #204: a whitespace-only alt is blank to the parser and must
/// drop, not abort.
test "blank image alt drops with disclosure" {
  let residual : Array[DumpResidual] = []
  let ctx = wb_ctx(residual)
  let out : Array[Json] = []
  docx_run_specs(
    [
      @document.Image(@document.Image::{
        content_type: "image/png",
        alt_text: Some(" "),
        data: b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0d\x49\x44\x41\x54\x78\x9c\x63\xf8\xcf\xc0\xf0\x1f\x00\x00\x00\x05\x00\x01\x5f\xc9\x8e\xd2\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82",
      }),
    ],
    @document.run_properties(),
    0,
    ctx,
    out,
    in_note_body=false,
    plain=false,
  )
  // the image op emits without alt; the blank alt is disclosed
  let mut has_image = false
  for spec in out {
    if spec.stringify().contains("\"image\":") {
      has_image = true
      assert_false(spec.stringify().contains("\"alt\""))
    }
  }
  assert_true(has_image)
  assert_true(
    residual.map(entry => entry.code).contains("docx.image_alt_dropped"),
  )
}
