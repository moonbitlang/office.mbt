///|
test "gradient fills retain their colors and direction" {
  debug_inspect(
    @xlsx2html.style_css(
      @xlsx.Style::fill(@xlsx.Fill::gradient("FF0000", "0000FF", shading=1)),
    ),
    content="\"background-image:linear-gradient(0deg,#FF0000 0%,#0000FF 100%);\"",
  )
}

///|
test "symmetric and diagonal gradients keep their source stops" {
  debug_inspect(
    [
      @xlsx2html.style_css(
        @xlsx.Style::fill(@xlsx.Fill::gradient("112233", "445566", shading=2)),
      ),
      @xlsx2html.style_css(
        @xlsx.Style::fill(@xlsx.Fill::gradient("112233", "445566", shading=7)),
      ),
    ],
    content=(
      #|[
      #|  "background-image:linear-gradient(180deg,#112233 0%,#445566 50%,#112233 100%);",
      #|  "background-image:linear-gradient(345deg,#112233 0%,#445566 100%);",
      #|]
    ),
  )
}

///|
test "workbook colors are resolved without inventing absent theme colors" {
  let book = @xlsx.Workbook::new()
  let unknown = @xlsx.Style::font(@xlsx.Font::with_values(color_theme=10))
  let themed = @xlsx.Style::font(
    @xlsx.Font::with_values(color_theme=4, color_tint=0.5),
  )
  let invalid = @xlsx.Style::font(
    @xlsx.Font::with_values(color="112233", color_tint=2.0),
  )
  let indexed = @xlsx.Style::fill(@xlsx.Fill::solid_indexed(2))
  debug_inspect(
    (
      @xlsx2html.style_css(unknown, workbook=book),
      @xlsx2html.style_css(themed, workbook=book).contains("color:#"),
      @xlsx2html.style_css(themed),
      @xlsx2html.style_css(invalid, workbook=book),
      @xlsx2html.style_css(indexed, workbook=book),
    ),
    content="(\"\", true, \"\", \"\", \"background-color:#FF0000;\")",
  )
}

///|
test "underline and strike decorations coexist" {
  debug_inspect(
    @xlsx2html.style_css(
      @xlsx.Style::font(
        @xlsx.Font::with_values(strike=true, underline="single"),
      ),
    ),
    content="\"text-decoration:line-through underline;\"",
  )
}

///|
test "border styles retain their authored weight and line pattern" {
  debug_inspect(
    @xlsx2html.style_css(
      @xlsx.Style::border([
        @xlsx.Border::with_values("top", color="112233", style=5),
        @xlsx.Border::with_values("bottom", color="445566", style=6),
        @xlsx.Border::with_values("left", color="778899", style=3),
        @xlsx.Border::with_values("right", color="AABBCC", style=4),
      ]),
    ),
    content=(
      #|"border-top:3px solid #112233;border-bottom:3px double #445566;border-left:1px dashed #778899;border-right:1px dotted #AABBCC;"
    ),
  )
}

///|
test "malformed gradient colors cannot enter a stylesheet" {
  let css = @xlsx2html.style_css(
    @xlsx.Style::fill(
      @xlsx.Fill::gradient("</style><script>bad</script>", "0000FF"),
    ),
  )
  debug_inspect(
    (css.contains("linear-gradient("), css.contains("<")),
    content="(false, false)",
  )
}

///|
test "hash-prefixed gradient colors render before and after workbook serialization" {
  for (first, last) in [("#FF0000", "#0000FF"), ("#80FF0000", "#FF0000FF")] {
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Data"))
    workbook.set_cell_int("Data", "A1", 1)
    workbook.set_cell_style(
      "Data",
      "A1",
      workbook.new_style(@xlsx.Style::fill(@xlsx.Fill::gradient(first, last))),
    )
    let expected = "linear-gradient(180deg,#FF0000 0%,#0000FF 100%)"
    let direct = @xlsx2html.render_workbook(workbook, title="gradient")
    let restored = @xlsx.read(@xlsx.write(workbook).exact_view())
    debug_inspect(
      (
        direct.contains(expected),
        @xlsx2html.render_workbook(restored, title="gradient").contains(
          expected,
        ),
      ),
      content="(true, true)",
    )
  }
  for color in ["##FF0000", "#FF0000;", "#</style><script>x</script>"] {
    debug_inspect(
      @xlsx2html.style_css(
        @xlsx.Style::fill(@xlsx.Fill::gradient(color, "#0000FF")),
      ),
      content="\"\"",
    )
  }
}

///|
test "all linear gradient variants agree with serialized OOXML geometry" {
  let degrees = [90, 270, 90, 0, 180, 0, 45, 255, 45, 135, 315, 135]
  for shading, degree in degrees {
    let fill = @xlsx.Fill::gradient("#FF0000", "#0000FF", shading~)
    let style = @xlsx.Style::fill(fill)
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Data"))
    workbook.set_cell_int("Data", "A1", 1)
    workbook.set_cell_style("Data", "A1", workbook.new_style(style))
    let bytes = @xlsx.write(workbook)
    let archive = @zip.read(bytes)
    guard archive.get("xl/styles.xml") is Some(styles) else {
      fail("Missing workbook styles")
    }
    let xml = @utf8.decode(styles.exact_view())
    let opening = if degree == 0 {
      "<gradientFill>"
    } else {
      "<gradientFill degree=\"" + degree.to_string() + "\">"
    }
    let symmetric = shading is (2 | 5 | 8 | 11)
    let css = @xlsx2html.style_css(style)
    let stops : Array[String] = []
    for index, part in xml.split("<stop position=\"") {
      if index > 0 {
        guard part.find("\"") is Some(end) else {
          fail("Unterminated gradient stop")
        }
        stops.push(part[:end].to_owned())
      }
    }
    let expected_stops = if symmetric { ["0", "0.5", "1"] } else { ["0", "1"] }
    let css_stops = if symmetric {
      "#FF0000 0%,#0000FF 50%,#FF0000 100%"
    } else {
      "#FF0000 0%,#0000FF 100%"
    }
    let expected_css = "background-image:linear-gradient(" +
      ((degree + 90) % 360).to_string() +
      "deg," +
      css_stops +
      ");"
    let restored = @xlsx.read(bytes.exact_view())
    debug_inspect(
      (
        xml.contains(opening),
        stops == expected_stops,
        css == expected_css,
        @xlsx2html.render_workbook(workbook, title="Direct").contains(css),
        @xlsx2html.render_workbook(restored, title="Restored").contains(css),
      ),
      content="(true, true, true, true, true)",
    )
  }
  for shading in 12..<16 {
    debug_inspect(
      @xlsx2html.style_css(
        @xlsx.Style::fill(@xlsx.Fill::gradient("#FF0000", "#0000FF", shading~)),
      ),
      content="\"\"",
    )
  }
}
