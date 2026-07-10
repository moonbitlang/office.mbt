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
/// Saves `bytes` over `path` atomically. The path is resolved first so a
/// symlinked workbook updates its target (keeping "save in place"
/// semantics) instead of being replaced by a regular file. The bytes go
/// to a unique, exclusively-created temp file in the target's directory,
/// which is then renamed over the target. Only name collisions are
/// retried; once the temp exists, every subsequent failure removes it.
async fn write_file_replacing(path : String, bytes : Bytes) -> Unit {
  let target = resolve_save_target(path)
  let stamp = @env.now()
  let mut temp = ""
  for attempt in 0..<5 {
    let candidate = "\{target}.tmp-\{stamp}-\{attempt}"
    let file = @async/fs.create(
      candidate,
      allow_existing=false,
      permission=0o644,
    ) catch {
      err => {
        // Retry only when the name is taken; any other failure aborts
        // before a temp exists, so there is nothing to clean up.
        let collided = (try? @async/fs.kind(candidate, follow_symlink=false))
          is Ok(_)
        if collided && attempt < 4 {
          continue
        }
        raise err
      }
    }
    file.close()
    temp = candidate
    break
  }
  if temp == "" {
    raise CliError("error: could not create a temp file next to \{target}")
  }
  // The exclusive claim above is ours; from here on, any failure must
  // remove the temp so no partial workbook bytes are left behind.
  write_file(temp, bytes) catch {
    err => {
      @async/fs.remove(temp) catch {
        _ => ()
      }
      raise err
    }
  }
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

///|
/// The real file the save should replace: symlinks resolve to their
/// target on native; the wasm sandbox has no realpath (and practically
/// no symlinks), so the path is used as-is there.
#cfg(target="native")
async fn resolve_save_target(path : String) -> String noraise {
  @async/fs.realpath(path) catch {
    _ => path
  }
}

///|
#cfg(target="wasm")
async fn resolve_save_target(path : String) -> String noraise {
  path
}
