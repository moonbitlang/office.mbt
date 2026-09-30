///|
fn pptx_unsupported(command : String) -> CliFailure {
  CliFailure(
    @lib.protocol_error(
      "office.unsupported_format",
      "PPTX does not yet support office " + command,
    ),
  )
}

///|
fn pptx_create_command() -> @argparse.Command {
  Command(
    "pptx",
    about="Create a one-slide presentation atomically",
    positionals=[
      PositionArg(
        "output",
        about="new .pptx destination",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "title",
        long="title",
        about="optional title text (maximum 4096 UTF-16 code units)",
      ),
    ],
    flags=[
      FlagArg("dry-run", long="dry-run", about="validate without publishing"),
      FlagArg(
        "overwrite",
        long="overwrite",
        about="replace an existing regular-file destination",
      ),
      FlagArg("json", long="json", about="print office.output/1 JSON"),
    ],
  )
}

///|
async fn run_create_pptx(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "output")
  let options = @transaction.create_transaction_options(
    output,
    dry_run=matches.flags.get_or_default("dry-run", false),
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    error => raise transaction_failure(error)
  }
  let report = @office_pptx.create_presentation(
    options,
    title=optional_value(matches, "title").unwrap_or(""),
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if office_async_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.pptx.create_failed", "PPTX creation", error,
      )
  }
  if matches.flags.get_or_default("json", false) {
    println(
      @lib.output_success(
        Json::object({
          "schema": Json::string("office.pptx.create/1"),
          "format": Json::string("pptx"),
          "output": Json::string(bounded_text(output, 160)),
          "slide_count": Json::number(1),
          "transaction": report.to_json(),
        }),
        warnings=transaction_warnings(report),
      ).stringify(indent=2),
    )
  } else {
    println(
      "\{human_transaction_status(report)}: one-slide PPTX -> \{human_text(output, 160)}",
    )
    print_transaction_warnings(report)
  }
}

///|
fn pptx_read_payload(
  file : String,
  summary : @office_pptx.PresentationSummary,
  text_mode : Bool,
  offset : Int,
  limit : Int,
  maximum : Int,
) -> BoundedOfficePayload raise CliFailure {
  let records : Array[Json] = []
  let count = summary.slides.length()
  let data = Json::object({
    "schema": Json::string(
      if text_mode {
        "office.pptx.text/1"
      } else {
        "office.pptx.outline/1"
      },
    ),
    "file": Json::string(file),
    "format": Json::string("pptx"),
    "slide_count": Json::number(count.to_double()),
    "width_emu": Json::number(summary.width_emu.to_double()),
    "height_emu": Json::number(summary.height_emu.to_double()),
    "slides": Json::array(records),
  })
  if text_mode {
    let returned = if offset >= count {
      0
    } else if count - offset < limit {
      count - offset
    } else {
      limit
    }
    guard data is Object(fields) else {
      abort("PPTX payload must be an object")
    }
    fields["offset"] = Json::number(offset.to_double())
    fields["limit"] = Json::number(limit.to_double())
    fields["returned"] = Json::number(returned.to_double())
    fields["truncated"] = Json::boolean(offset + returned < count)
  }
  let payload = bounded_office_payload(data, [], maximum, "pptx")
  let start = if text_mode { offset } else { 0 }
  let end = if text_mode && offset + limit < count {
    offset + limit
  } else {
    count
  }
  for i = start; i < end; i = i + 1 {
    let slide = summary.slides[i]
    let record = if text_mode {
      Json::object({
        "index": Json::number(slide.index.to_double()),
        "part": Json::string(slide.part),
        "text": Json::string(slide.text),
        "notes": Json::string(slide.notes),
      })
    } else {
      Json::object({
        "index": Json::number(slide.index.to_double()),
        "part": Json::string(slide.part),
        "shape_count": Json::number(slide.shape_count.to_double()),
      })
    }
    payload.budget.reserve_array_item(record, !records.is_empty())
    records.push(record)
  }
  payload
}

///|
fn run_pptx_read(
  matches : @argparse.Matches,
  source : OfficeReadPackage,
  text_mode : Bool,
  max_elements : Int,
  max_output : Int,
  offset : Int,
  limit : Int,
) -> Unit raise {
  if optional_value(matches, "under") is Some(_) {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "PPTX text does not yet support --under; use --offset and --limit to select slides",
      ),
    )
  }
  let summary = @office_pptx.read_presentation(
    source.bytes,
    max_elements~,
    max_text_chars=if text_mode { max_output } else { 16 * 1024 * 1024 },
    cancelled=office_async_cancelled,
  ) catch {
    @lib.OfficeError::ResourceLimit(kind~, limit~, actual~) =>
      raise format_resource_failure("pptx", kind, limit, actual~)
    @docx_core.DocxError::ResourceLimit(limit~, ..) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.pptx.resource_limit",
          "PPTX XML exceeds its read budget: " + limit.message(),
        ),
      )
    error if office_async_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.pptx.read_failed", "PPTX reading", error,
      )
  }
  if matches.flags.get_or_default("json", false) {
    emit_docx_success(
      checked_office_json_output(
        pptx_read_payload(
          source.file,
          summary,
          text_mode,
          offset,
          limit,
          max_output,
        ),
      ),
    )
  } else {
    let output = StringBuilder()
    let budget = OfficeOutputBudget::new(max_output, format="pptx")
    let start = if text_mode { offset } else { 0 }
    let end = if text_mode && offset + limit < summary.slides.length() {
      offset + limit
    } else {
      summary.slides.length()
    }
    for i = start; i < end; i = i + 1 {
      let slide = summary.slides[i]
      if text_mode {
        ensure_office_output_limit(slide.text, max_output, "pptx")
        ensure_office_output_limit(slide.notes, max_output, "pptx")
      }
      let line = if text_mode {
        "Slide \{slide.index}\n\{human_text(slide.text, max_output)}\nNotes: \{human_text(slide.notes, max_output)}\n"
      } else {
        "Slide \{slide.index}\t\{human_text(slide.part, max_output)}\t\{slide.shape_count} shapes\n"
      }
      budget.reserve_plain_text(line)
      output.write_string(line)
    }
    emit_docx_success(
      checked_office_human_output(output.to_string(), max_output, "pptx"),
    )
  }
}
