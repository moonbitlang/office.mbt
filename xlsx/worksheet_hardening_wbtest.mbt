///|
test "worksheet wb: missing-cell getters return None" {
  let sheet = Worksheet::new("Sheet1")
  inspect(sheet.get_cell_rich_text("Z99"), content="None")
  inspect(sheet.get_cell_formula("Z99"), content="None")
  inspect(sheet.get_cell_style("Z99"), content="None")
  inspect(sheet.get_cell_style_rc(99, 26), content="None")
}

///|
test "worksheet wb: sparkline and validation guard errors" {
  let sheet = Worksheet::new("Sheet1")
  let empty_inputs : Result[Unit, Error] = try? sheet.add_sparkline_group([], [])
  inspect(
    empty_inputs,
    content=(
      #|Err(InvalidSparkline(msg="sparkline inputs empty"))
    ),
  )
  let empty_list : Result[Unit, Error] = try? sheet.add_data_validation_list(
    "A1",
    [],
  )
  inspect(
    empty_list,
    content=(
      #|Err(UnsupportedFeature(msg="empty validation list"))
    ),
  )
}

///|
test "worksheet wb: delete_slicer empty/missing/remove branches" {
  let sheet = Worksheet::new("Sheet1")
  let empty_name : Result[Unit, Error] = try? sheet.delete_slicer("")
  inspect(
    empty_name,
    content=(
      #|Err(InvalidSheetOperation(msg="slicer name empty"))
    ),
  )
  let missing : Result[Unit, Error] = try? sheet.delete_slicer("Missing")
  inspect(
    missing,
    content=(
      #|Err(InvalidSheetOperation(msg="slicer not found"))
    ),
  )

  let region = Slicer::new("Region") catch {
    err => fail("slicer init failed: \{err}")
  }
  let typ = Slicer::new("Type") catch {
    err => fail("slicer init failed: \{err}")
  }
  sheet.add_slicer(region)
  sheet.add_slicer(typ)
  sheet.delete_slicer("Region")
  let slicers = sheet.get_slicers()
  inspect(slicers.length(), content="1")
  inspect(slicers[0].name, content="Type")
}

///|
test "worksheet wb: data validation append/clear/error branches" {
  let sheet = Worksheet::new("Sheet1")
  let dv = DataValidation::new(true)
  dv.set_sqref("A1")
  dv.set_drop_list(["Yes"])
  sheet.add_data_validation_xml(data_validation_xml(dv))
  inspect(sheet.get_data_validations().length(), content="1")
  sheet.delete_data_validation()
  inspect(sheet.get_data_validations().length(), content="0")

  let dropped = Worksheet::new("Sheet1")
  let dv_drop = DataValidation::new(true)
  dv_drop.set_sqref("B2")
  dv_drop.set_drop_list(["No"])
  dropped.add_data_validation_xml(data_validation_xml(dv_drop))
  dropped.delete_data_validation(sqrefs=["B2"])
  inspect(dropped.get_data_validations().length(), content="0")

  let missing_tag = Worksheet::new("Sheet1")
  missing_tag.add_data_validation_xml("<foo/>")
  let missing_tag_result : Result[Unit, Error] = try? missing_tag.delete_data_validation(sqrefs=[
      "A1",
    ],
  )
  inspect(
    missing_tag_result,
    content=(
      #|Err(InvalidXml(msg="data validation tag missing"))
    ),
  )

  let missing_sqref = Worksheet::new("Sheet1")
  missing_sqref.add_data_validation_xml(
    "<dataValidation type=\"list\"><formula1>\"Y\"</formula1></dataValidation>",
  )
  let missing_sqref_result : Result[Unit, Error] = try? missing_sqref.delete_data_validation(sqrefs=[
      "A1",
    ],
  )
  inspect(
    missing_sqref_result,
    content=(
      #|Err(InvalidXml(msg="data validation sqref missing"))
    ),
  )
}

