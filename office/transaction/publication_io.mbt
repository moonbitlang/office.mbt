///|
/// Publication I/O is intentionally built on `moonbitlang/async`. Keeping one
/// implementation for native and Wasm preserves cancellation behavior and
/// avoids a second, manually managed native ownership/concurrency runtime.
priv struct PublicationDirectory {
  path : String
}

///|
priv struct PublicationTemp {
  path : String
  file : @afs.File
  mut expected : Bytes
  mut written : Int
  mut final_permission_applied : Bool
}

///|
#cfg(all(target="native", platform="windows"))
async fn publication_set_permission(_path : String, _permission : Int) -> Unit {
  // Windows inherits the destination directory ACL; async chmod is unsupported.
  ()
}

///|
#cfg(all(target="native", not(platform="windows")))
async fn publication_set_permission(path : String, permission : Int) -> Unit {
  @afs.chmod(path, permission)
}

///|
#cfg(target="wasm")
async fn publication_set_permission(path : String, permission : Int) -> Unit {
  @afs.chmod(path, permission)
}

///|
async fn publication_directory_open(
  path : String,
  _output_path : String,
) -> PublicationDirectory {
  let kind = @afs.kind(path) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.destination_parent_failed",
        "could not open destination directory '\{bounded_text(path, 160)}': \{bounded_text(error.to_string(), 240)}",
      )
  }
  if !(kind is Directory) {
    raise transaction_error(
      "office.transaction.destination_parent_failed", "resolved destination parent is not a directory",
    )
  }
  { path, }
}

///|
fn publication_directory_duplicate(
  directory : PublicationDirectory,
  _output_path : String,
) -> PublicationDirectory {
  { path: directory.path }
}

///|
async fn publication_entry_kind(
  directory : PublicationDirectory,
  leaf : String,
  output_path : String,
) -> Int {
  let path = join_path(directory.path, leaf)
  let exists = @afs.exists(path) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.destination_check_failed",
        "could not inspect destination '\{bounded_text(output_path, 160)}': \{bounded_text(error.to_string(), 240)}",
      )
  }
  if !exists {
    return 0
  }
  let kind = @afs.kind(path) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.destination_check_failed",
        "could not inspect destination '\{bounded_text(output_path, 160)}': \{bounded_text(error.to_string(), 240)}",
      )
  }
  match kind {
    Regular => 1
    Directory => 2
    _ => 3
  }
}

///|
fn publication_entries_same(
  left : PublicationDirectory,
  left_leaf : String,
  right : PublicationDirectory,
  right_leaf : String,
  _output_path : String,
) -> Bool {
  join_path(left.path, left_leaf) == join_path(right.path, right_leaf)
}

///|
async fn publication_read_exactly(file : @afs.File, length : Int) -> Bytes {
  let buffer = FixedArray::make(length, b'\x00')
  let mut offset = 0
  while offset < length {
    let count = file.read_at(
      buffer,
      position=offset.to_int64(),
      offset~,
      len=length - offset,
    )
    if count <= 0 || count > length - offset {
      fail("asynchronous file read made invalid progress")
    }
    offset = offset + count
  }
  buffer.unsafe_reinterpret_as_bytes()
}

///|
async fn publication_file_read(
  directory : PublicationDirectory,
  leaf : String,
  max_bytes : Int,
  phase : String,
) -> Bytes {
  let path = join_path(directory.path, leaf)
  let kind = @afs.kind(path) catch {
    error if @async.is_being_cancelled() => raise error
    error => raise error
  }
  if !(kind is Regular) {
    raise transaction_error(
      "office.transaction.file_read_failed", "input must be a regular file",
    )
  }
  let file = @afs.open(
    path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  )
  defer file.close()
  if !(file.kind() is Regular) {
    raise transaction_error(
      "office.transaction.file_read_failed", "input must be a regular file",
    )
  }
  let size = file.size()
  if size < 0L || size > max_bytes.to_int64() {
    raise resource_limit_error(phase, "package_bytes", max_bytes, max_bytes + 1)
  }
  publication_read_exactly(file, size.to_int())
}

