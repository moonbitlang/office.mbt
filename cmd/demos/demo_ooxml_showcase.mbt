///|
pub fn demo_ooxml_showcase_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Showcase")
  let data = workbook.add_sheet("Data")
  sheet.set_col_width(1, 22.0)
  sheet.set_col_width(2, 56.0)
  sheet.set_col_width(3, 18.0)
  sheet.set_row_height(1, 34.0)
  sheet.set_cell("A1", "mbtexcel OOXML Showcase")
  sheet.merge_cells("A1:C1")

  // Rich text title.
  let title_font : @xlsx.RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: Some(16.0),
    color: Some("1F4E79"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: Some("Calibri"),
  }
  let accent_font : @xlsx.RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: Some("single"),
    size: Some(16.0),
    color: Some("C00000"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: Some("Calibri"),
  }
  sheet.set_cell_rich_text("A2", [
    { text: "Spreadsheet as a ", font: Some(title_font) },
    { text: "Document", font: Some(accent_font) },
  ])
  sheet.merge_cells("A2:C2")

  // Hyperlinks (external + internal).
  sheet.set_cell("A4", "External link")
  sheet.set_cell_hyperlink_opts(
    "B4",
    "https://github.com/xuri/excelize",
    External,
    opts=@xlsx.HyperlinkOpts::with_values(
      display="excelize on GitHub",
      tooltip="Opens in your browser",
    ),
  )
  sheet.set_cell("A5", "Internal link")
  sheet.set_cell_hyperlink_opts(
    "B5",
    "Data!A1",
    Location,
    opts=@xlsx.HyperlinkOpts::with_values(display="Jump to Data!A1"),
  )
  data.set_cell("A1", "You jumped here.")

  // Comment with rich text.
  let note_font : @xlsx.RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: Some(11.0),
    color: Some("7030A0"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  sheet.add_comment({
    cell: "C5",
    author: "mbtexcel",
    text: "",
    paragraph: [
      { text: "Note:", font: Some(note_font) },
      { text: " internal hyperlinks use HyperlinkType::Location", font: None },
    ],
    width: Some(260),
    height: Some(80),
  })

  // “Numbers stored as text” warnings are common in data imports.
  // We intentionally store numbers as text and then suppress the warning via IgnoredErrors.
  sheet.set_cell("A7", "Data import quirk")
  sheet.set_cell("B7", "Numbers stored as text (warnings suppressed)")
  sheet.set_cell("A8", "SKU")
  sheet.set_cell("B8", "Quantity(text)")
  let skus = ["A-100", "A-101", "B-200", "B-201", "C-300"]
  let qtys = ["0012", "0007", "0100", "0025", "0003"]
  for i in 0..<skus.length() {
    let r = 9 + i
    sheet.set_cell("A\{r}", skus[i])
    sheet.set_cell("B\{r}", qtys[i])
  }
  sheet.add_ignored_errors("B9:B13", NumberStoredAsText)

  // Header/footer image + print settings.
  sheet.set_header_footer(
    Some(
      @xlsx.HeaderFooterOptions::with_values(odd_header="&L&G&Cmbtexcel demo"),
    ),
  )
  sheet.add_header_footer_image(
    @xlsx.HeaderFooterImageOptions::new(
      Left,
      demo_logo_png,
      ".png",
      width="24pt",
      height="24pt",
    ),
  )
  sheet.set_page_layout(
    Some(
      @xlsx.PageLayoutOptions::with_values(
        orientation="landscape",
        fit_to_width=1,
        fit_to_height=1,
      ),
    ),
  )
  sheet.set_page_margins(
    Some(
      @xlsx.PageLayoutMarginsOptions::with_values(
        top=0.5,
        bottom=0.5,
        left=0.5,
        right=0.5,
      ),
    ),
  )

  // Sheet background (looks like a watermark in many viewers).
  sheet.set_sheet_background(demo_logo_png, "png")
  @excel.write(workbook)
}
