///|
test "unpaired UTF-16 surrogates are replaced and counted" {
  // lone surrogates cannot appear in MoonBit literals; parse them in
  guard @json.parse("\"a\\ud800b\\udc00c\"") is String(mixed) else {
    fail("expected a JSON string with isolated surrogates")
  }
  let (fixed, replaced) = @xlsx2html.sanitize_utf16_lossy(mixed)
  inspect(replaced, content="2")
  inspect(fixed, content="a\u{FFFD}b\u{FFFD}c")
}

///|
test "well-formed text passes through sanitization unchanged" {
  let clean = "plain 😀 text & <markup>"
  let (same, replaced) = @xlsx2html.sanitize_utf16_lossy(clean)
  inspect(replaced, content="0")
  assert_true(same == clean)
  let (empty, zero) = @xlsx2html.sanitize_utf16_lossy("")
  inspect(zero, content="0")
  assert_true(empty == "")
}

///|
test "lone surrogates at the string edges are replaced" {
  guard @json.parse("\"\\ud800\"") is String(lone_lead) else {
    fail("expected a lone leading surrogate")
  }
  let (lead_fixed, lead_count) = @xlsx2html.sanitize_utf16_lossy(lone_lead)
  inspect(lead_count, content="1")
  inspect(lead_fixed, content="\u{FFFD}")
  guard @json.parse("\"x\\udc00\"") is String(tail_trail) else {
    fail("expected a trailing lone surrogate")
  }
  let (trail_fixed, trail_count) = @xlsx2html.sanitize_utf16_lossy(tail_trail)
  inspect(trail_count, content="1")
  inspect(trail_fixed, content="x\u{FFFD}")
}

///|
test "chart label truncation never splits a surrogate pair" {
  // 22 units of 'a', then an astral pair straddling the 24-unit label
  // ceiling, then one more unit: the cut must back off the pair, and the
  // rendered document must stay UTF-8 encodable end to end
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "East")
  workbook.set_cell_int("Data", "B1", 5)
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(
    @xlsx.ChartSeries::new(
      "Data!$A$1:$A$1",
      "Data!$B$1:$B$1",
      name="aaaaaaaaaaaaaaaaaaaaaa😀z",
    ),
  )
  workbook.add_chart_with_options("Data", "D2", chart)
  let html = @xlsx2html.render_workbook(workbook, title="edge.xlsx")
  assert_true(html.contains("aaaaaaaaaaaaaaaaaaaaaa\u{2026}"))
  let (sanitized, replaced) = @xlsx2html.sanitize_utf16_lossy(html)
  inspect(replaced, content="0")
  // totality proof: encoding the rendered document must not trap
  assert_true(@utf8.encode(sanitized).length() > 0)
}
