///|
let max_page_break_rows = 1048575

///|
let max_page_break_cols = 16383

///|
fn normalize_optional_value(
  value : StringView,
  supported : Array[String],
  field_name : StringView,
) -> String raise XlsxError {
  let needle = value.to_string().to_lower()
  for item in supported {
    if item.to_lower() == needle {
      return item
    }
  }
  raise XlsxError::InvalidPageLayout(msg="\{field_name.to_string()} invalid")
}

///|
fn normalize_page_layout_options(
  options : PageLayoutOptions,
) -> PageLayoutOptions raise XlsxError {
  let updated = options
  match updated.orientation {
    Some(value) =>
      updated.orientation = Some(
        normalize_optional_value(
          value, supported_page_orientation, "orientation",
        ),
      )
    None => ()
  }
  match updated.page_order {
    Some(value) =>
      updated.page_order = Some(
        normalize_optional_value(value, supported_page_order, "page_order"),
      )
    None => ()
  }
  match updated.adjust_to {
    Some(value) =>
      if value < 10 || value > 400 {
        raise XlsxError::InvalidPageLayout(msg="adjust_to out of range")
      }
    None => ()
  }
  match updated.first_page_number {
    Some(value) => if value <= 0 { updated.first_page_number = None }
    None => ()
  }
  updated
}

///|
fn check_header_footer_limit(
  value : StringView,
  field_name : StringView,
) -> Unit raise XlsxError {
  if count_utf16_units(value) > max_field_length {
    raise XlsxError::InvalidHeaderFooter(
      msg="\{field_name.to_string()} too long",
    )
  }
}

///|
fn check_header_footer_limits(
  options : HeaderFooterOptions,
) -> Unit raise XlsxError {
  check_header_footer_limit(options.odd_header, "odd_header")
  check_header_footer_limit(options.odd_footer, "odd_footer")
  check_header_footer_limit(options.even_header, "even_header")
  check_header_footer_limit(options.even_footer, "even_footer")
  check_header_footer_limit(options.first_header, "first_header")
  check_header_footer_limit(options.first_footer, "first_footer")
}

///|
fn remove_break_by_id(breaks : Array[PageBreak], id : Int) -> Array[PageBreak] {
  let updated : Array[PageBreak] = []
  for brk in breaks {
    if brk.id == id {
      continue
    }
    updated.push(brk)
  }
  updated
}

///|
pub fn Worksheet::set_page_margins(
  self : Worksheet,
  options : PageLayoutMarginsOptions?,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  match options {
    Some(value) => self.page_margins = Some(value)
    None => ()
  }
}

///|
pub fn Worksheet::set_page_layout(
  self : Worksheet,
  options : PageLayoutOptions?,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  match options {
    Some(value) => self.page_layout = Some(normalize_page_layout_options(value))
    None => ()
  }
}

///|
pub fn Worksheet::set_header_footer(
  self : Worksheet,
  options : HeaderFooterOptions?,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  match options {
    Some(value) => {
      check_header_footer_limits(value)
      self.header_footer = Some(value)
    }
    None => self.header_footer = None
  }
}

///|
pub fn Worksheet::protect_sheet(
  self : Worksheet,
  options : SheetProtectionOptions,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.sheet_protection = Some(sheet_protection_from_options(options))
}

///|
pub fn Worksheet::unprotect_sheet(
  self : Worksheet,
  password? : String = "",
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  match self.sheet_protection {
    Some(protection) => {
      if password != "" {
        verify_sheet_protection_password(protection, password)
      }
      self.sheet_protection = None
    }
    None => raise XlsxError::InvalidSheetProtection(msg="sheet not protected")
  }
}

///|
pub fn Worksheet::set_sheet_background(
  self : Worksheet,
  data : Bytes,
  extension : String,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if data.length() == 0 {
    raise XlsxError::InvalidSheetBackground(msg="image data empty")
  }
  let ext = normalize_image_extension(extension)
  let content_type = match image_content_type(ext) {
    Some(value) => value
    None =>
      raise XlsxError::InvalidSheetBackground(msg="unsupported image type")
  }
  self.sheet_background = Some({ data, extension: ext, content_type })
}

///|
pub fn Worksheet::clear_sheet_background(
  self : Worksheet,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.sheet_background = None
}

///|
pub fn Worksheet::insert_page_break(
  self : Worksheet,
  cell : StringView,
) -> Unit raise XlsxError {
  let (row, col) = cell_ref_to_rc(cell)
  let row_id = row - 1
  let col_id = col - 1
  if row_id == 0 && col_id == 0 {
    return
  }
  if row_id != 0 {
    let mut found = false
    for brk in self.row_breaks {
      if brk.id == row_id {
        found = true
        break
      }
    }
    if !found {
      self.row_breaks.push({
        id: row_id,
        min: 0,
        max: max_page_break_cols,
        manual: true,
      })
    }
  }
  if col_id != 0 {
    let mut found = false
    for brk in self.col_breaks {
      if brk.id == col_id {
        found = true
        break
      }
    }
    if !found {
      self.col_breaks.push({
        id: col_id,
        min: 0,
        max: max_page_break_rows,
        manual: true,
      })
    }
  }
}

///|
pub fn Worksheet::remove_page_break(
  self : Worksheet,
  cell : StringView,
) -> Unit raise XlsxError {
  let (row, col) = cell_ref_to_rc(cell)
  let row_id = row - 1
  let col_id = col - 1
  if row_id == 0 && col_id == 0 {
    return
  }
  let row_count = self.row_breaks.length()
  let col_count = self.col_breaks.length()
  if row_count > 0 && col_count > 0 && row_count == col_count {
    let updated_rows = remove_break_by_id(self.row_breaks, row_id)
    self.row_breaks.clear()
    self.row_breaks.append(updated_rows[:])
    let updated_cols = remove_break_by_id(self.col_breaks, col_id)
    self.col_breaks.clear()
    self.col_breaks.append(updated_cols[:])
    return
  }
  if row_count > col_count {
    let updated_rows = remove_break_by_id(self.row_breaks, row_id)
    self.row_breaks.clear()
    self.row_breaks.append(updated_rows[:])
    return
  }
  if col_count > row_count {
    let updated_cols = remove_break_by_id(self.col_breaks, col_id)
    self.col_breaks.clear()
    self.col_breaks.append(updated_cols[:])
  }
}
