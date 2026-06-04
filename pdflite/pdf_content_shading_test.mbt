///|
fn content_shading_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_shading_function_for_test(n : Double) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (content_shading_name_for_test("/FunctionType"), PdfInteger(2)),
    (
      content_shading_name_for_test("/Domain"),
      PdfArray([PdfInteger(0), PdfInteger(1)]),
    ),
    (content_shading_name_for_test("/N"), PdfReal(n)),
  ])
}

///|
test "cpdfcontent function shading reads domain matrix and fallback function" {
  let doc = @pdflite.pdf_document_empty()
  let shading = @syntax.pdf_dictionary([
    (
      content_shading_name_for_test("/Domain"),
      PdfArray([PdfInteger(2), PdfInteger(3), PdfInteger(4), PdfInteger(5)]),
    ),
    (
      content_shading_name_for_test("/Matrix"),
      PdfArray([
        PdfInteger(1),
        PdfInteger(0),
        PdfInteger(0),
        PdfInteger(1),
        PdfInteger(7),
        PdfInteger(8),
      ]),
    ),
    (
      content_shading_name_for_test("/Function"),
      content_shading_function_for_test(2.0),
    ),
  ])
  guard (try! doc.content_read_function_shading(shading))
    is PdfContentFunctionShading(function_shading) else {
    fail("expected function shading")
  }
  @test.assert_eq(function_shading.funshading_domain, (2.0, 3.0, 4.0, 5.0))
  @test.assert_eq(
    function_shading.funshading_matrix,
    @geometry.transform_translate(7.0, 8.0),
  )
  guard function_shading.funshading_function.func
    is PdfFunctionInterpolation(interpolation) else {
    fail("expected interpolation function")
  }
  @test.assert_eq(interpolation.n, 2.0)
  guard (try! doc.content_read_function_shading(@syntax.pdf_dictionary([])))
    is PdfContentFunctionShading(default_shading) else {
    fail("expected default function shading")
  }
  @test.assert_eq(default_shading.funshading_domain, (0.0, 1.0, 0.0, 1.0))
  @test.assert_eq(
    default_shading.funshading_matrix,
    @geometry.transform_identity_matrix,
  )
  guard default_shading.funshading_function.func
    is PdfFunctionCalculator(calculator) else {
    fail("expected default calculator function")
  }
  @test.assert_eq(calculator.operations.length(), 0)
}

