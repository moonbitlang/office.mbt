// The `batch` subcommand: apply an `xlsx.batch/1` op script in one
// open → mutate → write cycle. All-or-nothing: parse and op failures leave
// the file untouched, zero ops writes nothing, and the final save goes
// through an exclusively-created unique temp file — written through the
// exclusive handle itself — then renamed over the resolved target, so a
// failed write cannot truncate the original and no other process can
// interpose on the temp path. (Rename replaces the inode: on POSIX the
// saved file is created owner-only, 0600 — never wider than the
// original; Windows ignores the mode and follows directory ACLs. ACLs
// and xattrs are not carried over. chmod afterwards for wider access.)

///|
async fn run_batch(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let script_path = arg(m, "script")
  let script = read_batch_script(script_path)
  let plan = @batch.parse_script_bytes(script) catch {
    BatchError(message) => raise CliError("error: " + message)
  }
  // Resolve a symlinked workbook to its target up front: the same resolved
  // path is opened and saved, so a link retargeted mid-run cannot make the
  // save clobber a different file than the one that was read.
  let target = resolve_save_target(file)
  let workbook = @lib.open_file(target)
  plan.apply(workbook) catch {
    BatchError(message) =>
      raise CliError("error: \{message}; \{file} not modified")
  }
  if flag(m, "dry-run") {
    println("dry-run ok: \{plan.operation_count()} op(s); \{file} not modified")
  } else if plan.operation_count() == 0 {
    // A zero-op script is a valid no-op: nothing to save, file untouched.
    println("applied 0 op(s) to \{file}")
  } else {
    write_file_replacing(target, @lib.write(workbook))
    println("applied \{plan.operation_count()} op(s) to \{file}")
  }
}

///|
/// Reads a regular script file through one pinned handle and rejects its size
/// before allocation. A size change during the read fails instead of silently
/// applying a stale prefix.
async fn read_batch_script(path : String) -> Bytes {
  let kind = @async/fs.kind(path) catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise CliError("error: could not inspect batch script \{path}")
  }
  if !(kind is Regular) {
    raise CliError("error: batch script is not a regular file: \{path}")
  }
  let file = @async/fs.open(
    path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  ) catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise CliError("error: could not open batch script \{path}")
  }
  defer file.close()
  if !(file.kind() is Regular) {
    raise CliError("error: batch script is not a regular file: \{path}")
  }
  let size = file.size() catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise CliError("error: could not size batch script \{path}")
  }
  if size < 0L || size > @batch.MAX_BATCH_SCRIPT_BYTES.to_int64() {
    raise CliError(
      "error: batch script exceeds the \{@batch.MAX_BATCH_SCRIPT_BYTES}-byte limit",
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
      _ => raise CliError("error: could not read batch script \{path}")
    }
    if count <= 0 || count > length - offset {
      raise CliError("error: could not read batch script \{path}")
    }
    offset = offset + count
  }
  let final_size = file.size() catch {
    error if @async.is_being_cancelled() => raise error
    _ => raise CliError("error: could not recheck batch script \{path}")
  }
  if final_size != size {
    raise CliError("error: batch script changed while it was read: \{path}")
  }
  @async.pause()
  buffer.unsafe_reinterpret_as_bytes()
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
  // Flush to stable storage before the rename: with delayed writeback, an
  // ENOSPC/EIO surfacing after a NoSync close could replace the last good
  // copy with a corrupt one.
  file.sync() catch {
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
  // Best-effort parent-directory sync so the rename itself is durable;
  // some platforms cannot fsync a directory, which is not worth failing
  // a successful save over.
  sync_parent_dir(target)
}

///|
async fn sync_parent_dir(target : String) -> Unit noraise {
  let dir = match target.rev_find("/") {
    Some(0) => "/"
    Some(index) => target[:index].to_owned()
    None => "."
  }
  let handle = @async/fs.open(dir, mode=ReadOnly) catch { _ => return }
  handle.sync() catch {
    _ => ()
  }
  handle.close()
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
