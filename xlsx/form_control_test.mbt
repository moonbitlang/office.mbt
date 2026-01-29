///|
test "form control excelize-like add/get" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let form_controls : Array[FormControl] = []
  let d1 = FormControl::new("D1", "Button")
  d1.set_macro_name("Button1_Click")
  form_controls.push(d1)
  let a1 = FormControl::new("A1", "Button", text="Button 1\n")
  a1.set_macro_name("Button1_Click")
  a1.set_width(140)
  a1.set_height(60)
  a1.set_paragraph([
    {
      text: "C1=A1+B1",
      font: Some({
        bold: true,
        italic: true,
        strike: false,
        outline: false,
        shadow: false,
        condense: false,
        extend: false,
        underline: Some("single"),
        size: Some(14.0),
        color: Some("777777"),
        color_theme: None,
        color_indexed: None,
        color_tint: None,
        charset: None,
        family_number: None,
        scheme: None,
        vert_align: None,
        family: Some("Times New Roman"),
      }),
    },
  ])
  a1.set_format(
    GraphicOptions::with_values(
      print_object=true,
      positioning=PicturePositioning::Absolute,
    ),
  )
  form_controls.push(a1)
  let a5 = FormControl::new("A5", "CheckBox", text="Check Box 1")
  a5.set_checked(true)
  a5.set_format(
    GraphicOptions::with_values(
      print_object=false,
      positioning=PicturePositioning::OneCell,
    ),
  )
  form_controls.push(a5)
  let a6 = FormControl::new("A6", "CheckBox", text="Check Box 2")
  a6.set_cell_link("C5")
  a6.set_format(
    GraphicOptions::with_values(positioning=PicturePositioning::TwoCell),
  )
  form_controls.push(a6)
  let a7 = FormControl::new("A7", "OptionButton", text="Option Button 1")
  a7.set_checked(true)
  form_controls.push(a7)
  form_controls.push(
    FormControl::new("A8", "OptionButton", text="Option Button 2"),
  )
  let d3 = FormControl::new("D3", "GroupBox", text="Group Box 1")
  d3.set_width(140)
  d3.set_height(60)
  form_controls.push(d3)
  let a9 = FormControl::new("A9", "Label", text="Label 1")
  a9.set_width(140)
  form_controls.push(a9)
  let c5 = FormControl::new("C5", "SpinButton")
  c5.set_width(40)
  c5.set_height(60)
  c5.set_current_val(7)
  c5.set_min_val(5)
  c5.set_max_val(10)
  c5.set_inc_change(1)
  c5.set_cell_link("C2")
  form_controls.push(c5)
  let d7 = FormControl::new("D7", "ScrollBar")
  d7.set_width(140)
  d7.set_height(20)
  d7.set_current_val(50)
  d7.set_min_val(10)
  d7.set_max_val(100)
  d7.set_inc_change(1)
  d7.set_page_change(1)
  d7.set_horizontally(true)
  d7.set_cell_link("C3")
  form_controls.push(d7)
  let g1 = FormControl::new("G1", "ScrollBar")
  g1.set_width(20)
  g1.set_height(140)
  g1.set_current_val(50)
  g1.set_min_val(1000)
  g1.set_max_val(100)
  g1.set_inc_change(1)
  g1.set_page_change(1)
  g1.set_cell_link("C4")
  form_controls.push(g1)
  for control in form_controls {
    workbook.add_form_control("Sheet1", control)
  }
  let result = workbook.get_form_controls("Sheet1")
  assert_eq(result.length(), 11)
  for i, expected in form_controls {
    let got = result[i]
    assert_eq(got.control_type, expected.control_type)
    assert_eq(got.cell, expected.cell)
    assert_eq(got.macro_name, expected.macro_name)
    assert_eq(got.checked, expected.checked)
    assert_eq(got.current_val, expected.current_val)
    assert_eq(got.min_val, expected.min_val)
    assert_eq(got.max_val, expected.max_val)
    assert_eq(got.inc_change, expected.inc_change)
    assert_eq(got.horizontally, expected.horizontally)
    assert_eq(got.cell_link, expected.cell_link)
    assert_eq(got.text, expected.text)
    assert_eq(got.paragraph.length(), expected.paragraph.length())
  }
}

///|
test "form control roundtrip preserves basic fields" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let a1 = FormControl::new("A1", "Button", text="Button 1\n")
  a1.set_macro_name("Button1_Click")
  a1.set_paragraph([
    {
      text: "C1=A1+B1",
      font: Some({
        bold: true,
        italic: true,
        strike: false,
        outline: false,
        shadow: false,
        condense: false,
        extend: false,
        underline: Some("single"),
        size: Some(14.0),
        color: Some("777777"),
        color_theme: None,
        color_indexed: None,
        color_tint: None,
        charset: None,
        family_number: None,
        scheme: None,
        vert_align: None,
        family: Some("Times New Roman"),
      }),
    },
  ])
  workbook.add_form_control("Sheet1", a1)
  let a7 = FormControl::new("A7", "OptionButton", text="Option Button 1")
  a7.set_checked(true)
  workbook.add_form_control("Sheet1", a7)
  let c5 = FormControl::new("C5", "SpinButton")
  c5.set_current_val(7)
  c5.set_min_val(5)
  c5.set_max_val(10)
  c5.set_inc_change(1)
  c5.set_cell_link("C2")
  workbook.add_form_control("Sheet1", c5)
  let d7 = FormControl::new("D7", "ScrollBar")
  d7.set_current_val(50)
  d7.set_min_val(10)
  d7.set_max_val(100)
  d7.set_inc_change(1)
  d7.set_page_change(1)
  d7.set_horizontally(true)
  d7.set_cell_link("C3")
  workbook.add_form_control("Sheet1", d7)
  let bytes = write(workbook)
  let parsed = read(bytes)
  let controls = parsed.get_form_controls("Sheet1")
  assert_eq(controls.length(), 4)
  let pairs : Array[String] = []
  for c in controls {
    pairs.push("\{c.cell}:\{c.control_type}")
  }
  inspect(pairs.contains("A1:Button"), content="true")
  inspect(pairs.contains("A7:OptionButton"), content="true")
  inspect(pairs.contains("C5:SpinButton"), content="true")
  inspect(pairs.contains("D7:ScrollBar"), content="true")
}

///|
test "form control invalid inputs and delete no-op" {
  let bad_type : Result[FormControl, Error] = try? FormControl::new(
    "A1", "Unknown",
  )
  inspect(bad_type is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  let spin = FormControl::new("C5", "SpinButton")
  let bad_link : Result[Unit, Error] = try? spin.set_cell_link("*")
  inspect(bad_link is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_value : Result[Unit, Error] = try? spin.set_current_val(30001)
  inspect(bad_value is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let del_empty : Result[Unit, Error] = try? workbook.delete_form_control(
    "Sheet1", "A1",
  )
  inspect(del_empty is Ok(_), content="true")
  let del_bad_sheet : Result[Unit, Error] = try? workbook.delete_form_control(
    "SheetN", "A1",
  )
  inspect(del_bad_sheet is Err(XlsxError::SheetNotFound(_)), content="true")
  let del_bad_cell : Result[Unit, Error] = try? workbook.delete_form_control(
    "Sheet1", "A",
  )
  inspect(del_bad_cell is Err(XlsxError::InvalidCellRef(_)), content="true")
}
