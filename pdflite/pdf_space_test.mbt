///|
fn space_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn space_bytes_for_test(values : ArrayView[Byte]) -> Bytes {
  Bytes::from_array(values)
}

///|
test "PdfColourSpace debug names preserve CamlPDF forms" {
  @test.assert_eq(@pdflite.PdfDeviceGray.debug_name(), "/DeviceGray")
  @test.assert_eq(
    @pdflite.pdf_string_of_colour_space(PdfDeviceGray),
    "/DeviceGray",
  )
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
test "cpdfcontent state serializes colour spaces and colour operands" {
  let spaces : Array[(@pdflite.PdfColourSpace, Json)] = [
    (PdfDeviceGray, Json::string("DeviceGray")),
    (PdfDeviceRGB, Json::string("DeviceRGB")),
    (PdfDeviceCMYK, Json::string("DeviceCMYK")),
    (
      PdfCalGray({ x: 1.0, y: 1.0, z: 1.0 }, { x: 0.0, y: 0.0, z: 0.0 }, 1.0),
      Json::string("CalGray"),
    ),
    (
      PdfCalRGB(
        { x: 1.0, y: 1.0, z: 1.0 },
        { x: 0.0, y: 0.0, z: 0.0 },
        [1.0, 1.0, 1.0],
        [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
      ),
      Json::string("CalRGB"),
    ),
    (
      PdfLab({ x: 1.0, y: 1.0, z: 1.0 }, { x: 0.0, y: 0.0, z: 0.0 }, [
        -100.0, 100.0, -100.0, 100.0,
      ]),
      Json::string("Lab"),
    ),
    (
      PdfICCBased(1, PdfDeviceRGB, [0.0, 1.0], None, PdfNull),
      Json::string("ICCBased"),
    ),
    (PdfIndexed(PdfDeviceRGB, [(0, [0, 0, 0])]), Json::string("Indexed")),
    (PdfPattern, Json::string("Pattern")),
    (
      PdfPatternWithBaseColourSpace(PdfDeviceRGB),
      Json::string("PatternWithBaseColourspace"),
    ),
    (
      PdfSeparation(space_name_for_test("/Spot"), PdfDeviceCMYK, PdfNull),
      Json::string("Separation"),
    ),
    (
      PdfDeviceN(
        [space_name_for_test("/Cyan")],
        PdfDeviceCMYK,
        PdfNull,
        PdfNull,
      ),
      Json::string("DeviceN"),
    ),
  ]
  for item in spaces {
    let (space, expected) = item
    @test.assert_eq(space.content_json(), expected)
    @test.assert_eq(@pdflite.pdf_colour_space_content_json(space), expected)
  }
  let floats = @pdflite.PdfContentColourFloats([0.1, 0.2, 0.3])
  @test.assert_eq(
    floats.content_json(),
    Json::array([Json::number(0.1), Json::number(0.2), Json::number(0.3)]),
  )
  let named = @pdflite.PdfContentColourNamed("/P1", [0.25, 0.75])
  let named_json = Json::array([
    Json::string("/P1"),
    Json::number(0.25),
    Json::number(0.75),
  ])
  @test.assert_eq(named.content_json(), named_json)
  @test.assert_eq(
    @pdflite.pdf_content_colour_values_content_json(named),
    named_json,
  )
  @test.assert_eq(
    @pdflite.PdfContentColourPattern.content_json(),
    Json::string("pattern"),
  )
}

///|
test "PdfColourSpace name only reports separation colourants" {
  @test.assert_eq(@pdflite.PdfDeviceRGB.name(), None)
  @test.assert_eq(@pdflite.pdf_name_of_colour_space(PdfDeviceRGB), None)
  @test.assert_eq(
    @pdflite.PdfSeparation(space_name_for_test("/Spot"), PdfDeviceGray, PdfNull).name(),
    Some(space_name_for_test("/Spot")),
  )
  @test.assert_eq(
    @pdflite.pdf_name_of_colour_space(
      PdfSeparation(space_name_for_test("/Spot"), PdfDeviceGray, PdfNull),
    ),
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
  let resources = @syntax.pdf_dictionary([
    (
      space_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
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
    try! @pdflite.pdf_read_colour_space(
      doc,
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
test "PdfDocument colour_space_components counts direct and resource spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([
    (
      space_name_for_test("/ColorSpace"),
      @syntax.pdf_dictionary([
        (
          space_name_for_test("/CSRGB"),
          PdfNameObject(space_name_for_test("/RGB")),
        ),
        (
          space_name_for_test("/CSNested"),
          PdfArray([PdfNameObject(space_name_for_test("/CSRGB"))]),
        ),
      ]),
    ),
  ])
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfNameObject(space_name_for_test("/DeviceGray")),
    ),
    1,
  )
  @test.assert_eq(
    try! @pdflite.pdf_colour_space_components(
      doc,
      resources,
      PdfNameObject(space_name_for_test("/DeviceGray")),
    ),
    1,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfNameObject(space_name_for_test("/DeviceRGB")),
    ),
    3,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfNameObject(space_name_for_test("/DeviceCMYK")),
    ),
    4,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfNameObject(space_name_for_test("/CSNested")),
    ),
    3,
  )
  let missing_resource : Result[Int, Error] = try
    doc.colour_space_components(
      @syntax.pdf_dictionary([]),
      PdfNameObject(space_name_for_test("/CSMissingDict")),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_resource is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == space_name_for_test("/ColorSpace") else {
    fail("expected missing ColorSpace resource dictionary")
  }
  let missing_space : Result[Int, Error] = try
    doc.colour_space_components(
      resources,
      PdfNameObject(space_name_for_test("/CSMissing")),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_space is Err(@core.PdfError::DictionaryKeyNotFound(name)) &&
    name == space_name_for_test("/CSMissing") else {
    fail("expected missing named color space")
  }
}

///|
test "PdfDocument colour_space_components counts array spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([])
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Pattern")),
        PdfNameObject(space_name_for_test("/RGB")),
      ]),
    ),
    3,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalRGB")),
        @syntax.pdf_dictionary([]),
      ]),
    ),
    3,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Lab")),
        @syntax.pdf_dictionary([]),
      ]),
    ),
    3,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalCMYK")),
        @syntax.pdf_dictionary([]),
      ]),
    ),
    4,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalGray")),
        @syntax.pdf_dictionary([]),
      ]),
    ),
    1,
  )
}

