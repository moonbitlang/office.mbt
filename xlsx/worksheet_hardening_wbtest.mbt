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
