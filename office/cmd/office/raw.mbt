///|
let raw_cli_max_package_bytes : Int = 128 * 1024 * 1024

///|
let raw_cli_max_xml_bytes : Int = 1024 * 1024

///|
fn repeated_values(matches : @argparse.Matches, name : String) -> Array[String] {
  match matches.values.get(name) {
    Some(values) => values
    None => []
  }
}

///|
fn raw_failure(error : @raw.RawError) -> CliFailure {
  CliFailure(error.to_protocol_error())
}

///|
fn transaction_failure(error : @transaction.TransactionError) -> CliFailure {
  CliFailure(error.to_protocol_error())
}

///|
fn unexpected_cli_failure(
  code : String,
  operation : String,
  error : Error,
) -> CliFailure {
  CliFailure(
    @lib.protocol_error(
      code,
      "\{operation} failed: \{bounded_text(error.to_string(), 240)}",
    ),
  )
}

///|
fn raw_mutation_failure(
  error : @raw.RawError,
) -> @transaction.TransactionError raise @transaction.TransactionError {
  match error {
    RawError(code~, message~, details~) =>
      match details {
        Some(value) =>
          @transaction.transaction_failure(code, message, details=value)
        None => @transaction.transaction_failure(code, message)
      }
  }
}

///|
fn raw_transaction_identifier() -> @transaction.TransactionIdentifier raise CliFailure {
  @transaction.transaction_identifier("office-raw-bounded", (path, bytes) => {
    @raw.raw_identify(path, bytes) catch {
      RawError(..) as error => raise raw_mutation_failure(error)
    }
  }) catch {
    TransactionError(..) as error => raise transaction_failure(error)
  }
}

///|
fn cli_file_error(code : String, message : String, path : String) -> CliFailure {
  CliFailure(
    @lib.protocol_error(
      code,
      message + raw_human_text(path, 160),
      details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
    ),
  )
}

///|
fn raw_human_text(value : String, maximum : Int) -> String {
  terminal_safe_text(bounded_text(value, maximum))
}

///|
async fn read_bounded_file(
  path : String,
  maximum : Int,
  code : String,
  description : String,
) -> Bytes {
  let kind = @afs.kind(path) catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise cli_file_error(code, "could not inspect \{description}: ", path)
  }
  if !(kind is Regular) {
    raise cli_file_error(code, "\{description} is not a regular file: ", path)
  }
  let file = @afs.open(
    path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  ) catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise cli_file_error(code, "could not open \{description}: ", path)
  }
  defer file.close()
  if !(file.kind() is Regular) {
    raise cli_file_error(code, "\{description} is not a regular file: ", path)
  }
  let size = file.size() catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise cli_file_error(code, "could not size \{description}: ", path)
  }
  if size < 0L || size > maximum.to_int64() {
    raise CliFailure(
      @lib.protocol_error(
        "office.raw.resource_limit",
        "\{description} exceeds the \{maximum}-byte limit",
        details=Json::object({
          "file": Json::string(bounded_text(path, 160)),
          "limit": Json::number(maximum.to_double()),
        }),
      ),
    )
  }
  let length = size.to_int()
  let buffer = FixedArray::make(length, b'\x00')
  let mut offset = 0
  while offset < length {
    let count = file.read_at(
      buffer,
      position=offset.to_int64(),
      offset~,
      len=length - offset,
    ) catch {
      error if @async.is_being_cancelled() => raise error
      _ => raise cli_file_error(code, "could not read \{description}: ", path)
    }
    if count <= 0 || count > length - offset {
      raise cli_file_error(code, "could not read \{description}: ", path)
    }
    offset = offset + count
  }
  complete_bounded_file_read(buffer)
}

///|
/// Keep the final read boundary cancellable even when every filesystem call
/// completed synchronously from the host cache.
async fn complete_bounded_file_read(buffer : FixedArray[Byte]) -> Bytes {
  @async.pause()
  buffer.unsafe_reinterpret_as_bytes()
}

///|
async fn write_new_raw_file(path : String, data : BytesView) -> Unit {
  @transaction.atomic_write_new(path, data) catch {
    error if @async.is_being_cancelled() => raise error
    _ =>
      raise cli_file_error(
        "office.raw.output_write_failed", "could not atomically create output file: ",
        path,
      )
  }
}

