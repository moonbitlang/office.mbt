///|
type NativePublicationDirectory = UInt64

///|
type NativePublicationTemp = UInt64

///|
type NativeSyncTask = UInt64

///|
type NativeReadTask = UInt64

///|
type NativeWriteTask = UInt64

///|
priv struct PublicationDirectory {
  state : NativePublicationDirectory
  path : String
}

///|
priv struct PublicationTemp {
  state : NativePublicationTemp
}

///|
#borrow(path)
extern "C" fn publication_directory_open_ffi(
  path : Bytes,
) -> NativePublicationDirectory = "bobzhang_office_transaction_directory_open"

///|
extern "C" fn publication_directory_duplicate_ffi(
  directory : NativePublicationDirectory,
) -> NativePublicationDirectory = "bobzhang_office_transaction_directory_duplicate"

///|
extern "C" fn publication_directory_ok_ffi(
  directory : NativePublicationDirectory,
) -> Bool = "bobzhang_office_transaction_directory_ok"

///|
extern "C" fn publication_directory_error_ffi(
  directory : NativePublicationDirectory,
) -> Int = "bobzhang_office_transaction_directory_error"

///|
#borrow(leaf)
extern "C" fn publication_read_start_ffi(
  directory : NativePublicationDirectory,
  leaf : Bytes,
  max_bytes : Int,
) -> NativeReadTask = "bobzhang_office_transaction_read_start"

///|
extern "C" fn publication_read_poll_ffi(task : NativeReadTask) -> Int = "bobzhang_office_transaction_read_poll"

///|
extern "C" fn publication_read_error_ffi(task : NativeReadTask) -> Int = "bobzhang_office_transaction_read_error"

///|
extern "C" fn publication_read_length_ffi(task : NativeReadTask) -> Int = "bobzhang_office_transaction_read_length"

///|
#borrow(destination)
extern "C" fn publication_read_copy_ffi(
  task : NativeReadTask,
  destination : FixedArray[Byte],
  offset : Int,
  length : Int,
) -> Bool = "bobzhang_office_transaction_read_copy"

///|
extern "C" fn publication_read_close_ffi(task : NativeReadTask) -> Unit = "bobzhang_office_transaction_read_close"

///|
#borrow(leaf)
extern "C" fn publication_directory_entry_kind_ffi(
  directory : NativePublicationDirectory,
  leaf : Bytes,
) -> Int = "bobzhang_office_transaction_directory_entry_kind"

///|
#borrow(left_leaf, right_leaf)
extern "C" fn publication_entries_same_ffi(
  left : NativePublicationDirectory,
  left_leaf : Bytes,
  right : NativePublicationDirectory,
  right_leaf : Bytes,
) -> Int = "bobzhang_office_transaction_entries_same"

///|
extern "C" fn publication_temp_create_ffi(
  directory : NativePublicationDirectory,
  permission : Int,
) -> NativePublicationTemp = "bobzhang_office_transaction_temp_create"

///|
extern "C" fn publication_temp_ok_ffi(temp : NativePublicationTemp) -> Bool = "bobzhang_office_transaction_temp_ok"

///|
extern "C" fn publication_temp_error_ffi(temp : NativePublicationTemp) -> Int = "bobzhang_office_transaction_temp_error"

///|
#owned(bytes)
extern "C" fn publication_temp_write_start_ffi(
  temp : NativePublicationTemp,
  bytes : Bytes,
) -> NativeWriteTask = "bobzhang_office_transaction_temp_write_start"

///|
extern "C" fn publication_write_poll_ffi(task : NativeWriteTask) -> Int = "bobzhang_office_transaction_write_poll"

///|
extern "C" fn publication_write_error_ffi(task : NativeWriteTask) -> Int = "bobzhang_office_transaction_write_error"

///|
extern "C" fn publication_write_close_ffi(task : NativeWriteTask) -> Unit = "bobzhang_office_transaction_write_close"

///|
extern "C" fn publication_temp_sync_start_ffi(
  temp : NativePublicationTemp,
) -> NativeSyncTask = "bobzhang_office_transaction_temp_sync_start"

///|
extern "C" fn publication_directory_sync_start_ffi(
  directory : NativePublicationDirectory,
) -> NativeSyncTask = "bobzhang_office_transaction_directory_sync_start"

///|
extern "C" fn publication_sync_poll_ffi(task : NativeSyncTask) -> Int = "bobzhang_office_transaction_sync_poll"

///|
extern "C" fn publication_sync_error_ffi(task : NativeSyncTask) -> Int = "bobzhang_office_transaction_sync_error"

///|
extern "C" fn publication_sync_close_ffi(task : NativeSyncTask) -> Unit = "bobzhang_office_transaction_sync_close"

///|
#borrow(destination_leaf)
extern "C" fn publication_temp_publish_ffi(
  temp : NativePublicationTemp,
  destination_leaf : Bytes,
  replace : Bool,
) -> Int = "bobzhang_office_transaction_temp_publish"

