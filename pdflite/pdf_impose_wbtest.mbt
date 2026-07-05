///|
fn impose_box_for_test(width : Double, height : Double) -> @syntax.PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(height)])
}

///|
fn impose_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn impose_assert_close_for_test(
  actual : Double,
  expected : Double,
) -> Unit raise {
  if (actual - expected).abs() > 0.000000001 {
    fail(
      "expected " +
      actual.to_string() +
      " to be close to " +
      expected.to_string(),
    )
  }
}

///|
fn impose_assert_matrix_close_for_test(
  actual : @geometry.TransformMatrix,
  expected : @geometry.TransformMatrix,
) -> Unit raise {
  impose_assert_close_for_test(actual.a, expected.a)
  impose_assert_close_for_test(actual.b, expected.b)
  impose_assert_close_for_test(actual.c, expected.c)
  impose_assert_close_for_test(actual.d, expected.d)
  impose_assert_close_for_test(actual.e, expected.e)
  impose_assert_close_for_test(actual.f, expected.f)
}

///|
fn impose_assert_box_close_for_test(
  document : PdfDocument,
  box : @syntax.PdfObject,
  width : Double,
  height : Double,
) -> Unit raise {
  let bounds = document.parse_rectangle(box)
  impose_assert_close_for_test(bounds.min_x, 0.0)
  impose_assert_close_for_test(bounds.min_y, 0.0)
  impose_assert_close_for_test(bounds.max_x, width)
  impose_assert_close_for_test(bounds.max_y, height)
}

///|
fn impose_assert_cm_close_for_test(
  op : @content.PdfContentOp,
  expected : @geometry.TransformMatrix,
) -> Unit raise {
  guard op is Op_cm(matrix) else { fail("expected cm operator") }
  impose_assert_matrix_close_for_test(matrix, expected)
}

///|
fn impose_transforms_for_test(
  fit? : Bool = false,
  x? : Int = 2,
  y? : Int = 2,
  columns? : Bool = false,
  rtl? : Bool = false,
  btt? : Bool = false,
  center? : Bool = false,
  margin? : Double = 0.0,
  page_width? : Double = 100.0,
  page_height? : Double = 200.0,
  output_width? : Double = 200.0,
  output_height? : Double = 400.0,
  fit_extra_hspace? : Double = 0.0,
  fit_extra_vspace? : Double = 0.0,
  count? : Int = 3,
) -> Array[@geometry.TransformMatrix] raise @core.PdfError {
  pdf_document_empty().pdf_impose_transforms(
    fit,
    x,
    y,
    columns,
    rtl,
    btt,
    center,
    margin,
    impose_box_for_test(page_width, page_height),
    impose_box_for_test(output_width, output_height),
    fit_extra_hspace,
    fit_extra_vspace,
    count,
  )
}

///|
fn impose_content_stream_for_test(
  ops : ArrayView[@content.PdfContentOp],
) -> @syntax.PdfObject raise @core.PdfError {
  pdf_content_stream_of_ops(ops)
}

///|
fn impose_content_ops_for_test(
  document : PdfDocument,
  content : ArrayView[@syntax.PdfObject],
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  document.parse_content_ops_with_resources(PdfDictionary([]), content)
}

///|
fn impose_page_for_test(
  ops : ArrayView[@content.PdfContentOp],
  resources? : @syntax.PdfObject = PdfDictionary([]),
  rest? : @syntax.PdfObject = PdfDictionary([]),
  rotate? : @page.PdfPageRotation = Rotate0,
  width? : Double = 100.0,
  height? : Double = 100.0,
) -> @page.PdfPage raise @core.PdfError {
  {
    content: [pdf_content_stream_of_ops(ops)],
    mediabox: impose_box_for_test(width, height),
    resources,
    rotate,
    rest,
  }
}

///|
fn impose_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> PdfDocument raise @core.PdfError {
  pdf_blank_document(100.0, 100.0, pages.length()).change_pages(pages)
}

///|
fn impose_page_content_ops_for_test(
  document : PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  document.parse_content_ops_with_resources(page.resources, page.content)
}

