///|
/// Wasm hosts do not expose directory handles through the portable async file
/// API. This value records the already-normalized parent path, and successful
/// reports carry an explicit warning about the weaker host-independent model.
priv struct PublicationDirectory {
  path : String
}

///|
priv struct PublicationTemp {
  path : String
  file : @afs.File
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
  Some({ path, file })
}

///|
async fn publication_temp_write(temp : PublicationTemp, bytes : Bytes) -> Unit {
  temp.file.write(bytes) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.write_failed",
        "could not write temporary package: \{bounded_text(error.to_string(), 240)}",
      )
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
async fn publication_temp_publish(
  temp : PublicationTemp,
  destination_leaf : String,
  replace : Bool,
  output_path : String,
) -> Unit {
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
}

///|
async fn publication_temp_cleanup(
  temp : PublicationTemp,
  output_path : String,
) -> Unit {
  @async.protect_from_cancel(
    () => {
      temp.file.close()
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
async fn publication_directory_sync(_directory : PublicationDirectory) -> Bool {
  @async.pause()
  false
}

///|
fn publication_directory_close(_directory : PublicationDirectory) -> Unit {
  ()
}