///|
extern "C" fn publication_temp_cleanup_ffi(
  temp : NativePublicationTemp,
) -> Bool = "bobzhang_office_transaction_temp_cleanup"

///|
extern "C" fn publication_temp_substitute_ffi(
  temp : NativePublicationTemp,
) -> Bool = "bobzhang_office_transaction_temp_substitute"

///|
extern "C" fn publication_temp_close_ffi(temp : NativePublicationTemp) -> Unit = "bobzhang_office_transaction_temp_close"

///|
extern "C" fn publication_directory_close_ffi(
  directory : NativePublicationDirectory,
) -> Unit = "bobzhang_office_transaction_directory_close"

///|
fn publication_error_is_exists(error : Int) -> Bool {
  @os_error.OSError(error, context="native Office publication").is_EEXIST()
}

///|
fn native_operation_message(operation : String, error : Int) -> String {
  "\{operation} failed with host error \{error}"
}

///|
fn publication_directory_from_state(
  state : NativePublicationDirectory,
  path : String,
  output_path : String,
) -> PublicationDirectory raise TransactionError {
  if !publication_directory_ok_ffi(state) {
    let error = publication_directory_error_ffi(state)
    publication_directory_close_ffi(state)
    raise transaction_error(
      "office.transaction.destination_parent_failed",
      native_operation_message("opening a pinned directory", error),
      details=Json::object({
        "directory": Json::string(bounded_text(path, 160)),
        "output": Json::string(bounded_text(output_path, 160)),
        "host_error": Json::number(error.to_double()),
      }),
    )
  }
  { state, path }
}

///|
fn publication_directory_open(
  path : String,
  output_path : String,
) -> PublicationDirectory raise TransactionError {
  // Open immediately after path resolution. All later checks and publication
  // are relative to this pinned identity.
  publication_directory_from_state(
    publication_directory_open_ffi(@utf8.encode(path)),
    path,
    output_path,
  )
}

///|
fn publication_directory_duplicate(
  directory : PublicationDirectory,
  output_path : String,
) -> PublicationDirectory raise TransactionError {
  publication_directory_from_state(
    publication_directory_duplicate_ffi(directory.state),
    directory.path,
    output_path,
  )
}

///|
fn publication_entry_kind(
  directory : PublicationDirectory,
  leaf : String,
  output_path : String,
) -> Int raise TransactionError {
  let kind = publication_directory_entry_kind_ffi(
    directory.state,
    @utf8.encode(leaf),
  )
  if kind < 0 {
    let error = publication_directory_error_ffi(directory.state)
    raise transaction_error(
      "office.transaction.destination_check_failed",
      native_operation_message("checking the pinned destination", error),
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
        "host_error": Json::number(error.to_double()),
      }),
    )
  }
  kind
}

///|
fn publication_entries_same(
  left : PublicationDirectory,
  left_leaf : String,
  right : PublicationDirectory,
  right_leaf : String,
  output_path : String,
) -> Bool raise TransactionError {
  let same = publication_entries_same_ffi(
    left.state,
    @utf8.encode(left_leaf),
    right.state,
    @utf8.encode(right_leaf),
  )
  if same < 0 {
    let error = publication_directory_error_ffi(right.state)
    raise transaction_error(
      "office.transaction.destination_check_failed",
      native_operation_message("comparing pinned file identities", error),
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
        "host_error": Json::number(error.to_double()),
      }),
    )
  }
  same == 1
}

///|
async fn publication_file_read(
  directory : PublicationDirectory,
  leaf : String,
  max_bytes : Int,
  phase : String,
) -> Bytes {
  let task = publication_read_start_ffi(
    directory.state,
    @utf8.encode(leaf),
    max_bytes,
  )
  if task == 0 {
    raise transaction_error(
      "office.transaction.file_read_failed", "could not start pinned asynchronous source read",
    )
  }
  defer publication_read_close_ffi(task)
  let mut status = publication_read_poll_ffi(task)
  while status == 0 {
    @async.pause()
    status = publication_read_poll_ffi(task)
  }
  let length = publication_read_length_ffi(task)
  if status < 0 {
    if length > max_bytes {
      raise resource_limit_error(phase, "package_bytes", max_bytes, length)
    }
    let error = publication_read_error_ffi(task)
    raise @os_error.OSError(error, context="reading a pinned Office source")
  }
  let buffer = FixedArray::make(length, b'\x00')
  let mut offset = 0
  let chunk_size = 1024 * 1024
  while offset < length {
    let remaining = length - offset
    let count = if remaining < chunk_size { remaining } else { chunk_size }
    if !publication_read_copy_ffi(task, buffer, offset, count) {
      raise transaction_error(
        "office.transaction.file_read_failed", "could not copy pinned source bytes from the I/O worker",
      )
    }
    offset = offset + count
    @async.pause()
  }
  buffer.unsafe_reinterpret_as_bytes()
}

