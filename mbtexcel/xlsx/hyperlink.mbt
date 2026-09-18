///|
pub(all) enum HyperlinkType {
  External
  Location
  Unset
} derive(Eq, Debug)

///|
pub struct Hyperlink {
  reference : String
  target : String
  link_type : HyperlinkType
  /// Workbook-internal location fragment. Always set for `Location`
  /// links; also set for `External` links whose XML carried both an
  /// `r:id` and a `location` attribute, which Excelize tracks
  /// independently.
  location : String?
  display : String?
  tooltip : String?
} derive(Debug)

///|
pub struct HyperlinkOpts {
  mut display : String?
  mut tooltip : String?
} derive(Debug)

///|
pub fn HyperlinkOpts::new() -> HyperlinkOpts {
  { display: None, tooltip: None, }
}

///|
pub fn HyperlinkOpts::with_values(
  display? : String,
  tooltip? : String,
) -> HyperlinkOpts {
  let opts = HyperlinkOpts::new()
  match display {
    Some(value) => opts.display = Some(value)
    None => ()
  }
  match tooltip {
    Some(value) => opts.tooltip = Some(value)
    None => ()
  }
  opts
}

///|
let max_sheet_hyperlinks = 65530

///|
/// Keeps every writer-produced relationship start tag below the default
/// 16 MiB OOXML-part ceiling even when every character needs XML escaping.
let max_hyperlink_target_chars : Int = 1024 * 1024

///|
fn is_ascii_uri_scheme_start(character : Char) -> Bool {
  let scalar = character.to_int()
  (scalar >= 'A'.to_int() && scalar <= 'Z'.to_int()) ||
  (scalar >= 'a'.to_int() && scalar <= 'z'.to_int())
}

///|
fn is_ascii_uri_scheme_character(character : Char) -> Bool {
  let scalar = character.to_int()
  is_ascii_uri_scheme_start(character) ||
  (scalar >= '0'.to_int() && scalar <= '9'.to_int()) ||
  character == '+' ||
  character == '-' ||
  character == '.'
}

///|
/// Returns a normalized explicit URI scheme.
fn explicit_hyperlink_uri_scheme(target : StringView) -> String? {
  let trimmed = target.trim()
  match trimmed.split_once(":") {
    None => None
    Some((raw_scheme, _)) => {
      if raw_scheme.length() == 0 {
        return None
      }
      let mut first = true
      for character in raw_scheme {
        if first {
          if !is_ascii_uri_scheme_start(character) {
            return None
          }
          first = false
        } else if !is_ascii_uri_scheme_character(character) {
          return None
        }
      }
      Some(raw_scheme.to_lower().to_owned())
    }
  }
}

///|
fn is_allowed_external_hyperlink_scheme(scheme : StringView) -> Bool {
  match scheme {
    "http"
    | "https"
    | "mailto"
    | "ftp"
    | "ftps"
    | "sftp"
    | "news"
    | "tel"
    | "sms"
    | "file"
    | "about"
    | "ppaction" => true
    _ => false
  }
}

///|
/// Unqualified A1 ranges such as `A1:B2` and `A:A` resemble URI schemes at
/// their first colon. Recognize the complete range before applying the URI
/// scheme guard to workbook-internal locations.
fn is_unqualified_hyperlink_location_range(target : StringView) -> Bool {
  let trimmed = target.trim()
  match trimmed.split_once(":") {
    None => false
    Some((start, end)) => {
      if end.contains(":") {
        return false
      }
      (parse_cell_ref(start) is Some(_) && parse_cell_ref(end) is Some(_)) ||
      (parse_column_ref(start) is Some(_) && parse_column_ref(end) is Some(_)) ||
      (parse_row_ref(start) is Some(_) && parse_row_ref(end) is Some(_))
    }
  }
}

///|
fn validate_hyperlink_xml_text(
  value : StringView,
  field : StringView,
) -> Unit raise XlsxError {
  for character in value {
    if !is_valid_xml_output_character(character) {
      raise InvalidHyperlink(
        msg="\{field} contains forbidden XML code point \{character.to_int()}",
      )
    }
  }
}