///|
async fn publication_temp_try_create(
  directory : PublicationDirectory,
  leaf : String,
  output_path : String,
  initial_permission? : Int = 0o600,
  fail_secure_permission? : Bool = false,
  fail_cleanup? : Bool = false,
  secure_release? : String,
) -> PublicationTemp? {
  let path = join_path(directory.path, leaf)
  let file = @async.protect_from_cancel(
    () => {
      @afs.open(
        path,
        mode=ReadWrite,
        create_mode=CreateNew,
        permission=initial_permission,
        sync=NoSync,
      )
    },
    resume_on_cancel=true,
  ) catch {
    error if @async.is_being_cancelled() => {
      @async.pause()
      raise error
    }
    @os_error.OSError(_) as error if error.is_EEXIST() => return None
    error =>
      raise transaction_error(
        "office.transaction.temp_create_failed",
        "could not create a temporary file next to the destination: \{bounded_text(error.to_string(), 240)}",
        details=Json::object({
          "output": Json::string(bounded_text(output_path, 160)),
        }),
      )
  }
  let temp = {
    path,
    file,
    expected: b"",
    written: 0,
    final_permission_applied: false,
  }
  @async.protect_from_cancel(
    () => {
      match secure_release {
        Some(release) => {
          @afs.write_file(
            release + ".ready",
            b"ready",
            create_mode=CreateNew,
            permission=0o600,
          )
          while !@afs.exists(release) {
            @async.pause()
          }
        }
        None => ()
      }
      if fail_secure_permission {
        raise transaction_error(
          "office.transaction.temp_create_failed", "injected staging-permission hardening failure",
        )
      }
      publication_set_permission(path, 0o600)
    },
    resume_on_cancel=true,
  ) catch {
    error => {
      publication_temp_cleanup(temp, output_path, fail_remove=fail_cleanup)
      if @async.is_being_cancelled() {
        @async.pause()
        raise error
      }
      raise transaction_error(
        "office.transaction.temp_create_failed",
        "could not secure temporary-file staging permissions: \{bounded_text(error.to_string(), 240)}",
        details=Json::object({
          "output": Json::string(bounded_text(output_path, 160)),
        }),
      )
    }
  }
  Some(temp)
}

///|
async fn publication_temp_write(
  temp : PublicationTemp,
  bytes : Bytes,
  fail_after_bytes~ : Int?,
  stall_after_bytes~ : Int?,
) -> Unit {
  temp.expected = bytes
  temp.written = 0
  let mut offset = 0
  let chunk_size = 1024 * 1024
  while offset < bytes.length() {
    let remaining = bytes.length() - offset
    let requested = if remaining < chunk_size { remaining } else { chunk_size }
    @async.protect_from_cancel(() => {
      let count = temp.file.write_once(bytes, offset~, len=requested)
      if count <= 0 || count > requested {
        raise transaction_error(
          "office.transaction.write_failed", "temporary package write made invalid progress",
        )
      }
      offset = offset + count
      temp.written = offset
    }) catch {
      error if @async.is_being_cancelled() => raise error
      TransactionError(..) as error => raise error
      error =>
        raise transaction_error(
          "office.transaction.write_failed",
          "could not write temporary package: \{bounded_text(error.to_string(), 240)}",
        )
    }
    match fail_after_bytes {
      Some(limit) if temp.written >= limit =>
        raise transaction_error(
          "office.transaction.write_failed", "injected failure after a partial asynchronous write",
        )
      _ => ()
    }
    match stall_after_bytes {
      Some(limit) if temp.written >= limit => @async.sleep(60_000)
      _ => ()
    }
  }
}

///|
async fn publication_temp_sync(temp : PublicationTemp) -> Unit {
  temp.file.sync() catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.sync_failed",
        "could not sync temporary package: \{bounded_text(error.to_string(), 240)}",
      )
  }
}

///|
async fn publication_temp_identity_matches(temp : PublicationTemp) -> Bool {
  let current = @afs.open(
    temp.path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  )
  defer current.close()
  let size = current.size()
  if size != temp.written.to_int64() {
    return false
  }
  if !(current.kind() is Regular) {
    return false
  }
  publication_read_exactly(current, temp.written) ==
  temp.expected[:temp.written].to_owned()
}

