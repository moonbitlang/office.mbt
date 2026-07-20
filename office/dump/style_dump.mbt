///|
/// The batch-expressible slice of a cell style, plus the reasons any of its
/// attributes could not be expressed. `params` is empty when the style
/// carries nothing the `style` op can reproduce.
priv struct StyleExtract {
  params : Map[String, Json]
  unexpressible : Array[String]
}

///|
/// Emits `style` ops for a worksheet's explicitly styled cells, coalescing
/// same-style contiguous cells within a row into one range op, and records
/// one residual per distinct style whose attributes are not fully
/// expressible. Style ops follow the cell ops so replay styles populated
/// cells.
fn dump_sheet_styles(
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  // cache the extract per style id; record which styles already reported
  // residual reasons so a shared style does not repeat them
  let extracts : Map[Int, StyleExtract] = {}
  let reported : Set[Int] = Set::new()
  fn extract_for(id : Int) -> StyleExtract raise {
    match extracts.get(id) {
      Some(found) => found
      None => {
        let style = workbook.get_style(id)
        let code = match style.num_fmt {
          Some(fmt) => @xlsx.builtin_number_format_code(fmt)
          None => None
        }
        let extract = extract_style(style, code)
        extracts[id] = extract
        extract
      }
    }
  }

  // styled cells in row-major order (dedup by reference, first wins)
  let seen : Set[String] = Set::new()
  let styled : Array[@xlsx.Cell] = []
  for cell in worksheet.cells {
    if seen.contains(cell.reference) {
      continue
    }
    seen.add(cell.reference)
    if cell.style_explicit && cell.style_id != 0 {
      styled.push(cell)
    }
  }
  styled.sort_by((a, b) => {
    if a.row == b.row {
      a.col - b.col
    } else {
      a.row - b.row
    }
  })

  // coalesce contiguous same-style cells within a row into runs
  let mut run_start = 0
  while run_start < styled.length() {
    let first = styled[run_start]
    let mut run_end = run_start
    while run_end + 1 < styled.length() {
      let next = styled[run_end + 1]
      let prev = styled[run_end]
      if next.row == prev.row &&
        next.col == prev.col + 1 &&
        next.style_id == first.style_id {
        run_end += 1
      } else {
        break
      }
    }
    let extract = extract_for(first.style_id)
    if !extract.params.is_empty() {
      let params : Map[String, Json] = {
        "sheet": Json::string(sheet),
        "range": Json::string("\{first.reference}:\{styled[run_end].reference}"),
      }
      for key, value in extract.params {
        params[key] = value
      }
      ops.push(
        Json::object({
          "op": Json::string("style"),
          "params": Json::object(params),
        }),
      )
    }
    if extract.unexpressible.length() > 0 && !reported.contains(first.style_id) {
      reported.add(first.style_id)
      residual.push({
        code: "xlsx.style_attributes_unexpressible",
        severity: "approximated",
        scope: "cells",
        location: dump_location(sheet, "cell", first.reference),
        asset: None,
        detail: "style attributes not expressible in \{XLSX_BATCH_SCHEMA}: " +
        extract.unexpressible.join(", "),
      })
    }
    run_start = run_end + 1
  }
}

///|
/// OOXML border style code → the batch `border` value name, for the seven
/// codes the `style` op accepts. Other codes are unexpressible.
fn border_style_name(code : Int) -> String? {
  match code {
    1 => Some("thin")
    2 => Some("medium")
    3 => Some("dashed")
    4 => Some("dotted")
    5 => Some("thick")
    6 => Some("double")
    7 => Some("hair")
    _ => None
  }
}

///|
fn is_hex6(value : String) -> Bool {
  guard value.length() == 6 else { return false }
  for ch in value {
    if !(ch is ('0'..='9' | 'a'..='f' | 'A'..='F')) {
      return false
    }
  }
  true
}

