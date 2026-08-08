///|
// `w:tbl` parsing. Table properties cascade the same way run and
// paragraph properties do — the table's `w:tblBorders` and
// `w:tblCellMar` supply defaults that each cell's `w:tcPr` overrides —
// so the readers take the inherited value and return the effective one.

///|
/// `w:tblW`/`w:tcW`: a value plus a `w:type` naming its unit.
fn read_width(el : @xml.XmlElement) -> @table.Width {
  let kind = attr(el, "w:type").unwrap_or("dxa")
  match kind {
    "nil" => Nil
    "auto" => Auto
    "pct" =>
      // may be a bare number in fiftieths, or a "50%" string
      match attr(el, "w:w") {
        Some(raw) =>
          if raw.has_suffix("%") {
            match parse_decimal(raw[0:raw.length() - 1].to_owned()) {
              Some(percent) => Percent(percent * 50.0)
              None => Auto
            }
          } else {
            match parse_int(Some(raw)) {
              Some(v) => Percent(v.to_double())
              None => Auto
            }
          }
        None => Auto
      }
    _ =>
      match parse_twips(attr(el, "w:w")) {
        Some(v) => Twips(Twips(v))
        None => Auto
      }
  }
}

///|
/// One `w:tblBorders`/`w:tcBorders` side. `w:val="none"`/`"nil"` clears
/// an inherited border rather than leaving it in place.
fn read_border(el : @xml.XmlElement) -> @table.Border? {
  match attr(el, "w:val") {
    Some("none") | Some("nil") => None
    _ => {
      let width = match parse_int(attr(el, "w:sz")) {
        Some(v) if v > 0 => v
        _ => 4 // Word's default 0.5pt when sz is absent
      }
      let color = match attr(el, "w:color") {
        Some("auto") | None => @pagelayout.black
        Some(hex) => parse_hex_color(hex).unwrap_or(@pagelayout.black)
      }
      Some({ width: EighthPoints(width), color })
    }
  }
}

///|
/// Read a borders container, starting from `inherited`.
fn read_borders(
  container : @xml.XmlElement,
  inherited : @table.Borders,
) -> @table.Borders {
  let mut borders = inherited
  for child in container.children {
    guard child is XmlElement(el) else { continue }
    let side = read_border(el)
    match el.name {
      "w:top" => borders = { ..borders, top: side }
      "w:bottom" => borders = { ..borders, bottom: side }
      // insideH/insideV apply between cells; approximate them onto the
      // shared edges so gridded tables draw their interior lines
      "w:left" | "w:start" => borders = { ..borders, left: side }
      "w:right" | "w:end" => borders = { ..borders, right: side }
      "w:insideH" => borders = { ..borders, top: side, bottom: side }
      "w:insideV" => borders = { ..borders, left: side, right: side }
      _ => ()
    }
  }
  borders
}

///|
fn read_cell_margins(
  container : @xml.XmlElement,
  inherited : @table.CellMargins,
) -> @table.CellMargins {
  let mut margins = inherited
  for child in container.children {
    guard child is XmlElement(el) else { continue }
    guard parse_twips(attr(el, "w:w")) is Some(v) else { continue }
    match el.name {
      "w:top" => margins = { ..margins, top: Twips(v) }
      "w:bottom" => margins = { ..margins, bottom: Twips(v) }
      "w:left" | "w:start" => margins = { ..margins, left: Twips(v) }
      "w:right" | "w:end" => margins = { ..margins, right: Twips(v) }
      _ => ()
    }
  }
  margins
}

///|
/// `w:shd w:fill` — the cell's background. "auto" means no fill.
fn read_shading(el : @xml.XmlElement) -> @pagelayout.Color? {
  match attr(el, "w:fill") {
    Some("auto") | None => None
    Some(hex) => parse_hex_color(hex)
  }
}

