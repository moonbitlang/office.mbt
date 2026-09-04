// `office delete-paragraph` — the N3b structural verb. The CLI half
// owns REQUEST policy: the target flag, the expect-text guard, and the
// output contract. Every structural refusal, the identity readback,
// and atomic publication live in the engine and the transaction.

///|
fn delete_paragraph_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("delete-paragraph") {
    Some(command) => command.summary
    None =>
      "Delete one direct body paragraph, refusing wherever the removal would dangle document state"
  }
  Command(
    "delete-paragraph",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="existing .docx package (never modified in place)",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "out",
        about="destination .docx; created atomically, nothing written on refusal",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "at",
        long="at",
        action=Append,
        about="the DIRECT body paragraph to delete: p[3], or stable p[id=\"…\"] resolved against the transaction snapshot",
      ),
      OptionArg(
        "expect-text",
        long="expect-text",
        action=Append,
        about="assert the target's full projection equals this text before deleting; a mismatch refuses with nothing written — the guard against deleting the wrong paragraph by ordinal",
      ),
    ],
    flags=[
      FlagArg(
        "dry-run",
        long="dry-run",
        about="run the identical resolve/plan/validate pipeline, exit as the real run would, write nothing",
      ),
      FlagArg(
        "overwrite",
        long="overwrite",
        about="replace an existing destination",
      ),
      docx_json_flag(),
    ],
  )
}

///|
fn delete_paragraph_report_json(
  file : String,
  output : String,
  at : String,
  expect_text : String?,
  dry_run : Bool,
  report : @office_docx.DocxDeleteParagraphReport,
  changed : Bool,
  transaction~ : Json,
) -> Json {
  Json::object({
    "schema": Json::string("office.docx.delete-paragraph/1"),
    "file": Json::string(file),
    "format": Json::string("docx"),
    "output": Json::string(output),
    "at": Json::string(at),
    "expect_text": match expect_text {
      Some(text) => Json::string(bounded_text(text, 160))
      None => Json::null()
    },
    "dry_run": Json::boolean(dry_run),
    "changed": Json::boolean(changed),
    "deleted": Json::object({
      "path": Json::string(report.path()),
      "para_id": match report.para_id() {
        Some(id) => Json::string(id)
        None => Json::null()
      },
      "paragraph_anchor_status": Json::string(report.anchor_status()),
      "text": Json::string(bounded_text(report.text(), 160)),
      // The record of what was destroyed must never look complete when
      // it is not: --expect-text compares the FULL projection, so a
      // caller feeding this field back needs to know it was cut.
      "text_truncated": Json::boolean(report.text().length() > 160),
    }),
    // Re-anchoring: after this publish the deleted path names the
    // SUCCESSOR — its stable identity, when it has one, is how an
    // agent keeps addressing it.
    "successor_para_id": match report.successor_para_id() {
      Some(id) => Json::string(id)
      None => Json::null()
    },
    "stories_scanned": Json::array([Json::string("/body")]),
    "transaction": transaction,
  })
}

///|
fn ensure_delete_paragraph_report_budget(
  record : Json,
  maximum : Int,
) -> Unit raise @transaction.TransactionError {
  ignore(bounded_docx_payload(record, [], maximum)) catch {
    _ =>
      raise @transaction.transaction_failure(
        "office.delete.report_too_large", "the JSON report for this deletion would exceed the output ceiling, so nothing was written; re-run without --json for the human summary",
      )
  }
}

