///|
pub(all) struct ConditionalFormatOptions {
  mut format_type : String
  mut above_average : Bool
  mut percent : Bool
  mut format : Int?
  mut criteria : String
  mut value : String
  mut min_type : String
  mut mid_type : String
  mut max_type : String
  mut min_value : String
  mut mid_value : String
  mut max_value : String
  mut min_color : String
  mut mid_color : String
  mut max_color : String
  mut bar_color : String
  mut bar_border_color : String
  mut bar_direction : String
  mut bar_only : Bool
  mut bar_solid : Bool
  mut icon_style : String
  mut reverse_icons : Bool
  mut icons_only : Bool
  mut stop_if_true : Bool
} derive(Eq, Show)

///|
pub fn ConditionalFormatOptions::new(
  format_type : String,
) -> ConditionalFormatOptions {
  {
    format_type,
    above_average: false,
    percent: false,
    format: None,
    criteria: "",
    value: "",
    min_type: "",
    mid_type: "",
    max_type: "",
    min_value: "",
    mid_value: "",
    max_value: "",
    min_color: "",
    mid_color: "",
    max_color: "",
    bar_color: "",
    bar_border_color: "",
    bar_direction: "",
    bar_only: false,
    bar_solid: false,
    icon_style: "",
    reverse_icons: false,
    icons_only: false,
    stop_if_true: false,
  }
}

///|
pub fn ConditionalFormatOptions::set_bar_border_color(
  self : ConditionalFormatOptions,
  value : String,
) -> Unit {
  self.bar_border_color = value
}

///|
pub fn ConditionalFormatOptions::set_bar_direction(
  self : ConditionalFormatOptions,
  value : String,
) -> Unit {
  self.bar_direction = value
}

///|
pub fn ConditionalFormatOptions::set_bar_solid(
  self : ConditionalFormatOptions,
  value : Bool,
) -> Unit {
  self.bar_solid = value
}

///|
fn normalize_conditional_type(value : StringView) -> String? {
  match value.to_string().to_lower() {
    "cell" => Some("cellIs")
    "average" => Some("aboveAverage")
    "duplicate" => Some("duplicateValues")
    "unique" => Some("uniqueValues")
    "top" => Some("top10")
    "bottom" => Some("top10")
    "text" => Some("text")
    "time_period" => Some("timePeriod")
    "blanks" => Some("containsBlanks")
    "no_blanks" => Some("notContainsBlanks")
    "errors" => Some("containsErrors")
    "no_errors" => Some("notContainsErrors")
    "2_color_scale" => Some("2_color_scale")
    "3_color_scale" => Some("3_color_scale")
    "data_bar" => Some("dataBar")
    "formula" => Some("expression")
    "icon_set" => Some("iconSet")
    _ => None
  }
}

///|
fn criteria_type(value : StringView) -> String? {
  match value.to_string().to_lower() {
    "!=" | "<>" => Some("notEqual")
    "<" => Some("lessThan")
    "<=" => Some("lessThanOrEqual")
    "=" | "==" | "equal to" => Some("equal")
    ">" => Some("greaterThan")
    ">=" | "greater than or equal to" => Some("greaterThanOrEqual")
    "begins with" => Some("beginsWith")
    "between" => Some("between")
    "containing" => Some("containsText")
    "continue month" => Some("nextMonth")
    "continue week" => Some("nextWeek")
    "ends with" => Some("endsWith")
    "greater than" => Some("greaterThan")
    "last 7 days" => Some("last7Days")
    "last month" => Some("lastMonth")
    "last week" => Some("lastWeek")
    "less than or equal to" => Some("lessThanOrEqual")
    "less than" => Some("lessThan")
    "not between" => Some("notBetween")
    "not containing" => Some("notContains")
    "not equal to" => Some("notEqual")
    "this month" => Some("thisMonth")
    "this week" => Some("thisWeek")
    "today" => Some("today")
    "tomorrow" => Some("tomorrow")
    "yesterday" => Some("yesterday")
    _ => None
  }
}

///|
fn normalize_criteria(value : StringView) -> String? {
  match criteria_type(value) {
    Some(mapped) => Some(mapped)
    None => {
      let raw = value.to_string()
      match raw {
        "notEqual"
        | "lessThan"
        | "lessThanOrEqual"
        | "equal"
        | "greaterThan"
        | "greaterThanOrEqual"
        | "beginsWith"
        | "between"
        | "containsText"
        | "nextMonth"
        | "nextWeek"
        | "endsWith"
        | "last7Days"
        | "lastMonth"
        | "lastWeek"
        | "notBetween"
        | "notContains"
        | "thisMonth"
        | "thisWeek"
        | "today"
        | "tomorrow"
        | "yesterday" => Some(raw)
        _ => None
      }
    }
  }
}

