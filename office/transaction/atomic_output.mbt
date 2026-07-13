///|
async fn atomic_write_new_with_faults(
  output_path : String,
  data : BytesView,
  permission : Int,
  fail_after_bytes? : Int,
  stall_after_bytes? : Int,
  post_rename_release? : String,
) -> Unit {
  checked_path(output_path, "output_path")
  if permission < 0 || permission > 0o777 {
    raise transaction_error(
      "office.transaction.invalid_options", "permission must be between 0000 and 0777",
    )
  }
  reject_ambiguous_platform_path(output_path, "output_path")
  if path_exists_checked(output_path) {
    raise transaction_error(
      "office.transaction.output_exists",
      "destination already exists",
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
      }),
    )
  }
  let destination_target = resolve_new_destination(output_path)
  let destination_leaf = path_leaf(destination_target)
  let directory = publication_directory_open(
    path_parent(destination_target),
    output_path,
  )
  defer publication_directory_close(directory)
  let pinned_kind = publication_entry_kind(
    directory, destination_leaf, output_path,
  )
  if pinned_kind != 0 {
    raise transaction_error(
      "office.transaction.output_exists",
      "destination appeared before staging began",
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
      }),
    )
  }
  @async.pause()
  let stamp = @env.now()
  let mut temp : PublicationTemp? = None
  for attempt in 0..<transaction_temp_attempts {
    let leaf = ".office-output-tmp-\{stamp}-\{attempt}"
    match publication_temp_try_create(directory, leaf, output_path) {
      Some(created) => {
        temp = Some(created)
        break
      }
      None => ()
    }
  }
  guard temp is Some(temp) else {
    raise transaction_error(
      "office.transaction.temp_create_failed",
      "could not allocate a unique temporary output file",
      details=Json::object({
        "output": Json::string(bounded_text(output_path, 160)),
      }),
    )
  }
  let mut published = false
  try {
    @async.pause()
    publication_temp_write(
      temp,
      data.to_owned(),
      fail_after_bytes~,
      stall_after_bytes~,
    )
    publication_temp_sync(temp)
    ignore(
      publication_temp_publish(
        temp, destination_leaf, false, output_path, permission,
      ),
    )
    published = true
    publication_temp_close(temp)
    ignore(
      @async.protect_from_cancel(
        () => {
          match post_rename_release {
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
          publication_directory_sync(directory)
        },
        resume_on_cancel=true,
      ) catch {
        _ => false
      },
    )
  } catch {
    error => {
      if !published {
        publication_temp_cleanup(temp, output_path)
      } else {
        publication_temp_close(temp)
      }
      if @async.is_being_cancelled() {
        @async.pause()
      }
      raise error
    }
  }
}

///|
/// Writes a new non-package output through same-directory staging and an
/// atomic no-replace rename. This is the small-file counterpart to package
/// publication: failures and pre-commit cancellation clean private staging,
/// while the final sync/rename boundary has an unambiguous outcome.
pub async fn atomic_write_new(
  output_path : String,
  data : BytesView,
  permission? : Int = 0o600,
) -> Unit {
  atomic_write_new_with_faults(output_path, data, permission)
}