///|
async fn run_delete_paragraph(matches : @argparse.Matches) -> Unit {
  reject_duplicate_scalar_options(matches, ["at", "expect-text"])
  let file = required_value(matches, "file")
  let output = required_value(matches, "out")
  let mode = office_validate_output_mode(matches)
  guard file.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office delete-paragraph requires a .docx document",
      ),
    )
  }
  guard output.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "the destination must end in .docx to match the edited format",
      ),
    )
  }
  let at = match optional_value(matches, "at") {
    Some(value) if value != "" => value
    Some(_) | None =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "delete-paragraph requires --at naming the DIRECT body paragraph: p[3], or stable p[id=\"…\"]",
        ),
      )
  }
  // The same request-boundary grammar the format verb settled: an
  // ordinal target must be exactly p[N]; a stable-looking target must
  // be exactly the single-segment stable shape. Everything else
  // refuses before any file is read. (The engine re-proves the ordinal
  // against the element tree; the snapshot resolves the stable form.)
  if at.has_prefix("p[id") {
    guard docx_stable_target_shape_valid(at) else {
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "--at '\{bounded_text(at, 80)}' is not the stable shape p[id=\"…\"]; pass the exact para_id spelling the read surfaces report",
        ),
      )
    }
  } else {
    guard format_scope_segment_kind(at) is Some("p") else {
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "--at '\{bounded_text(at, 80)}' is not a direct body paragraph; pass p[N] (the reader's own spelling) or a stable p[id=\"…\"]",
        ),
      )
    }
  }
  let expect_text = optional_value(matches, "expect-text")
  let dry_run = matches.flags.get_or_default("dry-run", false)
  let options = @transaction.transaction_options(
    file,
    output_path=output,
    dry_run~,
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    error => raise transaction_failure(error)
  }
  let preflight : ((@office_docx.DocxDeleteParagraphReport) -> Unit raise)? = match
    mode {
    Human => None
    JsonDocument | JsonLines =>
      Some((report : @office_docx.DocxDeleteParagraphReport) => {
        ensure_delete_paragraph_report_budget(
          delete_paragraph_report_json(
            file,
            output,
            at,
            expect_text,
            dry_run,
            report,
            true,
            transaction=Json::null(),
          ),
          docx_cli_default_max_output_chars -
          format_report_transaction_reserve(file, output),
        )
      })
  }
  let result = @office_docx.transact_docx_delete_paragraph(
    options,
    at~,
    expect_text?,
    preflight?,
  ) catch {
    error => raise map_delete_paragraph_failure(error)
  }
  let record = delete_paragraph_report_json(
    file,
    output,
    at,
    expect_text,
    dry_run,
    result.report(),
    result.transaction().changed,
    transaction=result.transaction().to_json(),
  )
  match mode {
    JsonDocument | JsonLines => {
      let warnings = []
      for warning in result.transaction().warning_records() {
        warnings.push(warning)
      }
      let payload = bounded_docx_payload(
        record, warnings, docx_cli_default_max_output_chars,
      ) catch {
        _ =>
          raise CliFailure(
            @lib.protocol_error(
              "office.delete.report_internal",
              "internal: the delete report exceeded the output ceiling despite the preflight; the edit itself completed and \{output} is valid",
            ),
          )
      }
      println(checked_office_json_output(payload))
    }
    Human => {
      let verb = if dry_run { "would delete" } else { "deleted" }
      println(
        "delete-paragraph: " +
        verb +
        " \{result.report().path()} (\"\{human_text(result.report().text(), 80)}\") -> " +
        human_text(output, 160),
      )
      for warning in result.transaction().warning_records() {
        println(
          "warning [\{human_text(warning.code, 160)}]: \{human_text(warning.message, 320)}",
        )
      }
    }
  }
}

///|
/// Map a transaction-layer failure to the CLI contract, preserving the
/// typed codes the transaction raises (the planner's refusal slugs, the
/// stable para_id refusals, `office.delete.expect_text_mismatch`, and
/// the shared preflight's protection codes).
fn map_delete_paragraph_failure(error : Error) -> CliFailure {
  match error {
    CliFailure(_) as failure => failure
    @transaction.TransactionError(_) as failure => transaction_failure(failure)
    _ =>
      unexpected_cli_failure(
        "office.delete_paragraph.failed", "delete-paragraph", error,
      )
  }
}
