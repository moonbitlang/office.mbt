///|
fn controls_define_names(
  workbook : @xlsx.Workbook,
) -> Unit raise @xlsx.XlsxError {
  // Workbook-scoped named cells used by formulas.
  workbook.set_defined_name(@xlsx.DefinedName::new("BasePrice", "UI!$B$3"))
  workbook.set_defined_name(@xlsx.DefinedName::new("DiscountPct", "UI!$B$4"))
  workbook.set_defined_name(@xlsx.DefinedName::new("TaxPct", "UI!$B$5"))
  workbook.set_defined_name(@xlsx.DefinedName::new("ShippingOn", "UI!$B$6"))
  workbook.set_defined_name(@xlsx.DefinedName::new("UnitCost", "UI!$B$7"))
  workbook.set_defined_name(@xlsx.DefinedName::new("Units", "UI!$B$8"))
}

///|
fn controls_add_ui_controls(
  workbook : @xlsx.Workbook,
) -> Unit raise @xlsx.XlsxError {
  // Discount slider: 0..50 (stored as integer percent).
  let discount = @xlsx.FormControl::new("D4", "ScrollBar", text="Discount")
  discount.set_width(220)
  discount.set_height(18)
  discount.set_cell_link("B4")
  discount.set_current_val(10)
  discount.set_min_val(0)
  discount.set_max_val(50)
  discount.set_inc_change(1)
  discount.set_page_change(5)
  discount.set_horizontally(true)
  workbook.add_form_control("UI", discount)

  // Tax spin: 0..15.
  let tax = @xlsx.FormControl::new("D5", "SpinButton", text="Tax")
  tax.set_width(90)
  tax.set_height(18)
  tax.set_cell_link("B5")
  tax.set_current_val(8)
  tax.set_min_val(0)
  tax.set_max_val(15)
  tax.set_inc_change(1)
  tax.set_page_change(1)
  tax.set_horizontally(true)
  workbook.add_form_control("UI", tax)

  // Shipping checkbox: 0/1 in B6.
  let shipping = @xlsx.FormControl::new(
    "D6",
    "CheckBox",
    text="Include shipping (+$4)",
  )
  shipping.set_width(220)
  shipping.set_height(18)
  shipping.set_cell_link("B6")
  shipping.set_checked(true)
  workbook.add_form_control("UI", shipping)
}

///|
pub fn demo_interactive_controls_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let ui = workbook.add_sheet("UI")
  let model = workbook.add_sheet("Model")
  controls_define_names(workbook)
  ui.set_col_width(1, 18.0)
  ui.set_col_width(2, 16.0)
  ui.set_col_width(3, 4.0)
  ui.set_col_width(4, 28.0)
  ui.set_col_width(5, 20.0)
  ui.set_row_height(1, 34.0)
  ui.set_cell("A1", "What-if Pricing Simulator")
  ui.merge_cells("A1:E1")

  // Simple “card” using a shape.
  workbook.add_shape(
    "UI",
    @xlsx.Shape::new(
      "A2",
      "rect",
      text="Use the controls on the right.\nThey write into B4/B5/B6 and drive formulas in the model.",
      width=560,
      height=50,
      fill_color="E2F0D9",
      line_color="70AD47",
      line_width=1.0,
      positioning=TwoCell,
      name="HintCard",
    ),
  )
  ui.set_cell("A3", "Base Price ($)")
  ui.set_cell("B3", "49")
  ui.set_cell("A4", "Discount (%)")
  ui.set_cell("B4", "10")
  ui.set_cell("A5", "Tax (%)")
  ui.set_cell("B5", "8")
  ui.set_cell("A6", "Shipping (0/1)")
  ui.set_cell("B6", "1")
  ui.set_cell("A7", "Unit Cost ($)")
  ui.set_cell("B7", "18")
  ui.set_cell("A8", "Units")
  ui.set_cell("B8", "120")

  // Data validation: constrain BasePrice and UnitCost to sane ranges.
  let dv_price = @xlsx.DataValidation::new(false)
  dv_price.set_sqref("B3")
  dv_price.set_range(DoubleValue(1.0), DoubleValue(500.0), Decimal, Between)
  ui.add_data_validation(dv_price)
  let dv_cost = @xlsx.DataValidation::new(false)
  dv_cost.set_sqref("B7")
  dv_cost.set_range(DoubleValue(0.0), DoubleValue(300.0), Decimal, Between)
  ui.add_data_validation(dv_cost)

  // Make the model sheet feel “engine-y”.
  model.set_col_width(1, 14.0)
  model.set_col_width(2, 16.0)
  model.set_col_width(3, 16.0)
  model.set_col_width(4, 16.0)
  model.set_col_width(5, 18.0)
  model.set_row(1, ["Qty", "Net Price", "Revenue", "Cost", "Profit"])

  // Model uses workbook named cells, so it reads nicely in Excel.
  // NetPrice = BasePrice * (1 - DiscountPct/100) + IF(ShippingOn=1, 4, 0)
  // Profit = Revenue - Cost, then taxed: Profit * (1 - TaxPct/100)
  for i in 0..<20 {
    let r = i + 2
    let qty = (i + 1) * 10
    model.set_cell("A\{r}", "\{qty}")
    model.set_cell_formula(
      "B\{r}",
      "BasePrice*(1-DiscountPct/100)+IF(ShippingOn=1,4,0)",
      value="0",
    )
    model.set_cell_formula("C\{r}", "A\{r}*B\{r}", value="0")
    model.set_cell_formula("D\{r}", "A\{r}*UnitCost", value="0")
    model.set_cell_formula("E\{r}", "(C\{r}-D\{r})*(1-TaxPct/100)", value="0")
  }

  // Conditional formatting: profit data bar + icon set.
  let bar = @xlsx.ConditionalFormatOptions::new("data_bar")
  bar.set_min_type("min")
  bar.set_max_type("max")
  bar.set_bar_color("#63BE7B")
  bar.set_bar_solid(true)
  model.set_conditional_format("E2:E21", [bar])
  let icons = @xlsx.ConditionalFormatOptions::new("icon_set")
  icons.set_icon_style("3Arrows")
  model.set_conditional_format("E2:E21", [icons])

  // Chart: Profit vs Qty.
  let chart = @xlsx.ChartOptions::new(Scatter)
  chart.title = "Profit vs Quantity"
  chart.x_axis.title = "Quantity"
  chart.y_axis.title = "Profit ($)"
  chart.series.push(
    @xlsx.ChartSeries::new(
      "Model!$A$2:$A$21",
      "Model!$E$2:$E$21",
      name="Profit",
    ),
  )
  chart.series[0].marker.symbol = "diamond"
  chart.series[0].marker.size = 7
  chart.series[0].marker.fill_color = "1F4E79"
  chart.series[0].marker.border.color = "1F4E79"
  chart.series[0].line.color = "1F4E79"
  workbook.add_chart_with_options("UI", "A10", chart)
  controls_add_ui_controls(workbook)
  @excel.write(workbook)
}