///|
fn validate_hyperlink_values(
  target : StringView,
  link_type : HyperlinkType,
  display : StringView,
  tooltip : StringView,
) -> Unit raise XlsxError {
  if target.trim() == "" {
    raise InvalidHyperlink(msg="hyperlink target is empty")
  }
  if target.length() > max_hyperlink_target_chars {
    raise InvalidHyperlink(msg="hyperlink target is too long")
  }
  validate_hyperlink_xml_text(target, "hyperlink target")
  validate_hyperlink_xml_text(display, "hyperlink display")
  validate_hyperlink_xml_text(tooltip, "hyperlink tooltip")
  if link_type == External {
    if target.contains("\\") {
      raise InvalidHyperlink(
        msg="external hyperlink target must use URI forward slashes",
      )
    }
    if !@ooxml.is_valid_external_relationship_target_iri(target) {
      raise InvalidHyperlink(
        msg="external hyperlink target is not a valid IRI reference",
      )
    }
  }
  match explicit_hyperlink_uri_scheme(target) {
    Some(scheme) =>
      match link_type {
        External =>
          if !is_allowed_external_hyperlink_scheme(scheme) {
            raise InvalidHyperlink(
              msg="unsafe external hyperlink scheme '\{scheme}:'",
            )
          }
        Location =>
          if !is_unqualified_hyperlink_location_range(target) {
            raise InvalidHyperlink(
              msg="location hyperlink target must not use URI scheme '\{scheme}:'",
            )
          }
        Unset => ()
      }
    None => ()
  }
}

///|
priv enum HyperlinkMergePlan {
  Keep
  Reanchor(Int)
  Conflict(String)
}

///|
priv struct IndexedHyperlinkBounds {
  index : Int
  bounds : (Int, Int, Int, Int)
}

///|
priv struct IndexedMergedRangeBounds {
  order : Int
  bounds : (Int, Int, Int, Int)
  anchor : String
}

///|
fn plan_overlapping_hyperlink_for_merge(
  index : Int,
  link_bounds : (Int, Int, Int, Int),
  merge_bounds : (Int, Int, Int, Int),
) -> HyperlinkMergePlan {
  if bounds_contain(merge_bounds, link_bounds) {
    return Reanchor(index)
  }
  let (min_row, min_col, _, _) = merge_bounds
  let (link_min_row, link_min_col, link_max_row, link_max_col) = link_bounds
  if !cell_in_bounds(
      min_row, min_col, link_min_row, link_min_col, link_max_row, link_max_col,
    ) {
    return Conflict(
      "merged range partially overlaps a hyperlink range away from its anchor",
    )
  }
  Keep
}

///|
/// Plans how the hyperlink sidecar participates in one merged range. Keeping
/// this decision separate from mutation lets both the public merge API and the
/// reader enforce the same identity rules with context-appropriate errors.
fn plan_hyperlinks_for_merge(
  hyperlinks : ArrayView[Hyperlink],
  merge_bounds : (Int, Int, Int, Int),
) -> HyperlinkMergePlan raise XlsxError {
  let mut overlapping_hyperlink : Int? = None
  let mut plan : HyperlinkMergePlan = Keep
  for index, link in hyperlinks {
    let link_bounds = parse_range_ref(link.reference)
    if rects_overlap(merge_bounds, link_bounds) {
      if overlapping_hyperlink is Some(_) {
        return Conflict("merged range contains multiple hyperlink identities")
      }
      overlapping_hyperlink = Some(index)
      plan = plan_overlapping_hyperlink_for_merge(
        index, link_bounds, merge_bounds,
      )
      if plan is Conflict(_) {
        return plan
      }
    }
  }
  plan
}

///|
fn reanchor_hyperlink(
  hyperlinks : Array[Hyperlink],
  index : Int,
  anchor : String,
) -> Unit {
  let link = hyperlinks[index]
  hyperlinks[index] = {
    reference: anchor,
    target: link.target,
    link_type: link.link_type,
    location: link.location,
    display: link.display,
    tooltip: link.tooltip,
  }
}

///|
fn compare_bounds_then_order(
  left_bounds : (Int, Int, Int, Int),
  left_order : Int,
  right_bounds : (Int, Int, Int, Int),
  right_order : Int,
) -> Int {
  let (left_min_row, left_min_col, left_max_row, left_max_col) = left_bounds
  let (right_min_row, right_min_col, right_max_row, right_max_col) = right_bounds
  if left_min_row != right_min_row {
    left_min_row.compare(right_min_row)
  } else if left_min_col != right_min_col {
    left_min_col.compare(right_min_col)
  } else if left_max_row != right_max_row {
    left_max_row.compare(right_max_row)
  } else if left_max_col != right_max_col {
    left_max_col.compare(right_max_col)
  } else {
    left_order.compare(right_order)
  }
}

///|
fn compare_indexed_hyperlink_bounds(
  left : IndexedHyperlinkBounds,
  right : IndexedHyperlinkBounds,
) -> Int {
  compare_bounds_then_order(left.bounds, left.index, right.bounds, right.index)
}

///|
fn compare_indexed_merged_range_bounds(
  left : IndexedMergedRangeBounds,
  right : IndexedMergedRangeBounds,
) -> Int {
  compare_bounds_then_order(left.bounds, left.order, right.bounds, right.order)
}

