// D3 CLI surface: `office create docx OUT` (blank) and the fresh-authoring
// `office batch --format docx OUT SCRIPT` variant. DOCX authoring is fresh-only
// (no existing-document mutation, #163/#95), so both route through the create
// transaction: fail-closed refuse-if-exists unless --overwrite. The XLSX
// `office batch FILE SCRIPT --out OUT` mutation path is unchanged.

///|
let office_docx_author_max_script_bytes : Int = 4 * 1024 * 1024

///|
let office_docx_author_max_image_bytes : Int = 8 * 1024 * 1024

///|
let office_docx_author_max_total_image_bytes : Int = 32 * 1024 * 1024

///|
fn docx_create_result_json(
  output : String,
  result : @office_docx.DocxCreateResult,
) -> Json {
  Json::object({
    "schema": Json::string(@lib.SCHEMA_DOCX_CREATE_RESULT),
    "format": Json::string("docx"),
    "output": Json::string(bounded_text(output, 160)),
    "transaction": result.transaction.to_json(),
  })
}

///|
fn docx_batch_result_json(
  output : String,
  result : @office_docx.DocxAuthorResult,
) -> Json {
  Json::object({
    "schema": Json::string(@lib.SCHEMA_DOCX_BATCH_RESULT),
    "format": Json::string("docx"),
    "output": Json::string(bounded_text(output, 160)),
    "ops": Json::number(result.report.ops.to_double()),
    "comments": Json::number(result.report.comments.to_double()),
    "footnotes": Json::number(result.report.footnotes.to_double()),
    "endnotes": Json::number(result.report.endnotes.to_double()),
    "transaction": result.transaction.to_json(),
  })
}

///|
fn checked_docx_create_options(
  matches : @argparse.Matches,
  output : String,
) -> @transaction.CreateTransactionOptions raise CliFailure {
  @transaction.create_transaction_options(
    output,
    dry_run=matches.flags.get_or_default("dry-run", false),
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error =>
      raise unexpected_cli_failure(
        "office.docx.create_failed", "DOCX creation option validation", error,
      )
  }
}

///|
async fn run_create_docx(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "output")
  guard output.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office create docx requires a .docx destination",
      ),
    )
  }
  let options = checked_docx_create_options(matches, output)
  let result = @office_docx.create_blank_document(options) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.docx.create_failed", "DOCX creation", error,
      )
  }
  if matches.flags.get_or_default("json", false) {
    println(
      @lib.output_success(
        docx_create_result_json(output, result),
        warnings=transaction_warnings(result.transaction),
      ).stringify(indent=2),
    )
  } else {
    println(
      "\{human_transaction_status(result.transaction)}: blank DOCX -> \{human_text(output, 160)}",
    )
    print_transaction_warnings(result.transaction)
  }
}

///|
/// Loads the image bytes a fresh-authoring script references, bounded per image
/// and in aggregate. A missing or oversized asset is a typed refusal — nothing
/// is published.
async fn load_docx_authoring_images(
  script : @docx_batch.BatchScript,
) -> Map[String, Bytes] {
  let images : Map[String, Bytes] = Map([])
  let mut total = 0
  for path in script.image_paths() {
    let at = match script.image_reference(path) {
      Some(reference) => " (referenced at \{reference})"
      None => ""
    }
    let bytes = @afs.read_file(path).binary() catch {
      error =>
        raise CliFailure(
          @lib.protocol_error(
            "office.docx.author_asset_read_failed",
            "could not read image '\{bounded_text(path, 160)}'\{at}: \{error}",
          ),
        )
    }
    if bytes.length() > office_docx_author_max_image_bytes {
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.resource_limit",
          "image '\{bounded_text(path, 160)}'\{at} exceeds the \{office_docx_author_max_image_bytes}-byte per-image ceiling",
        ),
      )
    }
    total += bytes.length()
    if total > office_docx_author_max_total_image_bytes {
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.resource_limit",
          "the authoring script's images exceed the \{office_docx_author_max_total_image_bytes}-byte aggregate ceiling",
        ),
      )
    }
    images[path] = bytes
  }
  images
}

///|
async fn run_docx_batch(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "target")
  let script_path = required_value(matches, "script")
  guard output.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office batch --format docx requires a .docx destination",
      ),
    )
  }
  // Fresh DOCX authoring publishes to the positional destination; --out is an
  // XLSX-only mutation concept and is rejected here to keep the surface honest.
  guard optional_value(matches, "out") is None else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office batch --format docx does not accept --out (the destination is the positional target)",
      ),
    )
  }
  let options = checked_docx_create_options(matches, output)
  let script_bytes = read_bounded_file(
    script_path,
    office_docx_author_max_script_bytes,
    "office.docx.author_script_read_failed",
    "authoring script",
    limit_code="office.docx.resource_limit",
  )
  let script_text = @utf8.decode(script_bytes, ignore_bom=true) catch {
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.invalid_script", "the authoring script is not valid UTF-8",
        ),
      )
  }
  let script = @office_docx.parse_docx_authoring_script(script_text) catch {
    @office_docx.DocxAuthorParseError(reason) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.docx.invalid_script",
          "invalid authoring script: " + bounded_text(reason, 240),
        ),
      )
  }
  let images = load_docx_authoring_images(script)
  let result = @office_docx.author_document(options, script, images) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.docx.author_failed", "DOCX authoring", error,
      )
  }
  if matches.flags.get_or_default("json", false) {
    println(
      @lib.output_success(
        docx_batch_result_json(output, result),
        warnings=transaction_warnings(result.transaction),
      ).stringify(indent=2),
    )
  } else {
    println(
      "\{human_transaction_status(result.transaction)}: authored DOCX (\{result.report.ops} op(s)) -> \{human_text(output, 160)}",
    )
    print_transaction_warnings(result.transaction)
  }
}
