///|
/// Helper: attach one rule to a range with common tweaks applied via a
/// configuration callback, so each family below stays one line.
fn cf_rule(
  format_type : String,
  configure : (@xlsx.ConditionalFormatOptions) -> Unit,
) -> @xlsx.ConditionalFormatOptions {
  let opt = @xlsx.ConditionalFormatOptions::new(format_type)
  configure(opt)
  opt
}

///|
/// Every conditional-format rule family round-trips through write + read:
/// cell operators, text operators, all time periods, average/top10 variants,
/// duplicates, blanks/errors, color scales, data bars, formulas, icon sets.
test "conditional format families round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set = (range : String, opt : @xlsx.ConditionalFormatOptions) => {
    workbook.set_conditional_format("Sheet1", range, [opt])
  }
  set(
    "A1:A5",
    cf_rule("cell", opt => {
      opt.set_criteria("between")
      opt.set_min_value("2")
      opt.set_max_value("8")
    }),
  )
  set(
    "B1:B5",
    cf_rule("cell", opt => {
      opt.set_criteria("!=")
      opt.set_value("5")
    }),
  )
  set(
    "C1:C5",
    cf_rule("cell", opt => {
      opt.set_criteria("<=")
      opt.set_value("3")
    }),
  )
  set(
    "D1:D5",
    cf_rule("text", opt => {
      opt.set_criteria("begins with")
      opt.set_value("ab")
    }),
  )
  set(
    "E1:E5",
    cf_rule("text", opt => {
      opt.set_criteria("ends with")
      opt.set_value("yz")
    }),
  )
  set(
    "F1:F5",
    cf_rule("text", opt => {
      opt.set_criteria("containing")
      opt.set_value("mid")
    }),
  )
  set(
    "G1:G5",
    cf_rule("text", opt => {
      opt.set_criteria("not containing")
      opt.set_value("xx")
    }),
  )
  set("H1:H5", cf_rule("time_period", opt => opt.set_criteria("yesterday")))
  set("I1:I5", cf_rule("time_period", opt => opt.set_criteria("tomorrow")))
  set("J1:J5", cf_rule("time_period", opt => opt.set_criteria("last 7 days")))
  set(
    "K1:K5",
    cf_rule("time_period", opt => opt.set_criteria("continue month")),
  )
  set("L1:L5", cf_rule("time_period", opt => opt.set_criteria("this week")))
  set("M1:M5", cf_rule("time_period", opt => opt.set_criteria("last month")))
  set("N1:N5", cf_rule("average", opt => opt.set_above_average(true)))
  set("O1:O5", cf_rule("average", opt => opt.set_above_average(false)))
  set(
    "P1:P5",
    cf_rule("top", opt => {
      opt.set_value("10")
      opt.set_percent(true)
    }),
  )
  set("Q1:Q5", cf_rule("bottom", opt => opt.set_value("5")))
  set("R1:R5", cf_rule("duplicate", _opt => ()))
  set("S1:S5", cf_rule("unique", _opt => ()))
  set("T1:T5", cf_rule("blanks", _opt => ()))
  set("U1:U5", cf_rule("no_blanks", _opt => ()))
  set("V1:V5", cf_rule("errors", _opt => ()))
  set("W1:W5", cf_rule("no_errors", _opt => ()))
  set(
    "X1:X5",
    cf_rule("2_color_scale", opt => {
      opt.set_min_type("num")
      opt.set_min_value("0")
      opt.set_min_color("#FFEE90")
      opt.set_max_type("percent")
      opt.set_max_value("90")
      opt.set_max_color("#00FF00")
    }),
  )
  set(
    "Y1:Y5",
    cf_rule("3_color_scale", opt => {
      opt.set_min_type("min")
      opt.set_min_color("#FF0000")
      opt.set_mid_type("percentile")
      opt.set_mid_value("60")
      opt.set_mid_color("#FFFF00")
      opt.set_max_type("max")
      opt.set_max_color("#0000FF")
    }),
  )
  set(
    "Z1:Z5",
    cf_rule("data_bar", opt => {
      opt.set_min_type("min")
      opt.set_max_type("max")
      opt.set_bar_color("#638EC6")
      opt.set_bar_border_color("#FF0000")
      opt.set_bar_direction("rightToLeft")
      opt.set_bar_solid(true)
      opt.set_bar_only(true)
    }),
  )
  set(
    "AA1:AA5",
    cf_rule("formula", opt => {
      opt.set_criteria("$AA1>0")
      opt.set_stop_if_true(true)
    }),
  )
  set(
    "AB1:AB5",
    cf_rule("icon_set", opt => {
      opt.set_icon_style("4Rating")
      opt.set_reverse_icons(true)
    }),
  )
  set(
    "AC1:AC5",
    cf_rule("icon_set", opt => {
      opt.set_icon_style("5Rating")
      opt.set_icons_only(true)
    }),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let formats = parsed.get_conditional_formats("Sheet1")
  let summary = StringBuilder()
  let ranges = formats.keys().collect()
  ranges.sort()
  for range in ranges {
    for opt in formats.get(range).unwrap() {
      summary.write_string(
        "\{range}|\{opt.format_type}|\{opt.criteria}|\{opt.value}\n",
      )
    }
  }
  inspect(
    summary.to_string(),
    content=(
      #|A1:A5|cell|between|
      #|B1:B5|cell|not equal to|5
      #|C1:C5|cell|less than or equal to|3
      #|D1:D5|text|begins with|ab
      #|E1:E5|text|ends with|yz
      #|F1:F5|text|containing|mid
      #|G1:G5|text|not containing|xx
      #|H1:H5|time_period|yesterday|
      #|I1:I5|time_period|tomorrow|
      #|J1:J5|time_period|last 7 days|
      #|K1:K5|time_period|continue month|
      #|L1:L5|time_period|this week|
      #|M1:M5|time_period|last month|
      #|N1:N5|average|=|
      #|O1:O5|average|=|
      #|P1:P5|top|=|10
      #|Q1:Q5|bottom|=|5
      #|R1:R5|duplicate|=|
      #|S1:S5|unique|=|
      #|T1:T5|blanks||
      #|U1:U5|no_blanks||
      #|V1:V5|errors||
      #|W1:W5|no_errors||
      #|X1:X5|2_color_scale|=|
      #|Y1:Y5|3_color_scale|=|
      #|Z1:Z5|data_bar|=|
      #|AA1:AA5|formula|$AA1>0|
      #|AB1:AB5|icon_set||
      #|AC1:AC5|icon_set||
      #|
    ),
  )
  // spot-check structured details beyond the type/criteria triple
  let scale = formats.get("Y1:Y5").unwrap()[0]
  inspect(
    "\{scale.min_type}/\{scale.mid_type}/\{scale.max_type} mid=\{scale.mid_value}",
    content=(
      #|min/percentile/max mid=60
    ),
  )
  let bar = formats.get("Z1:Z5").unwrap()[0]
  inspect(
    "\{bar.bar_direction} solid=\{bar.bar_solid} only=\{bar.bar_only} border=\{bar.bar_border_color}",
    content=(
      #|rightToLeft solid=true only=true border=#FF0000
    ),
  )
  let icons = formats.get("AB1:AB5").unwrap()[0]
  inspect(
    "\{icons.icon_style} reverse=\{icons.reverse_icons}",
    content=(
      #|4Rating reverse=true
    ),
  )
  let top = formats.get("P1:P5").unwrap()[0]
  inspect(
    "\{top.format_type} \{top.value} percent=\{top.percent}",
    content=(
      #|top 10 percent=true
    ),
  )
  let between = formats.get("A1:A5").unwrap()[0]
  inspect(
    "\{between.criteria} min=\{between.min_value} max=\{between.max_value}",
    content=(
      #|between min=2 max=8
    ),
  )
}

