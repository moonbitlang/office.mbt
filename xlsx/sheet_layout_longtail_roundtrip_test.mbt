///|
/// Sheet protection round-trips every permission flag; passwords are write-
/// only — the options getter never exposes the stored hash (it cannot be
/// reversed), so `password` reads back empty for both the legacy and the
/// SHA-512 variants while `algorithm_name` and the flags survive.
test "sheet protection round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Legacy"))
  ignore(workbook.add_sheet("Hashed"))
  workbook.protect_sheet(
    "Legacy",
    @xlsx.SheetProtectionOptions::with_values(
      password="pw",
      auto_filter=true,
      delete_columns=true,
      delete_rows=true,
      edit_objects=true,
      edit_scenarios=true,
      format_cells=true,
      format_columns=true,
      format_rows=true,
      insert_columns=true,
      insert_hyperlinks=true,
      insert_rows=true,
      pivot_tables=true,
      select_locked_cells=true,
      select_unlocked_cells=true,
      sort=true,
    ),
  )
  workbook.protect_sheet(
    "Hashed",
    @xlsx.SheetProtectionOptions::with_values(
      algorithm_name="SHA-512",
      password="secret",
      sort=true,
      auto_filter=true,
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let legacy = parsed.get_sheet_protection("Legacy")
  debug_inspect(
    legacy,
    content=(
      #|{
      #|  algorithm_name: "",
      #|  password: "",
      #|  auto_filter: true,
      #|  delete_columns: true,
      #|  delete_rows: true,
      #|  edit_objects: true,
      #|  edit_scenarios: true,
      #|  format_cells: true,
      #|  format_columns: true,
      #|  format_rows: true,
      #|  insert_columns: true,
      #|  insert_hyperlinks: true,
      #|  insert_rows: true,
      #|  pivot_tables: true,
      #|  select_locked_cells: true,
      #|  select_unlocked_cells: true,
      #|  sort: true,
      #|}
    ),
  )
  let hashed = parsed.get_sheet_protection("Hashed")
  inspect(hashed.algorithm_name, content="SHA-512")
  inspect(hashed.password.length() > 0, content="false")
  inspect(
    "\{hashed.sort} \{hashed.auto_filter} \{hashed.delete_rows}",
    content="true true false",
  )
}

///|
/// Page margins, page layout, and odd/even header-footer settings round-trip
/// through write + read.
test "page margins layout and header footer round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_page_margins(
    "Sheet1",
    Some(
      @xlsx.PageLayoutMarginsOptions::with_values(
        top=0.5,
        bottom=0.75,
        left=0.25,
        right=0.3,
        header=0.2,
        footer=0.4,
        horizontally=true,
        vertically=true,
      ),
    ),
  )
  workbook.set_page_layout(
    "Sheet1",
    Some(
      @xlsx.PageLayoutOptions::with_values(
        size=9,
        orientation="landscape",
        first_page_number=7,
        adjust_to=85,
        fit_to_height=2,
        fit_to_width=3,
        black_and_white=true,
        page_order="overThenDown",
      ),
    ),
  )
  workbook.set_header_footer(
    "Sheet1",
    Some(
      @xlsx.HeaderFooterOptions::with_values(
        align_with_margins=false,
        scale_with_doc=false,
        different_odd_even=true,
        different_first=true,
        odd_header="&LOdd Head",
        odd_footer="&ROdd Foot",
        even_header="&CEven Head",
        even_footer="&LEven Foot",
        first_header="&CFirst Head",
        first_footer="&CFirst Foot",
      ),
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_page_margins("Sheet1"),
    content=(
      #|{
      #|  top: Some(0.5),
      #|  bottom: Some(0.75),
      #|  left: Some(0.25),
      #|  right: Some(0.3),
      #|  header: Some(0.2),
      #|  footer: Some(0.4),
      #|  horizontally: Some(true),
      #|  vertically: Some(true),
      #|}
    ),
  )
  debug_inspect(
    parsed.get_page_layout("Sheet1"),
    content=(
      #|{
      #|  size: Some(9),
      #|  orientation: Some("landscape"),
      #|  first_page_number: Some(7),
      #|  adjust_to: Some(85),
      #|  fit_to_height: Some(2),
      #|  fit_to_width: Some(3),
      #|  black_and_white: Some(true),
      #|  page_order: Some("overThenDown"),
      #|}
    ),
  )
  debug_inspect(
    parsed.get_header_footer("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    align_with_margins: Some(false),
      #|    different_first: true,
      #|    different_odd_even: true,
      #|    scale_with_doc: Some(false),
      #|    odd_header: "&LOdd Head",
      #|    odd_footer: "&ROdd Foot",
      #|    even_header: "&CEven Head",
      #|    even_footer: "&LEven Foot",
      #|    first_header: "&CFirst Head",
      #|    first_footer: "&CFirst Foot",
      #|  },
      #|)
    ),
  )
}