///|
test "cpdfcontent radial and axial shading readers mirror source defaults" {
  let doc = @pdflite.pdf_document_empty()
  let radial = @syntax.pdf_dictionary([
    (
      content_shading_name_for_test("/Coords"),
      PdfArray([
        PdfInteger(1),
        PdfInteger(2),
        PdfInteger(3),
        PdfInteger(4),
        PdfInteger(5),
        PdfInteger(6),
      ]),
    ),
    (
      content_shading_name_for_test("/Domain"),
      PdfArray([PdfReal(0.25), PdfReal(0.75)]),
    ),
    (
      content_shading_name_for_test("/Function"),
      PdfArray([
        content_shading_function_for_test(1.0),
        content_shading_function_for_test(3.0),
      ]),
    ),
    (
      content_shading_name_for_test("/Extend"),
      PdfArray([PdfBoolean(true), PdfBoolean(false)]),
    ),
  ])
  guard (try! doc.content_read_radial_shading(radial))
    is PdfContentRadialShading(radial_shading) else {
    fail("expected radial shading")
  }
  @test.assert_eq(
    radial_shading.radialshading_coords,
    (1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
  )
  @test.assert_eq(radial_shading.radialshading_domain, (0.25, 0.75))
  @test.assert_eq(radial_shading.radialshading_function.length(), 2)
  @test.assert_eq(radial_shading.radialshading_extend, (true, false))
  guard (try! doc.content_read_axial_shading(@syntax.pdf_dictionary([])))
    is PdfContentAxialShading(axial_shading) else {
    fail("expected axial shading")
  }
  @test.assert_eq(axial_shading.axialshading_coords, (0.0, 0.0, 0.0, 0.0))
  @test.assert_eq(axial_shading.axialshading_domain, (0.0, 1.0))
  @test.assert_eq(axial_shading.axialshading_function.length(), 1)
  @test.assert_eq(axial_shading.axialshading_extend, (false, false))
}

///|
test "cpdfcontent shading wrapper preserves source field semantics" {
  let doc = @pdflite.pdf_document_empty()
  let shading_object = @syntax.pdf_dictionary([
    (content_shading_name_for_test("/ShadingType"), PdfInteger(3)),
    (
      content_shading_name_for_test("/Coords"),
      PdfArray([
        PdfInteger(0),
        PdfInteger(1),
        PdfInteger(2),
        PdfInteger(3),
        PdfInteger(4),
        PdfInteger(5),
      ]),
    ),
    (
      content_shading_name_for_test("/colourSpace"),
      PdfNameObject(content_shading_name_for_test("/DeviceRGB")),
    ),
    (content_shading_name_for_test("/Background"), PdfArray([PdfReal(0.5)])),
    (content_shading_name_for_test("/BBox"), PdfBoolean(true)),
  ])
  let extgstate = @syntax.pdf_dictionary([
    (content_shading_name_for_test("/CA"), PdfReal(0.5)),
  ])
  let shading = try! doc.content_read_shading(
    @geometry.transform_translate(1.0, 2.0),
    extgstate,
    shading_object,
  )
  @test.assert_eq(
    shading.shading_colourspace,
    PdfNameObject(content_shading_name_for_test("/DeviceRGB")),
  )
  @test.assert_eq(shading.shading_background, Some(PdfArray([PdfReal(0.5)])))
  @test.assert_eq(shading.shading_bbox, Some(PdfBoolean(true)))
  @test.assert_eq(shading.shading_antialias, true)
  @test.assert_eq(
    shading.shading_matrix,
    @geometry.transform_translate(1.0, 2.0),
  )
  @test.assert_eq(shading.shading_extgstate, extgstate)
  guard shading.shading is PdfContentRadialShading(_) else {
    fail("expected radial shading kind")
  }
  let fallback = try! doc.content_read_shading(
    @geometry.transform_identity_matrix,
    @syntax.pdf_dictionary([]),
    @syntax.pdf_dictionary([]),
  )
  @test.assert_eq(fallback.shading_colourspace, PdfNull)
  guard fallback.shading is PdfContentTensorProductPatchMesh else {
    fail("expected tensor-product fallback")
  }
}

///|
test "cpdfcontent pattern reader handles tiling shading missing resources" {
  let doc = @pdflite.pdf_document_empty()
  let tiling_name = content_shading_name_for_test("/P1")
  let shading_name = content_shading_name_for_test("/P2")
  let missing_shading_name = content_shading_name_for_test("/P3")
  let resources = @syntax.pdf_dictionary([
    (
      content_shading_name_for_test("/Pattern"),
      @syntax.pdf_dictionary([
        (
          tiling_name,
          @syntax.pdf_dictionary([
            (content_shading_name_for_test("/PatternType"), PdfInteger(1)),
          ]),
        ),
        (
          shading_name,
          @syntax.pdf_dictionary([
            (content_shading_name_for_test("/PatternType"), PdfInteger(2)),
            (
              content_shading_name_for_test("/Shading"),
              @syntax.pdf_dictionary([
                (content_shading_name_for_test("/ShadingType"), PdfInteger(2)),
              ]),
            ),
          ]),
        ),
        (
          missing_shading_name,
          @syntax.pdf_dictionary([
            (content_shading_name_for_test("/PatternType"), PdfInteger(2)),
          ]),
        ),
      ]),
    ),
  ])
  guard (try! doc.content_read_pattern(resources, tiling_name))
    is Some(PdfContentColouredTilingPattern(PdfContentTiling)) else {
    fail("expected tiling pattern")
  }
  guard (try! doc.content_read_pattern(resources, shading_name))
    is Some(PdfContentShadingPattern(shading)) else {
    fail("expected shading pattern")
  }
  guard shading.shading is PdfContentAxialShading(_) else {
    fail("expected axial shading pattern")
  }
  @test.assert_eq(
    try! @pdflite.pdf_content_read_pattern(
      doc,
      resources,
      content_shading_name_for_test("/Missing"),
    ),
    None,
  )
  let missing_shading = try
    doc.content_read_pattern(resources, missing_shading_name)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_shading is Err(SoftError("No shading dictionary")) else {
    fail("expected SoftError for missing shading dictionary")
  }
}