///|
async fn xml_argument(matches : @argparse.Matches) -> String? {
  match (optional_value(matches, "xml"), optional_value(matches, "xml-file")) {
    (Some(value), None) => Some(value)
    (None, Some(path)) => {
      let bytes = read_bounded_file(
        path, raw_cli_max_xml_bytes, "office.raw.xml_read_failed", "XML input file",
      )
      let text = @utf8.decode(bytes, ignore_bom=true) catch {
        _ =>
          raise CliFailure(
            @lib.protocol_error(
              "office.raw.invalid_xml_encoding",
              "XML input file is not valid UTF-8",
              details=Json::object({
                "file": Json::string(bounded_text(path, 160)),
              }),
            ),
          )
      }
      Some(text)
    }
    (None, None) => None
    (Some(_), Some(_)) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "--xml and --xml-file are mutually exclusive",
        ),
      )
  }
}

///|
fn raw_inventory_human(inventory : @raw.RawInventory) -> String {
  let parts = inventory.part_records()
  let lines : Array[String] = [
    "\{inventory.document_format().name()} package: \{parts.length()} parts",
  ]
  for part in parts {
    let kind = if part.is_xml() { "xml" } else { "binary" }
    let aliases = part.semantic_aliases()
    let alias_text = if aliases.is_empty() {
      ""
    } else {
      let values = []
      for alternate in aliases {
        values.push(raw_human_text(alternate, 160))
      }
      "  aliases=" + values.join(",")
    }
    lines.push(
      "/\{raw_human_text(part.part_name(), 160)}  \{kind}  \{part.byte_size()} bytes  \{raw_human_text(part.media_type(), 160)}" +
      alias_text,
    )
  }
  lines.join("\n")
}

///|
async fn run_raw_list(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data = read_bounded_file(
    file, raw_cli_max_package_bytes, "office.file_read_failed", "input package",
  )
  let inventory = @raw.raw_inventory(file, data) catch {
    RawError(..) as error => raise raw_failure(error)
  }
  if matches.flags.get_or_default("json", false) {
    println(@lib.output_success(inventory.to_json()).stringify(indent=2))
  } else {
    println(raw_inventory_human(inventory))
  }
}

///|
fn raw_part_json(
  part : @raw.RawPartData,
  encoding : String,
  content? : String,
  output? : String,
) -> Json {
  let info = part.part_info()
  match (content, output) {
    (Some(value), None) =>
      Json::object({
        "schema": Json::string(@lib.SCHEMA_RAW_PART),
        "format": Json::string(part.document_format().name()),
        "part": info.to_json(),
        "encoding": Json::string(encoding),
        "content": Json::string(value),
      })
    (None, Some(path)) =>
      Json::object({
        "schema": Json::string(@lib.SCHEMA_RAW_PART),
        "format": Json::string(part.document_format().name()),
        "part": info.to_json(),
        "encoding": Json::string(encoding),
        "output": Json::string(path),
      })
    _ =>
      Json::object({
        "schema": Json::string(@lib.SCHEMA_RAW_PART),
        "format": Json::string(part.document_format().name()),
        "part": info.to_json(),
        "encoding": Json::string(encoding),
      })
  }
}

///|
async fn run_raw_read(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let selector = required_value(matches, "part")
  let data = read_bounded_file(
    file, raw_cli_max_package_bytes, "office.file_read_failed", "input package",
  )
  let part = @raw.raw_read(file, data, selector) catch {
    RawError(..) as error => raise raw_failure(error)
  }
  let bytes = part.payload_bytes()
  let json = matches.flags.get_or_default("json", false)
  let base64 = matches.flags.get_or_default("base64", false)
  match optional_value(matches, "output") {
    Some(path) => {
      write_new_raw_file(path, bytes)
      if json {
        println(
          @lib.output_success(raw_part_json(part, "binary", output=path)).stringify(
            indent=2,
          ),
        )
      } else {
        println(
          "wrote \{bytes.length()} bytes from /\{part.part_info().part_name()} to \{raw_human_text(path, 160)}",
        )
      }
    }
    None if base64 => {
      let encoded = @base64.encode(bytes)
      if json {
        println(
          @lib.output_success(raw_part_json(part, "base64", content=encoded)).stringify(
            indent=2,
          ),
        )
      } else {
        println(encoded)
      }
    }
    None => {
      let text = part.xml_text() catch {
        RawError(..) as error => raise raw_failure(error)
      }
      if json {
        println(
          @lib.output_success(raw_part_json(part, "xml", content=text)).stringify(
            indent=2,
          ),
        )
      } else {
        println(text)
      }
    }
  }
}