///|
fn publication_temp_try_create(
  directory : PublicationDirectory,
  _leaf : String,
  permission : Int,
  output_path : String,
) -> PublicationTemp? raise TransactionError {
  let state = publication_temp_create_ffi(directory.state, permission)
  if !publication_temp_ok_ffi(state) {
    let error = publication_temp_error_ffi(state)
    publication_temp_close_ffi(state)
    if publication_error_is_exists(error) {
      return None
    }
    raise transaction_error(
      "office.transaction.temp_create_failed",
      native_operation_message("creating a random temporary file", error),
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
        "host_error": Json::number(error.to_double()),
      }),
    )
  }
  Some({ state, })
}

///|
async fn publication_temp_write(temp : PublicationTemp, bytes : Bytes) -> Unit {
  let task = publication_temp_write_start_ffi(temp.state, bytes)
  if task == 0 {
    raise transaction_error(
      "office.transaction.write_failed", "could not start asynchronous temporary-file write",
    )
  }
  defer publication_write_close_ffi(task)
  let mut status = publication_write_poll_ffi(task)
  while status == 0 {
    @async.pause()
    status = publication_write_poll_ffi(task)
  }
  if status < 0 {
    let error = publication_write_error_ffi(task)
    raise transaction_error(
      "office.transaction.write_failed",
      native_operation_message("writing the temporary package", error),
      details=Json::object({ "host_error": Json::number(error.to_double()) }),
    )
  }
}

///|
async fn publication_temp_sync(temp : PublicationTemp) -> Unit {
  let task = publication_temp_sync_start_ffi(temp.state)
  if task == 0 {
    raise transaction_error(
      "office.transaction.sync_failed", "could not start asynchronous temporary-file sync",
    )
  }
  defer publication_sync_close_ffi(task)
  let mut status = publication_sync_poll_ffi(task)
  while status == 0 {
    @async.pause()
    status = publication_sync_poll_ffi(task)
  }
  if status < 0 {
    let error = publication_sync_error_ffi(task)
    raise transaction_error(
      "office.transaction.sync_failed",
      native_operation_message("syncing the temporary package", error),
    )
  }
}

///|
fn publication_temp_publish(
  temp : PublicationTemp,
  destination_leaf : String,
  replace : Bool,
  output_path : String,
) -> Bool raise TransactionError {
  let status = publication_temp_publish_ffi(
    temp.state,
    @utf8.encode(destination_leaf),
    replace,
  )
  if status > 0 {
    // A portable hard-link fallback can commit before its private source link
    // is removed. Retry that cleanup and surface a report warning if it remains.
    return status == 1 || publication_temp_cleanup_ffi(temp.state)
  }
  let error = publication_temp_error_ffi(temp.state)
  if !replace && publication_error_is_exists(error) {
    raise transaction_error(
      "office.transaction.output_exists",
      "destination appeared before the atomic publish completed",
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
      }),
    )
  }
  raise transaction_error(
    "office.transaction.commit_failed",
    native_operation_message("atomically publishing the destination", error),
    details=Json::object({
      "output": Json::string(bounded_text(output_path, 160)),
      "host_error": Json::number(error.to_double()),
    }),
  )
}

///|
fn publication_temp_substitute(
  temp : PublicationTemp,
) -> Unit raise TransactionError {
  if !publication_temp_substitute_ffi(temp.state) {
    let error = publication_temp_error_ffi(temp.state)
    raise transaction_error(
      "office.transaction.commit_failed",
      native_operation_message("injecting temporary-file substitution", error),
    )
  }
}

///|
async fn publication_temp_cleanup(
  temp : PublicationTemp,
  output_path : String,
) -> Unit {
  @async.protect_from_cancel(
    () => {
      let cleaned = publication_temp_cleanup_ffi(temp.state)
      let error = publication_temp_error_ffi(temp.state)
      publication_temp_close_ffi(temp.state)
      if !cleaned {
        raise transaction_error(
          "office.transaction.cleanup_failed",
          native_operation_message(
            "removing the owned temporary package", error,
          ),
          details=Json::object({
            "output": Json::string(bounded_text(output_path, 160)),
            "host_error": Json::number(error.to_double()),
          }),
        )
      }
    },
    resume_on_cancel=true,
  )
}

///|
fn publication_temp_close(temp : PublicationTemp) -> Unit {
  publication_temp_close_ffi(temp.state)
}

///|
async fn publication_directory_sync(directory : PublicationDirectory) -> Bool {
  let task = publication_directory_sync_start_ffi(directory.state)
  if task == 0 {
    return false
  }
  defer publication_sync_close_ffi(task)
  let mut status = publication_sync_poll_ffi(task)
  while status == 0 {
    @async.pause()
    status = publication_sync_poll_ffi(task)
  }
  status > 0
}

///|
fn publication_directory_close(directory : PublicationDirectory) -> Unit {
  publication_directory_close_ffi(directory.state)
}