///|
test "pdf_impose_make_space hard boxes even with zero spacing" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=80.0),
  ])
  let spaced = try! document.pdf_impose_make_space(false, 0.0, false)
  let pages = try! spaced.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, impose_box_for_test(100.0, 80.0))
  @test.assert_eq(try! impose_page_content_ops_for_test(spaced, pages[0]), [
    Op_re(0.0, 0.0, 100.0, 80.0),
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "pdf_impose_make_space expands non-fit pages after shifting contents" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=80.0),
  ])
  let spaced = try! document.pdf_impose_make_space(false, 20.0, false)
  let pages = try! spaced.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, impose_box_for_test(120.0, 100.0))
  @test.assert_eq(try! impose_page_content_ops_for_test(spaced, pages[0]), [
    Op_cm(@geometry.transform_translate(10.0, 10.0)),
    Op_re(0.0, 0.0, 100.0, 80.0),
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "pdf_impose_make_space fit scales and shifts while preserving page size" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=80.0),
  ])
  let spaced = try! document.pdf_impose_make_space(true, 20.0, false)
  let pages = try! spaced.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, impose_box_for_test(100.0, 80.0))
  @test.assert_eq(try! impose_page_content_ops_for_test(spaced, pages[0]), [
    Op_cm(@geometry.transform_translate(10.0, 10.0)),
    Op_cm(@geometry.transform_scale(@geometry.point2(0.0, 0.0), 0.8, 0.8)),
    Op_re(0.0, 0.0, 100.0, 80.0),
    Op_W,
    Op_n,
    Op_S,
  ])
}

///|
test "pdf_impose_add_border appends cpdf stamp rectangle" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=80.0),
    try! impose_page_for_test([Op_BT, Op_ET], width=100.0, height=80.0),
  ])
  let bordered = try! document.pdf_impose_add_border(2.0, false)
  let pages = try! bordered.pages_of_pagetree()
  let border_ops : ReadOnlyArray[@content.PdfContentOp] = [
    @content.pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(impose_name_for_test("/CPDFSTAMP")),
    Op_rg(0.0, 0.0, 0.0),
    Op_RG(0.0, 0.0, 0.0),
    Op_w(2.0),
    Op_re(1.0, 1.0, 98.0, 78.0),
    Op_s,
    Op_EMC,
    Op_Q,
    @content.pdf_content_end_artifact(),
  ]
  @test.assert_eq(
    try! impose_page_content_ops_for_test(bordered, pages[0]),
    pdf_page_concat_ops([Op_q, Op_S, Op_Q], border_ops),
  )
  @test.assert_eq(
    try! impose_page_content_ops_for_test(bordered, pages[1]),
    pdf_page_concat_ops([Op_q, Op_BT, Op_ET, Op_Q], border_ops),
  )
}

///|
test "pdf_impose_add_border treats zero width as no border" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=80.0),
  ])
  let bordered = try! document.pdf_impose_add_border(0.0, true)
  let pages = try! bordered.pages_of_pagetree()
  @test.assert_eq(try! impose_page_content_ops_for_test(bordered, pages[0]), [
    Op_S,
  ])
}

