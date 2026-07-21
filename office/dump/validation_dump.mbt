///|
/// Emits candidate `validate` ops for a worksheet's data validations, one
/// op per sqref region (the batch sqref reader takes a single region), and
/// records each for the full-replay validation pass. Runs after the filter
/// op in the per-sheet canonical order.
///
/// The reader parses the sheet's stored validations all-or-nothing: one
/// entry it cannot read (an x14 validation) hides every validation on the
/// sheet, so a read failure must surface as a residual, never a silent
/// empty dump.
fn dump_sheet_validations(
  workbook : @xlsx.Workbook,
  sheet : String,
  ops : Array[Json],
  candidates : Array[TableCandidate],
  residual : Array[DumpResidual],
) -> Unit {
  let validations = match (try? workbook.get_data_validations(sheet)) {
    Ok(validations) => validations
    Err(error) => {
      residual.push({
        code: "xlsx.validation_unsupported",
        severity: "dropped",
        scope: "cells",
        location: Json::object({ "sheet": Json::string(sheet) }),
        asset: None,
        detail: "the sheet's stored data validations could not be read, so all of them are dropped: " +
        bounded_reason("\{to_repr(error)}"),
      })
      return
    }
  }
  for validation in validations {
    for region in validation.sqref.split(" ") {
      let region_text = region.to_string()
      if region_text == "" {
        continue
      }
      let params : Map[String, Json] = {
        "sheet": Json::string(sheet),
        "range": Json::string(region_text),
        "type": Json::string(validation.validation_type),
      }
      if validation.validation_type == "list" {
        // an inline dropdown is stored as a quoted, comma-joined literal;
        // anything else in formula1 is a source range
        let stored = validation.formula1
        if stored.length() >= 2 &&
          stored.has_prefix("\"") &&
          stored.has_suffix("\"") {
          let inner = stored.substring(start=1, end=stored.length() - 1)
          let values : Array[Json] = []
          for value in inner.split(",") {
            values.push(Json::string(value.to_string()))
          }
          params["values"] = Json::array(values)
        } else if stored != "" {
          params["source"] = Json::string(stored)
        }
      } else if validation.validation_type == "custom" {
        // Excel ignores operator and formula2 for custom rules and the
        // batch reader rejects both; formula1 carries the whole rule
        if validation.formula1 != "" {
          params["formula1"] = Json::string(validation.formula1)
        }
      } else {
        // a stored comparison may omit its operator (OOXML defaults it to
        // between); the batch reader requires one, so emit the default
        params["operator"] = Json::string(
          comparison_operator_or_default(validation.operator),
        )
        if validation.formula1 != "" {
          params["formula1"] = Json::string(validation.formula1)
        }
        if validation.formula2 != "" {
          params["formula2"] = Json::string(validation.formula2)
        }
      }
      // tri-states explicit so a default change can never shift semantics
      params["allow_blank"] = Json::boolean(validation.allow_blank)
      match validation.error_style {
        Some(style) if style != "" =>
          params["error_style"] = Json::string(style)
        _ => ()
      }
      match validation.error_title {
        Some(title) if title != "" =>
          params["error_title"] = Json::string(title)
        _ => ()
      }
      match validation.error {
        Some(message) if message != "" =>
          params["error_message"] = Json::string(message)
        _ => ()
      }
      match validation.prompt_title {
        Some(title) if title != "" =>
          params["input_title"] = Json::string(title)
        _ => ()
      }
      match validation.prompt {
        Some(message) if message != "" =>
          params["input_message"] = Json::string(message)
        _ => ()
      }
      candidates.push({
        op_index: ops.length(),
        sheet,
        payload: ValidationObject(validation, region_text),
      })
      ops.push(
        Json::object({
          "op": Json::string("validate"),
          "params": Json::object(params),
        }),
      )
    }
  }
}

///|
/// The OOXML default operator for comparison validations whose stored
/// attribute is absent.
fn comparison_operator_or_default(operator : String) -> String {
  if operator == "" {
    "between"
  } else {
    operator
  }
}

///|
/// Whether the replayed workbook carries a data validation for `region`
/// that matches the source validation in every field the reader exposes.
/// The replayed validation's sqref is exactly the region (one op per
/// region), while the source's sqref may span several regions. `ordinal`
/// selects among several replayed validations on the same region: ops
/// append in candidate order, so the n-th same-region candidate must match
/// the n-th same-region replayed validation.
fn validation_replayed_faithfully(
  replayed : @xlsx.Workbook,
  sheet : String,
  wanted : @xlsx.DataValidation,
  region : String,
  ordinal : Int,
) -> Bool {
  let replayed_validations = (try? replayed.get_data_validations(sheet)).unwrap_or([],
  )
  let mut found : @xlsx.DataValidation? = None
  let mut seen = 0
  for validation in replayed_validations {
    if validation.sqref == region {
      if seen == ordinal {
        found = Some(validation)
        break
      }
      seen += 1
    }
  }
  guard found is Some(actual) else { return false }
  // the operator is compared per type: Excel ignores it for custom rules
  // (the batch apply path pins a placeholder), and comparisons default an
  // absent stored operator to between — both sides normalize identically
  let operator_faithful = match wanted.validation_type {
    "custom" => true
    "list" => actual.operator == wanted.operator
    _ =>
      comparison_operator_or_default(actual.operator) ==
      comparison_operator_or_default(wanted.operator)
  }
  operator_faithful &&
  actual.validation_type == wanted.validation_type &&
  actual.formula1 == wanted.formula1 &&
  actual.formula2 == wanted.formula2 &&
  actual.allow_blank == wanted.allow_blank &&
  actual.show_drop_down == wanted.show_drop_down &&
  actual.show_error_message == wanted.show_error_message &&
  actual.show_input_message == wanted.show_input_message &&
  actual.error_style == wanted.error_style &&
  actual.error_title == wanted.error_title &&
  actual.error == wanted.error &&
  actual.prompt_title == wanted.prompt_title &&
  actual.prompt == wanted.prompt
}