///|
/// Sheet properties (tab colors in all encodings, widths, outline flags) and
/// a fully-populated sheet view round-trip through write + read.
test "sheet props and sheet view round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_sheet_props(
    "Sheet1",
    Some(
      @xlsx.SheetPropsOptions::with_values(
        code_name="CodeSheet",
        enable_format_conditions_calculation=false,
        published=false,
        auto_page_breaks=false,
        fit_to_page=true,
        tab_color_theme=5,
        tab_color_tint=-0.3,
        outline_summary_below=false,
        outline_summary_right=false,
        base_col_width=12,
        default_col_width=11.5,
        default_row_height=17.25,
        custom_height=true,
        zero_height=true,
        thick_top=true,
        thick_bottom=true,
      ),
    ),
  )
  workbook.set_sheet_view(
    "Sheet1",
    0,
    @xlsx.SheetViewOptions::with_values(
      default_grid_color=false,
      right_to_left=false,
      show_formulas=true,
      show_grid_lines=false,
      show_row_col_headers=false,
      show_ruler=false,
      show_zeros=false,
      top_left_cell="B2",
      view="pageLayout",
      zoom_scale=140,
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_sheet_props("Sheet1"),
    content=(
      #|{
      #|  code_name: Some("CodeSheet"),
      #|  enable_format_conditions_calculation: Some(false),
      #|  published: Some(false),
      #|  auto_page_breaks: Some(false),
      #|  fit_to_page: Some(true),
      #|  tab_color_indexed: None,
      #|  tab_color_rgb: None,
      #|  tab_color_theme: Some(5),
      #|  tab_color_tint: Some(-0.3),
      #|  outline_summary_below: Some(false),
      #|  outline_summary_right: Some(false),
      #|  base_col_width: Some(12),
      #|  default_col_width: Some(11.5),
      #|  default_row_height: Some(17.25),
      #|  custom_height: Some(true),
      #|  zero_height: Some(true),
      #|  thick_top: Some(true),
      #|  thick_bottom: Some(true),
      #|}
    ),
  )
  debug_inspect(
    parsed.get_sheet_view("Sheet1", 0),
    content=(
      #|{
      #|  default_grid_color: Some(false),
      #|  right_to_left: Some(false),
      #|  show_formulas: Some(true),
      #|  show_grid_lines: Some(false),
      #|  show_row_col_headers: Some(false),
      #|  show_ruler: Some(false),
      #|  show_zeros: Some(false),
      #|  top_left_cell: Some("B2"),
      #|  view: Some("pageLayout"),
      #|  zoom_scale: Some(140),
      #|}
    ),
  )
}

///|
/// Auto-filter column criteria survive the write + read cycle (the getter on
/// a freshly parsed workbook exercises the filterColumn parser, not just the
/// in-memory model).
test "auto filter criteria round-trip through read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  for i, header in ["Name", "Qty", "Price"] {
    workbook.set_cell("Sheet1", "\{["A", "B", "C"][i]}1", header)
  }
  workbook.set_cell("Sheet1", "A2", "widget")
  let sheet = workbook.sheet("Sheet1").unwrap()
  sheet.set_cell_value("B2", Numeric(10.0))
  sheet.set_cell_value("C2", Numeric(3.5))
  let options : Array[@xlsx.AutoFilterOption] = [
    { column: "B", expression: "x == 10" },
    { column: "C", expression: "x > 5" },
  ]
  workbook.set_auto_filter("Sheet1", "A1:C3", options)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_auto_filter("Sheet1"),
    content=(
      #|Some(
      #|  {
      #|    range_ref: "A1:C3",
      #|    columns: [
      #|      { col: 2, filters: Some(["10"]), custom_filters: None },
      #|      {
      #|        col: 3,
      #|        filters: None,
      #|        custom_filters: Some(
      #|          {
      #|            and_filter: false,
      #|            filters: [{ operator: "greaterThan", value: "5" }],
      #|          },
      #|        ),
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}

///|
/// Page breaks written by insert_page_break survive a read + write cycle:
/// the second package still contains both the row and the column break.
test "page breaks survive read and rewrite" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "E30", "data")
  workbook.insert_page_break("Sheet1", "A25")
  workbook.insert_page_break("Sheet1", "C1")
  let reread = @xlsx.read(@xlsx.write(workbook))
  let second = @xlsx.write(reread)
  let archive = @zip.read(second)
  let sheet_xml = @encoding/utf8.decode(
    archive.get("xl/worksheets/sheet1.xml").unwrap(),
  )
  inspect(sheet_xml.contains("<rowBreaks"), content="true")
  inspect(sheet_xml.contains("<colBreaks"), content="true")
  inspect(sheet_xml.contains("<brk id=\"24\""), content="true")
  inspect(sheet_xml.contains("<brk id=\"2\""), content="true")
}