///|
test "pdf_impose_layout calculates fit sheets and spacing" {
  let layout = try! pdf_document_empty().pdf_impose_layout(
    true,
    220.0,
    120.0,
    0.0,
    5,
    impose_box_for_test(100.0, 50.0),
  )
  @test.assert_eq(layout.pages_per_sheet, 4)
  @test.assert_eq(layout.x_slots, 2)
  @test.assert_eq(layout.y_slots, 2)
  @test.assert_eq(layout.output_mediabox, impose_box_for_test(220.0, 120.0))
  @test.assert_eq(layout.fit_extra_hspace, 20.0 / 3.0)
  @test.assert_eq(layout.fit_extra_vspace, 20.0 / 3.0)

  let too_small : Result[PdfImposeLayout, Error] = try
    pdf_document_empty().pdf_impose_layout(
      true,
      99.0,
      120.0,
      0.0,
      5,
      impose_box_for_test(100.0, 50.0),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard too_small
    is Err(
      @core.PdfError::BadNumberArgument(
        "impose: not even a single page would fit"
      )
    ) else {
    fail("expected fit layout to reject too-small output")
  }
}

///|
test "pdf_impose_layout calculates non-fit stacks and output boxes" {
  let horizontal = try! pdf_document_empty().pdf_impose_layout(
    false,
    0.0,
    1.0,
    5.0,
    3,
    impose_box_for_test(100.0, 50.0),
  )
  @test.assert_eq(horizontal.pages_per_sheet, 3)
  @test.assert_eq(horizontal.x_slots, 3)
  @test.assert_eq(horizontal.y_slots, 1)
  @test.assert_eq(horizontal.output_mediabox, impose_box_for_test(310.0, 60.0))

  let vertical = try! pdf_document_empty().pdf_impose_layout(
    false,
    2.0,
    0.0,
    5.0,
    3,
    impose_box_for_test(100.0, 50.0),
  )
  @test.assert_eq(vertical.pages_per_sheet, 3)
  @test.assert_eq(vertical.x_slots, 1)
  @test.assert_eq(vertical.y_slots, 3)
  @test.assert_eq(vertical.output_mediabox, impose_box_for_test(110.0, 160.0))

  let grid = try! pdf_document_empty().pdf_impose_layout(
    false,
    2.0,
    3.0,
    5.0,
    7,
    impose_box_for_test(100.0, 50.0),
  )
  @test.assert_eq(grid.pages_per_sheet, 6)
  @test.assert_eq(grid.x_slots, 2)
  @test.assert_eq(grid.y_slots, 3)
  @test.assert_eq(grid.output_mediabox, impose_box_for_test(210.0, 160.0))

  let bad_zero : Result[PdfImposeLayout, Error] = try
    pdf_document_empty().pdf_impose_layout(
      false,
      0.0,
      0.0,
      0.0,
      3,
      impose_box_for_test(100.0, 50.0),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_zero
    is Err(
      @core.PdfError::BadNumberArgument(
        "impose-xy: both dimensions cannot be zero"
      )
    ) else {
    fail("expected non-fit layout to reject zero dimensions")
  }
}

///|
test "PdfDocument impose assembles simple non-fit sheets" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
    try! impose_page_for_test([Op_BT, Op_ET], width=100.0, height=100.0),
  ])
  let imposed = try! document.impose(2.0, 1.0)
  let pages = try! imposed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].mediabox, impose_box_for_test(200.0, 100.0))
  @test.assert_eq(try! impose_page_content_ops_for_test(imposed, pages[0]), [
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_re(0.0, 0.0, 100.0, 100.0),
    Op_W,
    Op_n,
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(@geometry.transform_translate(100.0, 0.0)),
    Op_re(0.0, 0.0, 100.0, 100.0),
    Op_W,
    Op_n,
    Op_BT,
    Op_ET,
    Op_Q,
  ])
}

///|
test "PdfDocument impose applies non-fit output margin through wrapper" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
  ])
  let imposed = try! pdf_impose(document, 1.0, 0.0, margin=10.0)
  let pages = try! imposed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].mediabox, impose_box_for_test(120.0, 220.0))
  let ops = try! impose_page_content_ops_for_test(imposed, pages[0])
  @test.assert_eq(ops[0], Op_cm(@geometry.transform_translate(10.0, 10.0)))
}

///|
test "PdfDocument impose calculates fit-mode extra spacing" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
  ])
  let imposed = try! document.impose(250.0, 120.0, fit=true)
  let pages = try! imposed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].mediabox, impose_box_for_test(250.0, 120.0))
  @test.assert_eq(try! impose_page_content_ops_for_test(imposed, pages[0]), [
    Op_q,
    Op_cm(@geometry.transform_translate(16.6666666667, 10.0)),
    Op_re(0.0, 0.0, 100.0, 100.0),
    Op_W,
    Op_n,
    Op_S,
    Op_Q,
  ])
}

///|
test "PdfDocument impose retargets page references to imposed sheets" {
  let key_open_action = impose_name_for_test("/OpenAction")
  let xyz_name = impose_name_for_test("/XYZ")
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
    try! impose_page_for_test([Op_BT, Op_ET], width=100.0, height=100.0),
  ])
  let page_numbers = try! document.page_reference_numbers()
  document.add_object_given_number(
    document.root(),
    try! document
    .lookup_object_or_null(document.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(page_numbers[1]),
        PdfNameObject(xyz_name),
        PdfReal(10.0),
        PdfReal(20.0),
        PdfNull,
      ]),
    ),
  )
  let imposed = try! document.impose(2.0, 1.0)
  let imposed_numbers = try! imposed.page_reference_numbers()
  guard imposed
    .lookup_object_or_null(imposed.root())
    .lookup_immediate(key_open_action)
    is Some(open_action) else {
    fail("expected imposed open action")
  }
  @test.assert_eq(
    imposed.direct(open_action),
    PdfArray([
      PdfIndirect(imposed_numbers[0]),
      PdfNameObject(xyz_name),
      PdfReal(10.0),
      PdfReal(20.0),
      PdfNull,
    ]),
  )
}