///|
async fn publication_temp_publish(
  temp : PublicationTemp,
  destination_leaf : String,
  replace : Bool,
  output_path : String,
  permission : Int,
) -> Bool {
  if temp.written != temp.expected.length() ||
    !publication_temp_identity_matches(temp) {
    raise transaction_error(
      "office.transaction.commit_failed", "temporary package identity changed before publication",
    )
  }
  let destination = join_path(path_parent(temp.path), destination_leaf)
  // Do not begin the non-interruptible permission/sync/rename boundary with a
  // pending cancellation. Once it starts, finish it so callers always know
  // whether the atomic rename committed.
  @async.pause()
  @async.protect_from_cancel(
    () => {
      try {
        publication_set_permission(temp.path, permission) catch {
          error =>
            raise transaction_error(
              "office.transaction.commit_failed",
              "could not apply destination permissions: \{bounded_text(error.to_string(), 240)}",
            )
        }
        temp.final_permission_applied = true
        temp.file.sync() catch {
          error =>
            raise transaction_error(
              "office.transaction.sync_failed",
              "could not sync final package metadata: \{bounded_text(error.to_string(), 240)}",
            )
        }
        temp.file.close()
        @afs.rename(temp.path, destination, replace~) catch {
          @os_error.OSError(_) as error if !replace && error.is_EEXIST() =>
            raise transaction_error(
              "office.transaction.output_exists",
              "destination appeared before the atomic publish completed",
              details=Json::object({
                "output": Json::string(bounded_text(output_path, 160)),
              }),
            )
          error =>
            raise transaction_error(
              "office.transaction.commit_failed",
              "could not atomically publish destination: \{bounded_text(error.to_string(), 240)}",
              details=Json::object({
                "output": Json::string(bounded_text(output_path, 160)),
              }),
            )
        }
      } catch {
        error => {
          temp.file.close()
          let restored = try {
            publication_set_permission(temp.path, 0o600)
            true
          } catch {
            _ => false
          }
          if restored {
            temp.final_permission_applied = false
          }
          raise error
        }
      }
    },
    resume_on_cancel=true,
  )
  true
}

///|
async fn publication_temp_substitute(temp : PublicationTemp) -> Unit {
  let moved = temp.path + ".owned"
  @afs.rename(temp.path, moved, replace=false)
  @afs.write_file(
    temp.path,
    b"foreign",
    create_mode=CreateNew,
    permission=0o600,
  )
}

///|
async fn publication_temp_cleanup(
  temp : PublicationTemp,
  output_path : String,
  fail_remove? : Bool = false,
) -> Unit {
  @async.protect_from_cancel(
    () => {
      temp.file.close()
      if temp.final_permission_applied {
        publication_set_permission(temp.path, 0o600) catch {
          error =>
            raise transaction_error(
              "office.transaction.cleanup_failed",
              "could not restore temporary-file staging permissions: \{bounded_text(error.to_string(), 240)}",
            )
        }
        temp.final_permission_applied = false
      }
      let matches = publication_temp_identity_matches(temp) catch { _ => false }
      if !matches {
        raise transaction_error(
          "office.transaction.cleanup_failed",
          "temporary package identity changed; refusing to delete a foreign path",
          details=Json::object({
            "output": Json::string(bounded_text(output_path, 160)),
          }),
        )
      }
      if fail_remove {
        raise transaction_error(
          "office.transaction.cleanup_failed",
          "injected temporary-package removal failure",
          details=Json::object({
            "output": Json::string(bounded_text(output_path, 160)),
          }),
        )
      }
      @afs.remove(temp.path) catch {
        error =>
          raise transaction_error(
            "office.transaction.cleanup_failed",
            "could not remove temporary package: \{bounded_text(error.to_string(), 240)}",
            details=Json::object({
              "output": Json::string(bounded_text(output_path, 160)),
            }),
          )
      }
    },
    resume_on_cancel=true,
  )
}

///|
fn publication_temp_close(temp : PublicationTemp) -> Unit {
  temp.file.close()
}

///|
async fn publication_directory_sync(directory : PublicationDirectory) -> Bool {
  let file = @afs.open(
    directory.path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  ) catch {
    _ => return false
  }
  defer file.close()
  file.sync() catch {
    _ => return false
  }
  true
}

///|
fn publication_directory_close(_directory : PublicationDirectory) -> Unit {
  ()
}
