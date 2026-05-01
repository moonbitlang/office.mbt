///|
fn space_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
test "PdfColourSpace debug names preserve CamlPDF forms" {
  @test.assert_eq(@pdflite.PdfDeviceGray.debug_name(), "/DeviceGray")
  @test.assert_eq(@pdflite.PdfDeviceRGB.debug_name(), "/DeviceRGB")
  @test.assert_eq(@pdflite.PdfDeviceCMYK.debug_name(), "/DeviceCMYK")
  @test.assert_eq(
    @pdflite.PdfPatternWithBaseColourSpace(PdfDeviceRGB).debug_name(),
    "PatternWithBaseColourspace (/DeviceRGB)",
  )
  @test.assert_eq(
    @pdflite.PdfIndexed(PdfDeviceCMYK, [(0, [0, 0, 0, 255])]).debug_name(),
    "Indexed (/DeviceCMYK)",
  )
  @test.assert_eq(
    @pdflite.PdfSeparation(space_name_for_test("/Spot"), PdfDeviceGray, PdfNull).debug_name(),
    "Separation (/DeviceGray)",
  )
  @test.assert_eq(
    @pdflite.PdfDeviceN(
      [space_name_for_test("/Cyan")],
      PdfDeviceCMYK,
      PdfNull,
      PdfNull,
    ).debug_name(),
    "DeviceN (/DeviceCMYK)",
  )
}

///|
test "PdfColourSpace name only reports separation colourants" {
  @test.assert_eq(@pdflite.PdfDeviceRGB.name(), None)
  @test.assert_eq(
    @pdflite.PdfSeparation(space_name_for_test("/Spot"), PdfDeviceGray, PdfNull).name(),
    Some(space_name_for_test("/Spot")),
  )
}

///|
test "pdf_colour_space_of_object reads direct device aliases and patterns" {
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfNameObject(space_name_for_test("/DeviceGray")),
    ),
    Some(PdfDeviceGray),
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfNameObject(space_name_for_test("/G")),
    ),
    Some(PdfDeviceGray),
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfNameObject(space_name_for_test("/RGB")),
    ),
    Some(PdfDeviceRGB),
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfNameObject(space_name_for_test("/CMYK")),
    ),
    Some(PdfDeviceCMYK),
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfArray([PdfNameObject(space_name_for_test("/Pattern"))]),
    ),
    Some(PdfPattern),
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfArray([
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
      ]),
    ),
    Some(PdfPatternWithBaseColourSpace(PdfDeviceRGB)),
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfArray([
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfNameObject(space_name_for_test("/Missing")),
      ]),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_colour_space_of_object(
      PdfNameObject(space_name_for_test("/Missing")),
    ),
    None,
  )
}

///|
test "pdf_object_of_colour_space writes supported direct colour spaces" {
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(PdfDeviceGray),
    Some(PdfNameObject(space_name_for_test("/DeviceGray"))),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(PdfDeviceRGB),
    Some(PdfNameObject(space_name_for_test("/DeviceRGB"))),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(PdfDeviceCMYK),
    Some(PdfNameObject(space_name_for_test("/DeviceCMYK"))),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(PdfPattern),
    Some(PdfNameObject(space_name_for_test("/Pattern"))),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfPatternWithBaseColourSpace(PdfDeviceRGB),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
      ]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfPatternWithBaseColourSpace(
        PdfCalGray({ x: 1.0, y: 1.0, z: 1.0 }, { x: 0.0, y: 0.0, z: 0.0 }, 1.0),
      ),
    ),
    None,
  )
}
