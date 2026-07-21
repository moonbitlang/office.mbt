///|
/// Emits candidate `cf` ops for a worksheet's conditional-format rules, one
/// op per rule, and records each for the full-replay validation pass.
/// Multi-region sqrefs are never split (a scale or bar computes over its
/// whole range, so splitting would change semantics); since the batch
/// range reader takes a single region, a multi-region rule's op is
/// rejected by the parse pre-filter and the rule residualizes.
///
/// Rules whose type or options the batch cf vocabulary cannot express
/// residualize immediately with a named reason; expressible rules flow
/// through the shared parse pre-filter and replay diff, which drop any
/// divergence to a residual.
fn dump_sheet_conditional_formats(
  workbook : @xlsx.Workbook,
  sheet : String,
  ops : Array[Json],
  candidates : Array[TableCandidate],
  residual : Array[DumpResidual],
) -> Unit {
  let formats = match (try? workbook.get_conditional_formats(sheet)) {
    Ok(formats) => formats
    Err(error) => {
      // the reader parses the sheet's retained rule fragments all-or-
      // nothing; a read failure must surface, never a silent empty section
      residual.push({
        code: "xlsx.conditional_format_unsupported",
        severity: "dropped",
        scope: "cells",
        location: Json::object({ "sheet": Json::string(sheet) }),
        asset: None,
        detail: "the sheet's stored conditional formats could not be read, so all of them are dropped: " +
        bounded_reason("\{to_repr(error)}"),
      })
      return
    }
  }
  for sqref, rules in formats {
    for rule in rules {
      let params : Map[String, Json] = {
        "sheet": Json::string(sheet),
        "range": Json::string(sqref),
      }
      match cf_rule_params(workbook, rule, params) {
        Some(reason) => residual.push(cf_residual(sheet, sqref, reason))
        None => {
          candidates.push({
            op_index: ops.length(),
            sheet,
            payload: ConditionalObject(rule, sqref),
          })
          ops.push(
            Json::object({
              "op": Json::string("cf"),
              "params": Json::object(params),
            }),
          )
        }
      }
    }
  }
}

///|
/// Fills `params` with the batch `cf` op parameters for `rule`, returning
/// a reason instead when the rule is not expressible. Requirements the
/// batch parse contract enforces (a cell rule's highlight, a scale's
/// colors) are NOT pre-checked here: the shared parse pre-filter rejects
/// them with the engine's own message.
fn cf_rule_params(
  workbook : @xlsx.Workbook,
  rule : @xlsx.ConditionalFormatOptions,
  params : Map[String, Json],
) -> String? {
  params["type"] = Json::string(rule.format_type)
  match rule.format_type {
    "cell" => {
      params["criteria"] = Json::string(cf_cell_criteria_token(rule.criteria))
      let criteria = rule.criteria.to_lower()
      if criteria == "between" || criteria == "not between" {
        if rule.min_value != "" {
          params["min_value"] = Json::string(rule.min_value)
        }
        if rule.max_value != "" {
          params["max_value"] = Json::string(rule.max_value)
        }
      } else if rule.value != "" {
        params["value"] = Json::string(rule.value)
      }
    }
    "formula" =>
      // the engine stores the expression in `criteria`
      params["formula"] = Json::string(rule.criteria)
    "2_color_scale" | "3_color_scale" => {
      if rule.min_type != "" {
        params["min_type"] = Json::string(rule.min_type)
      }
      if rule.min_value != "" {
        params["min_value"] = Json::string(rule.min_value)
      }
      if rule.min_color != "" {
        params["min_color"] = Json::string(rule.min_color)
      }
      if rule.format_type == "3_color_scale" {
        if rule.mid_type != "" {
          params["mid_type"] = Json::string(rule.mid_type)
        }
        if rule.mid_value != "" {
          params["mid_value"] = Json::string(rule.mid_value)
        }
        if rule.mid_color != "" {
          params["mid_color"] = Json::string(rule.mid_color)
        }
      }
      if rule.max_type != "" {
        params["max_type"] = Json::string(rule.max_type)
      }
      if rule.max_value != "" {
        params["max_value"] = Json::string(rule.max_value)
      }
      if rule.max_color != "" {
        params["max_color"] = Json::string(rule.max_color)
      }
    }
    "data_bar" => {
      if rule.bar_only {
        return Some("data bar with bar_only is not expressible")
      }
      if rule.bar_color != "" {
        params["bar_color"] = Json::string(rule.bar_color)
      }
      if rule.min_type != "" {
        params["min_type"] = Json::string(rule.min_type)
      }
      if rule.min_value != "" {
        params["min_value"] = Json::string(rule.min_value)
      }
      if rule.max_type != "" {
        params["max_type"] = Json::string(rule.max_type)
      }
      if rule.max_value != "" {
        params["max_value"] = Json::string(rule.max_value)
      }
      if rule.bar_solid {
        params["bar_solid"] = Json::boolean(true)
      }
      if rule.bar_direction != "" {
        params["bar_direction"] = Json::string(rule.bar_direction)
      }
      if rule.bar_border_color != "" {
        params["bar_border_color"] = Json::string(rule.bar_border_color)
      }
    }
    "icon_set" => {
      if rule.icons_only {
        return Some("icon set with icons_only is not expressible")
      }
      params["icon_style"] = Json::string(rule.icon_style)
      if rule.reverse_icons {
        params["reverse_icons"] = Json::boolean(true)
      }
    }
    other => return Some("rule type '\{other}' is not expressible")
  }
  if rule.stop_if_true {
    params["stop_if_true"] = Json::boolean(true)
  }
  match rule.format {
    Some(style_id) => {
      guard (try? workbook.get_conditional_style(style_id)) is Ok(style) else {
        return Some("rule references a missing highlight style")
      }
      // the cf op expresses exactly fill / font_color / bold / italic; a
      // dxf carrying anything more can never rebuild equal, so disclose it
      // up front with a named reason instead of burning a replay round
      let extract = extract_style(style)
      if !extract.unexpressible.is_empty() {
        return Some(
          "highlight style is not expressible: " +
          extract.unexpressible.join(", "),
        )
      }
      for key, value in extract.params {
        match key {
          "fill" | "font_color" | "bold" | "italic" => params[key] = value
          other =>
            return Some(
              "highlight style sets '\{other}', which cf cannot express",
            )
        }
      }
    }
    None => ()
  }
  None
}

