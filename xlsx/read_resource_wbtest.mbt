///|
test "read resource wb: x14 block scanning retains only matched blocks" {
  let xml = StringBuilder::new()
  xml.write_view("<worksheet><x14:conditionalFormattings>")
  for index in 0..<2_000 {
    xml.write_view(
      "<x14:conditionalFormatting><x14:cfRule id=\"\{index}\"/></x14:conditionalFormatting>",
    )
  }
  xml.write_view("</x14:conditionalFormattings></worksheet>")
  let blocks = parse_x14_conditional_formatting_blocks(xml.to_string())
  assert_eq(blocks.length(), 2_000)
  assert_true(blocks[0].contains("id=\"0\""))
  assert_true(blocks[1_999].contains("id=\"1999\""))
}
