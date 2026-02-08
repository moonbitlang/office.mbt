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
