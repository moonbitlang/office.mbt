///|
test "drawing/chart/form-control APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let add_image_result : Result[Unit, Error] = try? workbook.add_image(
    "Sheet:1",
    "A1",
    Bytes::from_array([]),
    "png",
    "image/png",
  )
  inspect(
    add_image_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_image_opts_result : Result[Unit, Error] = try? workbook.add_image_with_options(
    "Sheet:1",
    "A1",
    Bytes::from_array([]),
    "png",
    "image/png",
    GraphicOptions::new(),
  )
  inspect(
    add_image_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let hf_opts = HeaderFooterImageOptions::new(
    HeaderFooterImagePosition::Left,
    Bytes::from_array([]),
    "png",
  )
  let add_hf_image_result : Result[Unit, Error] = try? workbook.add_header_footer_image(
    "Sheet:1", hf_opts,
  )
  inspect(
    add_hf_image_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_pictures_result : Result[Array[Image], Error] = try? workbook.get_pictures(
    "Sheet:1", "A1",
  )
  inspect(
    get_pictures_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_picture_cells_result : Result[Array[String], Error] = try? workbook.get_picture_cells(
    "Sheet:1",
  )
  inspect(
    get_picture_cells_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_picture_result : Result[Unit, Error] = try? workbook.delete_picture(
    "Sheet:1", "A1",
  )
  inspect(
    delete_picture_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_chart_result : Result[Unit, Error] = try? workbook.add_chart(
    "Sheet:1", "A1", "",
  )
  inspect(
    add_chart_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let chart_opts = ChartOptions::new(ChartType::Col)
  let add_chart_opts_result : Result[Unit, Error] = try? workbook.add_chart_with_options(
    "Sheet:1", "A1", chart_opts,
  )
  inspect(
    add_chart_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_chart_result : Result[Unit, Error] = try? workbook.delete_chart(
    "Sheet:1", "A1",
  )
  inspect(
    delete_chart_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_vml_result : Result[Unit, Error] = try? workbook.add_vml_drawing_xml(
    "Sheet:1", "",
  )
  inspect(add_vml_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let add_vml_hf_result : Result[Unit, Error] = try? workbook.add_vml_drawing_hf_xml(
    "Sheet:1", "",
  )
  inspect(
    add_vml_hf_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let control = FormControl::new("A1", "button") catch {
    err => fail("form control init failed: \{err}")
  }
  let add_control_result : Result[Unit, Error] = try? workbook.add_form_control(
    "Sheet:1", control,
  )
  inspect(
    add_control_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_controls_result : Result[Array[FormControl], Error] = try? workbook.get_form_controls(
    "Sheet:1",
  )
  inspect(
    get_controls_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_control_result : Result[Unit, Error] = try? workbook.delete_form_control(
    "Sheet:1", "A1",
  )
  inspect(
    delete_control_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