///|
/// Extracts the batch `style` op parameters a `Style` can express, and
/// records every retained attribute the op vocabulary cannot reproduce.
fn extract_style(style : @xlsx.Style, num_fmt_code : String?) -> StyleExtract {
  let params : Map[String, Json] = {}
  let unexpressible : Array[String] = []

  // font: bold / italic / color are expressible; everything else is not
  match style.font {
    Some(font) => {
      if font.bold is Some(true) {
        params["bold"] = Json::boolean(true)
      }
      if font.italic is Some(true) {
        params["italic"] = Json::boolean(true)
      }
      match font.color {
        Some(color) if is_hex6(color) =>
          params["font_color"] = Json::string(color)
        Some(_) => unexpressible.push("font_color_nonrgb")
        None => ()
      }
      if font.size is Some(_) {
        unexpressible.push("font_size")
      }
      if font.underline is Some(_) {
        unexpressible.push("font_underline")
      }
      if font.strike is Some(true) {
        unexpressible.push("font_strike")
      }
      if font.vert_align is Some(_) {
        unexpressible.push("font_vert_align")
      }
      if font.family is Some(_) || font.scheme is Some(_) {
        unexpressible.push("font_name")
      }
    }
    None => ()
  }

  // fill: a solid RGB fill is expressible (Fill::solid is a pattern fill
  // with pattern code 1 and one RGB color); patterns, themes, and indexed
  // colors are not
  match style.fill {
    Some(fill) =>
      if fill.pattern is Some(1) &&
        fill.colors is Some([color]) &&
        is_hex6(color) &&
        fill.fg_theme is None &&
        fill.fg_indexed is None &&
        fill.bg_theme is None &&
        fill.bg_indexed is None &&
        (fill.transparency is None || fill.transparency is Some(0)) {
        params["fill"] = Json::string(color)
      } else {
        unexpressible.push("fill_unsupported")
      }
    None => ()
  }

  // number format: custom code, or a known builtin id → its code
  match style.custom_num_fmt {
    Some(code) if code != "" => params["number_format"] = Json::string(code)
    _ =>
      match num_fmt_code {
        Some(code) => params["number_format"] = Json::string(code)
        None =>
          if style.num_fmt is Some(id) && id != 0 {
            unexpressible.push("number_format_builtin_\{id}")
          }
      }
  }

  // alignment: horizontal is expressible; everything else is not
  match style.alignment {
    Some(align) => {
      match align.horizontal {
        Some(h) if h != "" => params["align"] = Json::string(h)
        _ => ()
      }
      if (align.vertical is Some(v) && v != "") ||
        align.wrap_text is Some(true) ||
        (align.text_rotation is Some(r) && r != 0) ||
        (align.indent is Some(i) && i != 0) ||
        align.shrink_to_fit is Some(true) {
        unexpressible.push("alignment_unsupported")
      }
    }
    None => ()
  }

  // borders: per-side style names for codes 1..7 with one shared color
  match style.border {
    Some(borders) => extract_borders(borders, params, unexpressible)
    None => ()
  }

  // protection: not expressible
  if style.protection is Some(_) {
    unexpressible.push("protection")
  }
  { params, unexpressible }
}

///|
/// Maps a border array to the batch per-side border params, recording a
/// residual reason for codes or colors the `style` op cannot express.
fn extract_borders(
  borders : Array[@xlsx.Border],
  params : Map[String, Json],
  unexpressible : Array[String],
) -> Unit {
  let mut border_color : String? = None
  let mut color_conflict = false
  for border in borders {
    let key = match border.typ {
      "top" => "border_top"
      "bottom" => "border_bottom"
      "left" => "border_left"
      "right" => "border_right"
      _ => {
        // diagonal and other sides have no op parameter
        unexpressible.push("border_side_\{border.typ}")
        continue
      }
    }
    match border.style {
      Some(code) =>
        match border_style_name(code) {
          Some(name) => params[key] = Json::string(name)
          None => unexpressible.push("border_style_\{code}")
        }
      None => ()
    }
    match border.color {
      Some(color) if is_hex6(color) =>
        match border_color {
          None => border_color = Some(color)
          Some(existing) => if existing != color { color_conflict = true }
        }
      Some(_) => unexpressible.push("border_color_nonrgb")
      None => ()
    }
  }
  match border_color {
    Some(color) => params["border_color"] = Json::string(color)
    None => ()
  }
  if color_conflict {
    // the op carries a single border_color; distinct per-side colors
    // cannot be reproduced
    unexpressible.push("border_per_side_color")
  }
}
