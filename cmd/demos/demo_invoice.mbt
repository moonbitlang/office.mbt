///|
fn invoice_styles(workbook : @xlsx.Workbook) -> (Int, Int, Int, Int) {
  let title_font = @xlsx.Font::with_values(
    bold=true,
    size=28.0,
    color="1F4E79",
    family="Calibri",
  )
  let title_style = @xlsx.Style::new()
  let title_style = @xlsx.Style::with_font(title_style, title_font)
  let header_font = @xlsx.Font::with_values(
    bold=true,
    size=12.0,
    color="FFFFFF",
    family="Calibri",
  )
  let header_style = @xlsx.Style::new()
  let header_style = @xlsx.Style::with_font(header_style, header_font)
  let header_style = @xlsx.Style::with_fill(
    header_style,
    @xlsx.Fill::solid("1F4E79"),
  )
  let header_style = @xlsx.Style::with_alignment(
    header_style,
    @xlsx.Alignment::with_values(horizontal="center", vertical="center"),
  )
  let money_style = @xlsx.Style::number_format("$#,##0.00")
  let muted_font = @xlsx.Font::with_values(size=10.0, color="666666")
  let muted_style = @xlsx.Style::new()
  let muted_style = @xlsx.Style::with_font(muted_style, muted_font)
  (
    workbook.new_style(title_style),
    workbook.new_style(header_style),
    workbook.new_style(money_style),
    workbook.new_style(muted_style),
  )
}

///|
pub fn demo_invoice_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Invoice")
  let (title_style, header_style, money_style, muted_style) = invoice_styles(
    workbook,
  )
  sheet.set_col_width(1, 18.0)
  sheet.set_col_width(2, 38.0)
  sheet.set_col_width(3, 12.0)
  sheet.set_col_width(4, 14.0)
  sheet.set_col_width(5, 14.0)
  sheet.set_col_width(6, 18.0)
  sheet.set_row_height(1, 40.0)
  sheet.set_cell("A1", "INVOICE")
  sheet.set_cell_style("A1", title_style)
  sheet.merge_cells("A1:F1")
  sheet.set_cell("A3", "Bill To:")
  sheet.set_cell("A4", "Moonbit Coffee Co.")
  sheet.set_cell("A5", "123 Spreadsheet St.")
  sheet.set_cell("A6", "San Francisco, CA")
  sheet.set_cell("E3", "Invoice #")
  sheet.set_cell("F3", "MBT-2026-0001")
  sheet.set_cell("E4", "Date")
  sheet.set_cell("F4", "2026-01-31")
  sheet.set_cell("E5", "Status")
  sheet.set_cell("F5", "Draft")
  let status_dv = @xlsx.DataValidation::new(true)
  status_dv.set_sqref("F5")
  status_dv.set_drop_list(["Draft", "Sent", "Paid", "Overdue"])
  status_dv.set_input("Choose status", "Pick one of the options from the list.")
  status_dv.set_error(Stop, "Invalid", "Pick a value from the list.")
  sheet.add_data_validation(status_dv)
  sheet.set_cell("A8", "Item")
  sheet.set_cell("B8", "Description")
  sheet.set_cell("C8", "Qty")
  sheet.set_cell("D8", "Unit")
  sheet.set_cell("E8", "Unit Price")
  sheet.set_cell("F8", "Line Total")
  sheet.set_row_style(8, header_style)
  sheet.set_row_height(8, 20.0)
  let rows = [
    ("Espresso Beans", "Single-origin, 1kg bag", 2, "bag", 28.50),
    ("Cold Brew", "12-pack", 3, "case", 36.00),
    ("Mugs", "Ceramic, 11oz", 8, "ea", 9.75),
  ]
  for i, row in rows {
    let r = 9 + i
    let (item, desc, qty, unit, price) = row
    sheet.set_cell("A\{r}", item)
    sheet.set_cell("B\{r}", desc)
    sheet.set_cell("C\{r}", "\{qty}")
    sheet.set_cell("D\{r}", unit)
    sheet.set_cell("E\{r}", "\{price}")
    sheet.set_cell_formula(
      "F\{r}",
      "C\{r}*E\{r}",
      value="\{(qty.to_double() * price)}",
    )
    sheet.set_cell_style("E\{r}", money_style)
    sheet.set_cell_style("F\{r}", money_style)
  }
  sheet.set_cell("E13", "Subtotal")
  sheet.set_cell_formula("F13", "SUM(F9:F11)", value="0")
  sheet.set_cell_style("F13", money_style)
  sheet.set_cell("E14", "Tax (8.5%)")
  sheet.set_cell_formula("F14", "F13*0.085", value="0")
  sheet.set_cell_style("F14", money_style)
  sheet.set_cell("E15", "Total")
  sheet.set_cell_formula("F15", "F13+F14", value="0")
  sheet.set_cell_style("F15", money_style)
  sheet.set_cell("A18", "Notes: This sheet is protected (password: moonbit).")
  sheet.set_cell_style("A18", muted_style)
  sheet.merge_cells("A18:F18")
  sheet.protect_sheet(
    @xlsx.SheetProtectionOptions::with_values(
      password="moonbit",
      select_locked_cells=true,
      select_unlocked_cells=true,
      sort=true,
      auto_filter=true,
    ),
  )
  sheet.set_header_footer(
    Some(
      @xlsx.HeaderFooterOptions::with_values(
        odd_header="&L&\"Calibri,Bold\"MoonBit Invoice&R&D",
        odd_footer="&CPage &P of &N",
      ),
    ),
  )
  @excel.write(workbook)
}
