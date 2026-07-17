///|
/// Cumulative semantic budget for one workbook read. Every decoded XML source
/// is charged before downstream parsers inspect it. Opening elements account
/// for XML-backed items; range-like constructs that expand into additional
/// in-memory entries charge those entries separately.
priv struct ReadBudget {
  limits : ReadLimits
  cancelled : () -> Bool
  mut parser_items : Int
  mut parser_work_units : Int
}

///|
fn ReadBudget::new(
  limits : ReadLimits,
  cancelled? : () -> Bool = () => false,
) -> ReadBudget {
  { limits, cancelled, parser_items: 0, parser_work_units: 0 }
}

///|
fn read_budget_actual(current : Int, amount : Int, limit : Int) -> Int {
  if amount > limit - current {
    limit + 1
  } else {
    current + amount
  }
}

///|
fn ReadBudget::charge_items(
  self : ReadBudget,
  amount : Int,
) -> Unit raise XlsxError {
  if amount <= 0 {
    return
  }
  let actual = read_budget_actual(
    self.parser_items,
    amount,
    self.limits.max_parser_items,
  )
  if actual > self.limits.max_parser_items {
    raise ResourceLimitExceeded(
      kind="parser_items",
      limit=self.limits.max_parser_items,
      actual~,
    )
  }
  self.parser_items = actual
}

///|
fn ReadBudget::charge_work(
  self : ReadBudget,
  amount : Int,
) -> Unit raise XlsxError {
  if amount <= 0 {
    return
  }
  let actual = read_budget_actual(
    self.parser_work_units,
    amount,
    self.limits.max_parser_work_units,
  )
  if actual > self.limits.max_parser_work_units {
    raise ResourceLimitExceeded(
      kind="parser_work_units",
      limit=self.limits.max_parser_work_units,
      actual~,
    )
  }
  self.parser_work_units = actual
}

///|
fn ReadBudget::checkpoint(self : ReadBudget) -> Unit raise XlsxError {
  if (self.cancelled)() {
    raise ReadCancelled
  }
}

///|
fn ReadBudget::tag_end(
  self : ReadBudget,
  xml : StringView,
  start : Int,
) -> Int? raise XlsxError {
  let mut index = start
  let mut next_checkpoint = start
  let mut quote : UInt16? = None
  while index < xml.length() {
    if index >= next_checkpoint {
      self.checkpoint()
      next_checkpoint = index + 4096
    }
    let unit = xml[index]
    match quote {
      Some(delimiter) => if unit == delimiter { quote = None }
      None =>
        if unit == ('"' : UInt16) || unit == ('\'' : UInt16) {
          quote = Some(unit)
        } else if unit == ('>' : UInt16) {
          return Some(index)
        }
    }
    index = index + 1
  }
  None
}

///|
fn xml_name_local_start(xml : StringView, start : Int, end : Int) -> Int {
  let mut local_start = start
  for index in start..<end {
    if xml[index] == (':' : UInt16) {
      local_start = index + 1
    }
  }
  local_start
}

///|
fn xml_name_local_is(
  xml : StringView,
  start : Int,
  end : Int,
  expected : StringView,
) -> Bool {
  let local_start = xml_name_local_start(xml, start, end)
  if end - local_start != expected.length() {
    return false
  }
  for index in 0..<expected.length() {
    if xml[local_start + index] != expected[index] {
      return false
    }
  }
  true
}

///|
fn ReadBudget::charge_col_expansion(
  self : ReadBudget,
  tag : StringView,
) -> Unit raise XlsxError {
  guard attr_value(tag, "min") is Some(min_text) &&
    attr_value(tag, "max") is Some(max_text) else {
    return
  }
  let min_col = @string.parse_int(min_text, base=10) catch { _ => return }
  let max_col = @string.parse_int(max_text, base=10) catch { _ => return }
  if min_col <= 0 ||
    max_col < min_col ||
    min_col > cell_ref_max_cols ||
    max_col > cell_ref_max_cols {
    return
  }
  let span = max_col - min_col + 1
  self.charge_items(span)
  self.charge_work(span)
}

///|
/// Preflights one decoded XML source in a single quote-aware pass. This runs
/// before any feature parser materializes arrays or maps from the source.
fn ReadBudget::scan_xml(
  self : ReadBudget,
  xml : StringView,
) -> Unit raise XlsxError {
  self.checkpoint()
  self.charge_work(xml.length())
  let mut index = 0
  let mut next_checkpoint = 0
  while index < xml.length() {
    if index >= next_checkpoint {
      self.checkpoint()
      next_checkpoint = index + 4096
    }
    if xml[index] != ('<' : UInt16) || index + 1 >= xml.length() {
      index = index + 1
      continue
    }
    let first = xml[index + 1]
    if first == ('/' : UInt16) ||
      first == ('?' : UInt16) ||
      first == ('!' : UInt16) {
      index = index + 2
      continue
    }
    let name_start = index + 1
    let mut name_end = name_start
    while name_end < xml.length() &&
          !is_xml_attr_space_unit(xml[name_end]) &&
          xml[name_end] != ('/' : UInt16) &&
          xml[name_end] != ('>' : UInt16) {
      name_end = name_end + 1
    }
    if name_end == name_start {
      index = index + 1
      continue
    }
    self.charge_items(1)
    let tag_end = match self.tag_end(xml, name_end) {
      Some(value) => value
      None => return
    }
    if xml_name_local_is(xml, name_start, name_end, "col") {
      self.charge_col_expansion(xml[name_end:tag_end])
    }
    index = tag_end + 1
  }
}

///|
test "read budget counts source, elements, and derived column expansion" {
  let limits = ReadLimits::with_values(
    max_parser_items=5,
    max_parser_work_units=1024,
  )
  let budget = ReadBudget::new(limits)
  budget.scan_xml("<worksheet><cols><col min='1' max='2'/></cols></worksheet>")
  assert_eq(budget.parser_items, 5)
}

///|
test "read budget checks cancellation inside a long start tag" {
  let checks = [0]
  let budget = ReadBudget::new(ReadLimits::new(), cancelled=() => {
    checks[0] += 1
    checks[0] >= 3
  })
  let xml = "<item value='" + "x".repeat(12 * 1024) + "'/>"
  try budget.scan_xml(xml) catch {
    ReadCancelled => assert_true(checks[0] >= 3)
    _ => fail("expected read cancellation")
  } noraise {
    _ => fail("expected read cancellation")
  }
}