///|
fn criteria_text_from_operator(value : StringView) -> String {
  match value.to_string() {
    "beginsWith" => "begins with"
    "between" => "between"
    "containsText" => "containing"
    "endsWith" => "ends with"
    "equal" => "equal to"
    "greaterThan" => "greater than"
    "greaterThanOrEqual" => "greater than or equal to"
    "last7Days" => "last 7 days"
    "lastMonth" => "last month"
    "lastWeek" => "last week"
    "lessThan" => "less than"
    "lessThanOrEqual" => "less than or equal to"
    "nextMonth" => "continue month"
    "nextWeek" => "continue week"
    "notBetween" => "not between"
    "notContains" => "not containing"
    "notEqual" => "not equal to"
    "thisMonth" => "this month"
    "thisWeek" => "this week"
    "today" => "today"
    "tomorrow" => "tomorrow"
    "yesterday" => "yesterday"
    _ => value.to_string()
  }
}

///|
fn palette_color(color : StringView) -> String {
  if color == "" {
    return "FF000000"
  }
  let text = color.to_string()
  let trimmed = if text.has_prefix("#") {
    text[1:] catch {
      _ => text
    }
  } else {
    text
  }
  "FF\{trimmed.to_upper()}"
}

///|
fn write_dxf_attr(sb : StringBuilder, opt : ConditionalFormatOptions) -> Unit {
  match opt.format {
    Some(id) => sb.write_view(" dxfId=\"\{id}\"")
    None => ()
  }
}

///|
fn write_stop_if_true(
  sb : StringBuilder,
  opt : ConditionalFormatOptions,
) -> Unit {
  if opt.stop_if_true {
    sb.write_view(" stopIfTrue=\"1\"")
  }
}

///|
fn write_formula(sb : StringBuilder, formula : StringView) -> Unit {
  sb.write_view("<formula>")
  sb.write_view(escape_xml_text(formula))
  sb.write_view("</formula>")
}

///|
fn time_period_formula(criteria : StringView, cell_ref : StringView) -> String? {
  match criteria.to_string() {
    "yesterday" => Some("FLOOR(\{cell_ref.to_string()},1)=TODAY()-1")
    "today" => Some("FLOOR(\{cell_ref.to_string()},1)=TODAY()")
    "tomorrow" => Some("FLOOR(\{cell_ref.to_string()},1)=TODAY()+1")
    "last7Days" =>
      Some(
        "AND(TODAY()-FLOOR(\{cell_ref.to_string()},1)<=6,FLOOR(\{cell_ref.to_string()},1)<=TODAY())",
      )
    "lastWeek" =>
      Some(
        "AND(TODAY()-ROUNDDOWN(\{cell_ref.to_string()},0)>=(WEEKDAY(TODAY())),TODAY()-ROUNDDOWN(\{cell_ref.to_string()},0)<(WEEKDAY(TODAY())+7))",
      )
    "thisWeek" =>
      Some(
        "AND(TODAY()-ROUNDDOWN(\{cell_ref.to_string()},0)<=WEEKDAY(TODAY())-1,ROUNDDOWN(\{cell_ref.to_string()},0)-TODAY()>=7-WEEKDAY(TODAY()))",
      )
    "nextWeek" =>
      Some(
        "AND(ROUNDDOWN(\{cell_ref.to_string()},0)-TODAY()>(7-WEEKDAY(TODAY())),ROUNDDOWN(\{cell_ref.to_string()},0)-TODAY()<(15-WEEKDAY(TODAY())))",
      )
    "lastMonth" =>
      Some(
        "AND(MONTH(\{cell_ref.to_string()})=MONTH(TODAY())-1,OR(YEAR(\{cell_ref.to_string()})=YEAR(TODAY()),AND(MONTH(\{cell_ref.to_string()})=1,YEAR(\{cell_ref.to_string()})=YEAR(TODAY())-1)))",
      )
    "thisMonth" =>
      Some(
        "AND(MONTH(\{cell_ref.to_string()})=MONTH(TODAY()),YEAR(\{cell_ref.to_string()})=YEAR(TODAY()))",
      )
    "nextMonth" =>
      Some(
        "AND(MONTH(\{cell_ref.to_string()})=MONTH(TODAY())+1,OR(YEAR(\{cell_ref.to_string()})=YEAR(TODAY()),AND(MONTH(\{cell_ref.to_string()})=12,YEAR(\{cell_ref.to_string()})=YEAR(TODAY())+1)))",
      )
    _ => None
  }
}