///|
test "PdfDocument impose marks source content as artifact for structure trees" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
  ])
  let imposed = try! document.impose(1.0, 1.0, process_struct_tree=true)
  let pages = try! imposed.pages_of_pagetree()
  @test.assert_eq(try! impose_page_content_ops_for_test(imposed, pages[0]), [
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_re(0.0, 0.0, 100.0, 100.0),
    Op_W,
    Op_n,
    @content.pdf_content_begin_artifact(),
    Op_S,
    @content.pdf_content_end_artifact(),
    Op_Q,
  ])
}

///|
test "PdfDocument twoup_stack imposes and uprights two-page sheets" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=100.0),
    try! impose_page_for_test([Op_BT, Op_ET], width=100.0, height=100.0),
  ])
  let stacked = try! document.twoup_stack()
  let pages = try! stacked.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].rotate, Rotate0)
  try! impose_assert_box_close_for_test(
    stacked,
    pages[0].mediabox,
    100.0,
    200.0,
  )
  let ops = try! impose_page_content_ops_for_test(stacked, pages[0])
  impose_assert_cm_close_for_test(
    ops[0],
    @geometry.transform_translate(-50.0, 50.0),
  )
  impose_assert_cm_close_for_test(
    ops[1],
    @geometry.transform_rotate(@geometry.point2(100.0, 50.0), @math.PI / 2.0),
  )
  let actual_tail : Array[@content.PdfContentOp] = []
  for op in ops[2:] {
    actual_tail.push(op)
  }
  @test.assert_eq(actual_tail, [
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_q,
    Op_cm(@geometry.transform_translate(0.0, 0.0)),
    Op_re(0.0, 0.0, 100.0, 100.0),
    Op_W,
    Op_n,
    Op_S,
    Op_Q,
    Op_q,
    Op_cm(@geometry.transform_translate(100.0, 0.0)),
    Op_re(0.0, 0.0, 100.0, 100.0),
    Op_W,
    Op_n,
    Op_BT,
    Op_ET,
    Op_Q,
  ])
  let wrapped = try! pdf_twoup_stack(document)
  @test.assert_eq((try! wrapped.pages_of_pagetree()).length(), 1)
}

///|
test "PdfDocument twoup scales imposed sheets back to first page size" {
  let document = try! impose_document_for_test([
    try! impose_page_for_test([Op_S], width=100.0, height=200.0),
    try! impose_page_for_test([Op_BT, Op_ET], width=100.0, height=200.0),
  ])
  let twoup = try! document.twoup()
  let pages = try! twoup.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].rotate, Rotate0)
  try! impose_assert_box_close_for_test(twoup, pages[0].mediabox, 100.0, 200.0)
  let wrapped = try! pdf_twoup(document)
  @test.assert_eq((try! wrapped.pages_of_pagetree()).length(), 1)
}