///|
fn checked_transaction_options(
  matches : @argparse.Matches,
) -> @transaction.TransactionOptions raise CliFailure {
  let file = required_value(matches, "file")
  let output = optional_value(matches, "out")
  let dry_run = matches.flags.get_or_default("dry-run", false)
  let overwrite = matches.flags.get_or_default("overwrite", false)
  if overwrite && output is None {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--overwrite requires a separate --out destination",
      ),
    )
  }
  @transaction.transaction_options(
    file,
    output_path?=output,
    dry_run~,
    overwrite~,
  ) catch {
    TransactionError(..) as error => raise transaction_failure(error)
  }
}

///|
fn raw_result_json(
  mutation : @raw.RawMutation,
  report : @transaction.TransactionReport,
) -> Json {
  Json::object({
    "schema": Json::string(@lib.SCHEMA_RAW_RESULT),
    "change": mutation.to_json(),
    "transaction": report.to_json(),
  })
}

///|
fn print_raw_result(
  matches : @argparse.Matches,
  mutation : @raw.RawMutation,
  report : @transaction.TransactionReport,
) -> Unit {
  if matches.flags.get_or_default("json", false) {
    let warnings = []
    for warning in report.warning_records() {
      warnings.push(warning)
    }
    println(
      @lib.output_success(raw_result_json(mutation, report), warnings~).stringify(
        indent=2,
      ),
    )
  } else {
    let destination = optional_value(matches, "out").unwrap_or(
      required_value(matches, "file") catch {
        _ => "<input>"
      },
    )
    let status = if matches.flags.get_or_default("dry-run", false) {
      "validated dry run"
    } else {
      "committed"
    }
    println(
      "\{status}: \{mutation.action_name()} matched \{mutation.selected_count()} element(s) in /\{mutation.part_name()} -> \{raw_human_text(destination, 160)}",
    )
  }
}

///|
async fn run_raw_replace(matches : @argparse.Matches) -> Unit {
  let part = required_value(matches, "part")
  let xml = match xml_argument(matches) {
    Some(value) => value
    None =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "raw replace requires --xml or --xml-file",
        ),
      )
  }
  let options = checked_transaction_options(matches)
  let completed : Ref[@raw.RawMutation?] = Ref(None)
  let report = @transaction.transact(
    options,
    (format, original) => {
      let mutation = @raw.raw_replace_part(format, original, part, xml) catch {
        RawError(..) as error => raise raw_mutation_failure(error)
      }
      completed.val = Some(mutation)
      @transaction.transaction_mutation_with_manifest(
        mutation.candidate_bytes(),
        [mutation.part_name()],
      )
    },
    identifier=raw_transaction_identifier(),
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.transaction.failed", "raw replacement transaction", error,
      )
  }
  guard completed.val is Some(mutation) else {
    raise CliFailure(
      @lib.protocol_error(
        "office.transaction.invalid_contract", "raw mutation completed without metadata",
      ),
    )
  }
  print_raw_result(matches, mutation, report)
}

///|
fn namespace_arguments(
  matches : @argparse.Matches,
) -> Array[(String, String)] raise CliFailure {
  let output = []
  for value in repeated_values(matches, "namespace") {
    let binding = @raw.raw_namespace_binding(value) catch {
      RawError(..) as error => raise raw_failure(error)
    }
    output.push(binding)
  }
  output
}

///|
async fn run_raw_edit(matches : @argparse.Matches) -> Unit {
  let part = required_value(matches, "part")
  let path = required_value(matches, "path")
  let action_name = required_value(matches, "action")
  let action = match @raw.resolve_raw_action(action_name) {
    Some(value) => value
    None =>
      raise CliFailure(
        @lib.protocol_error(
          "office.raw.invalid_action",
          "unknown raw edit action '\{bounded_text(action_name, 80)}'",
          details=Json::object({
            "action": Json::string(bounded_text(action_name, 80)),
          }),
        ),
      )
  }
  let xml = xml_argument(matches)
  let attribute = optional_value(matches, "attribute")
  let value = optional_value(matches, "value")
  let namespaces = namespace_arguments(matches)
  let request = @raw.raw_edit_request(
    part,
    path,
    action,
    xml?,
    attribute?,
    value?,
    namespaces~,
    all=matches.flags.get_or_default("all", false),
  ) catch {
    RawError(..) as error => raise raw_failure(error)
  }
  let options = checked_transaction_options(matches)
  let completed : Ref[@raw.RawMutation?] = Ref(None)
  let report = @transaction.transact(
    options,
    (format, original) => {
      let mutation = @raw.raw_edit(format, original, request) catch {
        RawError(..) as error => raise raw_mutation_failure(error)
      }
      completed.val = Some(mutation)
      @transaction.transaction_mutation_with_manifest(
        mutation.candidate_bytes(),
        [mutation.part_name()],
      )
    },
    identifier=raw_transaction_identifier(),
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.transaction.failed", "raw edit transaction", error,
      )
  }
  guard completed.val is Some(mutation) else {
    raise CliFailure(
      @lib.protocol_error(
        "office.transaction.invalid_contract", "raw mutation completed without metadata",
      ),
    )
  }
  print_raw_result(matches, mutation, report)
}

