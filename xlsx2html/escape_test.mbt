// Escaping and CSS-validation tests: everything workbook-derived must be
// neutralized before it reaches markup or the stylesheet.

///|
test "escape_html neutralizes markup and keeps clean text untouched" {
  inspect(
    @xlsx2html.escape_html("<script>alert('x & y')</script>"),
    content="&lt;script&gt;alert('x &amp; y')&lt;/script&gt;",
  )
  inspect(@xlsx2html.escape_html("plain text"), content="plain text")
  inspect(@xlsx2html.escape_html(""), content="")
}

///|
test "escape_html_attribute also escapes quotes" {
  inspect(
    @xlsx2html.escape_html_attribute("a\"b<c>&"),
    content="a&quot;b&lt;c&gt;&amp;",
  )
}

///|
test "css_color admits only strict hex" {
  debug_inspect(
    @xlsx2html.css_color("4472C4"),
    content=(
      #|Some("#4472C4")
    ),
  )
  debug_inspect(
    @xlsx2html.css_color("FF4472C4"),
    content=(
      #|Some("#4472C4")
    ),
  )
  for
    bad in [
      "", "FFF", "4472C", "4472C44", "</style><", "expression(", "红红红红红红",
      "4472CG", "”4472C4", "GG112233", "</style>4",
    ] {
    if @xlsx2html.css_color(bad) is Some(_) {
      fail("expected '\{bad}' to be rejected")
    }
  }
}

///|
test "pixel conversions follow the Open XML width formula" {
  inspect(
    @xlsx2html.col_width_px(16.0),
    content=(
      #|112
    ),
  )
  inspect(
    @xlsx2html.col_width_px(0.0),
    content=(
      #|0
    ),
  )
  inspect(
    @xlsx2html.col_width_px(8.43),
    content=(
      #|59
    ),
  )
  inspect(
    @xlsx2html.row_height_px(15.0),
    content=(
      #|20
    ),
  )
}

///|
test "style_css renders safe declarations and omits invalid colors" {
  let styled = @xlsx.Style::new()
    .with_font(
      @xlsx.Font::with_values(bold=true, italic=true, size=12.5, color="FFFFFF"),
    )
    .with_fill(@xlsx.Fill::solid("4472C4"))
    .with_alignment(
      @xlsx.Alignment::with_values(
        horizontal="center",
        vertical="top",
        wrap_text=true,
      ),
    )
  inspect(
    @xlsx2html.style_css(styled),
    content="font-weight:bold;font-style:italic;font-size:12.5pt;color:#FFFFFF;background-color:#4472C4;text-align:center;vertical-align:top;white-space:normal;",
  )
  // A hostile "color" cannot break out of the style block: the property
  // is dropped entirely.
  let hostile = @xlsx.Style::new().with_font(
    @xlsx.Font::with_values(color="</style><script>alert(1)</script>"),
  )
  inspect(@xlsx2html.style_css(hostile), content="")
  // Non-solid fills are omitted per the documented fidelity limits.
  let gradient = @xlsx.Style::new().with_fill(
    @xlsx.Fill::gradient("4472C4", "FFFFFF"),
  )
  inspect(@xlsx2html.style_css(gradient), content="")
}
