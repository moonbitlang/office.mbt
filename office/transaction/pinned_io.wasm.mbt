///|
/// Wasm hosts expose normalized paths but not portable directory descriptors.
/// Reports retain the explicit weaker-semantics warning for this target.
priv struct PublicationDirectory {
  path : String
}

///|
priv struct PublicationTemp {
  path : String
  file : @afs.File
  mut expected : Bytes
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
  if !@afs.exists(path) {
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
  if kind is Directory {
    2
  } else {
    1
  }
}

///|
fn publication_entries_same(
  left : PublicationDirectory,
  left_leaf : String,
  right : PublicationDirectory,
  right_leaf : String,
  output_path : String,
) -> Bool {
  let left_path = join_path(left.path, left_leaf)
  let right_path = join_path(right.path, right_leaf)
  ignore(output_path)
  left_path == right_path
}

///|
async fn publication_file_read(
  directory : PublicationDirectory,
  leaf : String,
  max_bytes : Int,
  phase : String,
) -> Bytes {
  let path = join_path(directory.path, leaf)
  let file = @afs.open(
    path,
    mode=ReadOnly,
    create_mode=OpenExisting,
    sync=NoSync,
  )
  defer file.close()
  let size = file.size()
  if size < 0L || size > max_bytes.to_int64() {
    raise resource_limit_error(phase, "package_bytes", max_bytes, max_bytes + 1)
  }
  let length = size.to_int()
  file.read_exactly_at(length, position=0L)
}

///|
async fn publication_temp_try_create(
  directory : PublicationDirectory,
  leaf : String,
  permission : Int,
  output_path : String,
) -> PublicationTemp? {
  let path = join_path(directory.path, leaf)
  let file = @afs.open(
    path,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission~,
    sync=NoSync,
  ) catch {
    @os_error.OSError(_) as error if error.is_EEXIST() => return None
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.temp_create_failed",
        "could not create a temporary file next to the destination: \{bounded_text(error.to_string(), 240)}",
        details=Json::object({
          "output": Json::string(bounded_text(output_path, 160)),
        }),
      )
  }
  Some({ path, file, expected: b"" })
}

///|
async fn publication_temp_write(temp : PublicationTemp, bytes : Bytes) -> Unit {
  let mut offset = 0
  let chunk_size = 1024 * 1024
  while offset < bytes.length() {
    let remaining = bytes.length() - offset
    let requested = if remaining < chunk_size { remaining } else { chunk_size }
    temp.file.write(bytes[offset:offset + requested]) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        raise transaction_error(
          "office.transaction.write_failed",
          "could not write temporary package: \{bounded_text(error.to_string(), 240)}",
        )
    }
    offset = offset + requested
  }
  temp.expected = bytes
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
  if size != temp.expected.length().to_int64() {
    return false
  }
  current.read_exactly_at(temp.expected.length(), position=0L) == temp.expected
}

///|
async fn publication_temp_publish(
  temp : PublicationTemp,
  destination_leaf : String,
  replace : Bool,
  output_path : String,
) -> Bool {
  if !publication_temp_identity_matches(temp) {
    raise transaction_error(
      "office.transaction.commit_failed", "temporary package identity changed before publication",
    )
  }
  temp.file.close()
  let destination = join_path(path_parent(temp.path), destination_leaf)
  @afs.rename(temp.path, destination, replace~) catch {
    error if @async.is_being_cancelled() => raise error
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
) -> Unit {
  @async.protect_from_cancel(
    () => {
      temp.file.close()
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
fn publication_directory_sync(_directory : PublicationDirectory) -> Bool {
  false
}

///|
fn publication_directory_close(_directory : PublicationDirectory) -> Unit {
  ()
}
