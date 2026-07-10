// The `batch` subcommand: apply an `xlsx.batch/1` op script in one
// open → mutate → write cycle. All-or-nothing: parse and op failures leave
// the file untouched, zero ops writes nothing, and the final save goes
// through an exclusively-created unique temp file — written through the
// exclusive handle itself — then renamed over the resolved target, so a
// failed write cannot truncate the original and no other process can
// interpose on the temp path. (Rename replaces the inode: the saved file
// is created owner-only, 0600 — never wider than the original; ACLs and
// xattrs are not carried over. chmod afterwards for wider access.)

///|
async fn run_batch(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let script_path = arg(m, "script")
  let text = @encoding/utf8.decode(@async/fs.read_file(script_path).binary())
  check_number_token_lengths(script_path, text)
  let document = @json.parse(text) catch {
    err => raise CliError("error: \{script_path}: \{err}")
  }
  let ops = @batch.parse_script(document) catch {
    @batch.BatchError(message) => raise CliError("error: " + message)
  }
  // Resolve a symlinked workbook to its target up front: the same resolved
  // path is opened and saved, so a link retargeted mid-run cannot make the
  // save clobber a different file than the one that was read.
  let target = resolve_save_target(file)
  let workbook = @lib.open_file(target)
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
    write_file_replacing(target, @lib.write(workbook))
    println("applied \{ops.length()} op(s) to \{file}")
  }
}

///|
/// Rejects absurdly long numeric literals (outside strings) before the
/// JSON parser sees them: pathological forms such as an 800-digit
/// mantissa can lose their spelling in parsing and round incorrectly (a
/// known upstream gap), and no real script needs a 40+ character number.
fn check_number_token_lengths(
  script_path : String,
  text : String,
) -> Unit raise CliError {
  let mut in_string = false
  let mut escaped = false
  let mut run = 0
  for i in 0..<text.length() {
    let c = text[i]
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        in_string = false
      }
    } else if c == '"' {
      in_string = true
      run = 0
    } else if c is ('0'..='9' | '.' | 'e' | 'E' | '+' | '-') {
      run += 1
      if run > 40 {
        raise CliError(
          "error: \{script_path}: numeric literal longer than 40 characters",
        )
      }
    } else {
      run = 0
    }
  }
}

///|
/// Saves `bytes` over the (already-resolved) `target` atomically: the
/// bytes are written through the exclusively-created temp file's own
/// handle — never by reopening the path, which another process could
/// swap for a symlink — and the temp is renamed over the target. Only
/// true EEXIST collisions are retried; once the temp exists, every
/// subsequent failure removes it.
async fn write_file_replacing(target : String, bytes : Bytes) -> Unit {
  let stamp = @env.now()
  let mut temp = ""
  let mut handle : @async/fs.File? = None
  for attempt in 0..<5 {
    let candidate = "\{target}.tmp-\{stamp}-\{attempt}"
    let file = @async/fs.create(
      candidate,
      allow_existing=false,
      permission=0o600,
    ) catch {
      @os_error.OSError(_) as ose if ose.is_EEXIST() && attempt < 4 => continue
      err => raise err
    }
    temp = candidate
    handle = Some(file)
    break
  }
  let file = match handle {
    Some(file) => file
    None =>
      raise CliError("error: could not create a temp file next to \{target}")
  }
  // The exclusive handle is ours; from here on, any failure must close
  // the handle and remove the temp so no partial workbook bytes leak.
  file.write(bytes) catch {
    err => {
      file.close()
      @async/fs.remove(temp) catch {
        _ => ()
      }
      raise err
    }
  }
  file.close()
  @async/fs.rename(temp, target, replace=true) catch {
    err => {
      @async/fs.remove(temp) catch {
        _ => ()
      }
      raise err
    }
  }
}

///|
/// The real file the save should replace: symlinks resolve to their
/// target on native (resolution failures propagate — silently falling
/// back to the link path could redirect the save); the wasm sandbox has
/// no realpath (and practically no symlinks), so the path is used as-is.
#cfg(target="native")
async fn resolve_save_target(path : String) -> String {
  @async/fs.realpath(path)
}

///|
#cfg(target="wasm")
async fn resolve_save_target(path : String) -> String noraise {
  path
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
