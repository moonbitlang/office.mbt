///|
fn build_lang_fmt_workbook(num_fmt : Int) -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  // 45476 is the serial for 2024-07-03
  sheet.set_cell_value("A1", Numeric(45476))
  let style_idx = workbook.new_style(
    @xlsx.Style::builtin_number_format(num_fmt),
  )
  workbook.set_cell_style("Sheet1", "A1", style_idx)
  workbook
}

///|
test "culture_info zh-CN renders language builtin date formats" {
  let workbook = build_lang_fmt_workbook(31)
  let zh_cn = @xlsx.Options::with_values(culture_info="zh-CN")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=zh_cn),
    content=(
      #|Some("2024年7月3日")
    ),
  )
  let month_only = build_lang_fmt_workbook(27)
  debug_inspect(
    month_only.get_cell_value("Sheet1", "A1", options=zh_cn),
    content=(
      #|Some("2024年7月")
    ),
  )
}

///|
test "culture_info ko-KR renders language builtin date formats" {
  let workbook = build_lang_fmt_workbook(31)
  let ko_kr = @xlsx.Options::with_values(culture_info="ko-KR")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=ko_kr),
    content=(
      #|Some("2024년 07월 03일")
    ),
  )
}

///|
test "culture_info en-US uses short date and long time patterns" {
  let workbook = build_lang_fmt_workbook(30)
  let en_us = @xlsx.Options::with_values(culture_info="en-US")
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=en_us),
    content=(
      #|Some("7/3/24")
    ),
  )
  // long-time range renders the time-of-day portion
  let time_fmt = build_lang_fmt_workbook(33)
  let sheet = match time_fmt.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  sheet.set_cell_value("A1", Numeric(45476.5))
  debug_inspect(
    time_fmt.get_cell_value("Sheet1", "A1", options=en_us),
    content=(
      #|Some("12:00:00")
    ),
  )
}

///|
test "culture_info pattern overrides and fallbacks" {
  // option short-date pattern overrides id 30 for CJK cultures
  let workbook = build_lang_fmt_workbook(30)
  let zh_cn_override = @xlsx.Options::with_values(
    culture_info="zh-CN",
    short_date_pattern="yyyy-mm-dd",
  )
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1", options=zh_cn_override),
    content=(
      #|Some("2024-07-03")
    ),
  )
  // unset culture leaves the raw serial untouched
  let plain = build_lang_fmt_workbook(31)
  debug_inspect(
    plain.get_cell_value("Sheet1", "A1"),
    content=(
      #|Some("45476")
    ),
  )
  // zh-TW era formats carry a [$-404] locale token the format engine
  // does not support; the value passes through unformatted
  let era = build_lang_fmt_workbook(27)
  let zh_tw = @xlsx.Options::with_values(culture_info="zh-TW")
  debug_inspect(
    era.get_cell_value("Sheet1", "A1", options=zh_tw),
    content=(
      #|Some("45476")
    ),
  )
  // IDs outside a culture's table fall back to the raw value
  let thai_range = build_lang_fmt_workbook(67)
  debug_inspect(
    thai_range.get_cell_value("Sheet1", "A1", options=zh_cn_override),
    content=(
      #|Some("45476")
    ),
  )
}
