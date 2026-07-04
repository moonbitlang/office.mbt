///|
test "cell APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_cell_result : Result[Unit, Error] = Ok(
    workbook.set_cell("Sheet:1", "A1", "alpha"),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_cell_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_cell_value_result : Result[Unit, Error] = Ok(
    workbook.set_cell_value("Sheet:1", "A1", String("beta")),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_cell_value_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_rich_text_result : Result[Unit, Error] = Ok(
    workbook.set_cell_rich_text(
      "Sheet:1",
      "A1",
      ([{ text: "rt", font: None }] : Array[RichTextRun]),
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_rich_text_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_hyperlink_result : Result[Unit, Error] = Ok(
    workbook.set_cell_hyperlink(
      "Sheet:1",
      "A1",
      "https://example.com",
      External,
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_hyperlink_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_hyperlink_opts_result : Result[Unit, Error] = Ok(
    workbook.set_cell_hyperlink_opts(
      "Sheet:1",
      "A1",
      "https://example.com",
      External,
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_hyperlink_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let remove_hyperlink_result : Result[Unit, Error] = Ok(
    workbook.remove_cell_hyperlink("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    remove_hyperlink_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_cell_result : Result[String?, Error] = Ok(
    workbook.get_cell("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_cell_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_rich_text_result : Result[Array[RichTextRun]?, Error] = Ok(
    workbook.get_cell_rich_text("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_rich_text_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_hyperlink_result : Result[Hyperlink?, Error] = Ok(
    workbook.get_cell_hyperlink("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_hyperlink_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_raw_result : Result[CellValue?, Error] = Ok(
    workbook.get_cell_value_raw("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(get_raw_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_type_result : Result[CellValueType?, Error] = Ok(
    workbook.get_cell_type("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_type_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_value_result : Result[String?, Error] = Ok(
    workbook.get_cell_value("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_value_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let calc_value_result : Result[String, Error] = Ok(
    workbook.calc_cell_value("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    calc_value_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_formula_result : Result[Unit, Error] = Ok(
    workbook.set_cell_formula("Sheet:1", "A1", "1+1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_formula_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_formula_opts_result : Result[Unit, Error] = Ok(
    workbook.set_cell_formula_opts("Sheet:1", "A1", "1+1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_formula_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_formula_result : Result[String?, Error] = Ok(
    workbook.get_cell_formula("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_formula_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_style_result : Result[Unit, Error] = Ok(
    workbook.set_cell_style("Sheet:1", "A1", 0),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_style_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_style_result : Result[Int?, Error] = Ok(
    workbook.get_cell_style("Sheet:1", "A1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_style_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