///|
test "PdfDocument impose rejects empty input" {
  let document = try! pdf_blank_document(10.0, 10.0, 0)
  let result : Result[PdfDocument, Error] = try
    document.impose(1.0, 1.0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result
    is Err(@core.PdfError::BadNumberArgument("impose: pages must not be empty")) else {
    fail("expected impose to reject empty documents")
  }
}

///|
test "pdf_impose_transforms preserves row and column ordering" {
  @test.assert_eq(try! impose_transforms_for_test(columns=false, count=3), [
    @geometry.transform_translate(0.0, 200.0),
    @geometry.transform_translate(100.0, 200.0),
    @geometry.transform_translate(0.0, 0.0),
  ])
  @test.assert_eq(try! impose_transforms_for_test(columns=true, count=3), [
    @geometry.transform_translate(0.0, 200.0),
    @geometry.transform_translate(0.0, 0.0),
    @geometry.transform_translate(100.0, 200.0),
  ])
}

///|
test "pdf_impose_transforms centers short final rows" {
  @test.assert_eq(
    try! impose_transforms_for_test(x=3, y=1, center=true, count=2),
    [
      @geometry.transform_translate(50.0, 0.0),
      @geometry.transform_translate(150.0, 0.0),
    ],
  )
}

///|
test "pdf_impose_transforms preserves right-to-left and bottom-to-top ordering" {
  @test.assert_eq(
    try! impose_transforms_for_test(rtl=true, btt=true, count=4),
    [
      @geometry.transform_translate(100.0, 0.0),
      @geometry.transform_translate(0.0, 0.0),
      @geometry.transform_translate(100.0, 200.0),
      @geometry.transform_translate(0.0, 200.0),
    ],
  )
}

///|
test "pdf_impose_transforms applies fit spacing and margin transforms" {
  @test.assert_eq(
    try! impose_transforms_for_test(
      x=2,
      y=1,
      output_width=220.0,
      output_height=120.0,
      fit_extra_hspace=5.0,
      fit_extra_vspace=7.0,
      count=2,
    ),
    [
      @geometry.transform_translate(5.0, 7.0),
      @geometry.transform_translate(110.0, 7.0),
    ],
  )
  @test.assert_eq(
    try! impose_transforms_for_test(
      fit=true,
      x=1,
      y=1,
      margin=10.0,
      page_width=200.0,
      page_height=100.0,
      output_width=200.0,
      output_height=100.0,
      count=1,
    ),
    [{ a: 0.8, b: 0.0, c: 0.0, d: 0.8, e: 20.0, f: 10.0 }],
  )
}

///|
test "pdf_impose_transforms rejects invalid grids and margins" {
  let bad_grid : Result[Array[@geometry.TransformMatrix], Error] = try
    impose_transforms_for_test(x=0)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_grid
    is Err(
      @core.PdfError::BadNumberArgument("impose: x and y must be positive")
    ) else {
    fail("expected BadNumberArgument for non-positive imposition grid")
  }

  let bad_margin : Result[Array[@geometry.TransformMatrix], Error] = try
    impose_transforms_for_test(
      fit=true,
      x=1,
      y=1,
      margin=60.0,
      output_width=200.0,
      output_height=100.0,
      count=1,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_margin
    is Err(
      @core.PdfError::BadNumberArgument("impose: margin would fill whole page")
    ) else {
    fail("expected BadNumberArgument for over-large imposition margin")
  }
}

///|
test "pdf_impose_transform_content wraps fast and parsed content like cpdf" {
  let document = pdf_document_empty()
  let matrix = @geometry.transform_translate(10.0, 20.0)
  let source : ReadOnlyArray[@syntax.PdfObject] = [
    try! impose_content_stream_for_test([Op_BT, Op_ET]),
  ]
  let fast = try! document.pdf_impose_transform_content(
    PdfDictionary([]),
    matrix,
    source,
    true,
  )
  @test.assert_eq(fast.length(), 3)
  @test.assert_eq(try! impose_content_ops_for_test(document, fast), [
    Op_q,
    Op_cm(matrix),
    Op_BT,
    Op_ET,
    Op_Q,
  ])

  let unbalanced : ReadOnlyArray[@syntax.PdfObject] = [
    try! impose_content_stream_for_test([Op_q, Op_BT]),
  ]
  let parsed = try! document.pdf_impose_transform_content(
    PdfDictionary([]),
    matrix,
    unbalanced,
    false,
  )
  @test.assert_eq(parsed.length(), 1)
  @test.assert_eq(try! impose_content_ops_for_test(document, parsed), [
    Op_q,
    Op_cm(matrix),
    Op_Q,
    Op_q,
    Op_BT,
    Op_Q,
  ])
}

///|
test "pdf_impose_pages_core combines pages and transforms annotations" {
  let document = pdf_document_empty()
  let key_annots = impose_name_for_test("/Annots")
  let key_rect = impose_name_for_test("/Rect")
  let key_font = impose_name_for_test("/Font")
  let key_xobject = impose_name_for_test("/XObject")
  let key_first = impose_name_for_test("/First")
  let key_second = impose_name_for_test("/Second")
  let first_font = impose_name_for_test("/F1")
  let second_xobject = impose_name_for_test("/Im1")
  let direct_annotation = @syntax.PdfDictionary([
    (
      key_rect,
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
    ),
  ])
  document.add_object_given_number(
    20,
    PdfDictionary([
      (
        key_rect,
        PdfArray([PdfInteger(1), PdfInteger(2), PdfInteger(3), PdfInteger(4)]),
      ),
    ]),
  )
  let first_page = try! impose_page_for_test(
    [Op_BT, Op_ET],
    resources=PdfDictionary([
      (key_font, PdfDictionary([(first_font, PdfIndirect(10))])),
    ]),
    rest=PdfDictionary([
      (key_first, PdfInteger(1)),
      (key_annots, PdfArray([direct_annotation])),
    ]),
    rotate=Rotate90,
  )
  let second_page = try! impose_page_for_test(
    [Op_S],
    resources=PdfDictionary([
      (key_xobject, PdfDictionary([(second_xobject, PdfIndirect(11))])),
    ]),
    rest=PdfDictionary([
      (key_second, PdfInteger(2)),
      (key_annots, PdfArray([PdfIndirect(20)])),
    ]),
  )
  let imposed = try! document.pdf_impose_pages_core(
    [first_page, second_page],
    false,
    2,
    1,
    false,
    false,
    false,
    false,
    0.0,
    impose_box_for_test(200.0, 100.0),
    false,
    0.0,
    0.0,
  )
  @test.assert_eq(imposed.mediabox, impose_box_for_test(200.0, 100.0))
  @test.assert_eq(imposed.rotate, Rotate90)
  @test.assert_eq(imposed.content.length(), 2)
  @test.assert_eq(
    document.parse_content_ops_with_resources(
      imposed.resources,
      imposed.content,
    ),
    [
      Op_q,
      Op_cm(@geometry.transform_translate(0.0, 0.0)),
      Op_BT,
      Op_ET,
      Op_Q,
      Op_q,
      Op_cm(@geometry.transform_translate(100.0, 0.0)),
      Op_S,
      Op_Q,
    ],
  )
  @test.assert_eq(
    imposed.resources.lookup_immediate(key_font),
    Some(PdfDictionary([(first_font, PdfIndirect(10))])),
  )
  @test.assert_eq(
    imposed.resources.lookup_immediate(key_xobject),
    Some(PdfDictionary([(second_xobject, PdfIndirect(11))])),
  )
  @test.assert_eq(imposed.rest.lookup_immediate(key_first), Some(PdfInteger(1)))
  @test.assert_eq(
    imposed.rest.lookup_immediate(key_second),
    Some(PdfInteger(2)),
  )
  guard imposed.rest.lookup_immediate(key_annots)
    is Some(PdfArray([PdfDictionary(_) as annotation, PdfIndirect(20)])) else {
    fail("expected combined annotation array")
  }
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(10.0), PdfReal(10.0)])),
  )
  @test.assert_eq(
    document.lookup_object_or_null(20).lookup_immediate(key_rect),
    Some(PdfArray([PdfReal(101.0), PdfReal(2.0), PdfReal(103.0), PdfReal(4.0)])),
  )
}

