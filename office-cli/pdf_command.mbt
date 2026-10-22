///|
fn pdf_flag(matches : @argparse.Matches, name : String) -> Bool {
  if matches.flags.get_or_default(name, false) {
    return true
  }
  matches.subcommand.map_or(false, child => pdf_flag(child.1, name))
}

///|
fn pdf_operation(matches : @argparse.Matches) -> String {
  guard matches.subcommand is Some((name, child)) else { return "" }
  let action = pdf_operation(child)
  if action == "" {
    name
  } else {
    name + " " + action
  }
}

///|
async fn run_pdf(matches : @argparse.Matches) -> Unit {
  let mode = if pdf_flag(matches, "jsonl") {
    JsonLines
  } else if pdf_flag(matches, "json") {
    JsonDocument
  } else {
    Human
  }
  let dry_run = pdf_flag(matches, "dry-run")
  let overwrite = pdf_flag(matches, "overwrite")
  let result = @pdf_cli.execute(matches) catch {
    error if @async.is_being_cancelled() => raise error
    @pdf_cli.PdfCliError::Usage(message) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          bounded_text(message, 240),
        ),
      )
    @pdf_cli.PdfCliError::Runtime(message) =>
      raise CliFailure(
        @lib.protocol_error("office.pdf.failed", bounded_text(message, 240)),
      )
    error =>
      raise unexpected_cli_failure("office.pdf.failed", "PDF operation", error)
  }
  let fields : Map[String, Json] = {
    "schema": Json::string("office.pdf/1"),
    "operation": Json::string(pdf_operation(matches)),
    "result": result.data,
    "dry_run": Json::boolean(dry_run),
    "committed": Json::boolean(false),
  }
  if result.artifact is Some(artifact) {
    fields["output"] = Json::string(artifact.path)
    fields["result_size"] = Json::number(artifact.bytes.length().to_double())
    // Use the same create-new publication primitive as Office render/preview.
    // Explicit replacement removes the old destination before staging; it is
    // not an atomic swap and a subsequent failure can leave the path absent.
    if !overwrite && @afs.exists(artifact.path) {
      raise CliFailure(
        @lib.protocol_error(
          "office.transaction.output_exists",
          "destination already exists; use --overwrite to replace it",
          details=Json::object({ "output": Json::string(artifact.path) }),
        ),
      )
    }
    if !dry_run {
      if overwrite {
        @afs.remove(artifact.path) catch {
          _ => ()
        }
      }
      @transaction.atomic_write_new(artifact.path, artifact.bytes) catch {
        @transaction.TransactionError(..) as error =>
          raise transaction_failure(error)
        error => raise error
      }
      fields["committed"] = Json::boolean(true)
    }
  }
  let report = @lib.output_success(Json::object(fields))
  match mode {
    JsonDocument => println(report.stringify(indent=2))
    JsonLines => println(report.stringify())
    Human =>
      if result.artifact is Some(artifact) {
        if dry_run {
          println("validated dry run: \{human_text(artifact.path, 512)}")
        } else {
          println("wrote \{human_text(artifact.path, 512)}")
        }
      } else {
        @stdio.stdout.write(result.text)
      }
  }
}
