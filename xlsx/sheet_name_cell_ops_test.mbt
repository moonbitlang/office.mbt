///|
test "cell APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_cell_result : Result[Unit, Error] = try? workbook.set_cell(
    "Sheet:1", "A1", "alpha",
  )
  inspect(
    set_cell_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_cell_value_result : Result[Unit, Error] = try? workbook.set_cell_value(
    "Sheet:1",
    "A1",
    CellValue::String("beta"),
  )
  inspect(
    set_cell_value_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_rich_text_result : Result[Unit, Error] = try? workbook.set_cell_rich_text(
    "Sheet:1",
    "A1",
    ([{ text: "rt", font: None }] : Array[RichTextRun]),
  )
  inspect(
    set_rich_text_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_hyperlink_result : Result[Unit, Error] = try? workbook.set_cell_hyperlink(
    "Sheet:1",
    "A1",
    "https://example.com",
    HyperlinkType::External,
  )
  inspect(
    set_hyperlink_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_hyperlink_opts_result : Result[Unit, Error] = try? workbook.set_cell_hyperlink_opts(
    "Sheet:1",
    "A1",
    "https://example.com",
    HyperlinkType::External,
  )
  inspect(
    set_hyperlink_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let remove_hyperlink_result : Result[Unit, Error] = try? workbook.remove_cell_hyperlink(
    "Sheet:1", "A1",
  )
  inspect(
    remove_hyperlink_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_cell_result : Result[String?, Error] = try? workbook.get_cell(
    "Sheet:1", "A1",
  )
  inspect(
    get_cell_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_rich_text_result : Result[Array[RichTextRun]?, Error] = try? workbook.get_cell_rich_text(
    "Sheet:1", "A1",
  )
  inspect(
    get_rich_text_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_hyperlink_result : Result[Hyperlink?, Error] = try? workbook.get_cell_hyperlink(
    "Sheet:1", "A1",
  )
  inspect(
    get_hyperlink_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_raw_result : Result[CellValue?, Error] = try? workbook.get_cell_value_raw(
    "Sheet:1", "A1",
  )
  inspect(get_raw_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_type_result : Result[CellValueType?, Error] = try? workbook.get_cell_type(
    "Sheet:1", "A1",
  )
  inspect(
    get_type_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_value_result : Result[String?, Error] = try? workbook.get_cell_value(
    "Sheet:1", "A1",
  )
  inspect(
    get_value_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let calc_value_result : Result[String, Error] = try? workbook.calc_cell_value(
    "Sheet:1", "A1",
  )
  inspect(
    calc_value_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_formula_result : Result[Unit, Error] = try? workbook.set_cell_formula(
    "Sheet:1", "A1", "1+1",
  )
  inspect(
    set_formula_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_formula_opts_result : Result[Unit, Error] = try? workbook.set_cell_formula_opts(
    "Sheet:1", "A1", "1+1",
  )
  inspect(
    set_formula_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_formula_result : Result[String?, Error] = try? workbook.get_cell_formula(
    "Sheet:1", "A1",
  )
  inspect(
    get_formula_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_style_result : Result[Unit, Error] = try? workbook.set_cell_style(
    "Sheet:1", "A1", 0,
  )
  inspect(
    set_style_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_style_result : Result[Int?, Error] = try? workbook.get_cell_style(
    "Sheet:1", "A1",
  )
  inspect(
    get_style_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
