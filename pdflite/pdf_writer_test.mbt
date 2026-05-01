///|
fn writer_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn writer_name_for_test(values : ArrayView[Int]) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(writer_bytes_for_test(values))
}

///|
test "pdf_write_object renders primitive scalar objects" {
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfNull),
    writer_bytes_for_test([110, 117, 108, 108]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfBoolean(true)),
    writer_bytes_for_test([116, 114, 117, 101]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfInteger(-42)),
    writer_bytes_for_test([45, 52, 50]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfIndirect(7)),
    writer_bytes_for_test([55, 32, 48, 32, 82]),
  )
}

///|
test "pdf_write_object escapes names and literal strings as bytes" {
  let name = writer_name_for_test([47, 65, 32, 66, 35, 67])
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfNameObject(name)),
    writer_bytes_for_test([47, 65, 35, 50, 48, 66, 35, 50, 51, 67]),
  )
  let string = writer_bytes_for_test([65, 10, 40, 41, 92, 0, 255])
  @test.assert_eq(
    try! @pdflite.pdf_write_object(PdfString(string)),
    writer_bytes_for_test([
      40, 65, 92, 110, 92, 40, 92, 41, 92, 92, 92, 48, 48, 48, 92, 51, 55, 55, 41,
    ]),
  )
}

///|
test "pdf_write_object round trips arrays and dictionaries through primitive parser" {
  let type_key = writer_name_for_test([47, 84, 121, 112, 101])
  let object = @pdflite.pdf_dictionary([
    (type_key, PdfNameObject(writer_name_for_test([47, 80, 97, 103, 101]))),
    (
      writer_name_for_test([47, 75, 105, 100, 115]),
      @pdflite.pdf_array([PdfInteger(7), PdfIndirect(8)]),
    ),
  ])
  let rendered = try! @pdflite.pdf_write_object(object)
  @test.assert_eq(try! @pdflite.pdf_parse_object_from_bytes(rendered), object)
}

///|
test "pdf_write_indirect_object renders direct stream data" {
  let length_name = writer_name_for_test([47, 76, 101, 110, 103, 116, 104])
  let object = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(length_name, PdfInteger(5))]),
    StreamGot(writer_bytes_for_test([72, 101, 108, 108, 111])),
  )
  let rendered = try! @pdflite.pdf_write_indirect_object({
    number: 7,
    generation: 0,
    object,
  })
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(rendered)
  @test.assert_eq(parsed.number, 7)
  @test.assert_eq(parsed.object, object)
}