///|
test "worksheet wb: pivot-table wrapper and picture/header-footer guards" {
  let sheet = Worksheet::new("Sheet1")
  ignore(
    sheet.add_pivot_table(
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="Pivot1",
    ),
  )
  inspect(sheet.pivot_tables().length(), content="1")

  sheet.add_image("A1", [1], ".png", "image/png")
  inspect(sheet.get_pictures("A1").length(), content="1")

  let dot_extension : Result[Unit, Error] = try? sheet.add_image(
    "A1",
    [1],
    ".",
    "image/png",
  )
  inspect(
    dot_extension,
    content=(
      #|Err(UnsupportedFeature(msg="image extension missing"))
    ),
  )
  let empty_extension : Result[Unit, Error] = try? sheet.add_image(
    "A1",
    [1],
    "",
    "image/png",
  )
  inspect(
    empty_extension,
    content=(
      #|Err(UnsupportedFeature(msg="image extension missing"))
    ),
  )
  let invalid_scale : Result[Unit, Error] = try? sheet.add_image(
    "A1",
    [1],
    ".png",
    "image/png",
    scale_x=0.0,
  )
  inspect(
    invalid_scale,
    content=(
      #|Err(InvalidSheetOperation(msg="picture scale must be > 0"))
    ),
  )

  let missing_width : Result[Unit, Error] = try? sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(Left, [1], ".png", width="", height="8pt"),
  )
  inspect(
    missing_width,
    content=(
      #|Err(InvalidHeaderFooter(msg="header/footer width empty"))
    ),
  )
  let missing_height : Result[Unit, Error] = try? sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(Left, [1], ".png", width="9pt", height=""),
  )
  inspect(
    missing_height,
    content=(
      #|Err(InvalidHeaderFooter(msg="header/footer height empty"))
    ),
  )
}

///|
test "worksheet wb: add_picture_from_bytes_with_options default branches" {
  let sheet = Worksheet::new("Sheet1")
  sheet.add_picture_from_bytes_with_options(
    "B2",
    [1, 2, 3],
    ".png",
    GraphicOptions::new(),
  )
  let pictures = sheet.get_pictures("B2")
  inspect(pictures.length(), content="1")
  let image = pictures[0]
  inspect(image.offset_x, content="0")
  inspect(image.offset_y, content="0")
  inspect(image.scale_x == 1.0, content="true")
  inspect(image.scale_y == 1.0, content="true")
  inspect(image.hyperlink == "", content="true")
  inspect(image.hyperlink_type, content="Unset")
  inspect(image.name == "", content="true")
  inspect(image.alt_text == "", content="true")
  inspect(image.lock_aspect_ratio, content="false")
  inspect(image.print_object, content="true")
  inspect(image.locked, content="true")
  inspect(image.positioning, content="OneCell")
}