///|
fn text_formula(
  criteria : StringView,
  cell_ref : StringView,
  value : StringView,
) -> String? {
  let escaped = value.to_string().replace_all(old="\"", new="\"\"")
  match criteria.to_string() {
    "containsText" =>
      Some("NOT(ISERROR(SEARCH(\"\{escaped}\",\{cell_ref.to_string()})))")
    "notContains" =>
      Some("ISERROR(SEARCH(\"\{escaped}\",\{cell_ref.to_string()}))")
    "beginsWith" =>
      Some("LEFT(\{cell_ref.to_string()},LEN(\"\{escaped}\"))=\"\{escaped}\"")
    "endsWith" =>
      Some("RIGHT(\{cell_ref.to_string()},LEN(\"\{escaped}\"))=\"\{escaped}\"")
    _ => None
  }
}

///|
fn icon_set_steps(icon_style : StringView) -> Array[String]? {
  match icon_style.to_string() {
    "3Arrows"
    | "3ArrowsGray"
    | "3Flags"
    | "3Signs"
    | "3Stars"
    | "3Symbols"
    | "3Symbols2"
    | "3TrafficLights1"
    | "3TrafficLights2"
    | "3Triangles" => Some(["0", "33", "67"])
    "4Arrows" | "4ArrowsGray" | "4Rating" | "4RedToBlack" | "4TrafficLights" =>
      Some(["0", "25", "50", "75"])
    "5Arrows" | "5ArrowsGray" | "5Boxes" | "5Quarters" | "5Rating" =>
      Some(["0", "20", "40", "60", "80"])
    _ => None
  }
}

///|
fn prepare_conditional_format_range(
  range_ref : StringView,
) -> (String, String) raise XlsxError {
  let cleaned = range_ref.to_string().replace_all(old=",", new=" ")
  if cleaned.trim() == "" {
    raise XlsxError::InvalidConditionalFormat(msg="range is empty")
  }
  let sqrefs : Array[String] = []
  let mut master_cell = ""
  for part in cleaned.split(" ") {
    let trimmed = part.to_string().trim().to_string()
    if trimmed == "" {
      continue
    }
    let parts : Array[String] = []
    for item in trimmed.split(":") {
      parts.push(item.to_string())
    }
    if parts.length() > 2 || parts.length() == 0 {
      raise XlsxError::InvalidConditionalFormat(msg="range reference invalid")
    }
    let (start_ref, end_ref) = if parts.length() == 1 {
      parse_range_ref_token(parts[0])
    } else {
      let (start_ref, _start_end) = parse_range_ref_token(parts[0])
      let (_end_start, end_ref) = parse_range_ref_token(parts[1])
      (start_ref, end_ref)
    }
    let (row1, col1) = cell_ref_to_rc(start_ref)
    let (row2, col2) = cell_ref_to_rc(end_ref)
    let min_row = if row1 < row2 { row1 } else { row2 }
    let max_row = if row1 > row2 { row1 } else { row2 }
    let min_col = if col1 < col2 { col1 } else { col2 }
    let max_col = if col1 > col2 { col1 } else { col2 }
    let start_cell = cell_ref_from(min_row, min_col)
    let end_cell = cell_ref_from(max_row, max_col)
    let normalized = if start_cell == end_cell {
      start_cell
    } else {
      "\{start_cell}:\{end_cell}"
    }
    if master_cell == "" {
      master_cell = start_cell
    }
    sqrefs.push(normalized)
  }
  if sqrefs.length() == 0 {
    raise XlsxError::InvalidConditionalFormat(msg="range reference invalid")
  }
  (sqrefs.join(" "), master_cell)
}