///|
test "PdfDocument colour_space_components counts special spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([])
  let icc = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(4))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), icc]),
    ),
    4,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Separation")),
        PdfNameObject(space_name_for_test("/Spot")),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        PdfNull,
      ]),
    ),
    1,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfInteger(1),
      ]),
    ),
    1,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/I")),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        PdfInteger(1),
      ]),
    ),
    1,
  )
  @test.assert_eq(
    try! doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/DeviceN")),
        PdfArray([
          PdfNameObject(space_name_for_test("/Cyan")),
          PdfNameObject(space_name_for_test("/Magenta")),
          PdfNameObject(space_name_for_test("/Yellow")),
        ]),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        PdfNull,
      ]),
    ),
    3,
  )
}

///|
test "PdfDocument colour_space_components rejects malformed spaces" {
  let doc = @pdflite.pdf_document_empty()
  let resources = @syntax.pdf_dictionary([])
  let pattern : Result[Int, Error] = try
    doc.colour_space_components(
      resources,
      PdfNameObject(space_name_for_test("/Pattern")),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard pattern is Err(@core.PdfError::ColourSpaceExpected) else {
    fail("expected @core.PdfError::ColourSpaceExpected for pattern")
  }
  let bad_icc : Result[Int, Error] = try
    doc.colour_space_components(
      resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/ICCBased")),
        @syntax.pdf_stream(
          @syntax.pdf_dictionary([]),
          StreamGot(@ascii.encode("icc")),
        ),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_icc is Err(@core.PdfError::ColourSpaceExpected) else {
    fail("expected @core.PdfError::ColourSpaceExpected for bad ICCBased")
  }
  let malformed : Result[Int, Error] = try
    doc.colour_space_components(
      resources,
      PdfArray([PdfInteger(1), PdfInteger(2)]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard malformed is Err(@core.PdfError::ColourSpaceExpected) else {
    fail(
      "expected @core.PdfError::ColourSpaceExpected for malformed color space",
    )
  }
}

///|
test "PdfDocument read_colour_space parses calibrated dictionaries" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([
        PdfNameObject(space_name_for_test("/CalGray")),
        @syntax.pdf_dictionary([]),
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
        @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([
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
  let result : Result[@pdflite.PdfColourSpace?, Error] = try
    doc.read_colour_space(
      @syntax.pdf_dictionary([]),
      PdfArray([
        PdfNameObject(space_name_for_test("/CalGray")),
        @syntax.pdf_dictionary([
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
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::NumberExpected) else {
    fail("expected malformed calibrated number")
  }
}

///|
test "PdfDocument read_colour_space parses ICCBased streams" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  let default_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(3))]),
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
  let metadata : @syntax.PdfObject = PdfString(@ascii.encode("meta"))
  let explicit_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
  let cmyk_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(4))]),
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
  let empty_resources = @syntax.pdf_dictionary([])
  let bad_n_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(2))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    try! doc.read_colour_space(
      empty_resources,
      PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), bad_n_stream]),
    ),
    None,
  )
  let missing_n_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([]),
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
        @syntax.pdf_dictionary([]),
      ]),
    ),
    None,
  )
  let unsupported_alternate_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
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
  let malformed_range_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (space_name_for_test("/N"), PdfInteger(1)),
      (
        space_name_for_test("/Range"),
        PdfArray([PdfNameObject(space_name_for_test("/Bad")), PdfInteger(1)]),
      ),
    ]),
    StreamGot(@ascii.encode("icc")),
  )
  let result : Result[@pdflite.PdfColourSpace?, Error] = try
    doc.read_colour_space(
      @syntax.pdf_dictionary([]),
      PdfArray([
        PdfNameObject(space_name_for_test("/ICCBased")),
        malformed_range_stream,
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::NumberExpected) else {
    fail("expected malformed ICCBased range number")
  }
}

///|
test "PdfDocument read_colour_space parses Indexed string and stream tables" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
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
  let lookup_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/Length"), PdfInteger(4))]),
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
  doc.add_object_given_number(
    8,
    PdfNameObject(space_name_for_test("/ASCIIHexDecode")),
  )
  let encoded_lookup = @codec.pdf_ascii_hex_encode(
    space_bytes_for_test([1, 2, 3, 4]),
  )
  let lookup_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([
      (space_name_for_test("/Length"), PdfInteger(encoded_lookup.length())),
      (space_name_for_test("/Filter"), PdfIndirect(8)),
    ]),
    StreamGot(encoded_lookup),
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
  let empty_resources = @syntax.pdf_dictionary([])
  let icc_base = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(3))]),
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
  let empty_resources = @syntax.pdf_dictionary([])
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
  let bad_hival : Result[@pdflite.PdfColourSpace?, Error] = try
    doc.read_colour_space(
      @syntax.pdf_dictionary([]),
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfNameObject(space_name_for_test("/Bad")),
        PdfString(space_bytes_for_test([1, 2, 3])),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_hival is Err(@core.PdfError::NumberExpected) else {
    fail("expected @core.PdfError::NumberExpected for Indexed hival")
  }
  let short_table : Result[@pdflite.PdfColourSpace?, Error] = try
    doc.read_colour_space(
      @syntax.pdf_dictionary([]),
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfInteger(1),
        PdfString(space_bytes_for_test([1, 2, 3])),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard short_table is Err(@core.PdfError::EndOfInput) else {
    fail("expected @core.PdfError::EndOfInput for short Indexed table")
  }
  let negative_hival : Result[@pdflite.PdfColourSpace?, Error] = try
    doc.read_colour_space(
      @syntax.pdf_dictionary([]),
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfInteger(-1),
        PdfString(space_bytes_for_test([1, 2, 3])),
      ]),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard negative_hival is Err(@core.PdfError::InvalidReadLength(-1)) else {
    fail(
      "expected @core.PdfError::InvalidReadLength for negative Indexed hival",
    )
  }
}

