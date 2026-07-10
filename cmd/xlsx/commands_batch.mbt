// The `batch` subcommand: apply an `xlsx.batch/1` op script in one
// open → mutate → write cycle. All-or-nothing: parse and op failures leave
// the file untouched, zero ops writes nothing, and the final save goes
// through an exclusively-created unique temp file + rename so a failed
// write cannot truncate the original. (Rename replaces the inode: the
// saved file has this CLI's standard 0644 permissions; special modes,
// ACLs, and xattrs of the original are not carried over.)

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
  } else if ops.length() == 0 {
    // A zero-op script is a valid no-op: nothing to save, file untouched.
    println("applied 0 op(s) to \{file}")
  } else {
    write_file_replacing(file, @lib.write(workbook))
    println("applied \{ops.length()} op(s) to \{file}")
  }
}

///|
/// Saves `bytes` over `path` atomically: the bytes go to a unique,
/// exclusively-created temp file in the same directory, which is then
/// renamed over `path`. A predictable temp name would let an existing
/// sidecar be destroyed or a symlink redirect the write, so creation uses
/// `CreateNew` with a timestamped name and a short retry; the temp is
/// removed if anything after its creation fails.
async fn write_file_replacing(path : String, bytes : Bytes) -> Unit {
  let stamp = @env.now()
  let mut temp = ""
  let mut created = false
  for attempt in 0..<5 {
    let candidate = "\{path}.tmp-\{stamp}-\{attempt}"
    @async/fs.write_file(
      candidate,
      bytes,
      create_mode=@async/fs.CreateNew,
      permission=0o644,
    ) catch {
      err => {
        if attempt == 4 {
          raise err
        }
        continue
      }
    }
    temp = candidate
    created = true
    break
  }
  if !created {
    raise CliError("error: could not create a temp file next to \{path}")
  }
  @async/fs.rename(temp, path, replace=true) catch {
    err => {
      @async/fs.remove(temp) catch {
        _ => ()
      }
      raise err
    }
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
