///|
test "conditional format + merge APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let ignored_errors_result : Result[Unit, Error] = Ok(
    workbook.add_ignored_errors("Sheet:1", "A1", NumberStoredAsText),
  ) catch {
    e => Err(e)
  }
  inspect(
    ignored_errors_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_cf_xml_result : Result[Unit, Error] = Ok(
    workbook.add_conditional_format_xml(
      "Sheet:1", "<conditionalFormatting></conditionalFormatting>",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_cf_xml_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_cf_result : Result[Unit, Error] = Ok(
    workbook.set_conditional_format("Sheet:1", "A1:A1", []),
  ) catch {
    e => Err(e)
  }
  inspect(set_cf_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_cf_result : Result[
    Map[String, Array[ConditionalFormatOptions]],
    Error,
  ] = Ok(workbook.get_conditional_formats("Sheet:1")) catch { e => Err(e) }
  inspect(get_cf_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let unset_cf_result : Result[Unit, Error] = Ok(
    workbook.unset_conditional_format("Sheet:1", "A1:A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    unset_cf_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let merge_cells_result : Result[Unit, Error] = Ok(
    workbook.merge_cells("Sheet:1", "A1:B2"),
  ) catch {
    e => Err(e)
  }
  inspect(
    merge_cells_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let merge_cell_result : Result[Unit, Error] = Ok(
    workbook.merge_cell("Sheet:1", "A1", "B2"),
  ) catch {
    e => Err(e)
  }
  inspect(
    merge_cell_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let unmerge_cells_result : Result[Unit, Error] = Ok(
    workbook.unmerge_cells("Sheet:1", "A1:B2"),
  ) catch {
    e => Err(e)
  }
  inspect(
    unmerge_cells_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let unmerge_cell_result : Result[Unit, Error] = Ok(
    workbook.unmerge_cell("Sheet:1", "A1", "B2"),
  ) catch {
    e => Err(e)
  }
  inspect(
    unmerge_cell_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_merges_result : Result[Array[String], Error] = Ok(
    workbook.get_merge_cells("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_merges_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_merge_info_result : Result[Array[MergeCell], Error] = Ok(
    workbook.get_merge_cells_info("Sheet:1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_merge_info_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