///|
/// A differential (dxf) style carrying long-tail font, border, fill,
/// alignment, and protection settings survives write + read.
test "conditional dxf long-tail style round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let style = @xlsx.Style::font(
      @xlsx.Font::with_values(
        bold=true,
        italic=true,
        strike=true,
        outline=true,
        shadow=true,
        condense=true,
        extended=true,
        underline="double",
        size=13.5,
        color="#336699",
        vert_align="superscript",
        family="Consolas",
      ),
    )
    .with_fill(@xlsx.Fill::pattern(pattern=9, color="#FFCC00"))
    .with_border([
      @xlsx.Border::with_values("left", color="#FF0000", style=2),
      @xlsx.Border::with_values("right", color="#00FF00", style=3),
      @xlsx.Border::with_values("diagonalUp", color="#0000FF", style=1),
      @xlsx.Border::with_values("diagonalDown", color="#0000FF", style=1),
    ])
    .with_alignment(
      @xlsx.Alignment::with_values(
        horizontal="center",
        vertical="top",
        wrap_text=true,
        text_rotation=45,
        indent=2,
        shrink_to_fit=true,
        justify_last_line=true,
        reading_order=2,
        relative_indent=1,
      ),
    )
  let format_id = workbook.new_conditional_style(style)
  let opt = @xlsx.ConditionalFormatOptions::new("cell")
  opt.set_criteria(">")
  opt.set_value("0")
  opt.set_format(Some(format_id))
  let protection_id = workbook.new_conditional_style(
    @xlsx.Style::protection(
      @xlsx.Protection::with_values(hidden=true, locked=false),
    ),
  )
  let opt_protect = @xlsx.ConditionalFormatOptions::new("cell")
  opt_protect.set_criteria("<")
  opt_protect.set_value("0")
  opt_protect.set_format(Some(protection_id))
  workbook.set_conditional_format("Sheet1", "A1:B4", [opt, opt_protect])
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let parsed_opts = parsed
    .get_conditional_formats("Sheet1")
    .get("A1:B4")
    .unwrap()
  let parsed_style = parsed.get_conditional_style(
    parsed_opts[0].format.unwrap(),
  )
  debug_inspect(
    parsed_style,
    content=(
      #|{
      #|  number_format: None,
      #|  num_fmt: None,
      #|  decimal_places: None,
      #|  custom_num_fmt: None,
      #|  neg_red: None,
      #|  font: Some(
      #|    {
      #|      bold: Some(true),
      #|      italic: Some(true),
      #|      strike: Some(true),
      #|      outline: Some(true),
      #|      shadow: Some(true),
      #|      condense: Some(true),
      #|      extended: Some(true),
      #|      underline: Some("double"),
      #|      size: Some(13.5),
      #|      color: Some("336699"),
      #|      color_theme: None,
      #|      color_indexed: None,
      #|      color_tint: None,
      #|      charset: None,
      #|      family_number: None,
      #|      scheme: None,
      #|      vert_align: Some("superscript"),
      #|      family: Some("Consolas"),
      #|    },
      #|  ),
      #|  fill: Some(
      #|    {
      #|      typ: Some("pattern"),
      #|      pattern: Some(9),
      #|      shading: None,
      #|      colors: Some(["FFCC00"]),
      #|      transparency: None,
      #|      fg_theme: None,
      #|      fg_indexed: None,
      #|      fg_tint: None,
      #|      bg_theme: None,
      #|      bg_indexed: None,
      #|      bg_tint: None,
      #|    },
      #|  ),
      #|  border: Some(
      #|    [
      #|      { typ: "left", color: Some("FF0000"), style: Some(2) },
      #|      { typ: "right", color: Some("00FF00"), style: Some(3) },
      #|      { typ: "diagonalUp", color: Some("0000FF"), style: Some(1) },
      #|      { typ: "diagonalDown", color: Some("0000FF"), style: Some(1) },
      #|    ],
      #|  ),
      #|  protection: None,
      #|  alignment: Some(
      #|    {
      #|      horizontal: Some("center"),
      #|      vertical: Some("top"),
      #|      wrap_text: Some(true),
      #|      text_rotation: Some(45),
      #|      indent: Some(2),
      #|      shrink_to_fit: Some(true),
      #|      justify_last_line: Some(true),
      #|      reading_order: Some(2),
      #|      relative_indent: Some(1),
      #|    },
      #|  ),
      #|}
    ),
  )
  let parsed_protection = parsed.get_conditional_style(
    parsed_opts[1].format.unwrap(),
  )
  debug_inspect(
    parsed_protection,
    content=(
      #|{
      #|  number_format: None,
      #|  num_fmt: None,
      #|  decimal_places: None,
      #|  custom_num_fmt: None,
      #|  neg_red: None,
      #|  font: None,
      #|  fill: None,
      #|  border: None,
      #|  protection: Some({ hidden: Some(true), locked: Some(false) }),
      #|  alignment: None,
      #|}
    ),
  )
}