///|
/// Charges the comparison levels of a bounded sort without multiplying two
/// caller-controlled integers. The actual library sort is short for ordinary
/// sheets; checkpoints before and after it keep cancellation responsive.
fn charge_hyperlink_bound_sort(
  budget : ReadBudget,
  count : Int,
) -> Unit raise XlsxError {
  let mut width = 1
  while width < count {
    budget.checkpoint()
    budget.charge_work(count)
    if width > count / 2 {
      break
    }
    width = width * 2
  }
}

///|
fn index_hyperlink_bounds(
  hyperlinks : ArrayView[Hyperlink],
  budget : ReadBudget,
) -> Array[IndexedHyperlinkBounds] raise XlsxError {
  budget.checkpoint()
  budget.charge_work(hyperlinks.length())
  let indexed : Array[IndexedHyperlinkBounds] = []
  for index, link in hyperlinks {
    if index % 4096 == 0 {
      budget.checkpoint()
    }
    indexed.push({ index, bounds: parse_range_ref(link.reference), })
  }
  charge_hyperlink_bound_sort(budget, indexed.length())
  indexed.sort_by(compare_indexed_hyperlink_bounds)
  budget.checkpoint()
  indexed
}

///|
fn index_merged_range_bounds(
  merged_cells : ArrayView[String],
  budget : ReadBudget,
) -> Array[IndexedMergedRangeBounds] raise XlsxError {
  budget.checkpoint()
  budget.charge_work(merged_cells.length())
  let indexed : Array[IndexedMergedRangeBounds] = []
  for order, merged in merged_cells {
    if order % 4096 == 0 {
      budget.checkpoint()
    }
    let bounds = parse_range_ref(merged)
    let (min_row, min_col, _, _) = bounds
    indexed.push({ order, bounds, anchor: cell_ref_from(min_row, min_col), })
  }
  charge_hyperlink_bound_sort(budget, indexed.length())
  indexed.sort_by(compare_indexed_merged_range_bounds)
  budget.checkpoint()
  indexed
}

///|
/// Canonicalizes hyperlink identities retained from an existing workbook.
/// Older producers (including earlier mbtexcel versions) can leave a link on
/// a non-anchor cell inside a merged range. Reject ambiguous layouts rather
/// than exposing a hyperlink that lookup and removal cannot address. A row
/// sweep keeps disjoint layouts near O((H + M) log(H + M)); every residual
/// active-set comparison is budgeted and cancellation-aware.
fn canonicalize_loaded_hyperlinks_for_merges(
  hyperlinks : Array[Hyperlink],
  merged_cells : ArrayView[String],
  budget : ReadBudget,
) -> Unit raise XlsxError {
  if hyperlinks.length() == 0 || merged_cells.length() == 0 {
    return
  }
  let indexed_hyperlinks = index_hyperlink_bounds(hyperlinks, budget)
  let indexed_merges = index_merged_range_bounds(merged_cells, budget)
  let mut active : Array[IndexedHyperlinkBounds] = []
  let planned_anchors : Map[Int, String] = Map([])
  let reanchors : Array[(Int, String)] = []
  let mut hyperlink_cursor = 0
  for merged in indexed_merges {
    budget.checkpoint()
    let (merge_min_row, _, merge_max_row, _) = merged.bounds
    while hyperlink_cursor < indexed_hyperlinks.length() {
      let (link_min_row, _, _, _) = indexed_hyperlinks[hyperlink_cursor].bounds
      if link_min_row > merge_max_row {
        break
      }
      if hyperlink_cursor % 4096 == 0 {
        budget.checkpoint()
      }
      budget.charge_work(1)
      active.push(indexed_hyperlinks[hyperlink_cursor])
      hyperlink_cursor += 1
    }
    let retained : Array[IndexedHyperlinkBounds] = []
    let mut found_overlap = false
    let mut plan : HyperlinkMergePlan = Keep
    let mut active_index = 0
    while active_index < active.length() {
      if active_index % 4096 == 0 {
        budget.checkpoint()
        let remaining = active.length() - active_index
        budget.charge_work(if remaining > 4096 { 4096 } else { remaining })
      }
      let indexed = active[active_index]
      let (_, _, link_max_row, _) = indexed.bounds
      if link_max_row >= merge_min_row {
        retained.push(indexed)
        if rects_overlap(merged.bounds, indexed.bounds) {
          if found_overlap {
            raise InvalidXml(
              msg="invalid merged-cell hyperlink layout: merged range contains multiple hyperlink identities",
            )
          }
          found_overlap = true
          plan = plan_overlapping_hyperlink_for_merge(
            indexed.index,
            indexed.bounds,
            merged.bounds,
          )
          if plan is Conflict(msg) {
            raise InvalidXml(msg="invalid merged-cell hyperlink layout: \{msg}")
          }
        }
      }
      active_index += 1
    }
    active = retained
    match plan {
      Keep => ()
      Reanchor(index) =>
        match planned_anchors.get(index) {
          Some(existing) =>
            if existing != merged.anchor {
              raise InvalidXml(
                msg="invalid merged-cell hyperlink layout: hyperlink resolves to multiple merged-cell anchors",
              )
            }
          None => {
            planned_anchors[index] = merged.anchor
            reanchors.push((index, merged.anchor))
          }
        }
      Conflict(msg) =>
        raise InvalidXml(msg="invalid merged-cell hyperlink layout: \{msg}")
    }
  }
  for action_index, action in reanchors {
    if action_index % 4096 == 0 {
      budget.checkpoint()
    }
    budget.charge_work(1)
    let (index, anchor) = action
    reanchor_hyperlink(hyperlinks, index, anchor)
  }
}