///|
test "PdfDocument read_colour_space parses Separation and DeviceN spaces" {
  let doc = @pdflite.pdf_document_empty()
  let empty_resources = @syntax.pdf_dictionary([])
  let tint = @syntax.pdf_dictionary([
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
        @syntax.pdf_dictionary([]),
      ),
    ),
  )
  let attributes = @syntax.pdf_dictionary([
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
  let empty_resources = @syntax.pdf_dictionary([])
  let tint = @syntax.pdf_dictionary([])
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
test "pdf_object_of_colour_space writes supported colour spaces" {
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
  let whitepoint : @pdflite.PdfTristimulusPoint = { x: 0.9, y: 1.0, z: 1.1 }
  let blackpoint : @pdflite.PdfTristimulusPoint = { x: 0.1, y: 0.2, z: 0.3 }
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(PdfCalGray(whitepoint, blackpoint, 2.2)),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/CalGray")),
        PdfDictionary([
          (
            space_name_for_test("/WhitePoint"),
            PdfArray([PdfReal(0.9), PdfReal(1.0), PdfReal(1.1)]),
          ),
          (
            space_name_for_test("/BlackPoint"),
            PdfArray([PdfReal(0.1), PdfReal(0.2), PdfReal(0.3)]),
          ),
          (space_name_for_test("/Gamma"), PdfReal(2.2)),
        ]),
      ]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfCalRGB(whitepoint, blackpoint, [1.0, 1.1, 1.2], [
        1.0, 0.0, 0.1, 0.0, 1.0, 0.2, 0.0, 0.0, 1.0,
      ]),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/CalRGB")),
        PdfDictionary([
          (
            space_name_for_test("/WhitePoint"),
            PdfArray([PdfReal(0.9), PdfReal(1.0), PdfReal(1.1)]),
          ),
          (
            space_name_for_test("/BlackPoint"),
            PdfArray([PdfReal(0.1), PdfReal(0.2), PdfReal(0.3)]),
          ),
          (
            space_name_for_test("/Gamma"),
            PdfArray([PdfReal(1.0), PdfReal(1.1), PdfReal(1.2)]),
          ),
          (
            space_name_for_test("/Matrix"),
            PdfArray([
              PdfReal(1.0),
              PdfReal(0.0),
              PdfReal(0.1),
              PdfReal(0.0),
              PdfReal(1.0),
              PdfReal(0.2),
              PdfReal(0.0),
              PdfReal(0.0),
              PdfReal(1.0),
            ]),
          ),
        ]),
      ]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfLab(whitepoint, blackpoint, [-80.0, 90.0, -70.0, 85.0]),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/Lab")),
        PdfDictionary([
          (
            space_name_for_test("/WhitePoint"),
            PdfArray([PdfReal(0.9), PdfReal(1.0), PdfReal(1.1)]),
          ),
          (
            space_name_for_test("/BlackPoint"),
            PdfArray([PdfReal(0.1), PdfReal(0.2), PdfReal(0.3)]),
          ),
          (
            space_name_for_test("/Range"),
            PdfArray([
              PdfReal(-80.0),
              PdfReal(90.0),
              PdfReal(-70.0),
              PdfReal(85.0),
            ]),
          ),
        ]),
      ]),
    ),
  )
  let icc_stream = @syntax.pdf_stream(
    @syntax.pdf_dictionary([(space_name_for_test("/N"), PdfInteger(3))]),
    StreamGot(@ascii.encode("icc")),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfICCBased(
        3,
        PdfDeviceRGB,
        [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
        None,
        icc_stream,
      ),
    ),
    Some(
      PdfArray([PdfNameObject(space_name_for_test("/ICCBased")), icc_stream]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfIndexed(PdfDeviceRGB, [(0, [4, 5, 6]), (1, [1, 2, 3])]),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/Indexed")),
        PdfNameObject(space_name_for_test("/DeviceRGB")),
        PdfInteger(1),
        PdfString(space_bytes_for_test([4, 5, 6, 1, 2, 3])),
      ]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_document_empty().write_colour_space(PdfDeviceRGB),
    PdfNameObject(space_name_for_test("/DeviceRGB")),
  )
  @test.assert_eq(
    @pdflite.pdf_write_colour_space(@pdflite.pdf_document_empty(), PdfDeviceRGB),
    PdfNameObject(space_name_for_test("/DeviceRGB")),
  )
  let tint : @syntax.PdfObject = PdfDictionary([
    (space_name_for_test("/FunctionType"), PdfInteger(2)),
  ])
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfSeparation(space_name_for_test("/Spot"), PdfDeviceCMYK, tint),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/Separation")),
        PdfNameObject(space_name_for_test("/Spot")),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
      ]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfDeviceN(
        [space_name_for_test("/Cyan"), space_name_for_test("/Magenta")],
        PdfDeviceCMYK,
        tint,
        @syntax.pdf_dictionary([]),
      ),
    ),
    Some(
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
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfDeviceN(
        [space_name_for_test("/Cyan")],
        PdfDeviceCMYK,
        tint,
        @syntax.pdf_dictionary([
          (space_name_for_test("/Subtype"), PdfInteger(1)),
        ]),
      ),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/DeviceN")),
        PdfArray([PdfNameObject(space_name_for_test("/Cyan"))]),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
        PdfDictionary([(space_name_for_test("/Subtype"), PdfInteger(1))]),
      ]),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfDeviceN([space_name_for_test("/Cyan")], PdfDeviceCMYK, tint, PdfNull),
    ),
    Some(
      PdfArray([
        PdfNameObject(space_name_for_test("/DeviceN")),
        PdfArray([PdfNameObject(space_name_for_test("/Cyan"))]),
        PdfNameObject(space_name_for_test("/DeviceCMYK")),
        tint,
        PdfNull,
      ]),
    ),
  )
}

///|
test "pdf_object_of_colour_space rejects unsupported indexed tables" {
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfIndexed(PdfDeviceRGB, [(1, [1, 2, 3])]),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfIndexed(PdfDeviceRGB, [(0, [1, 2, 256])]),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfIndexed(PdfDeviceRGB, [(0, [1, 2, 3]), (1, [4, 5])]),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfIndexed(PdfDeviceRGB, [(-1, [1, 2, 3])]),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(PdfIndexed(PdfPattern, [(0, [1])])),
    None,
  )
  let unsupported_base : @pdflite.PdfColourSpace = PdfIndexed(PdfDeviceRGB, [])
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfPatternWithBaseColourSpace(unsupported_base),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfSeparation(space_name_for_test("/Spot"), unsupported_base, PdfNull),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_object_of_colour_space(
      PdfDeviceN(
        [space_name_for_test("/Spot")],
        unsupported_base,
        PdfNull,
        PdfNull,
      ),
    ),
    None,
  )
  @test.assert_eq(
    @pdflite.pdf_document_empty().write_colour_space(
      PdfIndexed(PdfDeviceRGB, []),
    ),
    PdfNull,
  )
}
