///|
fn space_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn space_bytes_for_test(values : ArrayView[Byte]) -> Bytes {
  Bytes::from_array(values)
}

///|
test "PdfColourSpace debug names preserve CamlPDF forms" {
  @test.assert_eq(@pdflite.PdfDeviceGray.debug_name(), "/DeviceGray")
  @test.assert_eq(@pdflite.PdfDeviceRGB.debug_name(), "/DeviceRGB")
  @test.assert_eq(@pdflite.PdfDeviceCMYK.debug_name(), "/DeviceCMYK")
  @test.assert_eq(
    @pdflite.PdfCalGray(
      { x: 1.0, y: 1.0, z: 1.0 },
      { x: 0.0, y: 0.0, z: 0.0 },
      1.0,
    ).debug_name(),
    "/CalGray",
  )
  @test.assert_eq(
    @pdflite.PdfCalRGB(
      { x: 1.0, y: 1.0, z: 1.0 },
      { x: 0.0, y: 0.0, z: 0.0 },
      [1.0, 1.0, 1.0],
      [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
    ).debug_name(),
    "/CalRGB",
  )
  @test.assert_eq(
    @pdflite.PdfLab({ x: 1.0, y: 1.0, z: 1.0 }, { x: 0.0, y: 0.0, z: 0.0 }, [
      -100.0, 100.0, -100.0, 100.0,
    ]).debug_name(),
    "/Lab",
  )
  @test.assert_eq(
    @pdflite.PdfICCBased(1, PdfDeviceGray, [0.0, 1.0], None, PdfNull).debug_name(),
    "ICCBased (/DeviceGray)",
  )
  @test.assert_eq(
    @pdflite.PdfPatternWithBaseColourSpace(PdfDeviceRGB).debug_name(),
    "PatternWithBaseColourspace (/DeviceRGB)",
  )
  @test.assert_eq(@pdflite.PdfPattern.debug_name(), "/Pattern")
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
  @test.assert_eq(@pdflite.pdf_colour_space_of_object(PdfInteger(1)), None)
}

///|
test "PdfDocument read_colour_space resolves resources and nested arrays" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @pdflite.pdf_dictionary([
    (
      space_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (
          space_name_for_test("/CS1"),
          PdfNameObject(space_name_for_test("/RGB")),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.read_colour_space(
      resources,
      PdfNameObject(space_name_for_test("/CS1")),
    ),
    Some(PdfDeviceRGB),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      resources,
      PdfArray([PdfNameObject(space_name_for_test("/CS1"))]),
    ),
    Some(PdfDeviceRGB),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfNameObject(space_name_for_test("/CS1")),
      ]),
    ),
    Some(PdfPatternWithBaseColourSpace(PdfDeviceRGB)),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfNameObject(space_name_for_test("/Missing")),
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      resources,
      PdfNameObject(space_name_for_test("/Missing")),
    ),
    None,
  )
  @test.assert_eq(try! doc.read_colour_space(resources, PdfInteger(1)), None)
}

///|
test "PdfDocument read_colour_space parses calibrated dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalGray")),
        @pdflite.pdf_dictionary([]),
      ]),
    ),
    Some(
      PdfCalGray({ x: 0.0, y: 0.0, z: 0.0 }, { x: 0.0, y: 0.0, z: 0.0 }, 1.0),
    ),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalGray")),
        @pdflite.pdf_dictionary([
          (
            space_name_for_test("/WhitePoint"),
            PdfArray([PdfReal(0.9), PdfReal(1.0), PdfReal(0.8)]),
          ),
          (space_name_for_test("/Gamma"), PdfReal(2.2)),
        ]),
      ]),
    ),
    Some(
      PdfCalGray({ x: 0.9, y: 1.0, z: 0.8 }, { x: 0.0, y: 0.0, z: 0.0 }, 2.2),
    ),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalRGB")),
        @pdflite.pdf_dictionary([
          (
            space_name_for_test("/WhitePoint"),
            PdfArray([PdfInteger(1), PdfInteger(1), PdfInteger(1)]),
          ),
          (
            space_name_for_test("/Gamma"),
            PdfArray([PdfReal(1.8), PdfReal(1.9), PdfReal(2.0)]),
          ),
        ]),
      ]),
    ),
    Some(
      PdfCalRGB(
        { x: 1.0, y: 1.0, z: 1.0 },
        { x: 0.0, y: 0.0, z: 0.0 },
        [1.8, 1.9, 2.0],
        [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
      ),
    ),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Lab")),
        @pdflite.pdf_dictionary([
          (
            space_name_for_test("/WhitePoint"),
            PdfArray([PdfInteger(1), PdfInteger(1), PdfInteger(1)]),
          ),
          (
            space_name_for_test("/Range"),
            PdfArray([
              PdfInteger(-80),
              PdfInteger(90),
              PdfInteger(-70),
              PdfInteger(85),
            ]),
          ),
        ]),
      ]),
    ),
    Some(
      PdfLab({ x: 1.0, y: 1.0, z: 1.0 }, { x: 0.0, y: 0.0, z: 0.0 }, [
        -80.0, 90.0, -70.0, 85.0,
      ]),
    ),
  )
}