///|
fn build_cell_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
  operator : StringView,
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"cellIs\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  write_dxf_attr(sb, opt)
  if operator != "" {
    sb.write_view(" operator=\"\{escape_xml_attr(operator)}\"")
  }
  sb.write_view(">")
  if operator == "between" || operator == "notBetween" {
    if opt.min_value == "" || opt.max_value == "" {
      raise XlsxError::InvalidConditionalFormat(
        msg="between criteria requires min/max",
      )
    }
    write_formula(sb, opt.min_value)
    write_formula(sb, opt.max_value)
  } else {
    if opt.value == "" {
      raise XlsxError::InvalidConditionalFormat(
        msg="cell criteria requires value",
      )
    }
    write_formula(sb, opt.value)
  }
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn build_time_period_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
  criteria : StringView,
  master_cell : StringView,
) -> String raise XlsxError {
  let formula = match time_period_formula(criteria, master_cell) {
    Some(value) => value
    None => raise XlsxError::InvalidConditionalFormat(msg="time period invalid")
  }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"timePeriod\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  write_dxf_attr(sb, opt)
  sb.write_view(">")
  write_formula(sb, formula)
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn build_text_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
  criteria : StringView,
  master_cell : StringView,
) -> String raise XlsxError {
  let rule_type = match criteria.to_string() {
    "containsText" => "containsText"
    "notContains" => "notContainsText"
    "beginsWith" => "beginsWith"
    "endsWith" => "endsWith"
    _ => raise XlsxError::InvalidConditionalFormat(msg="text criteria invalid")
  }
  if opt.value == "" {
    raise XlsxError::InvalidConditionalFormat(msg="text value required")
  }
  let formula = match text_formula(criteria, master_cell, opt.value) {
    Some(value) => value
    None =>
      raise XlsxError::InvalidConditionalFormat(msg="text formula invalid")
  }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"\{rule_type}\"")
  sb.write_view(" priority=\"\{priority}\"")
  sb.write_view(" operator=\"\{escape_xml_attr(criteria)}\"")
  sb.write_view(" text=\"\{escape_xml_attr(opt.value)}\"")
  write_stop_if_true(sb, opt)
  write_dxf_attr(sb, opt)
  sb.write_view(">")
  write_formula(sb, formula)
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn build_top10_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
  bottom : Bool,
) -> String raise XlsxError {
  let mut rank = 10
  if opt.value != "" {
    rank = @strconv.parse_int(opt.value, base=10) catch { _ => rank }
  }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"top10\"")
  sb.write_view(" priority=\"\{priority}\"")
  if bottom {
    sb.write_view(" bottom=\"1\"")
  }
  if opt.percent {
    sb.write_view(" percent=\"1\"")
  }
  sb.write_view(" rank=\"\{rank}\"")
  write_stop_if_true(sb, opt)
  write_dxf_attr(sb, opt)
  sb.write_view("/>")
  sb.to_string()
}

///|
fn build_above_average_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
) -> String {
  let above = if opt.above_average { "1" } else { "0" }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"aboveAverage\"")
  sb.write_view(" priority=\"\{priority}\"")
  sb.write_view(" aboveAverage=\"\{above}\"")
  write_stop_if_true(sb, opt)
  write_dxf_attr(sb, opt)
  sb.write_view("/>")
  sb.to_string()
}

///|
fn build_simple_rule(
  rule_type : StringView,
  opt : ConditionalFormatOptions,
  priority : Int,
  formula? : String,
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"\{rule_type.to_string()}\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  write_dxf_attr(sb, opt)
  match formula {
    Some(value) => {
      sb.write_view(">")
      write_formula(sb, value)
      sb.write_view("</cfRule>")
    }
    None => sb.write_view("/>")
  }
  sb.to_string()
}

