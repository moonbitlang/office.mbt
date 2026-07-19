///|
/// Register a style, apply it to the next free cell in column A, and return
/// its style id so the parsed workbook can be interrogated.
fn apply_style(
  workbook : @xlsx.Workbook,
  row : Int,
  style : @xlsx.Style,
) -> Int raise {
  let style_id = workbook.new_style(style)
  workbook.set_cell("Sheet1", "A\{row}", "styled \{row}")
  workbook.set_cell_style("Sheet1", "A\{row}", style_id)
  style_id
}

///|
/// Cell styles (not dxf) with long-tail fills survive write + read: gradient
/// fills across linear and path shading variants with transparency, a
/// pattern fill with a background color, and theme/indexed colors with tint.
test "cell style gradient and pattern fills round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    apply_style(
      workbook,
      1,
      @xlsx.Style::fill(@xlsx.Fill::gradient("#FF0000", "#0000FF")),
    ),
  )
  ignore(
    apply_style(
      workbook,
      2,
      @xlsx.Style::fill(
        @xlsx.Fill::gradient("#00FF00", "#FFFF00", shading=5, transparency=40),
      ),
    ),
  )
  ignore(
    apply_style(
      workbook,
      3,
      @xlsx.Style::fill(@xlsx.Fill::gradient("#112233", "#445566", shading=14)),
    ),
  )
  ignore(
    apply_style(
      workbook,
      4,
      @xlsx.Style::fill(@xlsx.Fill::gradient("#ABCDEF", "#FEDCBA", shading=16)),
    ),
  )
  ignore(
    apply_style(
      workbook,
      5,
      @xlsx.Style::fill(@xlsx.Fill::solid_bg_theme(7, tint=0.25)),
    ),
  )
  ignore(
    apply_style(
      workbook,
      6,
      @xlsx.Style::fill(@xlsx.Fill::solid_bg_indexed(22, tint=-0.15)),
    ),
  )
  ignore(
    apply_style(
      workbook,
      7,
      @xlsx.Style::fill(@xlsx.Fill::solid("#336699", transparency=30)),
    ),
  )
  ignore(
    apply_style(
      workbook,
      8,
      @xlsx.Style::fill(@xlsx.Fill::solid_indexed(40, tint=0.1)),
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let summary = StringBuilder()
  for row in 1..<=8 {
    let style = parsed.get_style(
      parsed.get_cell_style("Sheet1", "A\{row}").unwrap(),
    )
    match style.fill {
      Some(fill) =>
        summary.write_string(
          "A\{row}: typ=\{to_repr(fill.typ)} pattern=\{to_repr(fill.pattern)} shading=\{to_repr(fill.shading)} colors=\{to_repr(fill.colors)} transparency=\{to_repr(fill.transparency)} fg=\{to_repr(fill.fg_theme)}/\{to_repr(fill.fg_indexed)}/\{to_repr(fill.fg_tint)} bg=\{to_repr(fill.bg_theme)}/\{to_repr(fill.bg_indexed)}/\{to_repr(fill.bg_tint)}\n",
        )
      None => summary.write_string("A\{row}: no fill\n")
    }
  }
  inspect(
    summary.to_string(),
    content=(
      #|A1: typ=Some("gradient") pattern=None shading=Some(0) colors=Some(["FF0000", "0000FF"]) transparency=None fg=None/None/None bg=None/None/None
      #|A2: typ=Some("gradient") pattern=None shading=Some(5) colors=Some(["00FF00", "FFFF00"]) transparency=Some(40) fg=None/None/None bg=None/None/None
      #|A3: typ=Some("gradient") pattern=None shading=Some(14) colors=Some(["112233", "445566"]) transparency=None fg=None/None/None bg=None/None/None
      #|A4: typ=Some("gradient") pattern=None shading=Some(16) colors=Some(["ABCDEF", "FEDCBA"]) transparency=None fg=None/None/None bg=None/None/None
      #|A5: typ=Some("pattern") pattern=Some(1) shading=None colors=None transparency=None fg=None/None/None bg=Some(7)/None/Some(0.25)
      #|A6: typ=Some("pattern") pattern=Some(1) shading=None colors=None transparency=None fg=None/None/None bg=None/Some(22)/Some(-0.15)
      #|A7: typ=Some("pattern") pattern=Some(1) shading=None colors=Some(["336699"]) transparency=Some(30) fg=None/None/None bg=None/None/None
      #|A8: typ=Some("pattern") pattern=Some(1) shading=None colors=None transparency=None fg=None/Some(40)/Some(0.1) bg=None/None/None
      #|
    ),
  )
}

///|
/// Cell-style fonts with the long-tail flags (outline/condense/extended, an
/// underline value, theme color with tint) and borders with per-side styles
/// survive write + read; the two diagonal entries collapse to the first
/// one's style and color (single OOXML <diagonal> element).
test "cell style font and border long-tail round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font_style = @xlsx.Style::font(
    @xlsx.Font::with_values(
      bold=true,
      strike=true,
      outline=true,
      shadow=true,
      condense=true,
      extended=true,
      underline="doubleAccounting",
      size=9.5,
      color_theme=3,
      color_tint=-0.4,
      charset=204,
      // family 2 is the writer default and is folded back to None on read
      // (read.mbt keeps family only when != 2), so use 3 to round-trip
      family_number=3,
      scheme="minor",
      vert_align="superscript",
      family="Georgia",
    ),
  )
  ignore(apply_style(workbook, 1, font_style))
  // OOXML has a single <diagonal> element, so the writer keeps the FIRST
  // diagonal entry's style/color for both directions: diagonalDown's
  // style 9 / #00CED1 below collapse to diagonalUp's 8 / #FF8C00 on read.
  let border_style = @xlsx.Style::border([
    @xlsx.Border::with_values("left", color="#8B0000", style=4),
    @xlsx.Border::with_values("right", color="#006400", style=5),
    @xlsx.Border::with_values("top", color="#00008B", style=6),
    @xlsx.Border::with_values("bottom", color="#8B008B", style=7),
    @xlsx.Border::with_values("diagonalUp", color="#FF8C00", style=8),
    @xlsx.Border::with_values("diagonalDown", color="#00CED1", style=9),
  ])
  ignore(apply_style(workbook, 2, border_style))
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let font_back = parsed.get_style(
    parsed.get_cell_style("Sheet1", "A1").unwrap(),
  )
  debug_inspect(
    font_back.font,
    content=(
      #|Some(
      #|  {
      #|    bold: Some(true),
      #|    italic: None,
      #|    strike: Some(true),
      #|    outline: Some(true),
      #|    shadow: Some(true),
      #|    condense: Some(true),
      #|    extended: Some(true),
      #|    underline: Some("doubleAccounting"),
      #|    size: Some(9.5),
      #|    color: None,
      #|    color_theme: Some(3),
      #|    color_indexed: None,
      #|    color_tint: Some(-0.4),
      #|    charset: Some(204),
      #|    family_number: Some(3),
      #|    scheme: Some("minor"),
      #|    vert_align: Some("superscript"),
      #|    family: Some("Georgia"),
      #|  },
      #|)
    ),
  )
  let border_back = parsed.get_style(
    parsed.get_cell_style("Sheet1", "A2").unwrap(),
  )
  debug_inspect(
    border_back.border,
    content=(
      #|Some(
      #|  [
      #|    { typ: "left", color: Some("8B0000"), style: Some(4) },
      #|    { typ: "right", color: Some("006400"), style: Some(5) },
      #|    { typ: "top", color: Some("00008B"), style: Some(6) },
      #|    { typ: "bottom", color: Some("8B008B"), style: Some(7) },
      #|    { typ: "diagonalUp", color: Some("FF8C00"), style: Some(8) },
      #|    { typ: "diagonalDown", color: Some("FF8C00"), style: Some(8) },
      #|  ],
      #|)
    ),
  )
}