///|
/// A dxf style using theme/tint colors and a builtin number format id also
/// survives; a second empty dxf writes the bare element.
test "conditional dxf theme colors and builtin numfmt round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let themed = @xlsx.Style::font(
    @xlsx.Font::with_values(
      color_theme=4,
      color_tint=-0.25,
      charset=1,
      scheme="minor",
    ),
  ).with_fill(@xlsx.Fill::solid_theme(5, tint=0.4))
  let themed_id = workbook.new_conditional_style(themed)
  let numfmt_id = workbook.new_conditional_style(
    @xlsx.Style::builtin_number_format(14),
  )
  let empty_id = workbook.new_conditional_style(@xlsx.Style::new())
  let opt_a = @xlsx.ConditionalFormatOptions::new("cell")
  opt_a.set_criteria(">")
  opt_a.set_value("1")
  opt_a.set_format(Some(themed_id))
  let opt_b = @xlsx.ConditionalFormatOptions::new("cell")
  opt_b.set_criteria("<")
  opt_b.set_value("1")
  opt_b.set_format(Some(numfmt_id))
  let opt_c = @xlsx.ConditionalFormatOptions::new("cell")
  opt_c.set_criteria("=")
  opt_c.set_value("1")
  opt_c.set_format(Some(empty_id))
  workbook.set_conditional_format("Sheet1", "C1:C9", [opt_a, opt_b, opt_c])
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let opts = parsed.get_conditional_formats("Sheet1").get("C1:C9").unwrap()
  inspect(opts.length(), content="3")
  let themed_back = parsed.get_conditional_style(opts[0].format.unwrap())
  debug_inspect(
    themed_back,
    content=(
      #|{
      #|  number_format: None,
      #|  num_fmt: None,
      #|  decimal_places: None,
      #|  custom_num_fmt: None,
      #|  neg_red: None,
      #|  font: Some(
      #|    {
      #|      bold: None,
      #|      italic: None,
      #|      strike: None,
      #|      outline: None,
      #|      shadow: None,
      #|      condense: None,
      #|      extended: None,
      #|      underline: None,
      #|      size: None,
      #|      color: None,
      #|      color_theme: Some(4),
      #|      color_indexed: None,
      #|      color_tint: Some(-0.25),
      #|      charset: Some(1),
      #|      family_number: None,
      #|      scheme: Some("minor"),
      #|      vert_align: None,
      #|      family: None,
      #|    },
      #|  ),
      #|  fill: Some(
      #|    {
      #|      typ: Some("pattern"),
      #|      pattern: Some(1),
      #|      shading: None,
      #|      colors: None,
      #|      transparency: None,
      #|      fg_theme: None,
      #|      fg_indexed: None,
      #|      fg_tint: None,
      #|      bg_theme: Some(5),
      #|      bg_indexed: None,
      #|      bg_tint: Some(0.4),
      #|    },
      #|  ),
      #|  border: None,
      #|  protection: None,
      #|  alignment: None,
      #|}
    ),
  )
  let numfmt_back = parsed.get_conditional_style(opts[1].format.unwrap())
  debug_inspect(
    numfmt_back,
    content=(
      #|{
      #|  number_format: Some(Builtin(14)),
      #|  num_fmt: None,
      #|  decimal_places: None,
      #|  custom_num_fmt: None,
      #|  neg_red: None,
      #|  font: None,
      #|  fill: None,
      #|  border: None,
      #|  protection: None,
      #|  alignment: None,
      #|}
    ),
  )
}

