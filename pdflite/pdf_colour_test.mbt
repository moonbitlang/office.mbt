///|
test "cpdf colours exposes the complete CSS colour table" {
  let colours = @pdflite.pdf_css_colours()
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