///|
/// Excelize-compatible number-format constructors: currency ids resolve to
/// their format codes with adjustable decimal places and negative-red, and
/// the documented validation errors are pinned.
test "excelize currency and custom number formats" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(apply_style(workbook, 1, @xlsx.Style::excelize_currency_num_fmt(165)))
  ignore(
    apply_style(
      workbook,
      2,
      @xlsx.Style::excelize_currency_num_fmt(
        164,
        decimal_places=0,
        neg_red=true,
      ),
    ),
  )
  ignore(
    apply_style(
      workbook,
      3,
      @xlsx.Style::excelize_currency_num_fmt(166, decimal_places=4),
    ),
  )
  ignore(
    apply_style(
      workbook,
      4,
      @xlsx.Style::excelize_custom_num_fmt("0.000%;[Red]-0.000%"),
    ),
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let summary = StringBuilder()
  for row in 1..<=4 {
    let style = parsed.get_style(
      parsed.get_cell_style("Sheet1", "A\{row}").unwrap(),
    )
    summary.write_string("A\{row}: \{to_repr(style.number_format)}\n")
  }
  inspect(
    summary.to_string(),
    content=(
      #|A1: Some(Custom("[$$-409]#,##0.00"))
      #|A2: Some(Custom("\"¥\"#,##0;[Red]\"¥\"#,##0"))
      #|A3: Some(Custom("[$$-45C]#,##0.0000"))
      #|A4: Some(Custom("0.000%;[Red]-0.000%"))
      #|
    ),
  )
  let errors = StringBuilder()
  let decimal_err = @test.expect_error(() => {
    @xlsx.Style::excelize_currency_num_fmt(165, decimal_places=31)
  })
  errors.write_string("decimal 31 => \{repr(decimal_err)}\n")
  let unknown_err = @test.expect_error(() => {
    @xlsx.Style::excelize_currency_num_fmt(9999)
  })
  errors.write_string("unknown id => \{repr(unknown_err)}\n")
  let empty_err = @test.expect_error(() => {
    @xlsx.Style::excelize_custom_num_fmt("")
  })
  errors.write_string("empty custom => \{repr(empty_err)}\n")
  inspect(
    errors.to_string(),
    content=(
      #|decimal 31 => InvalidOptions(msg="decimal places must be in [0, 30]")
      #|unknown id => InvalidOptions(msg="unknown excelize currency number format")
      #|empty custom => InvalidOptions(msg="custom number format can not be empty")
      #|
    ),
  )
}
