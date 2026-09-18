///|
test "style JSON omits programmatic non-finite optional numbers" {
  let nan = @string.parse_double("NaN")
  let infinity = @string.parse_double("Infinity")
  let style = @xlsx.Style::font(
    @xlsx.Font::with_values(size=nan, color_tint=infinity),
  )
  let encoded = @inspect.style_to_json(style).stringify()
  assert_false(encoded.contains("NaN"))
  assert_false(encoded.contains("Infinity"))
  assert_eq(encoded, "{}")
}
