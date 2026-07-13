///|
/// A native directory identity pinned by an operating-system handle. The
/// primitive value is an opaque pointer to state owned and explicitly released
/// by this package.
type PublicationDirectory = UInt64

///|
/// An exclusively-created temporary file plus a duplicate of its pinned parent
/// handle. Transaction code explicitly closes or cleans this opaque state on
/// every path.
type PublicationTemp = UInt64

///|
#borrow(path)
extern "C" fn publication_directory_open_ffi(
  path : Bytes,
) -> PublicationDirectory = "bobzhang_office_transaction_directory_open"

///|
extern "C" fn publication_directory_ok_ffi(
  directory : PublicationDirectory,
) -> Bool = "bobzhang_office_transaction_directory_ok"

///|
extern "C" fn publication_directory_error_ffi(
  directory : PublicationDirectory,
) -> Int = "bobzhang_office_transaction_directory_error"

///|
#borrow(leaf)
extern "C" fn publication_temp_create_ffi(
  directory : PublicationDirectory,
  leaf : Bytes,
  permission : Int,
) -> PublicationTemp = "bobzhang_office_transaction_temp_create"

///|
extern "C" fn publication_temp_ok_ffi(temp : PublicationTemp) -> Bool = "bobzhang_office_transaction_temp_ok"

///|
extern "C" fn publication_temp_error_ffi(temp : PublicationTemp) -> Int = "bobzhang_office_transaction_temp_error"

///|
fn publication_error_is_exists(error : Int) -> Bool {
  @os_error.OSError(error, context="native Office publication").is_EEXIST()
}

///|
#borrow(bytes)
extern "C" fn publication_temp_write_ffi(
  temp : PublicationTemp,
  bytes : Bytes,
  offset : Int,
  length : Int,
) -> Int = "bobzhang_office_transaction_temp_write"

///|
extern "C" fn publication_temp_sync_ffi(temp : PublicationTemp) -> Bool = "bobzhang_office_transaction_temp_sync"

///|
#borrow(destination_leaf)
extern "C" fn publication_temp_publish_ffi(
  temp : PublicationTemp,
  destination_leaf : Bytes,
  replace : Bool,
) -> Bool = "bobzhang_office_transaction_temp_publish"

///|
extern "C" fn publication_temp_cleanup_ffi(temp : PublicationTemp) -> Bool = "bobzhang_office_transaction_temp_cleanup"

///|
extern "C" fn publication_temp_close_ffi(temp : PublicationTemp) -> Unit = "bobzhang_office_transaction_temp_close"

///|
extern "C" fn publication_directory_sync_ffi(
  directory : PublicationDirectory,
) -> Bool = "bobzhang_office_transaction_directory_sync"

///|
extern "C" fn publication_directory_close_ffi(
  directory : PublicationDirectory,
) -> Unit = "bobzhang_office_transaction_directory_close"

///|
fn native_operation_message(operation : String, error : Int) -> String {
  "\{operation} failed with host error \{error}"
}

///|
async fn publication_directory_open(
  path : String,
  output_path : String,
) -> PublicationDirectory {
  @async.pause()
  let directory = publication_directory_open_ffi(@utf8.encode(path))
  if !publication_directory_ok_ffi(directory) {
    let error = publication_directory_error_ffi(directory)
    publication_directory_close_ffi(directory)
    raise transaction_error(
      "office.transaction.destination_parent_failed",
      native_operation_message(
        "opening the resolved destination directory", error,
      ),
      details=Json::object({
        "directory": Json::string(bounded_text(path, 160)),
        "output": Json::string(bounded_text(output_path, 160)),
        "host_error": Json::number(error.to_double()),
      }),
    )
  }
  directory
}

///|
async fn publication_temp_try_create(
  directory : PublicationDirectory,
  leaf : String,
  permission : Int,
  output_path : String,
) -> PublicationTemp? {
  @async.pause()
  let temp = publication_temp_create_ffi(
    directory,
    @utf8.encode(leaf),
    permission,
  )
  if publication_temp_ok_ffi(temp) {
    return Some(temp)
  }
  let error = publication_temp_error_ffi(temp)
  if publication_error_is_exists(error) {
    publication_temp_close_ffi(temp)
    return None
  }
  publication_temp_close_ffi(temp)
  raise transaction_error(
    "office.transaction.temp_create_failed",
    native_operation_message("creating a temporary file", error),
    details=Json::object({
      "output": Json::string(bounded_text(output_path, 160)),
      "host_error": Json::number(error.to_double()),
    }),
  )
}

///|
async fn publication_temp_write(temp : PublicationTemp, bytes : Bytes) -> Unit {
  let mut offset = 0
  let chunk_size = 64 * 1024
  while offset < bytes.length() {
    @async.pause()
    let remaining = bytes.length() - offset
    let requested = if remaining < chunk_size { remaining } else { chunk_size }
    let written = publication_temp_write_ffi(temp, bytes, offset, requested)
    if written <= 0 {
      let error = publication_temp_error_ffi(temp)
      raise transaction_error(
        "office.transaction.write_failed",
        native_operation_message("writing the temporary package", error),
        details=Json::object({ "host_error": Json::number(error.to_double()) }),
      )
    }
    offset = offset + written
  }
}

///|
async fn publication_temp_sync(temp : PublicationTemp) -> Unit {
  @async.pause()
  if !publication_temp_sync_ffi(temp) {
    let error = publication_temp_error_ffi(temp)
    raise transaction_error(
      "office.transaction.sync_failed",
      native_operation_message("syncing the temporary package", error),
      details=Json::object({ "host_error": Json::number(error.to_double()) }),
    )
  }
}

///|
async fn publication_temp_publish(
  temp : PublicationTemp,
  destination_leaf : String,
  replace : Bool,
  output_path : String,
) -> Unit {
  @async.pause()
  if publication_temp_publish_ffi(temp, @utf8.encode(destination_leaf), replace) {
    return
  }
  let error = publication_temp_error_ffi(temp)
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
async fn publication_temp_cleanup(
  temp : PublicationTemp,
  output_path : String,
) -> Unit {
  @async.protect_from_cancel(
    () => {
      @async.pause()
      let cleaned = publication_temp_cleanup_ffi(temp)
      let error = publication_temp_error_ffi(temp)
      publication_temp_close_ffi(temp)
      if !cleaned {
        raise transaction_error(
          "office.transaction.cleanup_failed",
          native_operation_message("removing the temporary package", error),
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
  publication_temp_close_ffi(temp)
}

///|
async fn publication_directory_sync(directory : PublicationDirectory) -> Bool {
  @async.pause()
  publication_directory_sync_ffi(directory)
}

///|
fn publication_directory_close(directory : PublicationDirectory) -> Unit {
  publication_directory_close_ffi(directory)
}
