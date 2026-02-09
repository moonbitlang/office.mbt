///|
async fn ensure_dir(path : String) -> Unit {
  @async/fs.mkdir(path, permission=0o755, recursive=true) catch {
    _ => ()
  }
}

///|
async fn write_out(out_dir : String, name : String, bytes : Bytes) -> Unit {
  ensure_dir(out_dir)
  let path = "\{out_dir}/\{name}"
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err => {
      println("write failed: \{path}: \{err}")
      return
    }
  }
  println("wrote \{path} (\{bytes.length()} bytes)")
}

///|
fn parity_controls_min_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("B4", "10")
  sheet.set_cell("B5", "8")
  sheet.set_cell("B6", "1")

  let scroll = @xlsx.FormControl::new("D4", "ScrollBar", text="Discount")
  scroll.set_width(220)
  scroll.set_height(18)
  scroll.set_cell_link("B4")
  scroll.set_current_val(10)
  scroll.set_min_val(0)
  scroll.set_max_val(50)
  scroll.set_inc_change(1)
  scroll.set_page_change(5)
  scroll.set_horizontally(true)
  workbook.add_form_control("Sheet1", scroll)

  let spin = @xlsx.FormControl::new("D5", "SpinButton", text="Tax")
  spin.set_width(90)
  spin.set_height(18)
  spin.set_cell_link("B5")
  spin.set_current_val(8)
  spin.set_min_val(0)
  spin.set_max_val(15)
  spin.set_inc_change(1)
  spin.set_page_change(1)
  spin.set_horizontally(true)
  workbook.add_form_control("Sheet1", spin)

  let check = @xlsx.FormControl::new(
    "D6",
    "CheckBox",
    text="Include shipping (+$4)",
  )
  check.set_width(220)
  check.set_height(18)
  check.set_cell_link("B6")
  check.set_checked(true)
  workbook.add_form_control("Sheet1", check)

  @excel.write(workbook)
}

///|
fn parity_cf_min_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Sheet1")
  for i in 2..<=21 {
    let cell_a = "A\{i}"
    let cell_e = "E\{i}"
    sheet.set_cell_value(cell_a, Numeric((i - 1).to_double() * 10.0))
    sheet.set_cell_value(cell_e, Numeric(((i - 1) * 20 - 50).to_double()))
  }

  let data_bar = @xlsx.ConditionalFormatOptions::new("data_bar")
  data_bar.set_criteria("=")
  data_bar.set_min_type("min")
  data_bar.set_max_type("max")
  data_bar.set_bar_color("#63BE7B")
  data_bar.set_bar_solid(true)
  sheet.set_conditional_format("E2:E21", [data_bar])

  let icon_set = @xlsx.ConditionalFormatOptions::new("icon_set")
  icon_set.set_icon_style("3Arrows")
  sheet.set_conditional_format("E2:E21", [icon_set])

  @excel.write(workbook)
}

///|
fn parity_shared_strings_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_file()
  workbook.set_cell("Sheet1", "A1", "A")
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_cell("Sheet2", "A1", "B")
  @excel.write(workbook)
}

///|
fn usage() -> Unit {
  println("Usage: moon run cmd/parity -- [out_dir]")
  println("Default out_dir: _build/semantic_parity/mbt")
}

///|
async fn main {
  let args = @env.args()
  let out_dir = match args {
    [] | [_] => "_build/semantic_parity/mbt"
    [_, "-h"] | [_, "--help"] => {
      usage()
      return
    }
    [_, value, ..] => value
  }

  let dashboard : Result[Bytes, Error] = try? @demos.demo_dashboard_bytes()
  match dashboard {
    Ok(bytes) => write_out(out_dir, "dashboard.xlsx", bytes)
    Err(err) => println("dashboard generation failed: \{err}")
  }
  let controls : Result[Bytes, Error] = try? parity_controls_min_bytes()
  match controls {
    Ok(bytes) => write_out(out_dir, "controls.xlsx", bytes)
    Err(err) => println("controls generation failed: \{err}")
  }
  let cf : Result[Bytes, Error] = try? parity_cf_min_bytes()
  match cf {
    Ok(bytes) => write_out(out_dir, "cf.xlsx", bytes)
    Err(err) => println("cf generation failed: \{err}")
  }
  let shared_strings : Result[Bytes, Error] = try? parity_shared_strings_bytes()
  match shared_strings {
    Ok(bytes) => write_out(out_dir, "shared_strings.xlsx", bytes)
    Err(err) => println("shared_strings generation failed: \{err}")
  }
}