///|
test "pdf_impose pattern matrix rewrite only changes scn-used patterns" {
  let document = pdf_document_empty()
  let key_matrix = impose_name_for_test("/Matrix")
  let key_pattern = impose_name_for_test("/Pattern")
  let pattern_name = impose_name_for_test("/P1")
  let pattern_by_values = impose_name_for_test("/P2")
  let old_matrix = {
    ..@geometry.transform_identity_matrix,
    a: 2.0,
    d: 3.0,
    e: 4.0,
    f: 5.0,
  }
  let by_values_matrix = @geometry.transform_translate(7.0, 8.0)
  let page = try! impose_page_for_test(
    [Op_scnName(pattern_name, []), Op_SCNName(pattern_by_values, [0.5])],
    resources=PdfDictionary([
      (
        key_pattern,
        PdfDictionary([
          (
            pattern_name,
            PdfDictionary([(key_matrix, pdf_object_of_matrix(old_matrix))]),
          ),
          (
            pattern_by_values,
            PdfDictionary([(key_matrix, pdf_object_of_matrix(by_values_matrix))]),
          ),
        ]),
      ),
    ]),
  )
  let rewritten = try! document.pdf_impose_change_pattern_matrices_page(
    @geometry.transform_translate(10.0, 20.0),
    page,
  )
  guard rewritten.resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary(patterns)) else {
    fail("expected rewritten pattern resource dictionary")
  }
  guard patterns[0] is (name, PdfIndirect(number)) && name == pattern_name else {
    fail("expected scn-used pattern to be cloned as an indirect object")
  }
  let expected_matrix = @geometry.transform_matrix_compose(
    @geometry.transform_translate(10.0, 20.0),
    old_matrix,
  )
  @test.assert_eq(
    document.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(pdf_object_of_matrix(expected_matrix)),
  )
  @test.assert_eq(
    patterns[1],
    (
      pattern_by_values,
      PdfDictionary([(key_matrix, pdf_object_of_matrix(by_values_matrix))]),
    ),
  )
}