///|
/// Sparkline groups with the long-tail options (date axis, hidden, custom
/// colors, manual axis bounds, empty-cell handling) survive read + rewrite.
test "sparkline long-tail options survive read and rewrite" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = workbook.sheet("Sheet1").unwrap()
  for i in 1..<=5 {
    sheet.set_cell_value(
      "A\{i}",
      Numeric(Double::from_int(i * (if i % 2 == 0 { -1 } else { 1 }))),
    )
  }
  let opts = @xlsx.SparklineOptions::new(["D1"], ["Sheet1!A1:A5"])
  opts.set_style(12)
  opts.set_markers(true)
  opts.set_high(true)
  opts.set_low(true)
  opts.set_negative_color("#FF0000")
  opts.set_markers_color("#00FF00")
  opts.set_high_color("#0000FF")
  opts.set_low_color("#00FFFF")
  opts.set_first_color("#123456")
  opts.set_last_color("#654321")
  opts.set_series_color("#ABCDEF")
  opts.set_axis(true)
  opts.set_reverse(true)
  opts.set_hidden(true)
  opts.set_manual_min(-9)
  opts.set_manual_max(9)
  opts.set_empty_cells("zero")
  workbook.add_sparkline_options("Sheet1", opts)
  let reread = @xlsx.read(@xlsx.write(workbook))
  let second = @xlsx.write(reread)
  let archive = @zip.read(second)
  let sheet_xml = @encoding/utf8.decode(
    archive.get("xl/worksheets/sheet1.xml").unwrap(),
  )
  inspect(sheet_xml.contains("x14:sparklineGroup"), content="true")
  inspect(
    sheet_xml.contains("negative=\"1\""),
    content=(
      #|false
    ),
  )
  inspect(sheet_xml.contains("displayHidden=\"1\""), content="true")
  inspect(sheet_xml.contains("rightToLeft=\"1\""), content="true")
  inspect(sheet_xml.contains("manualMin=\"-9\""), content="true")
  inspect(sheet_xml.contains("manualMax=\"9\""), content="true")
  inspect(sheet_xml.contains("displayEmptyCellsAs=\"zero\""), content="true")
}

///|
/// Core document properties round-trip with every field populated.
test "doc props full round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_doc_props(
    @xlsx.CoreProperties::with_values(
      title="Title",
      subject="Subject",
      creator="Creator",
      keywords="k1;k2",
      description="Desc",
      last_modified_by="Editor",
      language="en-US",
      identifier="ID-1",
      revision="3",
      content_status="Final",
      category="Cat",
      version="1.2.3",
      created="2024-02-29T01:02:03Z",
      modified="2024-03-01T04:05:06Z",
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let props = parsed.get_doc_props()
  inspect(
    "\{props.title}|\{props.subject}|\{props.creator}|\{props.keywords}|\{props.description}",
    content="Title|Subject|Creator|k1;k2|Desc",
  )
  inspect(
    "\{props.last_modified_by}|\{props.language}|\{props.identifier}|\{props.revision}",
    content="Editor|en-US|ID-1|3",
  )
  inspect(
    "\{props.content_status}|\{props.category}|\{props.version}",
    content="Final|Cat|1.2.3",
  )
  inspect(
    "\{props.created}|\{props.modified}",
    content="2024-02-29T01:02:03Z|2024-03-01T04:05:06Z",
  )
}

///|
/// Defined names (workbook and sheet scope) are adjusted when rows and
/// columns are inserted or removed before the referenced range.
test "defined names adjust on row and column edits" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(
    @xlsx.DefinedName::new("data_block", "Sheet1!$B$5:$D$10"),
  )
  workbook.set_defined_name(
    @xlsx.DefinedName::new("local_cell", "Sheet1!$C$8", scope="Sheet1"),
  )
  // insert 2 rows above the range: rows shift down
  workbook.insert_rows("Sheet1", 2, 2)
  // remove column A: columns shift left
  workbook.remove_cols("Sheet1", 1, 1)
  let names = workbook.defined_names()
  let summary = StringBuilder()
  for name in names {
    summary.write_string("\{name.name}=\{name.refers_to}\n")
  }
  inspect(
    summary.to_string(),
    content=(
      #|data_block=Sheet1!$A$7:$C$12
      #|local_cell=Sheet1!$B$10
      #|
    ),
  )
  // and the adjusted names survive a write + read cycle
  let parsed = @xlsx.read(@xlsx.write(workbook))
  inspect(parsed.defined_names().length(), content="2")
}
