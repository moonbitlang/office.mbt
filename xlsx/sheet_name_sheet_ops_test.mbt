///|
test "sheet-level APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream_result : Result[StreamWriter, Error] = Ok(
    workbook.new_stream_writer("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(stream_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let set_margins_result : Result[Unit, Error] = Ok(
    workbook.set_page_margins("Sheet:1", None),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_margins_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_margins_result : Result[PageLayoutMarginsOptions, Error] = Ok(
    workbook.get_page_margins("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_margins_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_layout_result : Result[Unit, Error] = Ok(
    workbook.set_page_layout("Sheet:1", None),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_layout_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_layout_result : Result[PageLayoutOptions, Error] = Ok(
    workbook.get_page_layout("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_layout_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_header_footer_result : Result[Unit, Error] = Ok(
    workbook.set_header_footer("Sheet:1", None),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_header_footer_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_header_footer_result : Result[HeaderFooterOptions?, Error] = Ok(
    workbook.get_header_footer("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_header_footer_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_header_footer_images_result : Result[
    Array[HeaderFooterImageOptions],
    Error,
  ] = Ok(workbook.get_header_footer_images("Sheet:1")) catch { e => Err(e) }
  inspect(
    get_header_footer_images_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_props_result : Result[Unit, Error] = Ok(
    workbook.set_sheet_props("Sheet:1", None),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_props_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_props_result : Result[SheetPropsOptions, Error] = Ok(
    workbook.get_sheet_props("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_props_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_view_result : Result[Unit, Error] = Ok(
    workbook.set_sheet_view("Sheet:1", 0, SheetViewOptions::new()),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_view_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_view_result : Result[SheetViewOptions, Error] = Ok(
    workbook.get_sheet_view("Sheet:1", 0),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_view_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_panes_result : Result[Unit, Error] = Ok(
    workbook.set_panes("Sheet:1", Panes::new()),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_panes_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_panes_result : Result[Panes, Error] = Ok(
    workbook.get_panes("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_panes_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_dimension_result : Result[Unit, Error] = Ok(
    workbook.set_sheet_dimension("Sheet:1", "A1:B2"),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_dimension_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_dimension_result : Result[String, Error] = Ok(
    workbook.get_sheet_dimension("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_dimension_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let protect_result : Result[Unit, Error] = Ok(
    workbook.protect_sheet("Sheet:1", SheetProtectionOptions::new()),
  ) catch {
    e => Err(e)
  }
  inspect(protect_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let unprotect_result : Result[Unit, Error] = Ok(
    workbook.unprotect_sheet("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    unprotect_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_background_result : Result[Unit, Error] = Ok(
    workbook.set_sheet_background("Sheet:1", Bytes::from_array([]), "png"),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_background_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let clear_background_result : Result[Unit, Error] = Ok(
    workbook.clear_sheet_background("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    clear_background_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let insert_break_result : Result[Unit, Error] = Ok(
    workbook.insert_page_break("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    insert_break_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let remove_break_result : Result[Unit, Error] = Ok(
    workbook.remove_page_break("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    remove_break_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
