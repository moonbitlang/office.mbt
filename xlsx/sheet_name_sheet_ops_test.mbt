///|
test "sheet-level APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream_result : Result[StreamWriter, Error] = try? workbook.new_stream_writer(
    "Sheet:1",
  )
  inspect(stream_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let set_margins_result : Result[Unit, Error] = try? workbook.set_page_margins(
    "Sheet:1",
    None,
  )
  inspect(
    set_margins_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_margins_result : Result[PageLayoutMarginsOptions, Error] = try? workbook.get_page_margins(
    "Sheet:1",
  )
  inspect(
    get_margins_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_layout_result : Result[Unit, Error] = try? workbook.set_page_layout(
    "Sheet:1",
    None,
  )
  inspect(
    set_layout_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_layout_result : Result[PageLayoutOptions, Error] = try? workbook.get_page_layout(
    "Sheet:1",
  )
  inspect(
    get_layout_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_header_footer_result : Result[Unit, Error] = try? workbook.set_header_footer(
    "Sheet:1",
    None,
  )
  inspect(
    set_header_footer_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_header_footer_result : Result[HeaderFooterOptions?, Error] = try? workbook.get_header_footer(
    "Sheet:1",
  )
  inspect(
    get_header_footer_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_header_footer_images_result : Result[
    Array[HeaderFooterImageOptions],
    Error,
  ] = try? workbook.get_header_footer_images("Sheet:1")
  inspect(
    get_header_footer_images_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_props_result : Result[Unit, Error] = try? workbook.set_sheet_props(
    "Sheet:1",
    None,
  )
  inspect(
    set_props_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_props_result : Result[SheetPropsOptions, Error] = try? workbook.get_sheet_props(
    "Sheet:1",
  )
  inspect(
    get_props_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_view_result : Result[Unit, Error] = try? workbook.set_sheet_view(
    "Sheet:1",
    0,
    SheetViewOptions::new(),
  )
  inspect(
    set_view_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_view_result : Result[SheetViewOptions, Error] = try? workbook.get_sheet_view(
    "Sheet:1", 0,
  )
  inspect(
    get_view_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_panes_result : Result[Unit, Error] = try? workbook.set_panes(
    "Sheet:1",
    Panes::new(),
  )
  inspect(
    set_panes_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_panes_result : Result[Panes, Error] = try? workbook.get_panes(
    "Sheet:1",
  )
  inspect(
    get_panes_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_dimension_result : Result[Unit, Error] = try? workbook.set_sheet_dimension(
    "Sheet:1", "A1:B2",
  )
  inspect(
    set_dimension_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_dimension_result : Result[String, Error] = try? workbook.get_sheet_dimension(
    "Sheet:1",
  )
  inspect(
    get_dimension_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let protect_result : Result[Unit, Error] = try? workbook.protect_sheet(
    "Sheet:1",
    SheetProtectionOptions::new(),
  )
  inspect(protect_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let unprotect_result : Result[Unit, Error] = try? workbook.unprotect_sheet(
    "Sheet:1",
  )
  inspect(
    unprotect_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_background_result : Result[Unit, Error] = try? workbook.set_sheet_background(
    "Sheet:1",
    Bytes::from_array([]),
    "png",
  )
  inspect(
    set_background_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let clear_background_result : Result[Unit, Error] = try? workbook.clear_sheet_background(
    "Sheet:1",
  )
  inspect(
    clear_background_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let insert_break_result : Result[Unit, Error] = try? workbook.insert_page_break(
    "Sheet:1", "A1",
  )
  inspect(
    insert_break_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let remove_break_result : Result[Unit, Error] = try? workbook.remove_page_break(
    "Sheet:1", "A1",
  )
  inspect(
    remove_break_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