///|
fn hyperlink_matches_type(link : Hyperlink, link_type : HyperlinkType?) -> Bool {
  match link_type {
    None => true
    Some(Unset) => false
    // Excelize filters External by r:id presence and Location by the
    // location attribute independently, so an external link that also
    // carries a location fragment matches both filters.
    Some(Location) => link.link_type == Location || link.location is Some(_)
    Some(wanted) => link.link_type == wanted
  }
}

///|
test "hyperlink ceiling permits replacement and rejects a new identity" {
  let sheet = Worksheet::new("Sheet1")
  let dummy : Hyperlink = {
    reference: "Z1",
    target: "https://example.com",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  }
  let many : Array[Hyperlink] = Array::make(max_sheet_hyperlinks - 1, dummy)
  sheet.hyperlinks.append(many)
  sheet.set_cell_hyperlink("A1", "https://before.example", External)
  inspect(sheet.get_hyperlinks().length(), content="65530")
  sheet.set_cell_hyperlink("A1", "https://after.example", External)
  debug_inspect(
    sheet.get_cell_hyperlink("A1").map(link => link.target),
    content=(
      #|Some("https://after.example")
    ),
  )
  let result : Result[Unit, Error] = Ok(
    sheet.set_cell_hyperlink("B1", "https://example.com", External),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    result,
    content=(
      #|Err(HyperlinkLimitExceeded(limit=65530))
    ),
  )
}

///|
fn hyperlink_merge_budget_fixture(
  count : Int,
) -> (Array[Hyperlink], Array[String]) {
  let hyperlinks : Array[Hyperlink] = []
  let merged_cells : Array[String] = []
  for index in 0..<count {
    let row = index * 2 + 1
    hyperlinks.push({
      reference: "B\{row}",
      target: "https://example.test/\{index}",
      link_type: External,
      location: None,
      display: None,
      tooltip: None,
    })
    merged_cells.push("A\{row}:B\{row}")
  }
  (hyperlinks, merged_cells)
}

///|
test "loaded hyperlink merge sweep is budgeted and cancellable" {
  let count = 256
  let (hyperlinks, merged_cells) = hyperlink_merge_budget_fixture(count)
  let budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=1024 * 1024),
  )
  canonicalize_loaded_hyperlinks_for_merges(hyperlinks, merged_cells, budget)
  assert_eq(hyperlinks[0].reference, "A1")
  assert_eq(hyperlinks[count - 1].reference, "A511")
  // A Cartesian implementation needs 65,536 comparisons here. Sorting and
  // sweeping disjoint rows stays comfortably below that bound.
  assert_true(budget.parser_work_units < count * count)
  let charged_work = budget.parser_work_units

  let (limited_hyperlinks, _) = hyperlink_merge_budget_fixture(count)
  let limited_budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=charged_work - 1),
  )
  try
    canonicalize_loaded_hyperlinks_for_merges(
      limited_hyperlinks, merged_cells, limited_budget,
    )
  catch {
    ResourceLimitExceeded(kind~, ..) => assert_eq(kind, "parser_work_units")
    _ => fail("unexpected merged hyperlink work-limit error")
  } noraise {
    _ => fail("expected merged hyperlink work-limit rejection")
  }

  let (cancelled_hyperlinks, _) = hyperlink_merge_budget_fixture(count)
  let checks = [0]
  let cancelled_budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=1024 * 1024),
    cancelled=() => {
      checks[0] += 1
      checks[0] >= 25
    },
  )
  try
    canonicalize_loaded_hyperlinks_for_merges(
      cancelled_hyperlinks, merged_cells, cancelled_budget,
    )
  catch {
    ReadCancelled => assert_true(checks[0] >= 25)
    _ => fail("unexpected merged hyperlink cancellation error")
  } noraise {
    _ => fail("expected merged hyperlink cancellation")
  }
}