///|
fn build_color_scale_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
  mid : Bool,
) -> String {
  let min_type = if opt.min_type == "" { "min" } else { opt.min_type }
  let max_type = if opt.max_type == "" { "max" } else { opt.max_type }
  let mid_type = if opt.mid_type == "" { "percentile" } else { opt.mid_type }
  let min_value = if opt.min_value == "" { "0" } else { opt.min_value }
  let max_value = if opt.max_value == "" { "0" } else { opt.max_value }
  let mid_value = if opt.mid_value == "" { "50" } else { opt.mid_value }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"colorScale\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  sb.write_view(">")
  sb.write_view("<colorScale>")
  sb.write_view(
    "<cfvo type=\"\{escape_xml_attr(min_type)}\" val=\"\{escape_xml_attr(min_value)}\"/>",
  )
  sb.write_view("<color rgb=\"\{palette_color(opt.min_color)}\"/>")
  if mid {
    sb.write_view(
      "<cfvo type=\"\{escape_xml_attr(mid_type)}\" val=\"\{escape_xml_attr(mid_value)}\"/>",
    )
    sb.write_view("<color rgb=\"\{palette_color(opt.mid_color)}\"/>")
  }
  sb.write_view(
    "<cfvo type=\"\{escape_xml_attr(max_type)}\" val=\"\{escape_xml_attr(max_value)}\"/>",
  )
  sb.write_view("<color rgb=\"\{palette_color(opt.max_color)}\"/>")
  sb.write_view("</colorScale>")
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn build_data_bar_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
) -> String {
  let min_type = if opt.min_type == "" { "min" } else { opt.min_type }
  let max_type = if opt.max_type == "" { "max" } else { opt.max_type }
  let min_value = if opt.min_value == "" { "0" } else { opt.min_value }
  let max_value = if opt.max_value == "" { "0" } else { opt.max_value }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"dataBar\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  sb.write_view(">")
  let show_value = if opt.bar_only { "0" } else { "1" }
  sb.write_view("<dataBar showValue=\"\{show_value}\">")
  sb.write_view(
    "<cfvo type=\"\{escape_xml_attr(min_type)}\" val=\"\{escape_xml_attr(min_value)}\"/>",
  )
  sb.write_view(
    "<cfvo type=\"\{escape_xml_attr(max_type)}\" val=\"\{escape_xml_attr(max_value)}\"/>",
  )
  let bar_color = if opt.bar_color == "" {
    "FF638EC6"
  } else {
    palette_color(opt.bar_color)
  }
  sb.write_view("<color rgb=\"\{bar_color}\"/>")
  sb.write_view("</dataBar>")
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn build_icon_set_rule(
  opt : ConditionalFormatOptions,
  priority : Int,
) -> String raise XlsxError {
  let steps = match icon_set_steps(opt.icon_style) {
    Some(value) => value
    None =>
      raise XlsxError::InvalidConditionalFormat(msg="icon set style invalid")
  }
  let sb = StringBuilder::new()
  sb.write_view("<cfRule type=\"iconSet\"")
  sb.write_view(" priority=\"\{priority}\"")
  write_stop_if_true(sb, opt)
  sb.write_view(">")
  let show_value = if opt.icons_only { "0" } else { "1" }
  sb.write_view(
    "<iconSet iconSet=\"\{escape_xml_attr(opt.icon_style)}\" showValue=\"\{show_value}\"",
  )
  if opt.reverse_icons {
    sb.write_view(" reverse=\"1\"")
  }
  if opt.percent {
    sb.write_view(" percent=\"1\"")
  }
  sb.write_view(">")
  for step in steps {
    sb.write_view("<cfvo type=\"percent\" val=\"\{step}\"/>")
  }
  sb.write_view("</iconSet>")
  sb.write_view("</cfRule>")
  sb.to_string()
}

///|
fn conditional_format_rules_xml(
  opts : ArrayView[ConditionalFormatOptions],
  priority_start : Int,
  master_cell : StringView,
) -> Array[String] raise XlsxError {
  let rules : Array[String] = []
  for i, opt in opts {
    let rule_type = match normalize_conditional_type(opt.format_type) {
      Some(value) => value
      None => raise XlsxError::InvalidConditionalFormat(msg="type invalid")
    }
    let priority = priority_start + i + 1
    let rule = match opt.format_type.to_string().to_lower() {
      "cell" => {
        let op = match normalize_criteria(opt.criteria) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidConditionalFormat(msg="criteria invalid")
        }
        build_cell_rule(opt, priority, op)
      }
      "time_period" => {
        let op = match normalize_criteria(opt.criteria) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidConditionalFormat(msg="criteria invalid")
        }
        build_time_period_rule(opt, priority, op, master_cell)
      }
      "text" => {
        let op = match normalize_criteria(opt.criteria) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidConditionalFormat(msg="criteria invalid")
        }
        build_text_rule(opt, priority, op, master_cell)
      }
      "average" => build_above_average_rule(opt, priority)
      "duplicate" => build_simple_rule(rule_type, opt, priority)
      "unique" => build_simple_rule(rule_type, opt, priority)
      "top" => build_top10_rule(opt, priority, false)
      "bottom" => build_top10_rule(opt, priority, true)
      "blanks" =>
        build_simple_rule(
          rule_type,
          opt,
          priority,
          formula="LEN(TRIM(\{master_cell.to_string()}))=0",
        )
      "no_blanks" =>
        build_simple_rule(
          rule_type,
          opt,
          priority,
          formula="LEN(TRIM(\{master_cell.to_string()}))>0",
        )
      "errors" =>
        build_simple_rule(
          rule_type,
          opt,
          priority,
          formula="ISERROR(\{master_cell.to_string()})",
        )
      "no_errors" =>
        build_simple_rule(
          rule_type,
          opt,
          priority,
          formula="NOT(ISERROR(\{master_cell.to_string()}))",
        )
      "2_color_scale" => build_color_scale_rule(opt, priority, false)
      "3_color_scale" => build_color_scale_rule(opt, priority, true)
      "data_bar" => build_data_bar_rule(opt, priority)
      "formula" => {
        if opt.criteria == "" {
          raise XlsxError::InvalidConditionalFormat(
            msg="formula criteria missing",
          )
        }
        build_simple_rule(rule_type, opt, priority, formula=opt.criteria)
      }
      "icon_set" => build_icon_set_rule(opt, priority)
      _ => raise XlsxError::InvalidConditionalFormat(msg="type invalid")
    }
    rules.push(rule)
  }
  rules
}

