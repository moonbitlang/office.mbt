///|
test "data validation drop list roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let dv = DataValidation::new(false)
  dv.set_sqref("A1:B2")
  dv.set_drop_list(["Yes", "No"])
  sheet.add_data_validation(dv)
  let validations = sheet.get_data_validations()
  inspect(validations.length(), content="1")
  let first = validations[0]
  inspect(first.validation_type, content="list")
  inspect(first.formula1, content="\"Yes,No\"")
  inspect(first.sqref, content="A1:B2")
  inspect(first.allow_blank, content="false")
}

///|
test "data validation drop list length limit" {
  let dv = DataValidation::new(true)
  let long = "a".repeat(260)
  let result : Result[Unit, Error] = try? dv.set_drop_list([long])
  guard result is Err(XlsxError::InvalidDataValidation(_)) else {
    fail("expected length error")
  }
}

///|
test "data validation range value bounds" {
  let dv = DataValidation::new(true)
  let result : Result[Unit, Error] = try? dv.set_range(
    DoubleValue(1.0e39),
    IntValue(10),
    Whole,
    Between,
  )
  guard result is Err(XlsxError::InvalidDataValidation(_)) else {
    fail("expected range error")
  }
}

///|
test "data validation delete by sqref" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let dv1 = DataValidation::new(true)
  dv1.set_sqref("A1:A3")
  dv1.set_drop_list(["Yes"])
  sheet.add_data_validation(dv1)
  let dv2 = DataValidation::new(true)
  dv2.set_sqref("B1")
  dv2.set_drop_list(["No"])
  sheet.add_data_validation(dv2)
  sheet.delete_data_validation(sqrefs=["A2"])
  let validations = sheet.get_data_validations()
  let sqrefs : Array[String] = []
  for dv in validations {
    sqrefs.push(dv.sqref)
  }
  inspect(sqrefs.contains("A1 A3"), content="true")
  inspect(sqrefs.contains("B1"), content="true")
}

///|
test "data validation workbook invalid sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let dv = DataValidation::new(true)
  dv.set_sqref("A1")
  dv.set_drop_list(["Yes"])
  let add_result : Result[Unit, Error] = try? workbook.add_data_validation(
    "Sheet:1", dv,
  )
  inspect(add_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_result : Result[Array[DataValidation], Error] = try? workbook.get_data_validations(
    "Sheet:1",
  )
  inspect(get_result is Err(XlsxError::InvalidSheetName(_)), content="true")
}

///|
test "data validation read x14 extLst" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let out = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data)
      let ext =
        #|<extLst>
        #|  <ext uri="{2F02F2B1-0A8B-4F0A-8C2A-25A9A1B30E6B}" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main" xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main">
        #|    <x14:dataValidations>
        #|      <x14:dataValidation type="list" allowBlank="1">
        #|        <x14:formula1><xm:f>Sheet1!$B$1:$B$5</xm:f></x14:formula1>
        #|        <xm:sqref>A7:B8</xm:sqref>
        #|      </x14:dataValidation>
        #|    </x14:dataValidations>
        #|  </ext>
        #|</extLst>
      let modified = xml.replace_all(
        old="</worksheet>",
        new="\{ext}\n</worksheet>",
      )
      out.add(
        entry.name,
        @encoding/utf8.encode(modified),
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    } else {
      out.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  let new_bytes = @zip.write(out)
  let parsed = read(new_bytes)
  let dvs = parsed.get_data_validations("Sheet1")
  inspect(dvs.length(), content="1")
  inspect(dvs[0].validation_type, content="list")
  inspect(dvs[0].allow_blank, content="true")
  inspect(dvs[0].sqref, content="A7:B8")
  inspect(dvs[0].formula1, content="Sheet1!$B$1:$B$5")
}

///|
test "data validation enum/operator/style coverage" {
  let dv = DataValidation::new(true)
  dv.set_sqref("A1")
  let types : Array[DataValidationType] = [
    NoneType,
    Custom,
    Date,
    Decimal,
    List,
    TextLength,
    Time,
    Whole,
  ]
  for t in types {
    dv.set_range(IntValue(1), IntValue(2), t, Between)
  }
  let ops : Array[DataValidationOperator] = [
    Between,
    Equal,
    GreaterThan,
    GreaterThanOrEqual,
    LessThan,
    LessThanOrEqual,
    NotBetween,
    NotEqual,
  ]
  for op in ops {
    dv.set_range(IntValue(1), IntValue(2), Whole, op)
  }
  let styles : Array[DataValidationErrorStyle] = [Stop, Warning, Information]
  for style in styles {
    dv.set_error(style, "Title", "Message")
  }
  dv.set_range(DoubleValue(-1.5), DoubleValue(1.5), Decimal, Between)
  dv.set_range(TextValue("abc"), TextValue("def"), Custom, NotEqual)
  dv.set_sqref("A2")
  dv.set_sqref_drop_list("Sheet1!$A$1:$A$2")
  dv.set_drop_list(["=Sheet1!$B$1:$B$3"])
  dv.set_input("PromptTitle", "PromptMessage")
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_data_validation(dv)
  inspect(sheet.get_data_validations().length(), content="1")
}