///|
/// Maps the reader's word-form comparison criteria back to the tokens the
/// batch cf op accepts. Non-comparison criteria (text and time-period
/// forms) pass through verbatim so the parse pre-filter rejects them with
/// the engine's own message.
fn cf_cell_criteria_token(criteria : String) -> String {
  match criteria {
    "greater than" => ">"
    "greater than or equal to" => ">="
    "less than" => "<"
    "less than or equal to" => "<="
    "equal to" => "="
    "not equal to" => "!="
    other => other
  }
}

///|
fn cf_residual(sheet : String, sqref : String, reason : String) -> DumpResidual {
  {
    code: "xlsx.conditional_format_unsupported",
    severity: "dropped",
    scope: "cells",
    location: dump_location(sheet, "range", sqref),
    asset: None,
    detail: "conditional-format rule does not replay faithfully through \{XLSX_BATCH_SCHEMA}: " +
    bounded_reason(reason),
  }
}

///|
/// Whether the replayed workbook carries a conditional-format rule for
/// `sqref` matching the source rule in every reader-exposed field. The
/// highlight is compared by resolving BOTH dxf indexes to their Style
/// content (the numeric indexes legitimately differ across workbooks).
/// `ordinal` selects among several rules on one sqref: each cf op appends
/// its own rule fragment, so the n-th same-sqref candidate must match the
/// n-th same-sqref replayed rule.
fn conditional_replayed_faithfully(
  source : @xlsx.Workbook,
  replayed : @xlsx.Workbook,
  sheet : String,
  wanted : @xlsx.ConditionalFormatOptions,
  sqref : String,
  ordinal : Int,
) -> Bool {
  guard (try? replayed.get_conditional_formats(sheet)) is Ok(formats) else {
    return false
  }
  guard formats.get(sqref) is Some(rules) else { return false }
  guard rules.get(ordinal) is Some(actual) else { return false }
  let format_faithful = match (wanted.format, actual.format) {
    (None, None) => true
    (Some(wanted_id), Some(actual_id)) =>
      match
        (
          try? source.get_conditional_style(wanted_id),
          try? replayed.get_conditional_style(actual_id),
        ) {
        (Ok(wanted_style), Ok(actual_style)) => wanted_style == actual_style
        _ => false
      }
    _ => false
  }
  format_faithful &&
  actual.format_type == wanted.format_type &&
  actual.above_average == wanted.above_average &&
  actual.percent == wanted.percent &&
  actual.criteria == wanted.criteria &&
  actual.value == wanted.value &&
  actual.min_type == wanted.min_type &&
  actual.mid_type == wanted.mid_type &&
  actual.max_type == wanted.max_type &&
  actual.min_value == wanted.min_value &&
  actual.mid_value == wanted.mid_value &&
  actual.max_value == wanted.max_value &&
  actual.min_color == wanted.min_color &&
  actual.mid_color == wanted.mid_color &&
  actual.max_color == wanted.max_color &&
  actual.bar_color == wanted.bar_color &&
  actual.bar_border_color == wanted.bar_border_color &&
  actual.bar_direction == wanted.bar_direction &&
  actual.bar_only == wanted.bar_only &&
  actual.bar_solid == wanted.bar_solid &&
  actual.icon_style == wanted.icon_style &&
  actual.reverse_icons == wanted.reverse_icons &&
  actual.icons_only == wanted.icons_only &&
  actual.stop_if_true == wanted.stop_if_true
}