///|
fn conditional_format_xml(
  sqref : StringView,
  rules : ArrayView[String],
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<conditionalFormatting sqref=\"")
  sb.write_view(escape_xml_attr(sqref))
  sb.write_view("\">")
  for rule in rules {
    sb.write_view(rule)
  }
  sb.write_view("</conditionalFormatting>")
  sb.to_string()
}

///|
fn extract_tag_blocks(
  xml : StringView,
  tag_name : StringView,
) -> Array[String] raise XlsxError {
  let text = xml.to_string()
  let open_tag = "<\{tag_name.to_string()}"
  let close_tag = "</\{tag_name.to_string()}>"
  let parts = Array::from_iter(text.split(open_tag))
  if parts.length() <= 1 {
    return []
  }
  let blocks : Array[String] = []
  for i in 1..<parts.length() {
    let fragment = "\{open_tag}\{parts[i].to_string()}"
    let end_pos = match fragment.find(close_tag) {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="tag close missing")
    }
    let end = end_pos + close_tag.length()
    let slice = fragment[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="tag slice invalid")
      }
    blocks.push(slice.to_string())
  }
  blocks
}

///|
fn extract_tag_bodies(
  xml : StringView,
  tag_name : StringView,
) -> Array[String] raise XlsxError {
  let blocks = extract_tag_blocks(xml, tag_name)
  let close_tag = "</\{tag_name.to_string()}>"
  let bodies : Array[String] = []
  for block in blocks {
    let start = match block.find(">") {
      Some(pos) => pos + 1
      None => raise XlsxError::InvalidXml(msg="tag body start missing")
    }
    let end = match block.find(close_tag) {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="tag body end missing")
    }
    let body = block[start:end] catch {
        _ => raise XlsxError::InvalidXml(msg="tag body invalid")
      }
    bodies.push(body.to_string())
  }
  bodies
}

///|
fn color_text_from_rgb(rgb : StringView) -> String {
  let text = rgb.to_string()
  if text.has_prefix("FF") && text.length() == 8 {
    let rest = text[2:] catch { _ => text }
    "#\{rest}"
  } else {
    "#\{text}"
  }
}

