// The `batch` subcommand: apply an `xlsx.batch/1` op script in one
// open → mutate → write cycle. All-or-nothing: parse and op failures leave
// the file untouched, and the final write goes through a same-directory
// temp file + rename so a failed write cannot truncate the original.

///|
async fn run_batch(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let script_path = arg(m, "script")
  let text = @encoding/utf8.decode(@async/fs.read_file(script_path).binary())
  let document = @json.parse(text) catch {
    err => raise CliError("error: \{script_path}: \{err}")
  }
  let ops = @batch.parse_script(document) catch {
    @batch.BatchError(message) => raise CliError("error: " + message)
  }
  let workbook = @lib.open_file(file)
  for index, op in ops {
    @batch.apply_op(workbook, op) catch {
      err =>
        raise CliError(
          "error: op \{index} (\{op.name()}): \{strip_error_prefix(err)}; \{file} not modified",
        )
    }
  }
  if flag(m, "dry-run") {
    println("dry-run ok: \{ops.length()} op(s); \{file} not modified")
  } else {
    let bytes = @lib.write(workbook)
    // Temp-then-rename keeps the original intact if this write fails.
    let temp = file + ".batch-tmp"
    write_file(temp, bytes)
    @async/fs.rename(temp, file, replace=true)
    println("applied \{ops.length()} op(s) to \{file}")
  }
}

///|
/// Handler errors that are already CLI-formatted start with "error: ";
/// inside an op-indexed message that prefix would read twice.
fn strip_error_prefix(err : Error) -> String {
  let message = "\{err}"
  if message.has_prefix("error: ") {
    message["error: ".length():].to_owned()
  } else {
    message
  }
}
