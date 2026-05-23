///|
test "cpdf colours exposes the complete CSS colour table" {
  let colours = @pdflite.pdf_css_colours()
  @test.assert_eq(@pdflite.pdf_colours(), colours)
  @test.assert_eq(colours.length(), 148)
  @test.assert_eq(colours[0], ("aliceblue", 0xF0F8FF))
  @test.assert_eq(colours[colours.length() - 1], ("yellowgreen", 0x9ACD32))
}

///|
test "cpdf colours preserves aliases and lowercase names" {
  @test.assert_eq(@pdflite.pdf_css_colour_value("cyan"), Some(0x00FFFF))
  @test.assert_eq(@pdflite.pdf_css_colour_value("aqua"), Some(0x00FFFF))
  @test.assert_eq(@pdflite.pdf_css_colour_value("darkgray"), Some(0xA9A9A9))
  @test.assert_eq(@pdflite.pdf_css_colour_value("darkgrey"), Some(0xA9A9A9))
  @test.assert_eq(
    @pdflite.pdf_css_colour_value("RebeccaPurple"),
    Some(0x663399),
  )
  @test.assert_eq(@pdflite.pdf_css_colour_value("not-a-colour"), None)
}

///|
test "cpdf colour parser reads CSS names and numeric forms" {
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_colour("Red"),
    PdfContentRGB(1.0, 0.0, 0.0),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_colour("0.25"),
    PdfContentGrey(0.25),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_colour("1 -2 3.5"),
    PdfContentRGB(1.0, -2.0, 3.5),
  )
  @test.assert_eq(
    try! @pdflite.pdf_parse_content_colour("0 0.1 0.2 0.3"),
    PdfContentCMYK(0.0, 0.1, 0.2, 0.3),
  )
}

///|
test "cpdf colour parser rejects bad arities and non-numeric tokens" {
  let bad_count : Result[@pdflite.PdfContentColour, Error] = try? @pdflite.pdf_parse_content_colour(
    "0 1",
  )
  guard bad_count is Err(@pdflite.PdfError::BadNumberArgument("Bad color")) else {
    fail("expected BadNumberArgument for two colour components")
  }
  let bad_token : Result[@pdflite.PdfContentColour, Error] = try? @pdflite.pdf_parse_content_colour(
    "1 nope",
  )
  guard bad_token is Err(@pdflite.PdfError::BadNumberArgument("Bad color")) else {
    fail("expected BadNumberArgument for non-numeric colour token")
  }
  let unknown_css : Result[@pdflite.PdfContentColour, Error] = try? @pdflite.pdf_parse_content_colour(
    "not-a-colour",
  )
  guard unknown_css is Err(@pdflite.PdfError::BadNumberArgument("Bad color")) else {
    fail("expected BadNumberArgument for unknown CSS colour")
  }
}
