///|
fn bounded_decimal_argument(
  matches : @argparse.Matches,
  name : String,
  default_value : Int,
  minimum : Int,
  maximum : Int,
) -> Int raise CliFailure {
  let value = match optional_value(matches, name) {
    Some(text) => text
    None => return default_value
  }
  if value == "" || value.length() > 10 {
    raise docx_cli_failure(
      "office.invalid_arguments",
      "--\{name} must be an integer between \{minimum} and \{maximum}",
      details=Json::object({
        "argument": Json::string(name),
        "minimum": Json::number(minimum.to_double()),
        "maximum": Json::number(maximum.to_double()),
      }),
    )
  }
  let mut result = 0
  for unit in value {
    if !(unit is ('0'..='9')) {
      raise docx_cli_failure(
        "office.invalid_arguments",
        "--\{name} must be an integer between \{minimum} and \{maximum}",
        details=Json::object({
          "argument": Json::string(name),
          "minimum": Json::number(minimum.to_double()),
          "maximum": Json::number(maximum.to_double()),
        }),
      )
    }
    let digit = unit.to_int() - '0'.to_int()
    if result > (maximum - digit) / 10 {
      raise docx_cli_failure(
        "office.invalid_arguments",
        "--\{name} must be an integer between \{minimum} and \{maximum}",
        details=Json::object({
          "argument": Json::string(name),
          "minimum": Json::number(minimum.to_double()),
          "maximum": Json::number(maximum.to_double()),
        }),
      )
    }
    result = result * 10 + digit
  }
  if result < minimum || result > maximum {
    raise docx_cli_failure(
      "office.invalid_arguments",
      "--\{name} must be an integer between \{minimum} and \{maximum}",
      details=Json::object({
        "argument": Json::string(name),
        "minimum": Json::number(minimum.to_double()),
        "maximum": Json::number(maximum.to_double()),
      }),
    )
  }
  result
}

///|
fn cli_max_elements(matches : @argparse.Matches) -> Int raise CliFailure {
  bounded_decimal_argument(
    matches, "max-elements", docx_cli_default_max_elements, 1, docx_cli_hard_max_elements,
  )
}

///|
fn cli_max_output_chars(matches : @argparse.Matches) -> Int raise CliFailure {
  bounded_decimal_argument(
    matches, "max-output-chars", docx_cli_default_max_output_chars, 1, docx_cli_hard_max_output_chars,
  )
}

///|
fn docx_common_options() -> Array[@argparse.OptionArg] {
  [
    OptionArg(
      "max-elements",
      long="max-elements",
      about="maximum canonical projection nodes to scan (default 50000, hard limit 200000)",
    ),
    OptionArg(
      "max-output-chars",
      long="max-output-chars",
      about="maximum serialized output characters (default 1048576, hard limit 4194304)",
    ),
  ]
}

///|
fn docx_json_flag() -> @argparse.FlagArg {
  FlagArg("json", long="json", about="emit office.output/1 JSON")
}

///|
fn resolve_optional_under(
  projection : DocxProjection,
  matches : @argparse.Matches,
) -> (DocxProjectionEntry?, String?) raise CliFailure {
  match optional_value(matches, "under") {
    Some(path) => {
      let entry = resolve_projection_selector(projection, path)
      (Some(entry), Some(entry.path))
    }
    None => (None, None)
  }
}

///|
async fn run_docx_outline(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let max_elements = cli_max_elements(matches)
  let max_output = cli_max_output_chars(matches)
  let projection = read_docx_projection(file, max_elements)
  if matches.flags.get_or_default("json", false) {
    println(
      checked_docx_json_output(
        docx_outline_payload(projection),
        projection.warnings,
        max_output,
      ),
    )
  } else {
    println(
      checked_docx_human_output(docx_outline_human(projection), max_output),
    )
  }
}

///|
async fn run_docx_get(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let selector = required_value(matches, "selector")
  let max_elements = cli_max_elements(matches)
  let max_output = cli_max_output_chars(matches)
  let projection = read_docx_projection(file, max_elements)
  let entry = resolve_projection_selector(projection, selector)
  if matches.flags.get_or_default("json", false) {
    println(
      checked_docx_json_output(
        get_docx_payload(projection, entry, max_output),
        projection.warnings,
        max_output,
      ),
    )
  } else {
    let text = match entry.element {
      Some(_) => {
        let budget = DocxTextBudget::new(
          "element text characters",
          max_output.min(docx_cli_max_element_text_chars),
        )
        entry_text_with_budget(entry, budget)
      }
      None => ""
    }
    let primary = if text == "" { "\{entry.path}\t\{entry.kind}" } else { text }
    let lines = [primary]
    lines.append(human_warning_lines(projection.warnings))
    println(checked_docx_human_output(lines.join("\n"), max_output))
  }
}