///|
test "PdfDocument read_colour_space reports malformed calibrated numbers" {
  let doc = @pdflite.pdf_document_empty()
  let result : Result[@pdflite.PdfColourSpace?, Error] = try? doc.read_colour_space(
    @pdflite.pdf_dictionary([]),
    PdfArray([
      PdfNameObject(space_name_for_test("/CalGray")),
      @pdflite.pdf_dictionary([
        (
          space_name_for_test("/WhitePoint"),
          PdfArray([
            PdfNameObject(space_name_for_test("/Bad")),
            PdfInteger(1),
            PdfInteger(1),
          ]),
        ),
      ]),
    ]),
  )
  guard result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed calibrated number")
  }
}

///|
test "PdfDocument read_colour_space parses ICCBased streams" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let default_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(3))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), default_stream]),
    ),
    Some(
      PdfICCBased(
        3,
        PdfDeviceRGB,
        [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
        None,
        default_stream,
      ),
    ),
  )
  let metadata : @pdflite.PdfObject = PdfString(@ascii.encode("meta"))
  let explicit_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (space_name_for_test("/N"), PdfInteger(1)),
      (
        space_name_for_test("/Alternate"),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
      ),
      (space_name_for_test("/Range"), PdfArray([PdfReal(0.1), PdfReal(0.9)])),
      (space_name_for_test("/Metadata"), metadata),
    ]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/ICCBased")),
        explicit_stream,
      ]),
    ),
    Some(
      PdfICCBased(1, PdfDeviceCMYK, [0.1, 0.9], Some(metadata), explicit_stream),
    ),
  )
  let cmyk_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(4))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), cmyk_stream]),
    ),
    Some(
      PdfICCBased(
        4,
        PdfDeviceCMYK,
        [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
        None,
        cmyk_stream,
      ),
    ),
  )
}

///|
test "PdfDocument read_colour_space rejects unsupported ICCBased shapes" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let bad_n_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(2))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), bad_n_stream]),
    ),
    None,
  )
  let missing_n_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/ICCBased")),
        missing_n_stream,
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/ICCBased")),
        @pdflite.pdf_dictionary([]),
      ]),
    ),
    None,
  )
  let unsupported_alternate_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (space_name_for_test("/N"), PdfInteger(3)),
      (
        space_name_for_test("/Alternate"),
        PdfNameObject(space_name_for_test("/Missing")),
      ),
    ]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/ICCBased")),
        unsupported_alternate_stream,
      ]),
    ),
    None,
  )
}

///|
test "PdfDocument read_colour_space reports malformed ICCBased range numbers" {
  let doc = @pdflite.pdf_document_empty()
  let malformed_range_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (space_name_for_test("/N"), PdfInteger(1)),
      (
        space_name_for_test("/Range"),
        PdfArray([PdfNameObject(space_name_for_test("/Bad")), PdfInteger(1)]),
      ),
    ]),
    StreamGot(@ascii.encode("icc")),
  )
  let result : Result[@pdflite.PdfColourSpace?, Error] = try? doc.read_colour_space(
    @pdflite.pdf_dictionary([]),
    PdfArray([
      PdfNameObject(space_name_for_test("/ICCBased")),
      malformed_range_stream,
    ]),
  )
  guard result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed ICCBased range number")
  }
}

///|
test "PdfDocument read_colour_space parses Indexed string and stream tables" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfInteger(1),
        PdfString(space_bytes_for_test([10, 20, 30, 40, 50, 60])),
      ]),
    ),
    Some(PdfIndexed(PdfDeviceRGB, [(0, [10, 20, 30]), (1, [40, 50, 60])])),
  )
  let lookup_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(space_name_for_test("/Length"), PdfInteger(4))]),
    StreamGot(space_bytes_for_test([1, 2, 3, 4])),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/I")),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        PdfInteger(0),
        lookup_stream,
      ]),
    ),
    Some(PdfIndexed(PdfDeviceCMYK, [(0, [1, 2, 3, 4])])),
  )
}

