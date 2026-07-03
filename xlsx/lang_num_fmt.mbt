///|
/// Language-glyph builtin number formats, mirroring Excelize's
/// `langNumFmt` tables and `langNumFmtFunc` dispatch (numfmt.go). The
/// builtin IDs 27-36, 50-62, and 67-81 have no universal format code:
/// their meaning depends on the workbook's culture, selected through
/// `Options::culture_info` ("en-US", "ja-JP", "ko-KR", "zh-CN", "zh-TW",
/// case-insensitive). An unknown or unset culture leaves the raw value
/// untouched, like Go's `getBuiltInNumFmtCode` ok=false path.

///|
fn normalize_culture_info(value : String) -> String {
  value.to_lower().replace_all(old="_", new="-").trim().to_string()
}

///|
fn lang_num_fmt_zh_tw(id : Int) -> String {
  match id {
    27 | 36 | 50 | 57 => "[$-404]e/m/d"
    28 | 29 | 51 | 54 | 58 => "[$-404]e\"年\"m\"月\"d\"日\""
    30 => "m/d/yy"
    31 => "yyyy\"年\"m\"月\"d\"日\""
    32 => "hh\"時\"mm\"分\""
    33 => "hh\"時\"mm\"分\"ss\"秒\""
    34 | 52 | 55 => "上午/下午hh\"時\"mm\"分\""
    35 | 53 | 56 => "上午/下午hh\"時\"mm\"分\"ss\"秒\""
    _ => ""
  }
}

///|
fn lang_num_fmt_zh_cn(id : Int) -> String {
  match id {
    27 | 36 | 50 | 52 | 57 => "yyyy\"年\"m\"月\""
    28 | 29 | 51 | 53 | 54 | 58 => "m\"月\"d\"日\""
    30 => "m/d/yy"
    31 => "yyyy\"年\"m\"月\"d\"日\""
    32 => "h\"时\"mm\"分\""
    33 => "h\"时\"mm\"分\"ss\"秒\""
    34 | 55 => "上午/下午h\"时\"mm\"分\""
    35 | 56 => "上午/下午h\"时\"mm\"分\"ss\"秒\""
    _ => ""
  }
}

///|
fn lang_num_fmt_ja_jp(id : Int) -> String {
  match id {
    27 | 36 | 50 | 57 => "[$-411]ge.m.d"
    28 | 29 | 51 | 54 | 58 => "[$-411]ggge\"年\"m\"月\"d\"日\""
    30 => "m/d/yy"
    31 => "yyyy\"年\"m\"月\"d\"日\""
    32 => "h\"時\"mm\"分\""
    33 => "h\"時\"mm\"分\"ss\"秒\""
    34 | 52 | 55 => "yyyy\"年\"m\"月\""
    35 | 53 | 56 => "m\"月\"d\"日\""
    _ => ""
  }
}

///|
fn lang_num_fmt_ko_kr(id : Int) -> String {
  match id {
    27 | 36 | 50 | 57 => "yyyy\"年\" mm\"月\" dd\"日\""
    28 | 29 | 51 | 54 | 58 => "mm-dd"
    30 => "mm-dd-yy"
    31 => "yyyy\"년\" mm\"월\" dd\"일\""
    32 => "h\"시\" mm\"분\""
    33 => "h\"시\" mm\"분\" ss\"초\""
    34 | 35 | 52 | 53 | 55 | 56 => "yyyy-mm-dd"
    _ => ""
  }
}

///|
/// Resolves the format code for a language builtin number format ID under
/// the given options, mirroring Excelize's per-culture `langNumFmtFunc`
/// implementations: en-US renders short-date/long-time patterns, the CJK
/// cultures use their glyph tables, and IDs 30 / 32-33 honor the
/// `short_date_pattern` / `long_time_pattern` option overrides. Returns
/// `None` for an unknown or unset culture.
fn lang_num_fmt_code(options : Options, id : Int) -> String? {
  match normalize_culture_info(options.culture_info) {
    "en-us" => {
      let short_date = if options.short_date_pattern != "" {
        options.short_date_pattern
      } else {
        "M/d/yy"
      }
      let long_time = if options.long_time_pattern != "" {
        options.long_time_pattern
      } else {
        "h:mm:ss"
      }
      match id {
        32..=35 => Some(long_time)
        27..=31 | 50..=58 => Some(short_date)
        _ => Some("")
      }
    }
    "ja-jp" | "ko-kr" | "zh-cn" | "zh-tw" as culture => {
      if id == 30 && options.short_date_pattern != "" {
        return Some(options.short_date_pattern)
      }
      if (id == 32 || id == 33) && options.long_time_pattern != "" {
        return Some(options.long_time_pattern)
      }
      match culture {
        "ja-jp" => Some(lang_num_fmt_ja_jp(id))
        "ko-kr" => Some(lang_num_fmt_ko_kr(id))
        "zh-cn" => Some(lang_num_fmt_zh_cn(id))
        _ => Some(lang_num_fmt_zh_tw(id))
      }
    }
    _ => None
  }
}