///|
async fn run_docx_text(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let max_elements = cli_max_elements(matches)
  let max_output = cli_max_output_chars(matches)
  let offset = bounded_decimal_argument(
    matches, "offset", 0, 0, docx_cli_hard_max_elements,
  )
  let limit = bounded_decimal_argument(
    matches, "limit", docx_cli_default_text_limit, 0, docx_cli_hard_text_limit,
  )
  let projection = read_docx_projection(file, max_elements)
  let (under, under_path) = resolve_optional_under(projection, matches)
  let result = build_docx_text_result(
    projection, under, offset, limit, max_output,
  )
  if matches.flags.get_or_default("json", false) {
    println(
      checked_docx_json_output(
        docx_text_payload(projection, result, under_path),
        projection.warnings,
        max_output,
      ),
    )
  } else {
    println(
      checked_docx_human_output(
        docx_text_human(result, projection.warnings),
        max_output,
      ),
    )
  }
}

///|
fn canonical_query_kind(input : String) -> String? {
  match input.to_lower() {
    "body" => Some("body")
    "header" => Some("header")
    "footer" => Some("footer")
    "footnotes" => Some("footnotes")
    "endnotes" => Some("endnotes")
    "comments" => Some("comments")
    "note" => Some("note")
    "comment" => Some("comment")
    "p" | "paragraph" => Some("p")
    "r" | "run" => Some("r")
    "tbl" | "table" => Some("tbl")
    "tr" | "row" => Some("tr")
    "tc" | "cell" => Some("tc")
    "hyperlink" | "link" => Some("hyperlink")
    "image" | "picture" => Some("image")
    _ => None
  }
}

///|
fn query_kind(matches : @argparse.Matches) -> String? raise CliFailure {
  match optional_value(matches, "kind") {
    Some(value) =>
      match canonical_query_kind(value) {
        Some(kind) => Some(kind)
        None =>
          raise docx_cli_failure(
            "office.docx.invalid_query_kind",
            "unknown DOCX query kind '\{bounded_text(value, 80)}'",
            details=Json::object({
              "kind": Json::string(bounded_text(value, 80)),
              "allowed": Json::array([
                Json::string("body"),
                Json::string("header"),
                Json::string("footer"),
                Json::string("footnotes"),
                Json::string("endnotes"),
                Json::string("comments"),
                Json::string("note"),
                Json::string("comment"),
                Json::string("p"),
                Json::string("r"),
                Json::string("tbl"),
                Json::string("tr"),
                Json::string("tc"),
                Json::string("hyperlink"),
                Json::string("image"),
              ]),
            }),
          )
      }
    None => None
  }
}

///|
fn canonical_query_property_name(input : String) -> String? {
  match input.to_lower() {
    "style_id" | "style-id" => Some("style_id")
    "style_name" | "style-name" => Some("style_name")
    "alignment" | "align" => Some("alignment")
    "bold" => Some("bold")
    "italic" => Some("italic")
    "underline" => Some("underline")
    "content_type" | "content-type" => Some("content_type")
    "href" | "url" => Some("href")
    "author" => Some("author")
    "done" | "resolved" => Some("done")
    _ => None
  }
}

///|
fn validate_query_value(
  value : String,
  argument : String,
  allow_empty : Bool,
) -> Unit raise CliFailure {
  if (!allow_empty && value == "") ||
    !has_at_most_chars(value, @lib.SELECTOR_MAX_VALUE_LENGTH) {
    raise docx_cli_failure(
      "office.invalid_arguments",
      "--\{argument} must be a non-empty value of at most \{@lib.SELECTOR_MAX_VALUE_LENGTH} characters",
      details=Json::object({
        "argument": Json::string(argument),
        "maximum_characters": Json::number(
          @lib.SELECTOR_MAX_VALUE_LENGTH.to_double(),
        ),
      }),
    )
  }
}

///|
fn query_properties(
  matches : @argparse.Matches,
) -> Array[DocxPropertyPredicate] raise CliFailure {
  let raw = repeated_values(matches, "property")
  if raw.length() > 16 {
    raise docx_cli_failure(
      "office.docx.query_predicate_limit",
      "at most 16 --property predicates are allowed",
      details=Json::object({
        "limit": Json::number(16),
        "actual": Json::number(raw.length().to_double()),
      }),
    )
  }
  let predicates : Array[DocxPropertyPredicate] = []
  for value in raw {
    guard value.find("=") is Some(split) && split > 0 else {
      raise docx_cli_failure(
        "office.invalid_arguments",
        "--property requires NAME=VALUE",
        details=Json::object({
          "argument": Json::string("property"),
          "value": Json::string(bounded_text(value, 160)),
        }),
      )
    }
    let raw_name = value[:split].to_owned()
    let property_value = value[split + 1:].to_owned()
    guard canonical_query_property_name(raw_name) is Some(name) else {
      raise docx_cli_failure(
        "office.docx.invalid_query_property",
        "unknown DOCX query property '\{bounded_text(raw_name, 80)}'",
        details=Json::object({
          "property": Json::string(bounded_text(raw_name, 80)),
        }),
      )
    }
    validate_query_value(property_value, "property", true)
    if name == "bold" ||
      name == "italic" ||
      name == "underline" ||
      name == "done" {
      if property_value != "true" && property_value != "false" {
        raise docx_cli_failure(
          "office.docx.invalid_query_property",
          "boolean query property '\{name}' requires true or false",
          details=Json::object({
            "property": Json::string(name),
            "value": Json::string(bounded_text(property_value, 80)),
          }),
        )
      }
    }
    predicates.push({ name, value: property_value })
  }
  predicates
}