///|
fn parse_cf_rule(
  xml : StringView,
  master_cell : StringView,
) -> ConditionalFormatOptions raise XlsxError {
  let tag = match tag_attributes_in(xml, "cfRule") {
    Some(value) => value
    None => raise XlsxError::InvalidXml(msg="cfRule tag missing")
  }
  let rule_type = match attr_value(tag, "type") {
    Some(value) => value.to_string()
    None => raise XlsxError::InvalidXml(msg="cfRule type missing")
  }
  let opt = ConditionalFormatOptions::new("")
  opt.stop_if_true = match attr_value(tag, "stopIfTrue") {
    Some(value) => parse_xml_bool(value)
    None => false
  }
  match attr_value(tag, "dxfId") {
    Some(value) =>
      match (try? @strconv.parse_int(value, base=10)) {
        Ok(id) => opt.format = Some(id)
        Err(_) => ()
      }
    None => ()
  }
  let formulas = extract_tag_bodies(xml, "formula").map(value => unescape_xml_text(
    value,
  ))
  match rule_type {
    "cellIs" => {
      opt.format_type = "cell"
      let op = match attr_value(tag, "operator") {
        Some(value) => value
        None => ""
      }
      opt.criteria = criteria_text_from_operator(op)
      if formulas.length() == 2 {
        opt.min_value = formulas[0]
        opt.max_value = formulas[1]
      } else if formulas.length() == 1 {
        opt.value = formulas[0]
      }
    }
    "timePeriod" => {
      opt.format_type = "time_period"
      let mut criteria = ""
      if formulas.length() > 0 {
        let formula = formulas[0]
        for
          key, value in {
            "yesterday": time_period_formula("yesterday", master_cell),
            "today": time_period_formula("today", master_cell),
            "tomorrow": time_period_formula("tomorrow", master_cell),
            "last 7 days": time_period_formula("last7Days", master_cell),
            "last week": time_period_formula("lastWeek", master_cell),
            "this week": time_period_formula("thisWeek", master_cell),
            "continue week": time_period_formula("nextWeek", master_cell),
            "last month": time_period_formula("lastMonth", master_cell),
            "this month": time_period_formula("thisMonth", master_cell),
            "continue month": time_period_formula("nextMonth", master_cell),
          } {
          match value {
            Some(val) => if val == formula { criteria = key }
            None => ()
          }
        }
      }
      opt.criteria = criteria
    }
    "containsText" | "notContainsText" | "beginsWith" | "endsWith" => {
      opt.format_type = "text"
      let op = match attr_value(tag, "operator") {
        Some(value) => value
        None => ""
      }
      opt.criteria = criteria_text_from_operator(op)
      match attr_value(tag, "text") {
        Some(value) => opt.value = unescape_xml_text(value)
        None => ()
      }
    }
    "aboveAverage" => {
      opt.format_type = "average"
      opt.criteria = "="
      match attr_value(tag, "aboveAverage") {
        Some(value) => opt.above_average = parse_xml_bool(value)
        None => ()
      }
    }
    "duplicateValues" => opt.format_type = "duplicate"
    "uniqueValues" => opt.format_type = "unique"
    "top10" => {
      let bottom = match attr_value(tag, "bottom") {
        Some(value) => parse_xml_bool(value)
        None => false
      }
      opt.format_type = if bottom { "bottom" } else { "top" }
      opt.criteria = "="
      opt.percent = match attr_value(tag, "percent") {
        Some(value) => parse_xml_bool(value)
        None => false
      }
      match attr_value(tag, "rank") {
        Some(value) => opt.value = value.to_string()
        None => opt.value = "10"
      }
    }
    "containsBlanks" => opt.format_type = "blanks"
    "notContainsBlanks" => opt.format_type = "no_blanks"
    "containsErrors" => opt.format_type = "errors"
    "notContainsErrors" => opt.format_type = "no_errors"
    "colorScale" => {
      let scale_blocks = extract_tag_blocks(xml, "colorScale")
      if scale_blocks.length() == 0 {
        raise XlsxError::InvalidXml(msg="colorScale missing")
      }
      let scale = scale_blocks[0]
      let cfvos = extract_tag_blocks(scale, "cfvo")
      let colors = extract_tag_blocks(scale, "color")
      let types : Array[String] = []
      let values : Array[String] = []
      for cfvo in cfvos {
        let tag = match tag_attributes_in(cfvo, "cfvo") {
          Some(value) => value
          None => continue
        }
        types.push(
          match attr_value(tag, "type") {
            Some(value) => value.to_string()
            None => ""
          },
        )
        values.push(
          match attr_value(tag, "val") {
            Some(value) => value.to_string()
            None => ""
          },
        )
      }
      let rgb_values : Array[String] = []
      for color in colors {
        let tag = match tag_attributes_in(color, "color") {
          Some(value) => value
          None => continue
        }
        match attr_value(tag, "rgb") {
          Some(value) => rgb_values.push(color_text_from_rgb(value))
          None => ()
        }
      }
      if types.length() == 2 {
        opt.format_type = "2_color_scale"
        opt.min_type = types[0]
        opt.max_type = types[1]
        if values.length() >= 2 {
          opt.min_value = values[0]
          opt.max_value = values[1]
        }
        if rgb_values.length() >= 2 {
          opt.min_color = rgb_values[0]
          opt.max_color = rgb_values[1]
        }
      } else {
        opt.format_type = "3_color_scale"
        if types.length() >= 3 {
          opt.min_type = types[0]
          opt.mid_type = types[1]
          opt.max_type = types[2]
        }
        if values.length() >= 3 {
          opt.min_value = values[0]
          opt.mid_value = values[1]
          opt.max_value = values[2]
        }
        if rgb_values.length() >= 3 {
          opt.min_color = rgb_values[0]
          opt.mid_color = rgb_values[1]
          opt.max_color = rgb_values[2]
        }
      }
    }
    "dataBar" => {
      opt.format_type = "data_bar"
      let data_blocks = extract_tag_blocks(xml, "dataBar")
      if data_blocks.length() == 0 {
        raise XlsxError::InvalidXml(msg="dataBar missing")
      }
      let data = data_blocks[0]
      let tag = match tag_attributes_in(data, "dataBar") {
        Some(value) => value
        None => ""
      }
      let show_value = match attr_value(tag, "showValue") {
        Some(value) => parse_xml_bool(value)
        None => true
      }
      opt.bar_only = !show_value
      let cfvos = extract_tag_blocks(data, "cfvo")
      if cfvos.length() >= 2 {
        let tag0 = match tag_attributes_in(cfvos[0], "cfvo") {
          Some(value) => value
          None => ""
        }
        let tag1 = match tag_attributes_in(cfvos[1], "cfvo") {
          Some(value) => value
          None => ""
        }
        opt.min_type = match attr_value(tag0, "type") {
          Some(value) => value.to_string()
          None => ""
        }
        opt.min_value = match attr_value(tag0, "val") {
          Some(value) => value.to_string()
          None => ""
        }
        opt.max_type = match attr_value(tag1, "type") {
          Some(value) => value.to_string()
          None => ""
        }
        opt.max_value = match attr_value(tag1, "val") {
          Some(value) => value.to_string()
          None => ""
        }
      }
      let colors = extract_tag_blocks(data, "color")
      if colors.length() > 0 {
        let tag = match tag_attributes_in(colors[0], "color") {
          Some(value) => value
          None => ""
        }
        match attr_value(tag, "rgb") {
          Some(value) => opt.bar_color = color_text_from_rgb(value)
          None => ()
        }
      }
    }
    "expression" => {
      opt.format_type = "formula"
      if formulas.length() > 0 {
        opt.criteria = formulas[0]
      }
    }
    "iconSet" => {
      opt.format_type = "icon_set"
      let icon_blocks = extract_tag_blocks(xml, "iconSet")
      if icon_blocks.length() == 0 {
        raise XlsxError::InvalidXml(msg="iconSet missing")
      }
      let icon = icon_blocks[0]
      let tag = match tag_attributes_in(icon, "iconSet") {
        Some(value) => value
        None => ""
      }
      match attr_value(tag, "iconSet") {
        Some(value) => opt.icon_style = value.to_string()
        None => ()
      }
      match attr_value(tag, "reverse") {
        Some(value) => opt.reverse_icons = parse_xml_bool(value)
        None => ()
      }
      let show_value = match attr_value(tag, "showValue") {
        Some(value) => parse_xml_bool(value)
        None => true
      }
      opt.icons_only = !show_value
      match attr_value(tag, "percent") {
        Some(value) => opt.percent = parse_xml_bool(value)
        None => ()
      }
    }
    _ => raise XlsxError::InvalidXml(msg="conditional format type unsupported")
  }
  opt
}