///|
/// Invalid option combinations raise instead of writing broken XML. The
/// exact error is pinned per case: option violations raise
/// InvalidConditionalFormat, while the malformed range raises InvalidCellRef
/// from range parsing ("NOT"/"A" parse as full-column refs and "RANGE"
/// overflows the column limit before conditional-format validation runs).
test "conditional format invalid options raise" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let cases : Array[(String, String, Array[@xlsx.ConditionalFormatOptions])] = [
    (
      "empty range",
      " ",
      [
        cf_rule("cell", opt => {
          opt.set_criteria(">")
          opt.set_value("1")
        }),
      ],
    ),
    (
      "between without min/max",
      "A1:A5",
      [cf_rule("cell", opt => opt.set_criteria("between"))],
    ),
    (
      "cell comparison without value",
      "A1:A5",
      [cf_rule("cell", opt => opt.set_criteria(">"))],
    ),
    (
      "unknown time period",
      "A1:A5",
      [cf_rule("time_period", opt => opt.set_criteria("fortnight"))],
    ),
    (
      "text rule without value",
      "A1:A5",
      [cf_rule("text", opt => opt.set_criteria("containing"))],
    ),
    (
      "unknown icon style",
      "A1:A5",
      [cf_rule("icon_set", opt => opt.set_icon_style("9Rings"))],
    ),
    ("unknown rule type", "A1:A5", [cf_rule("sparkles", _opt => ())]),
    ("malformed range", "NOT A RANGE", [cf_rule("duplicate", _opt => ())]),
  ]
  let summary = StringBuilder()
  for case in cases {
    let (label, range, rules) = case
    let err = @test.expect_error(() => {
      workbook.set_conditional_format("Sheet1", range, rules)
    })
    summary.write_string("\{label} => \{repr(err)}\n")
  }
  inspect(
    summary.to_string(),
    content=(
      #|empty range => InvalidConditionalFormat(msg="range is empty")
      #|between without min/max => InvalidConditionalFormat(msg="between criteria requires min/max")
      #|cell comparison without value => InvalidConditionalFormat(msg="cell criteria requires value")
      #|unknown time period => InvalidConditionalFormat(msg="criteria invalid")
      #|text rule without value => InvalidConditionalFormat(msg="text value required")
      #|unknown icon style => InvalidConditionalFormat(msg="icon set style invalid")
      #|unknown rule type => InvalidConditionalFormat(msg="type invalid")
      #|malformed range => InvalidCellRef(value="RANGE")
      #|
    ),
  )
}
