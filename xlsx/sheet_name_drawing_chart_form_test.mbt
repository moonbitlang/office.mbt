///|
test "drawing/chart/form-control APIs validate sheet name" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let add_image_result : Result[Unit, Error] = Ok(
    workbook.add_image(
      "Sheet:1",
      "A1",
      Bytes::from_array([]),
      "png",
      "image/png",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_image_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_image_opts_result : Result[Unit, Error] = Ok(
    workbook.add_image_with_options(
      "Sheet:1",
      "A1",
      Bytes::from_array([]),
      "png",
      "image/png",
      @xlsx.GraphicOptions::new(),
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_image_opts_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let hf_opts = @xlsx.HeaderFooterImageOptions::new(
    Left,
    Bytes::from_array([]),
    "png",
  )
  let add_hf_image_result : Result[Unit, Error] = Ok(
    workbook.add_header_footer_image("Sheet:1", hf_opts),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_hf_image_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_pictures_result : Result[Array[@xlsx.Image], Error] = Ok(
    workbook.get_pictures("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_pictures_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_picture_cells_result : Result[Array[String], Error] = Ok(
    workbook.get_picture_cells("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_picture_cells_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_picture_result : Result[Unit, Error] = Ok(
    workbook.delete_picture("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    delete_picture_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_chart_result : Result[Unit, Error] = Ok(
    workbook.add_chart("Sheet:1", "A1", ""),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_chart_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let chart_opts = @xlsx.ChartOptions::new(Col)
  let add_chart_opts_result : Result[Unit, Error] = Ok(
    workbook.add_chart_with_options("Sheet:1", "A1", chart_opts),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_chart_opts_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_chart_result : Result[Unit, Error] = Ok(
    workbook.delete_chart("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    delete_chart_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_vml_result : Result[Unit, Error] = Ok(
    workbook.add_vml_drawing_xml("Sheet:1", ""),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_vml_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_vml_hf_result : Result[Unit, Error] = Ok(
    workbook.add_vml_drawing_hf_xml("Sheet:1", ""),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_vml_hf_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let control = @xlsx.FormControl::new("A1", "button") catch {
    err => fail("form control init failed: \{repr(err)}")
  }
  let add_control_result : Result[Unit, Error] = Ok(
    workbook.add_form_control("Sheet:1", control),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_control_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_controls_result : Result[Array[@xlsx.FormControl], Error] = Ok(
    workbook.get_form_controls("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_controls_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let delete_control_result : Result[Unit, Error] = Ok(
    workbook.delete_form_control("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    delete_control_result is Err(@xlsx.XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
