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

///|
test "read resource wb: x14 scanning rejects EOF and separates self-closing blocks" {
  let eof : Result[Array[String], Error] = Ok(
    parse_x14_conditional_formatting_blocks("<x14:conditionalFormatting"),
  ) catch {
    error => Err(error)
  }
  assert_true(eof is Err(InvalidXml(_)))

  let blocks = parse_x14_conditional_formatting_blocks(
    "<x14:conditionalFormattings><x14:conditionalFormatting/><x14:conditionalFormatting><xm:sqref>A1</xm:sqref></x14:conditionalFormatting></x14:conditionalFormattings>",
  )
  assert_eq(blocks.length(), 2)
  inspect(blocks[0], content="<x14:conditionalFormatting/>")
  assert_true(blocks[1].contains("<xm:sqref>A1</xm:sqref>"))
}