///|
test "worksheet wb: picture option Some branches and guard errors" {
  let sheet = Worksheet::new("Sheet1")
  let opts = GraphicOptions::with_values(
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  sheet.add_picture_from_bytes_with_options("C3", [1, 2, 3], ".png", opts)
  inspect(sheet.get_pictures("C3").length(), content="1")

  let empty_vml : Result[Unit, Error] = try? sheet.add_vml_drawing_hf_xml("")
  inspect(
    empty_vml,
    content=(
      #|Err(InvalidVmlDrawing(msg="vml drawing hf xml empty"))
    ),
  )
  let empty_options : Result[Unit, Error] = try? sheet.set_conditional_format(
    "A1",
    [],
  )
  inspect(
    empty_options,
    content=(
      #|Err(InvalidConditionalFormat(msg="options empty"))
    ),
  )
}

///|
test "worksheet wb: autofit merged anchor sums merged row/col spans" {
  let sheet = Worksheet::new("Sheet1")
  sheet.merge_cells("A1:B2")
  sheet.set_col_width(1, 10.0)
  sheet.set_col_width(2, 20.0)
  sheet.set_row_height(1, 10.0)
  sheet.set_row_height(2, 20.0)
  sheet.add_picture_from_bytes(
    "A1",
    [1, 2, 3],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let pictures = sheet.get_pictures("A1")
  inspect(pictures.length(), content="1")
  let image = pictures[0]
  inspect(image.width_emu, content="2286000")
  inspect(image.height_emu, content="342900")
}

///|
test "worksheet wb: autofit hits hidden/zero/outline pixel branches" {
  let hidden = Worksheet::new("Hidden")
  hidden.set_col_visible(1, false)
  hidden.set_row_visible(1, false)
  hidden.add_picture_from_bytes(
    "A1",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let hidden_image = hidden.get_pictures("A1")[0]
  inspect(hidden_image.width_emu, content="0")
  inspect(hidden_image.height_emu, content="0")

  let zero = Worksheet::new("Zero")
  zero.set_col_width(1, 0.0)
  zero.set_row_height(1, 0.0)
  zero.add_picture_from_bytes(
    "A1",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let zero_image = zero.get_pictures("A1")[0]
  inspect(zero_image.width_emu, content="0")
  inspect(zero_image.height_emu, content="0")

  let outline = Worksheet::new("Outline")
  outline.set_col_outline_level(1, 1)
  outline.set_row_outline_level(1, 1)
  outline.add_picture_from_bytes(
    "A1",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let outline_image = outline.get_pictures("A1")[0]
  inspect(outline_image.width_emu, content="609600")
  inspect(outline_image.height_emu, content="171450")
}

///|
test "worksheet wb: chart option guards and reference helper copies" {
  let sheet = Worksheet::new("Sheet1")
  sheet.add_picture_from_bytes("A1", [1], ".png")

  let opts = ChartOptions::new(Col)
  opts.series.push(ChartSeries::new("Sheet1!$A$1:$A$2", "Sheet1!$B$1:$B$2"))
  opts.format = GraphicOptions::with_values(scale_x=1.25, scale_y=0.75)
  sheet.add_chart_with_options("B2", opts)
  inspect(sheet.charts().length(), content="1")

  let shifted_image = image_with_reference(sheet.get_pictures("A1")[0], "D5")
  inspect(shifted_image.reference, content="D5")
  let shifted_chart = chart_with_reference(sheet.charts()[0], "E6")
  inspect(shifted_chart.reference, content="E6")

  let bad_offset_opts = ChartOptions::new(Col)
  bad_offset_opts.format = GraphicOptions::with_values(
    offset_x=-1,
    offset_y=0,
    scale_x=1.0,
    scale_y=1.0,
  )
  let bad_offset : Result[Unit, Error] = try? sheet.add_chart_with_options(
    "C3", bad_offset_opts,
  )
  inspect(
    bad_offset,
    content=(
      #|Err(InvalidSheetOperation(msg="chart offset must be >= 0"))
    ),
  )

  let bad_scale_opts = ChartOptions::new(Col)
  bad_scale_opts.format = GraphicOptions::with_values(scale_x=0.0, scale_y=1.0)
  let bad_scale : Result[Unit, Error] = try? sheet.add_chart_with_options(
    "C3", bad_scale_opts,
  )
  inspect(
    bad_scale,
    content=(
      #|Err(InvalidSheetOperation(msg="chart scale must be > 0"))
    ),
  )
}

///|
test "worksheet wb: conditional format helper edge branches" {
  inspect(pad_left_dec(1234, 2), content="1234")
  let existing_ext = "<cfRule type=\"expression\"><extLst></extLst></cfRule>"
  inspect(
    inject_x14_id_ext_lst_into_cf_rule(existing_ext, "id1"),
    content=existing_ext,
  )
  let invalid_rule : Result[String, Error] = try? inject_x14_id_ext_lst_into_cf_rule(
    "<cfRule/>", "id1",
  )
  inspect(
    invalid_rule,
    content=(
      #|Err(InvalidXml(msg="cfRule tag invalid"))
    ),
  )
}

///|
test "worksheet wb: conditional/data-validation update-failure and x14 fallback paths" {
  let dv_update_fail = Worksheet::new("Sheet1")
  dv_update_fail.add_data_validation_xml(
    "<?xml version=\"1.0\"?><dataValidation type=\"list\" sqref=\"A1\"><formula1>\"Y\"</formula1></dataValidation>",
  )
  let dv_update_result : Result[Unit, Error] = try? dv_update_fail.delete_data_validation(sqrefs=[
      "A2",
    ],
  )
  inspect(
    dv_update_result,
    content=(
      #|Err(InvalidXml(msg="data validation sqref update failed"))
    ),
  )

  let cf_merge = Worksheet::new("Sheet1")
  cf_merge.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  cf_merge.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"2\"><formula>2=2</formula></cfRule></conditionalFormatting>",
  )
  let merged = cf_merge.get_conditional_formats()
  let merged_opts = match merged.get("A1") {
    Some(value) => value
    None => fail("missing merged conditional formats")
  }
  inspect(merged_opts.length(), content="2")

  let cf_missing_tag = Worksheet::new("Sheet1")
  cf_missing_tag.add_conditional_format_xml("<foo/>")
  let missing_tag_result : Result[Unit, Error] = try? cf_missing_tag.unset_conditional_format(
    "A1",
  )
  inspect(
    missing_tag_result,
    content=(
      #|Err(InvalidXml(msg="conditionalFormatting tag missing"))
    ),
  )

  let cf_missing_sqref = Worksheet::new("Sheet1")
  cf_missing_sqref.add_conditional_format_xml(
    "<conditionalFormatting><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  let missing_sqref_result : Result[Unit, Error] = try? cf_missing_sqref.unset_conditional_format(
    "A1",
  )
  inspect(
    missing_sqref_result,
    content=(
      #|Err(InvalidXml(msg="conditionalFormatting sqref missing"))
    ),
  )

  let cf_update_fail = Worksheet::new("Sheet1")
  cf_update_fail.add_conditional_format_xml(
    "<?xml version=\"1.0\"?><conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  let update_fail_result : Result[Unit, Error] = try? cf_update_fail.unset_conditional_format(
    "A2",
  )
  inspect(
    update_fail_result,
    content=(
      #|Err(InvalidXml(msg="conditionalFormatting sqref update failed"))
    ),
  )

  let x14_prune = Worksheet::new("Sheet1")
  x14_prune.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><x14:id>unknown</x14:id><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  x14_prune.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"B1\"><cfRule type=\"expression\" priority=\"2\"><x14:id>broken<formula>2=2</formula></cfRule></conditionalFormatting>",
  )
  x14_prune.x14_data_bars["known"] = {
    sqref: "A1",
    bar_direction: "",
    bar_solid: false,
    bar_border_color: "",
  }
  x14_prune.unset_conditional_format("C1")
  inspect(x14_prune.x14_data_bars.length(), content="0")
}

///|
test "worksheet wb: rc cell api update branches and row/col basic guards" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell_style_rc(2, 2, 7)
  sheet.set_cell_value_rc(2, 2, Numeric(7.0))
  sheet.set_cell_value_rc(2, 2, String("txt"))
  sheet.set_cell_formula_rc(2, 2, "1+1", value="2")
  inspect(sheet.get_cell_rc(2, 2), content="Some(\"2\")")
  inspect(sheet.get_cell_formula("B2"), content="Some(\"1+1\")")
  inspect(sheet.get_cell_value_raw_rc(2, 2) is Some(_), content="true")
  inspect(sheet.get_cell_rc(9, 9), content="None")
  inspect(sheet.get_cell_value_raw_rc(9, 9), content="None")

  let bad_get_rc : Result[String?, Error] = try? sheet.get_cell_rc(0, 1)
  inspect(bad_get_rc is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_get_raw_rc : Result[CellValue?, Error] = try? sheet.get_cell_value_raw_rc(
    0, 1,
  )
  inspect(bad_get_raw_rc is Err(XlsxError::InvalidCellRef(_)), content="true")

  let bad_set_row : Result[Unit, Error] = try? sheet.set_row(0, ["A"][:])
  inspect(bad_set_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_set_col : Result[Unit, Error] = try? sheet.set_col(0, ["A"][:])
  inspect(bad_set_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_get_col : Result[Array[String], Error] = try? sheet.get_col(0)
  inspect(bad_get_col is Err(XlsxError::InvalidCellRef(_)), content="true")
}

///|
test "worksheet wb: row/col dimension guard and default branches" {
  let sheet = Worksheet::new("Sheet1")

  inspect(sheet.get_row_height(5), content="None")
  inspect(sheet.row_visible(5), content="true")
  inspect(sheet.row_outline_level(5), content="0")
  inspect(sheet.get_row_style(5), content="None")
  inspect(sheet.get_col_width(5), content="None")
  inspect(sheet.col_visible(5), content="true")
  inspect(sheet.col_outline_level(5), content="0")
  inspect(sheet.get_col_style(5), content="None")

  let bad_set_row_height_rc : Result[Unit, Error] = try? sheet.set_row_height(
    0, 1.0,
  )
  inspect(
    bad_set_row_height_rc is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_row_height_neg : Result[Unit, Error] = try? sheet.set_row_height(
    1, -1.0,
  )
  inspect(
    bad_set_row_height_neg is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_get_row_height : Result[Double?, Error] = try? sheet.get_row_height(0)
  inspect(
    bad_get_row_height is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_row_visible : Result[Unit, Error] = try? sheet.set_row_visible(
    0, true,
  )
  inspect(
    bad_set_row_visible is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_row_visible : Result[Bool, Error] = try? sheet.row_visible(0)
  inspect(bad_row_visible is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_set_row_outline_row : Result[Unit, Error] = try? sheet.set_row_outline_level(
    0, 1,
  )
  inspect(
    bad_set_row_outline_row is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_row_outline_level : Result[Unit, Error] = try? sheet.set_row_outline_level(
    1, 8,
  )
  inspect(
    bad_set_row_outline_level is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_row_outline_level : Result[Int, Error] = try? sheet.row_outline_level(
    0,
  )
  inspect(
    bad_row_outline_level is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_row_style_range_bounds : Result[Unit, Error] = try? sheet.set_row_style_range(
    0, 1, 1,
  )
  inspect(
    bad_row_style_range_bounds is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_row_style_range_order : Result[Unit, Error] = try? sheet.set_row_style_range(
    2, 1, 1,
  )
  inspect(
    bad_row_style_range_order is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_get_row_style : Result[Int?, Error] = try? sheet.get_row_style(0)
  inspect(
    bad_get_row_style is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )

  let bad_set_col_width_rc : Result[Unit, Error] = try? sheet.set_col_width(
    0, 1.0,
  )
  inspect(
    bad_set_col_width_rc is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_width_neg : Result[Unit, Error] = try? sheet.set_col_width(
    1, -1.0,
  )
  inspect(
    bad_set_col_width_neg is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_get_col_width : Result[Double?, Error] = try? sheet.get_col_width(0)
  inspect(
    bad_get_col_width is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_visible : Result[Unit, Error] = try? sheet.set_col_visible(
    0, true,
  )
  inspect(
    bad_set_col_visible is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_col_visible : Result[Bool, Error] = try? sheet.col_visible(0)
  inspect(bad_col_visible is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_set_col_outline_col : Result[Unit, Error] = try? sheet.set_col_outline_level(
    0, 1,
  )
  inspect(
    bad_set_col_outline_col is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_outline_level : Result[Unit, Error] = try? sheet.set_col_outline_level(
    1, 8,
  )
  inspect(
    bad_set_col_outline_level is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_col_outline_level : Result[Int, Error] = try? sheet.col_outline_level(
    0,
  )
  inspect(
    bad_col_outline_level is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_style : Result[Unit, Error] = try? sheet.set_col_style(0, 1)
  inspect(
    bad_set_col_style is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_get_col_style : Result[Int?, Error] = try? sheet.get_col_style(0)
  inspect(
    bad_get_col_style is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )

  sheet.set_row_style(2, 1)
  inspect(sheet.get_row_style(2), content="Some(1)")
  sheet.set_row_style(2, 0)
  inspect(sheet.get_row_style(2), content="None")
  sheet.set_col_style(2, 1)
  inspect(sheet.get_col_style(2), content="Some(1)")
  sheet.set_col_style(2, 0)
  inspect(sheet.get_col_style(2), content="None")

  let defaults = Worksheet::new("Defaults")
  defaults.set_sheet_props(
    Some(
      SheetPropsOptions::with_values(
        default_col_width=12.5,
        default_row_height=18.0,
      ),
    ),
  )
  defaults.set_col_outline_level(3, 1)
  defaults.set_row_outline_level(3, 1)
  defaults.add_picture_from_bytes(
    "C3",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let image = defaults.get_pictures("C3")[0]
  inspect(image.width_emu, content="952500")
  inspect(image.height_emu, content="209550")
}

///|
test "worksheet wb: row insert/remove structural guard and adjustment branches" {
  let sheet = Worksheet::new("Sheet1")
  let bad_insert_row : Result[Unit, Error] = try? sheet.insert_rows(0, 1)
  inspect(bad_insert_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_insert_count : Result[Unit, Error] = try? sheet.insert_rows(1, 0)
  inspect(
    bad_insert_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_remove_row : Result[Unit, Error] = try? sheet.remove_rows(0, 1)
  inspect(bad_remove_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_remove_count : Result[Unit, Error] = try? sheet.remove_rows(1, 0)
  inspect(
    bad_remove_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )

  sheet.set_auto_filter("A1:B4", [])
  sheet.set_cell("A1", "head")
  sheet.set_cell("A3", "value")
  sheet.set_row_height(1, 12.0)
  sheet.add_picture_from_bytes("C3", [1], ".png")
  let chart = ChartOptions::new(Col)
  chart.series.push(ChartSeries::new("Sheet1!$A$1:$A$2", "Sheet1!$B$1:$B$2"))
  sheet.add_chart_with_options("D3", chart)
  sheet.insert_rows(2, 1)
  inspect(sheet.get_pictures("C4").length(), content="1")
  inspect(sheet.charts()[0].reference, content="D4")
  match sheet.auto_filter {
    Some(filter) => inspect(filter.range_ref, content="A1:B5")
    None => fail("missing auto filter after row insert")
  }

  sheet.remove_rows(2, 1)
  inspect(sheet.get_pictures("C3").length(), content="1")
  inspect(sheet.charts()[0].reference, content="D3")
  inspect(sheet.get_row_height(1), content="Some(12)")
  match sheet.auto_filter {
    Some(filter) => inspect(filter.range_ref, content="A1:B4")
    None => fail("missing auto filter after row remove")
  }

  let drop = Worksheet::new("Drop")
  drop.merge_cells("A2:A2")
  ignore(drop.add_table("C2:D2", "DropTable", ["C", "D"]))
  drop.remove_rows(2, 1)
  inspect(drop.merged_cells().length(), content="0")
  inspect(drop.tables().length(), content="0")

  sheet.set_cell("A5", "tail")
  sheet.remove_row(5)
  inspect(sheet.get_cell("A5"), content="None")
}

///|
test "worksheet wb: duplicate-row helper edge branches" {
  let (row, col, abs_col, abs_row) = parse_cell_ref_with_abs("$B$3")
  inspect(row, content="3")
  inspect(col, content="2")
  inspect(abs_col, content="true")
  inspect(abs_row, content="true")
  let bad_no_col : Result[(Int, Int, Bool, Bool), Error] = try? parse_cell_ref_with_abs(
    "1A",
  )
  inspect(bad_no_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_invalid_char : Result[(Int, Int, Bool, Bool), Error] = try? parse_cell_ref_with_abs(
    "A1X",
  )
  inspect(bad_invalid_char is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_no_row : Result[(Int, Int, Bool, Bool), Error] = try? parse_cell_ref_with_abs(
    "A",
  )
  inspect(bad_no_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_zero_row : Result[(Int, Int, Bool, Bool), Error] = try? parse_cell_ref_with_abs(
    "A0",
  )
  inspect(bad_zero_row is Err(XlsxError::InvalidCellRef(_)), content="true")

  inspect(format_cell_ref_with_abs(3, 2, true, true) == "$B$3", content="true")
  let bad_format : Result[String, Error] = try? format_cell_ref_with_abs(
    0, 1, false, false,
  )
  inspect(bad_format is Err(XlsxError::InvalidCellRef(_)), content="true")

  let refs = duplicate_sqref_for_row(1, 2, "  A1:A1   B1:B2  ")
  inspect(refs, content="[\"A2:A2\"]")

  inspect(duplicate_xml_sqref("<foo/>", 1, 2), content="None")
  inspect(
    duplicate_xml_sqref("<dataValidation type=\"list\"></dataValidation>", 1, 2),
    content="None",
  )

  let dv = Worksheet::new("Sheet1")
  dv.add_data_validation_xml("<foo/>")
  dv.duplicate_data_validations(1, 2)
  inspect(dv.data_validations().length(), content="1")

  let merge_early = Worksheet::new("MergeEarly")
  merge_early.merge_cells("A1:A3")
  merge_early.duplicate_merge_cells(1, 2)
  inspect(merge_early.merged_cells().length(), content="1")

  let merge_shift = Worksheet::new("MergeShift")
  merge_shift.merge_cells("A4:B4")
  merge_shift.duplicate_merge_cells(3, 1)
  inspect(merge_shift.merged_cells().contains("A1:B1"), content="true")

  let duplicate = Worksheet::new("Duplicate")
  duplicate.set_row(1, ["A"][:])
  duplicate.duplicate_row(1)
  inspect(duplicate.get_row(2), content="[\"A\"]")
  let bad_target : Result[Unit, Error] = try? duplicate.duplicate_row_to(1, 1)
  inspect(
    bad_target is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
}

///|
test "worksheet wb: col insert/remove structural edge branches" {
  let guard_sheet = Worksheet::new("Guard")
  let bad_insert_col : Result[Unit, Error] = try? guard_sheet.insert_cols(0, 1)
  inspect(bad_insert_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_insert_count : Result[Unit, Error] = try? guard_sheet.insert_cols(1, 0)
  inspect(
    bad_insert_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_remove_col : Result[Unit, Error] = try? guard_sheet.remove_cols(0, 1)
  inspect(bad_remove_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_remove_count : Result[Unit, Error] = try? guard_sheet.remove_cols(1, 0)
  inspect(
    bad_remove_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )

  let insert = Worksheet::new("Insert")
  insert.auto_filter = Some({
    range_ref: "A1:D4",
    columns: [
      { col: 1, filters: Some(["keep"]), custom_filters: None },
      { col: 3, filters: Some(["shift"]), custom_filters: None },
    ],
  })
  insert.hyperlinks.push({
    reference: "A1:C1",
    target: "https://example.com",
    link_type: External,
    display: None,
    tooltip: None,
  })
  insert.add_picture_from_bytes("C3", [1], ".png")
  let insert_chart = ChartOptions::new(Col)
  insert_chart.series.push(
    ChartSeries::new("Insert!$A$1:$A$2", "Insert!$B$1:$B$2"),
  )
  insert.add_chart_with_options("D3", insert_chart)
  insert.insert_cols(2, 1)
  inspect(insert.get_pictures("D3").length(), content="1")
  inspect(insert.charts()[0].reference, content="E3")
  inspect(insert.hyperlinks()[0].reference, content="A1:D1")
  match insert.auto_filter {
    Some(filter) => {
      inspect(filter.range_ref, content="A1:E4")
      inspect(filter.columns.length(), content="2")
      inspect(filter.columns[0].col, content="1")
      inspect(filter.columns[1].col, content="4")
    }
    None => fail("missing auto filter after col insert")
  }

  let remove = Worksheet::new("Remove")
  remove.set_col_width(1, 9.0)
  remove.set_col_width(4, 11.0)
  remove.merge_cells("B1:B1")
  remove.hyperlinks.push({
    reference: "B1",
    target: "https://drop.example",
    link_type: External,
    display: None,
    tooltip: None,
  })
  remove.hyperlinks.push({
    reference: "A1:C1",
    target: "https://range.example",
    link_type: External,
    display: None,
    tooltip: None,
  })
  remove.auto_filter = Some({
    range_ref: "A1:D4",
    columns: [
      { col: 1, filters: Some(["left"]), custom_filters: None },
      { col: 2, filters: Some(["drop"]), custom_filters: None },
      { col: 4, filters: Some(["right"]), custom_filters: None },
    ],
  })
  ignore(remove.add_table("B1:B2", "DropColTable", ["B"]))
  ignore(remove.add_table("D1:E2", "KeepColTable", ["D", "E"]))
  remove.add_sparkline_group(["B1", "D1"], ["B1:B1", "D1:D1"])
  remove.add_picture_from_bytes("A1", [1], ".png")
  remove.add_picture_from_bytes("B1", [1], ".png")
  let remove_chart_a = ChartOptions::new(Col)
  remove_chart_a.series.push(
    ChartSeries::new("Remove!$A$1:$A$2", "Remove!$B$1:$B$2"),
  )
  remove.add_chart_with_options("A1", remove_chart_a)
  let remove_chart_b = ChartOptions::new(Col)
  remove_chart_b.series.push(
    ChartSeries::new("Remove!$A$1:$A$2", "Remove!$B$1:$B$2"),
  )
  remove.add_chart_with_options("B1", remove_chart_b)
  remove.col_breaks.push({ id: 0, min: 0, max: 16383, manual: true })
  remove.col_breaks.push({ id: 4, min: 0, max: 16383, manual: true })
  remove.remove_cols(2, 1)
  inspect(remove.merged_cells().length(), content="0")
  inspect(remove.hyperlinks().length(), content="1")
  inspect(remove.hyperlinks()[0].reference, content="A1:B1")
  match remove.auto_filter {
    Some(filter) => {
      inspect(filter.range_ref, content="A1:C4")
      inspect(filter.columns.length(), content="2")
      inspect(filter.columns[0].col, content="1")
      inspect(filter.columns[1].col, content="3")
    }
    None => fail("missing auto filter after col remove")
  }
  inspect(remove.tables().length(), content="1")
  inspect(remove.tables()[0].name, content="KeepColTable")
  inspect(remove.tables()[0].range_ref, content="C1:D2")
  inspect(remove.sparkline_groups().length(), content="1")
  inspect(remove.sparkline_groups()[0].sparklines.length(), content="1")
  inspect(remove.sparkline_groups()[0].sparklines[0].location, content="C1")
  inspect(remove.get_pictures("A1").length(), content="1")
  inspect(remove.get_pictures("B1").length(), content="0")
  inspect(remove.charts().length(), content="1")
  inspect(remove.charts()[0].reference, content="A1")
  inspect(remove.get_col_width(1), content="Some(9)")
  inspect(remove.get_col_width(3), content="Some(11)")
  inspect(remove.col_breaks.length(), content="2")
  inspect(remove.col_breaks[0].id, content="0")
  inspect(remove.col_breaks[1].id, content="3")

  let filter_drop = Worksheet::new("FilterDrop")
  filter_drop.auto_filter = Some({
    range_ref: "B1:B2",
    columns: [{ col: 2, filters: Some(["x"]), custom_filters: None }],
  })
  filter_drop.remove_cols(2, 1)
  inspect(filter_drop.auto_filter, content="None")

  let alias_sheet = Worksheet::new("Alias")
  alias_sheet.set_cell("A1", "a")
  alias_sheet.set_cell("B1", "b")
  alias_sheet.set_cell("C1", "c")
  alias_sheet.remove_col(2)
  inspect(alias_sheet.get_cell("A1"), content="Some(\"a\")")
  inspect(alias_sheet.get_cell("B1"), content="Some(\"c\")")
  inspect(alias_sheet.get_cell("C1"), content="None")
}

///|
test "worksheet wb: row remove residual drop and range-helper branches" {
  let sheet = Worksheet::new("RowDrop")
  sheet.auto_filter = Some({ range_ref: "A2:B2", columns: [] })
  sheet.hyperlinks.push({
    reference: "A1:A3",
    target: "https://rows.example",
    link_type: External,
    display: None,
    tooltip: None,
  })
  sheet.add_sparkline_group(["A2", "A4"], ["A2:A2", "A4:A4"])
  sheet.add_picture_from_bytes("A1", [1], ".png")
  sheet.add_picture_from_bytes("A2", [1], ".png")
  let keep_chart = ChartOptions::new(Col)
  keep_chart.series.push(
    ChartSeries::new("RowDrop!$A$1:$A$2", "RowDrop!$B$1:$B$2"),
  )
  sheet.add_chart_with_options("A1", keep_chart)
  let drop_chart = ChartOptions::new(Col)
  drop_chart.series.push(
    ChartSeries::new("RowDrop!$A$1:$A$2", "RowDrop!$B$1:$B$2"),
  )
  sheet.add_chart_with_options("A2", drop_chart)

  sheet.insert_rows(2, 1)
  inspect(sheet.hyperlinks()[0].reference, content="A1:A4")
  sheet.remove_rows(2, 1)
  inspect(sheet.hyperlinks()[0].reference, content="A1:A3")

  sheet.remove_rows(2, 1)
  inspect(sheet.auto_filter, content="None")
  inspect(sheet.hyperlinks()[0].reference, content="A1:A2")
  inspect(sheet.get_pictures("A1").length(), content="1")
  inspect(sheet.get_pictures("A2").length(), content="0")
  inspect(sheet.charts().length(), content="1")
  inspect(sheet.charts()[0].reference, content="A1")
  inspect(sheet.sparkline_groups().length(), content="1")
  inspect(sheet.sparkline_groups()[0].sparklines.length(), content="1")
  inspect(sheet.sparkline_groups()[0].sparklines[0].location, content="A3")
}