///|
test "PdfDocument read_colour_space parses Indexed through ICCBased alternate" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let icc_base = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(3))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), icc_base]),
        PdfInteger(0),
        PdfString(space_bytes_for_test([7, 8, 9])),
      ]),
    ),
    Some(
      PdfIndexed(
        PdfICCBased(
          3,
          PdfDeviceRGB,
          [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
          None,
          icc_base,
        ),
        [(0, [7, 8, 9])],
      ),
    ),
  )
}

///|
test "PdfDocument read_colour_space rejects unsupported Indexed shapes" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfInteger(0),
        PdfString(space_bytes_for_test([1, 2, 3])),
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/Missing")),
        PdfInteger(0),
        PdfString(space_bytes_for_test([1, 2, 3])),
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfInteger(0),
        PdfArray([]),
      ]),
    ),
    None,
  )
}

///|
test "PdfDocument read_colour_space reports malformed Indexed data" {
  let doc = @pdflite.pdf_document_empty()
  let bad_hival : Result[@pdflite.PdfColourSpace?, Error] = try? doc.read_colour_space(
    @pdflite.pdf_dictionary([]),
    PdfArray([
      PdfNameObject(space_name_for_test("/Indexed")),
      PdfNameObject(space_name_for_test("/DeviceRGB")),
      PdfNameObject(space_name_for_test("/Bad")),
      PdfString(space_bytes_for_test([1, 2, 3])),
    ]),
  )
  guard bad_hival is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected NumberExpected for Indexed hival")
  }
  let short_table : Result[@pdflite.PdfColourSpace?, Error] = try? doc.read_colour_space(
    @pdflite.pdf_dictionary([]),
    PdfArray([
      PdfNameObject(space_name_for_test("/Indexed")),
      PdfNameObject(space_name_for_test("/DeviceRGB")),
      PdfInteger(1),
      PdfString(space_bytes_for_test([1, 2, 3])),
    ]),
  )
  guard short_table is Err(@pdflite.PdfError::EndOfInput) else {
    fail("expected EndOfInput for short Indexed table")
  }
  let negative_hival : Result[@pdflite.PdfColourSpace?, Error] = try? doc.read_colour_space(
    @pdflite.pdf_dictionary([]),
    PdfArray([
      PdfNameObject(space_name_for_test("/Indexed")),
      PdfNameObject(space_name_for_test("/DeviceRGB")),
      PdfInteger(-1),
      PdfString(space_bytes_for_test([1, 2, 3])),
    ]),
  )
  guard negative_hival is Err(@pdflite.PdfError::InvalidReadLength(-1)) else {
    fail("expected InvalidReadLength for negative Indexed hival")
  }
}

///|
test "PdfDocument read_colour_space parses Separation and DeviceN spaces" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let tint = @pdflite.pdf_dictionary([
    (space_name_for_test("/FunctionType"), PdfInteger(2)),
  ])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Separation")),
        PdfNameObject(space_name_for_test("/Spot")),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
      ]),
    ),
    Some(PdfSeparation(space_name_for_test("/Spot"), PdfDeviceCMYK, tint)),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/DeviceN")),
        PdfArray([
          PdfNameObject(space_name_for_test("/Cyan")),
          PdfNameObject(space_name_for_test("/Magenta")),
        ]),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
      ]),
    ),
    Some(
      PdfDeviceN(
        [space_name_for_test("/Cyan"), space_name_for_test("/Magenta")],
        PdfDeviceCMYK,
        tint,
        @pdflite.pdf_dictionary([]),
      ),
    ),
  )
  let attributes = @pdflite.pdf_dictionary([
    (
      space_name_for_test("/Subtype"),
      PdfNameObject(space_name_for_test("/NChannel")),
    ),
  ])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/DeviceN")),
        PdfArray([PdfNameObject(space_name_for_test("/Cyan"))]),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
        attributes,
      ]),
    ),
    Some(
      PdfDeviceN(
        [space_name_for_test("/Cyan")],
        PdfDeviceCMYK,
        tint,
        attributes,
      ),
    ),
  )
}

///|
test "PdfDocument read_colour_space rejects malformed Separation and DeviceN spaces" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @pdflite.pdf_dictionary([])
  let tint = @pdflite.pdf_dictionary([])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Separation")),
        PdfNameObject(space_name_for_test("/Spot")),
        PdfNameObject(space_name_for_test("/Missing")),
        tint,
      ]),
    ),
    None,
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/DeviceN")),
        PdfArray([PdfNameObject(space_name_for_test("/Cyan")), PdfInteger(1)]),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
      ]),
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
