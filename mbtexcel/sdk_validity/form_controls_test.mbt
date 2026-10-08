///|
#cfg(target="native")
async test "modern form controls are Microsoft OpenXML schema-valid" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Widgets")
  for
    index, kind in [
      "CheckBox", "Radio", "Spin", "Scroll", "Button", "GBox", "Label",
    ] {
    let control = @xlsx.FormControl::new("A\{index * 5 + 1}", kind, text=kind)
    if kind == "CheckBox" || kind == "Radio" {
      control.set_checked(true)
      control.set_cell_link("G2")
    }
    if kind == "Spin" || kind == "Scroll" {
      control.set_current_val(5)
      control.set_min_val(1)
      control.set_max_val(20)
      control.set_inc_change(1)
      control.set_page_change(3)
      control.set_horizontally(true)
      control.set_cell_link("G3")
    }
    sheet.add_form_control(control)
  }
  let dir = @async/fs.tmpdir(prefix="mbtexcel-form-controls-")
  validate_via_sdk(dir, "controls", @xlsx.write(workbook))
}