///|
/// Read one `w:tc`, inheriting the table's borders and cell margins.
fn read_cell(
  tc : @xml.XmlElement,
  sheet : StyleSheet,
  theme : ThemeFonts,
  table_borders : @table.Borders,
  table_margins : @table.CellMargins,
  numbering : @numbering.Numbering,
  counters : @numbering.Counters,
) -> @table.Cell {
  let mut width : @table.Width = Auto
  let mut grid_span = 1
  let mut vmerge : @table.VMerge = VStart
  let mut borders = table_borders
  let mut margins = table_margins
  let mut shading : @pagelayout.Color? = None
  match tc.first("w:tcPr") {
    Some(props) =>
      for child in props.children {
        guard child is XmlElement(el) else { continue }
        match el.name {
          "w:tcW" => width = read_width(el)
          "w:gridSpan" =>
            match parse_int(attr(el, "w:val")) {
              Some(v) if v > 0 => grid_span = v
              _ => ()
            }
          "w:vMerge" =>
            // absent val, or "continue", means this row continues a merge
            vmerge = match attr(el, "w:val") {
              Some("restart") => VStart
              _ => VContinue
            }
          "w:tcBorders" => borders = read_borders(el, borders)
          "w:tcMar" => margins = read_cell_margins(el, margins)
          "w:shd" => shading = read_shading(el)
          _ => ()
        }
      }
    None => ()
  }
  let content : Array[@paragraph.ParagraphInput] = []
  for child in tc.children {
    guard child is XmlElement(el) else { continue }
    if el.name == "w:p" {
      let (block, _, _) = read_paragraph(
        el,
        sheet,
        theme,
        numbering~,
        counters~,
      )
      if block is Paragraph(input~, ..) {
        content.push(input)
      }
    }
  }
  @table.Cell::new(
    content,
    width~,
    grid_span~,
    vmerge~,
    borders~,
    margins~,
    shading~,
  )
}

///|
fn read_row(
  tr : @xml.XmlElement,
  sheet : StyleSheet,
  theme : ThemeFonts,
  table_borders : @table.Borders,
  table_margins : @table.CellMargins,
  numbering : @numbering.Numbering,
  counters : @numbering.Counters,
) -> @table.Row {
  let mut header = false
  let mut cant_split = false
  let mut min_height : @pagelayout.Twips? = None
  match tr.first("w:trPr") {
    Some(props) =>
      for child in props.children {
        guard child is XmlElement(el) else { continue }
        match el.name {
          "w:tblHeader" => header = parse_toggle(el)
          "w:cantSplit" => cant_split = parse_toggle(el)
          "w:trHeight" =>
            // only "atLeast" is a floor; "exact" is not honored yet and
            // "auto" imposes nothing
            if attr(el, "w:hRule") is Some("atLeast") {
              match parse_twips(attr(el, "w:val")) {
                Some(v) => min_height = Some(Twips(v))
                None => ()
              }
            }
          _ => ()
        }
      }
    None => ()
  }
  let cells : Array[@table.Cell] = []
  for child in tr.children {
    guard child is XmlElement(el) else { continue }
    if el.name == "w:tc" {
      cells.push(
        read_cell(
          el, sheet, theme, table_borders, table_margins, numbering, counters,
        ),
      )
    }
  }
  @table.Row::new(cells, header~, cant_split~, min_height~)
}

///|
/// Read a `w:tbl` into the engine's table model.
pub fn read_table(
  tbl : @xml.XmlElement,
  sheet : StyleSheet,
  theme? : ThemeFonts = ThemeFonts::empty(),
  numbering? : @numbering.Numbering = @numbering.Numbering::empty(),
  counters? : @numbering.Counters = @numbering.Counters::new(),
) -> @table.Table {
  let mut width : @table.Width = Auto
  let mut layout : @table.TableLayout = Autofit
  let mut borders = @table.Borders::none()
  let mut margins = @table.CellMargins::default()
  let mut indent = @pagelayout.Twips(0)
  match tbl.first("w:tblPr") {
    Some(props) =>
      for child in props.children {
        guard child is XmlElement(el) else { continue }
        match el.name {
          "w:tblW" => width = read_width(el)
          "w:tblLayout" =>
            layout = if attr(el, "w:type") is Some("fixed") {
              Fixed
            } else {
              Autofit
            }
          "w:tblBorders" => borders = read_borders(el, borders)
          "w:tblCellMar" => margins = read_cell_margins(el, margins)
          "w:tblInd" =>
            match parse_twips(attr(el, "w:w")) {
              Some(v) => indent = Twips(v)
              None => ()
            }
          _ => ()
        }
      }
    None => ()
  }
  let grid : Array[@pagelayout.Twips] = []
  match tbl.first("w:tblGrid") {
    Some(g) =>
      for col in g.elements_by_tag_name("w:gridCol") {
        match parse_twips(col.attributes.get("w:w")) {
          Some(v) => grid.push(Twips(v))
          None => ()
        }
      }
    None => ()
  }
  let rows : Array[@table.Row] = []
  for child in tbl.children {
    guard child is XmlElement(el) else { continue }
    if el.name == "w:tr" {
      rows.push(
        read_row(el, sheet, theme, borders, margins, numbering, counters),
      )
    }
  }
  @table.Table::new(rows, grid~, width~, layout~, borders~, indent~)
}