///|
fn master_cell_from_sqref(sqref : StringView) -> String raise XlsxError {
  let text = sqref.to_string().trim().to_string()
  if text == "" {
    raise XlsxError::InvalidXml(msg="sqref empty")
  }
  let mut first = ""
  for part in text.split(" ") {
    let trimmed = part.to_string().trim().to_string()
    if trimmed != "" {
      first = trimmed
      break
    }
  }
  if first == "" {
    raise XlsxError::InvalidXml(msg="sqref invalid")
  }
  let parts : Array[String] = []
  for item in first.split(":") {
    parts.push(item.to_string())
  }
  if parts.length() == 0 {
    raise XlsxError::InvalidXml(msg="sqref invalid")
  }
  let (start_ref, _end_ref) = parse_range_ref_token(parts[0])
  start_ref
}

///|
fn parse_conditional_format_xml(
  xml : StringView,
) -> (String, Array[ConditionalFormatOptions]) raise XlsxError {
  let tag = match tag_attributes_in(xml, "conditionalFormatting") {
    Some(value) => value
    None => raise XlsxError::InvalidXml(msg="conditionalFormatting missing")
  }
  let sqref = match attr_value(tag, "sqref") {
    Some(value) => unescape_xml_text(value)
    None =>
      raise XlsxError::InvalidXml(msg="conditionalFormatting sqref missing")
  }
  let master_cell = master_cell_from_sqref(sqref)
  let rules = extract_tag_blocks(xml, "cfRule")
  let opts : Array[ConditionalFormatOptions] = []
  for rule in rules {
    opts.push(parse_cf_rule(rule, master_cell))
  }
  (sqref, opts)
}