///|
async fn run_docx_query(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let max_elements = cli_max_elements(matches)
  let max_output = cli_max_output_chars(matches)
  let offset = bounded_decimal_argument(
    matches, "offset", 0, 0, docx_cli_hard_max_elements,
  )
  let limit = bounded_decimal_argument(
    matches, "limit", docx_cli_default_query_limit, 0, docx_cli_hard_query_limit,
  )
  let text = optional_value(matches, "text")
  match text {
    Some(value) => validate_query_value(value, "text", false)
    None => ()
  }
  let stable_id = optional_value(matches, "id")
  match stable_id {
    Some(value) => validate_query_value(value, "id", false)
    None => ()
  }
  let projection = read_docx_projection(file, max_elements)
  let (under, under_path) = resolve_optional_under(projection, matches)
  let spec : DocxQuerySpec = {
    under: under_path,
    kind: query_kind(matches),
    text,
    stable_id,
    properties: query_properties(matches),
    ignore_case: matches.flags.get_or_default("ignore-case", false),
    offset,
    limit,
  }
  let result = build_docx_query_result(projection, under, spec)
  if matches.flags.get_or_default("json", false) {
    println(
      checked_docx_json_output(
        docx_query_payload(projection, result, spec),
        projection.warnings,
        max_output,
      ),
    )
  } else {
    println(
      checked_docx_human_output(
        docx_query_human(result, projection.warnings),
        max_output,
      ),
    )
  }
}

///|
fn outline_command() -> @argparse.Command {
  Command(
    "outline",
    about="Summarize bounded DOCX structure using canonical selectors",
    positionals=[PositionArg("file", num_args=@argparse.ValueRange::single())],
    options=docx_common_options(),
    flags=[docx_json_flag()],
  )
}

///|
fn get_command() -> @argparse.Command {
  Command(
    "get",
    about="Resolve one canonical DOCX selector",
    positionals=[
      PositionArg("file", num_args=@argparse.ValueRange::single()),
      PositionArg(
        "selector",
        about="canonical path such as /docx/body/p[1]",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=docx_common_options(),
    flags=[docx_json_flag()],
  )
}

///|
fn text_command() -> @argparse.Command {
  let options = docx_common_options()
  options.append([
    OptionArg(
      "under",
      long="under",
      about="restrict paragraphs to a canonical DOCX selector subtree",
    ),
    OptionArg("offset", long="offset", about="zero-based result offset"),
    OptionArg(
      "limit",
      long="limit",
      about="maximum returned paragraphs (default 2000, hard limit 10000)",
    ),
  ])
  Command(
    "text",
    about="Extract bounded path-tagged DOCX paragraph text",
    positionals=[PositionArg("file", num_args=@argparse.ValueRange::single())],
    options~,
    flags=[docx_json_flag()],
  )
}

///|
fn query_command() -> @argparse.Command {
  let options = docx_common_options()
  options.append([
    OptionArg(
      "under",
      long="under",
      about="restrict matches to a canonical DOCX selector subtree",
    ),
    OptionArg(
      "kind",
      long="kind",
      about="exact element kind (aliases: paragraph, run, table, row, cell, link, picture)",
    ),
    OptionArg(
      "text",
      long="text",
      about="literal text substring (no regular expressions)",
    ),
    OptionArg("id", long="id", about="exact annotation id"),
    OptionArg(
      "property",
      long="property",
      action=Append,
      about="repeatable declared property predicate NAME=VALUE",
    ),
    OptionArg("offset", long="offset", about="zero-based match offset"),
    OptionArg(
      "limit",
      long="limit",
      about="maximum returned matches (default 100, hard limit 1000)",
    ),
  ])
  Command(
    "query",
    about="Run bounded deterministic predicates over DOCX elements",
    positionals=[PositionArg("file", num_args=@argparse.ValueRange::single())],
    options~,
    flags=[
      docx_json_flag(),
      FlagArg(
        "ignore-case",
        long="ignore-case",
        about="compare the --text literal case-insensitively",
      ),
    ],
  )
}