///|
fn raw_mutation_flags() -> Array[@argparse.FlagArg] {
  [
    FlagArg("dry-run", long="dry-run", about="validate without publishing"),
    FlagArg(
      "overwrite",
      long="overwrite",
      about="allow replacement of an existing separate --out destination",
    ),
    FlagArg("json", long="json", about="print office.output/1 JSON"),
  ]
}

///|
fn raw_mutation_output_options() -> Array[@argparse.OptionArg] {
  [
    OptionArg(
      "out",
      long="out",
      about="publish to a separate path instead of replacing the input",
    ),
  ]
}

///|
fn raw_command() -> @argparse.Command {
  let replace_options : Array[@argparse.OptionArg] = [
    OptionArg("xml", long="xml", conflicts_with=["xml-file"]),
    OptionArg("xml-file", long="xml-file", conflicts_with=["xml"]),
  ]
  for option in raw_mutation_output_options() {
    replace_options.push(option)
  }
  let edit_options : Array[@argparse.OptionArg] = [
    OptionArg("path", long="path", required=true),
    OptionArg("action", long="action", required=true),
    OptionArg("xml", long="xml", conflicts_with=["xml-file"]),
    OptionArg("xml-file", long="xml-file", conflicts_with=["xml"]),
    OptionArg("attribute", long="attribute"),
    OptionArg("value", long="value"),
    OptionArg(
      "namespace",
      long="namespace",
      action=Append,
      about="selector namespace binding PREFIX=URI (repeatable)",
    ),
  ]
  for option in raw_mutation_output_options() {
    edit_options.push(option)
  }
  let edit_flags : Array[@argparse.FlagArg] = [FlagArg("all", long="all")]
  for flag in raw_mutation_flags() {
    edit_flags.push(flag)
  }
  Command(
    "raw",
    about="Inventory, read, and atomically edit validated OOXML parts",
    subcommand_required=true,
    subcommands=[
      Command(
        "list",
        about="List canonical package parts and relationship-derived aliases",
        positionals=[
          PositionArg("file", num_args=@argparse.ValueRange::single()),
        ],
        flags=[FlagArg("json", long="json")],
      ),
      Command(
        "read",
        about="Read one existing package part",
        positionals=[
          PositionArg("file", num_args=@argparse.ValueRange::single()),
          PositionArg("part", num_args=@argparse.ValueRange::single()),
        ],
        flags=[
          FlagArg("json", long="json"),
          FlagArg(
            "base64",
            long="base64",
            about="encode the exact payload as base64",
            conflicts_with=["output"],
          ),
        ],
        options=[
          OptionArg(
            "output",
            long="output",
            about="write the exact payload to a new file",
            conflicts_with=["base64"],
          ),
        ],
      ),
      Command(
        "replace",
        about="Replace one existing XML part through the Office transaction",
        positionals=[
          PositionArg("file", num_args=@argparse.ValueRange::single()),
          PositionArg("part", num_args=@argparse.ValueRange::single()),
        ],
        options=replace_options,
        flags=raw_mutation_flags(),
      ),
      Command(
        "edit",
        about="Apply one bounded namespace-aware XML element edit",
        positionals=[
          PositionArg("file", num_args=@argparse.ValueRange::single()),
          PositionArg("part", num_args=@argparse.ValueRange::single()),
        ],
        options=edit_options,
        flags=edit_flags,
      ),
    ],
  )
}

///|
async fn run_raw(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("list", values)) => run_raw_list(values)
    Some(("read", values)) => run_raw_read(values)
    Some(("replace", values)) => run_raw_replace(values)
    Some(("edit", values)) => run_raw_edit(values)
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "raw requires list, read, replace, or edit",
        ),
      )
  }
}