///|
test "pdf_impose pages core rewrites pattern matrices before combining resources" {
  let document = pdf_document_empty()
  let key_matrix = impose_name_for_test("/Matrix")
  let key_pattern = impose_name_for_test("/Pattern")
  let pattern_name = impose_name_for_test("/P1")
  let old_matrix = @geometry.transform_translate(3.0, 4.0)
  let first_page = try! impose_page_for_test([Op_S])
  let second_page = try! impose_page_for_test(
    [Op_scnName(pattern_name, [])],
    resources=PdfDictionary([
      (
        key_pattern,
        PdfDictionary([
          (
            pattern_name,
            PdfDictionary([(key_matrix, pdf_object_of_matrix(old_matrix))]),
          ),
        ]),
      ),
    ]),
  )
  let imposed = try! document.pdf_impose_pages_core(
    [first_page, second_page],
    false,
    2,
    1,
    false,
    false,
    false,
    false,
    0.0,
    impose_box_for_test(200.0, 100.0),
    false,
    0.0,
    0.0,
  )
  guard imposed.resources.lookup_immediate(key_pattern)
    is Some(PdfDictionary([(name, PdfIndirect(number))])) &&
    name == pattern_name else {
    fail("expected imposed resources to contain rewritten pattern")
  }
  @test.assert_eq(
    document.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      pdf_object_of_matrix(
        @geometry.transform_matrix_compose(
          @geometry.transform_translate(100.0, 0.0),
          old_matrix,
        ),
      ),
    ),
  )
}

///|
test "pdf_impose pattern matrix rewrite descends into form xobjects" {
  let document = pdf_document_empty()
  let key_matrix = impose_name_for_test("/Matrix")
  let key_pattern = impose_name_for_test("/Pattern")
  let key_resources = impose_name_for_test("/Resources")
  let key_xobject = impose_name_for_test("/XObject")
  let key_subtype = impose_name_for_test("/Subtype")
  let form_name = impose_name_for_test("/Form")
  let xobject_name = impose_name_for_test("/Fm1")
  let pattern_name = impose_name_for_test("/PX")
  let old_matrix = @geometry.transform_translate(1.0, 2.0)
  let form = try! (try! pdf_content_stream_of_ops([Op_SCNName(pattern_name, [])]))
    .add_dict_entry(key_subtype, PdfNameObject(form_name))
    .add_dict_entry(
      key_resources,
      PdfDictionary([
        (
          key_pattern,
          PdfDictionary([
            (
              pattern_name,
              PdfDictionary([(key_matrix, pdf_object_of_matrix(old_matrix))]),
            ),
          ]),
        ),
      ]),
    )
  document.add_object_given_number(30, form)
  let page = try! impose_page_for_test(
    [Op_Do(xobject_name)],
    resources=PdfDictionary([
      (key_xobject, PdfDictionary([(xobject_name, PdfIndirect(30))])),
    ]),
  )
  ignore(
    try! document.pdf_impose_change_pattern_matrices_page(
      @geometry.transform_translate(10.0, 20.0),
      page,
    ),
  )
  guard document.lookup_object_or_null(30).lookup_immediate(key_resources)
    is Some(
      PdfDictionary(
        [(pattern_key, PdfDictionary([(name, PdfIndirect(number))]))]
      )
    ) &&
    pattern_key == key_pattern &&
    name == pattern_name else {
    fail("expected form xobject pattern to be rewritten")
  }
  @test.assert_eq(
    document.lookup_object_or_null(number).lookup_immediate(key_matrix),
    Some(
      pdf_object_of_matrix(
        @geometry.transform_matrix_compose(
          @geometry.transform_translate(10.0, 20.0),
          old_matrix,
        ),
      ),
    ),
  )
}

///|
test "pdf_impose_pages_core rejects empty page sets" {
  let result : Result[@page.PdfPage, Error] = try
    pdf_document_empty().pdf_impose_pages_core(
      [],
      false,
      1,
      1,
      false,
      false,
      false,
      false,
      0.0,
      impose_box_for_test(100.0, 100.0),
      false,
      0.0,
      0.0,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result
    is Err(@core.PdfError::BadNumberArgument("impose: pages must not be empty")) else {
    fail("expected BadNumberArgument for empty imposition page set")
  }
}
