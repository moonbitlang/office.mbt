///|
let transaction_max_validators = 32

///|
let transaction_portable_validator_name = "office-portable-opc"

///|
let transaction_temp_attempts = 32

///|
let transaction_max_package_bytes : Int = 128 * 1024 * 1024

///|
let transaction_max_archive_entries : Int = 8192

///|
let transaction_max_entry_uncompressed_bytes : Int = 64 * 1024 * 1024

///|
let transaction_max_total_uncompressed_bytes : Int = 256 * 1024 * 1024

///|
/// The complete transaction reserves one cross-phase materialization budget,
/// not one independent allowance per ZIP parse. The fixed reserve covers raw
/// package indexes, XML metadata, shallow archive forks, preservation maps,
/// and serializer working buffers that are not owned by `Archive` itself.
let transaction_max_live_materialized_bytes : Int64 = 384L * 1024L * 1024L

///|
let transaction_materialization_working_reserve : Int64 = 64L * 1024L * 1024L

///|
/// DOCX splice validation retains caller replacement buffers, edited payloads,
/// decoded text, and a strict XML tree concurrently. Only this conservative
/// share of the already charged working reserve may be used for the payload
/// buffers themselves; the remainder stays reserved for parser structures.
let transaction_splice_materialization_divisor : Int64 = 8L

///|
let transaction_max_splice_materialized_bytes : Int64 = 8L * 1024L * 1024L

///|
/// Before inflation, reserve the source buffer, copied local/central records,
/// decoded names, and bounded entry/runtime bookkeeping. The post-read check
/// replaces this conservative preflight with `Archive::retained_size_estimate`.
let transaction_package_retention_multiplier : Int64 = 3L

///|
let transaction_archive_entry_reserve : Int64 = 512L

///|
/// Format identification, portable OPC validation, format-specific parsing,
/// and preservation views can each materialize a normalized UTF-16 entry-name
/// projection while the bounded archive remains live. Exact-name map keys share
/// the archive strings and therefore need no additional character reserve.
let transaction_archive_name_projection_count : Int64 = 4L

///|
priv struct ResolvedPolicy {
  source_target : String
  source_directory : PublicationDirectory
  source_leaf : String
  destination_target : String
  destination_directory : PublicationDirectory
  destination_leaf : String
  output_path : String
  mode : TransactionMode
  replace : Bool
}

///|
priv struct TransactionFaults {
  fail_write : Bool
  fail_write_after_bytes : Int?
  stall_write_after_bytes : Int?
  fail_rename : Bool
  stall_after_temp : Bool
  post_rename_release : String?
  concurrent_replacement : Bytes?
  concurrent_destination : Bytes?
  relocate_parent_to : String?
  deny_cleanup : Bool
}

///|
fn no_transaction_faults() -> TransactionFaults {
  {
    fail_write: false,
    fail_write_after_bytes: None,
    stall_write_after_bytes: None,
    fail_rename: false,
    stall_after_temp: false,
    post_rename_release: None,
    concurrent_replacement: None,
    concurrent_destination: None,
    relocate_parent_to: None,
    deny_cleanup: false,
  }
}

///|
fn path_text(path : @path.Path) -> String {
  "\{path}"
}

///|
fn normalize_path_separators(path : String) -> String {
  if @path.sep == '\\' {
    path.replace_all(old="/", new="\\")
  } else {
    path
  }
}

///|
#cfg(all(target="native", platform="windows"))
fn is_windows_drive_absolute(path : String) -> Bool {
  let chars = path.to_array()
  chars.length() >= 3 &&
  chars[0].is_ascii_alphabetic() &&
  chars[1] == ':' &&
  chars[2] == '\\'
}

///|
#cfg(all(target="native", platform="windows"))
fn extend_windows_io_path(path : String) -> String {
  let normalized = normalize_path_separators(path)
  if @path.sep != '\\' ||
    normalized.has_prefix("\\\\?\\") ||
    normalized.has_prefix("\\\\.\\") {
    normalized
  } else if normalized.has_prefix("\\\\") {
    "\\\\?\\UNC\\" + normalized[2:].to_owned()
  } else if is_windows_drive_absolute(normalized) {
    "\\\\?\\" + normalized
  } else {
    normalized
  }
}

///|
#cfg(all(target="native", platform="windows"))
fn windows_current_drive() -> String? {
  guard @env.current_dir() is Some(current) else { return None }
  let normalized = normalize_path_separators(current)
  let chars = normalized.to_array()
  if chars.length() >= 2 && chars[0].is_ascii_alphabetic() && chars[1] == ':' {
    Some(normalized[:2].to_owned())
  } else {
    None
  }
}

///|
#cfg(all(target="native", platform="windows"))
fn fully_qualified_windows_path(path : String) -> String raise TransactionError {
  let normalized = normalize_path_separators(path)
  if normalized.has_prefix("\\\\?\\") ||
    normalized.has_prefix("\\\\.\\") ||
    normalized.has_prefix("\\\\") ||
    is_windows_drive_absolute(normalized) {
    normalized
  } else if normalized.has_prefix("\\") {
    match windows_current_drive() {
      Some(drive) => drive + normalized
      None =>
        raise transaction_error(
          "office.transaction.invalid_options",
          "a current-drive-root-relative path requires a drive-qualified working directory",
          details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
        )
    }
  } else {
    path_text(@path.Path(normalized).resolve())
  }
}

///|
#cfg(all(target="native", platform="windows"))
fn filesystem_path(path : String) -> String raise TransactionError {
  extend_windows_io_path(fully_qualified_windows_path(path))
}

///|
#cfg(all(target="native", not(platform="windows")))
fn filesystem_path(path : String) -> String {
  // Preserve POSIX component traversal for the operating system. In
  // particular, a directory-symlink/../file path is not equivalent to
  // lexically removing the symlink and parent segment before file access.
  path
}

///|
#cfg(target="wasm")
fn filesystem_path(path : String) -> String {
  path_text(@path.Path(normalize_path_separators(path)).resolve())
}

///|
#cfg(target="native")
fn reject_ambiguous_platform_path(_path : String, _label : String) -> Unit {
  ()
}

///|
#cfg(target="wasm")
fn reject_ambiguous_platform_path(
  path : String,
  label : String,
) -> Unit raise TransactionError {
  let resolved = path_text(
    @path.Path(normalize_path_separators(path)).resolve(),
  )
  if resolved.has_prefix("//") {
    raise transaction_error(
      "office.transaction.invalid_options",
      "\{label} uses an ambiguous double-slash root that portable Wasm filesystems cannot identify safely",
      details=Json::object({
        "field": Json::string(label),
        "file": Json::string(bounded_text(path, 160)),
      }),
    )
  }
}

///|
fn path_parent(path : String) -> String {
  let parent = path_text(@path.Path(normalize_path_separators(path)).dirname())
  if parent.length() == 0 {
    "."
  } else {
    parent
  }
}

///|
fn path_leaf(path : String) -> String {
  @path.Path(normalize_path_separators(path)).basename().to_owned()
}

///|
fn join_path(parent : String, leaf : String) -> String {
  path_text(
    @path.Path(normalize_path_separators(parent)).join(
      Path(normalize_path_separators(leaf)),
    ),
  )
}

///|
#cfg(all(target="native", platform="windows"))
async fn canonical_existing_path(path : String) -> String {
  extend_windows_io_path(@afs.realpath(filesystem_path(path)))
}

///|
#cfg(all(target="native", not(platform="windows")))
async fn canonical_existing_path(path : String) -> String {
  @afs.realpath(filesystem_path(path))
}

///|
#cfg(target="wasm")
async fn canonical_existing_path(path : String) -> String {
  let resolved = filesystem_path(path)
  let _ = @afs.kind(resolved)
  resolved
}

///|
async fn resolve_source(path : String) -> String {
  canonical_existing_path(path) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.file_read_failed",
        "could not resolve input file '\{bounded_text(path, 160)}': \{bounded_text(error.to_string(), 240)}",
        details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
      )
  }
}

///|
async fn path_exists_checked(path : String) -> Bool {
  @afs.exists(filesystem_path(path)) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.destination_check_failed",
        "could not inspect destination '\{bounded_text(path, 160)}': \{bounded_text(error.to_string(), 240)}",
        details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
      )
  }
}

///|
async fn resolve_new_destination(path : String) -> String {
  let leaf = path_leaf(path)
  if leaf.length() == 0 || leaf == "." || leaf == ".." {
    raise transaction_error(
      "office.transaction.invalid_options",
      "output_path must name a file",
      details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
    )
  }
  let parent = path_parent(path)
  let resolved_parent = canonical_existing_path(parent) catch {
    error if @async.is_being_cancelled() => raise error
    error =>
      raise transaction_error(
        "office.transaction.destination_parent_failed",
        "could not resolve destination directory '\{bounded_text(parent, 160)}': \{bounded_text(error.to_string(), 240)}",
        details=Json::object({
          "directory": Json::string(bounded_text(parent, 160)),
        }),
      )
  }
  join_path(resolved_parent, leaf)
}

///|
async fn resolve_policy(options : TransactionOptions) -> ResolvedPolicy {
  reject_ambiguous_platform_path(options.input_path, "input_path")
  match options.output_path {
    Some(path) => reject_ambiguous_platform_path(path, "output_path")
    None => ()
  }
  let source_target = resolve_source(options.input_path)
  let source_leaf = path_leaf(source_target)
  let source_directory = publication_directory_open(
    path_parent(source_target),
    options.input_path,
  )
  try {
    match options.output_path {
      None => {
        let destination_directory = publication_directory_duplicate(
          source_directory,
          options.input_path,
        )
        {
          source_target,
          source_directory,
          source_leaf,
          destination_target: source_target,
          destination_directory,
          destination_leaf: source_leaf,
          output_path: options.input_path,
          mode: InPlace,
          replace: true,
        }
      }
      Some(output_path) => {
        let destination_exists = path_exists_checked(output_path)
        let destination_target = if destination_exists {
          let kind = @afs.kind(filesystem_path(output_path)) catch {
            error if @async.is_being_cancelled() => raise error
            error =>
              raise transaction_error(
                "office.transaction.destination_check_failed",
                "could not inspect destination '\{bounded_text(output_path, 160)}': \{bounded_text(error.to_string(), 240)}",
              )
          }
          if kind is Directory {
            raise transaction_error(
              "office.transaction.invalid_options", "output_path must name a file, not a directory",
            )
          }
          canonical_existing_path(output_path) catch {
            error if @async.is_being_cancelled() => raise error
            error =>
              raise transaction_error(
                "office.transaction.destination_check_failed",
                "could not resolve destination '\{bounded_text(output_path, 160)}': \{bounded_text(error.to_string(), 240)}",
              )
          }
        } else {
          resolve_new_destination(output_path)
        }
        if destination_target == source_target {
          raise transaction_error(
            "office.transaction.output_aliases_input",
            "output_path resolves to the input; omit output_path for an in-place transaction",
            details=Json::object({
              "input": Json::string(bounded_text(options.input_path, 160)),
              "output": Json::string(bounded_text(output_path, 160)),
            }),
          )
        }
        if destination_exists && !options.overwrite {
          raise transaction_error(
            "office.transaction.output_exists",
            "destination already exists; set overwrite=true to replace it",
            details=Json::object({
              "output": Json::string(bounded_text(output_path, 160)),
            }),
          )
        }
        let destination_directory = publication_directory_open(
          path_parent(destination_target),
          output_path,
        )
        try {
          let destination_leaf = path_leaf(destination_target)
          let pinned_kind = publication_entry_kind(
            destination_directory, destination_leaf, output_path,
          )
          if pinned_kind == 2 {
            raise transaction_error(
              "office.transaction.invalid_options", "output_path must name a file, not a directory",
            )
          }
          if pinned_kind > 1 {
            raise transaction_error(
              "office.transaction.invalid_options", "output_path must name a regular file",
            )
          }
          if pinned_kind == 1 &&
            publication_entries_same(
              source_directory, source_leaf, destination_directory, destination_leaf,
              output_path,
            ) {
            raise transaction_error(
              "office.transaction.output_aliases_input",
              "output_path resolves to the input; omit output_path for an in-place transaction",
              details=Json::object({
                "input": Json::string(bounded_text(options.input_path, 160)),
                "output": Json::string(bounded_text(output_path, 160)),
              }),
            )
          }
          if pinned_kind == 1 && !options.overwrite {
            raise transaction_error(
              "office.transaction.output_exists",
              "destination already exists; set overwrite=true to replace it",
              details=Json::object({
                "output": Json::string(bounded_text(output_path, 160)),
              }),
            )
          }
          {
            source_target,
            source_directory,
            source_leaf,
            destination_target,
            destination_directory,
            destination_leaf,
            output_path,
            mode: Output,
            replace: options.overwrite,
          }
        } catch {
          error => {
            publication_directory_close(destination_directory)
            raise error
          }
        }
      }
    }
  } catch {
    error => {
      publication_directory_close(source_directory)
      raise error
    }
  }
}

///|
async fn read_original(
  options : TransactionOptions,
  source_directory : PublicationDirectory,
  source_leaf : String,
) -> Bytes {
  publication_file_read(
    source_directory, source_leaf, transaction_max_package_bytes, "input package",
  ) catch {
    error if @async.is_being_cancelled() => raise error
    TransactionError(..) as error => raise error
    error =>
      raise transaction_error(
        "office.transaction.file_read_failed",
        "could not read input file '\{bounded_text(options.input_path, 160)}': \{bounded_text(error.to_string(), 240)}",
        details=Json::object({
          "file": Json::string(bounded_text(options.input_path, 160)),
        }),
      )
  }
}

///|
fn resource_limit_error(
  phase : String,
  kind : String,
  limit : Int,
  actual : Int,
) -> TransactionError {
  transaction_error(
    "office.transaction.resource_limit_exceeded",
    "transaction resource limit exceeded during " + phase,
    details=Json::object({
      "phase": Json::string(phase),
      "kind": Json::string(kind),
      "limit": Json::number(limit.to_double()),
      "actual": Json::number(actual.to_double()),
    }),
  )
}

///|
fn live_materialization_error(
  phase : String,
  limit : Int64,
  actual : Int64,
) -> TransactionError {
  transaction_error(
    "office.transaction.resource_limit_exceeded",
    "transaction live materialization budget exceeded during " + phase,
    details=Json::object({
      "phase": Json::string(phase),
      "kind": Json::string("live_materialized_bytes"),
      "limit": Json::number(limit.to_double()),
      "actual": Json::number(actual.to_double()),
    }),
  )
}

///|
fn transaction_mutation_budget(
  retained : Int64,
  live_limit : Int64,
  working_reserve : Int64,
) -> TransactionBudget {
  let remaining = live_limit - retained
  let package_limit = transaction_max_package_bytes.to_int64()
  let max_candidate_package_bytes = if remaining <= 0L {
    0
  } else if remaining < package_limit {
    remaining.to_int()
  } else {
    transaction_max_package_bytes
  }
  let splice_share = working_reserve /
    transaction_splice_materialization_divisor
  let max_splice_materialized_bytes = if splice_share <= 0L {
    0
  } else if splice_share < transaction_max_splice_materialized_bytes {
    splice_share.to_int()
  } else {
    transaction_max_splice_materialized_bytes.to_int()
  }
  { max_candidate_package_bytes, max_splice_materialized_bytes }
}

///|
fn enforce_returned_candidate_budget(
  mutation : TransactionMutation,
  original : Bytes,
  budget : TransactionBudget,
  retained : Int64,
  live_limit : Int64,
) -> ResolvedTransactionMutation raise TransactionError {
  // Serialized candidates are charged before content-equal canonicalization.
  // Only the opaque ReuseOriginal state bypasses the allowance, and it carries
  // no caller-provided bytes: resolution always substitutes this transaction's
  // own current input buffer.
  match mutation.result {
    ReuseOriginal => ()
    Serialized(candidate) =>
      if candidate.length() > budget.max_candidate_package_bytes {
        raise live_materialization_error(
          "candidate package",
          live_limit,
          retained + candidate.length().to_int64(),
        )
      }
  }
  mutation.resolve_against_original(original)
}

///|
fn check_package_size_with_limit(
  bytes : BytesView,
  phase : String,
  limit : Int,
) -> Unit raise TransactionError {
  if bytes.length() > limit {
    raise resource_limit_error(phase, "package_bytes", limit, bytes.length())
  }
}

///|
fn check_package_size(
  bytes : BytesView,
  phase : String,
) -> Unit raise TransactionError {
  check_package_size_with_limit(bytes, phase, transaction_max_package_bytes)
}

///|
fn transaction_archive_preflight_overhead(bytes : BytesView) -> Int64 {
  bytes.length().to_int64() * transaction_package_retention_multiplier +
  transaction_max_archive_entries.to_int64() * transaction_archive_entry_reserve
}

///|
/// Charges every normalized entry-name projection before any identifier or
/// validator can build it. The per-name ceiling also prevents one legal ZIP
/// header from consuming the complete transaction working reserve.
fn transaction_archive_name_reserve(
  archive : @zip.Archive,
  phase : String,
  invalid_code : String,
) -> Int64 raise TransactionError {
  let mut reserve = 0L
  for entry in archive.entries() {
    match scan_text(entry.name(), transaction_max_part_length) {
      Valid =>
        reserve = reserve +
          entry.name().length().to_int64() *
          2L *
          transaction_archive_name_projection_count
      TooLong =>
        raise resource_limit_error(
          phase,
          "entry_name_chars",
          transaction_max_part_length,
          transaction_max_part_length + 1,
        )
      Invalid =>
        raise transaction_error(
          invalid_code,
          "ZIP entry name is not valid Unicode during " + phase,
        )
    }
  }
  reserve
}

///|
fn read_transaction_archive(
  bytes : BytesView,
  phase : String,
  invalid_code : String,
  retained : Int64,
  live_limit : Int64,
) -> (@zip.Archive, Int64) raise TransactionError {
  let package_bytes = bytes.length().to_int64()
  let preflight_overhead = transaction_archive_preflight_overhead(bytes)
  let available = live_limit - retained - preflight_overhead
  if available <= 0L {
    raise live_materialization_error(
      phase,
      live_limit,
      retained + preflight_overhead + 1L,
    )
  }
  let aggregate_limit = if available <
    transaction_max_total_uncompressed_bytes.to_int64() {
    available.to_int()
  } else {
    transaction_max_total_uncompressed_bytes
  }
  let archive = @zip.read_limited(
    bytes,
    max_entries=transaction_max_archive_entries,
    max_entry_uncompressed_bytes=transaction_max_entry_uncompressed_bytes,
    max_total_uncompressed_bytes=aggregate_limit,
  ) catch {
    ResourceLimitExceeded(kind~, limit=_, actual~) if kind ==
      "total_uncompressed_bytes" &&
      aggregate_limit < transaction_max_total_uncompressed_bytes =>
      raise live_materialization_error(
        phase,
        live_limit,
        retained + preflight_overhead + actual.to_int64(),
      )
    ResourceLimitExceeded(kind~, limit~, actual~) =>
      raise resource_limit_error(phase, kind, limit, actual)
    _ =>
      raise transaction_error(
        invalid_code,
        "unreadable bounded ZIP package during " + phase,
      )
  }
  let name_reserve = transaction_archive_name_reserve(
    archive, phase, invalid_code,
  )
  let archive_cost = package_bytes +
    archive.retained_size_estimate() +
    name_reserve
  let actual = retained + archive_cost
  if actual > live_limit {
    raise live_materialization_error(phase, live_limit, actual)
  }
  (archive, archive_cost)
}

///|
fn identify_input(
  options : TransactionOptions,
  original : BytesView,
  identifier : TransactionIdentifier?,
  retained : Int64,
  live_limit : Int64,
) -> (@office.DocumentFormat, @zip.Archive, Int64) raise TransactionError {
  check_package_size(original, "input package")
  let (archive, archive_cost) = read_transaction_archive(
    original, "input package", "office.transaction.invalid_input", retained, live_limit,
  )
  // A custom identifier is an additional bounded, format-specific gate. Run it
  // before generic Office parsing, but never let it replace the mandatory
  // portable OPC validation below.
  let custom_format = match identifier {
    Some(identifier) =>
      Some(
        identifier.run(options.input_path, original, archive.fork()) catch {
          TransactionError(..) as error =>
            raise normalize_transaction_error(
              error, "office.transaction.invalid_input", "custom transaction identifier raised an invalid error",
            )
          error =>
            raise transaction_error(
              "office.transaction.invalid_input",
              "identifier '\{identifier.name}' rejected the input package: \{bounded_text(error.to_string(), 240)}",
              details=Json::object({
                "identifier": Json::string(identifier.name),
              }),
            )
        },
      )
    None => None
  }
  let portable_format = @office.detect_archive_format(
    options.input_path,
    archive,
  ) catch {
    error =>
      raise transaction_error(
        "office.transaction.invalid_input",
        bounded_text(Show::to_string(error), 320),
        details=Json::object({
          "validator": Json::string(transaction_portable_validator_name),
          "file": Json::string(bounded_text(options.input_path, 160)),
        }),
      )
  }
  match (identifier, custom_format) {
    (Some(identifier), Some(custom)) if custom != portable_format =>
      raise transaction_error(
        "office.transaction.invalid_input",
        "identifier '\{identifier.name}' reported \{custom.name()}, but mandatory portable validation reported \{portable_format.name()}",
        details=Json::object({
          "identifier": Json::string(identifier.name),
          "identifier_format": Json::string(custom.name()),
          "portable_format": Json::string(portable_format.name()),
        }),
      )
    _ => ()
  }
  (portable_format, archive, archive_cost)
}

///|
fn findings_json(findings : Array[ValidationFinding]) -> Json {
  Json::array(
    findings.map(finding => {
      Json::object({
        "code": Json::string(finding.code),
        "message": Json::string(finding.message),
      })
    }),
  )
}

///|
fn validate_validator_set(
  validators : Array[TransactionValidator],
  identifier : TransactionIdentifier?,
) -> Unit raise TransactionError {
  if validators.length() > transaction_max_validators {
    raise transaction_error(
      "office.transaction.invalid_contract",
      "transaction exceeds \{transaction_max_validators} validators",
    )
  }
  let names = []
  for validator in validators {
    if validator.name == transaction_portable_validator_name {
      raise transaction_error(
        "office.transaction.invalid_contract",
        "validator name '\{transaction_portable_validator_name}' is reserved for mandatory portable OPC validation",
      )
    }
    if names.contains(validator.name) {
      raise transaction_error(
        "office.transaction.invalid_contract",
        "duplicate validator name '\{validator.name}'",
      )
    }
    match identifier {
      Some(identifier) if validator.name == identifier.name =>
        raise transaction_error(
          "office.transaction.invalid_contract",
          "transaction identifier and validator names must be distinct; duplicate '\{validator.name}'",
        )
      _ => ()
    }
    names.push(validator.name)
  }
}

///|
fn validate_candidate(
  format : @office.DocumentFormat,
  validation_path : String,
  original : BytesView,
  original_archive : @zip.Archive,
  mutation : ResolvedTransactionMutation,
  validators : Array[TransactionValidator],
  identifier : TransactionIdentifier?,
  retained : Int64,
  live_limit : Int64,
) -> (Array[ValidationSummary], @zip.Archive) raise TransactionError {
  check_package_size(mutation.bytes, "candidate package")
  let archive = if mutation.bytes[:] == original {
    original_archive
  } else {
    let (candidate, _) = read_transaction_archive(
      mutation.bytes,
      "candidate package",
      "office.transaction.validation_failed",
      retained,
      live_limit,
    )
    candidate
  }
  let summaries : Array[ValidationSummary] = []
  // Preserve the custom-first boundary, then independently require portable
  // OPC validation. Both successful gates are visible in the report.
  let custom_format = match identifier {
    Some(identifier) => {
      let candidate_format = identifier.run(
        validation_path,
        mutation.bytes,
        archive.fork(),
      ) catch {
        TransactionError(..) as error =>
          raise normalize_transaction_error(
            error, "office.transaction.validation_failed", "custom transaction identifier raised an invalid error",
          )
        error =>
          raise transaction_error(
            "office.transaction.validation_failed",
            "identifier '\{identifier.name}' rejected the candidate package: \{bounded_text(error.to_string(), 240)}",
            details=Json::object({ "identifier": Json::string(identifier.name) }),
          )
      }
      summaries.push({ name: identifier.name, passed: true, finding_count: 0 })
      Some(candidate_format)
    }
    None => None
  }
  let portable_format = @office.detect_archive_format(validation_path, archive) catch {
    error =>
      raise transaction_error(
        "office.transaction.validation_failed",
        "portable Office validation failed: \{bounded_text(Show::to_string(error), 320)}",
        details=Json::object({
          "validator": Json::string(transaction_portable_validator_name),
        }),
      )
  }
  summaries.push({
    name: transaction_portable_validator_name,
    passed: true,
    finding_count: 0,
  })
  match (identifier, custom_format) {
    (Some(identifier), Some(custom)) if custom != portable_format =>
      raise transaction_error(
        "office.transaction.validation_failed",
        "identifier '\{identifier.name}' reported \{custom.name()}, but mandatory portable validation reported \{portable_format.name()}",
        details=Json::object({
          "identifier": Json::string(identifier.name),
          "identifier_format": Json::string(custom.name()),
          "portable_format": Json::string(portable_format.name()),
        }),
      )
    _ => ()
  }
  if portable_format != format {
    raise transaction_error(
      "office.transaction.format_changed",
      "candidate format \{portable_format.name()} does not match input format \{format.name()}",
      details=Json::object({
        "input_format": Json::string(format.name()),
        "candidate_format": Json::string(portable_format.name()),
      }),
    )
  }
  for validator in validators {
    let findings = validator.run(format, mutation.bytes, archive.fork()) catch {
      error =>
        raise transaction_error(
          "office.transaction.validation_failed",
          "validator '\{validator.name}' failed: \{bounded_text(error.to_string(), 240)}",
          details=Json::object({ "validator": Json::string(validator.name) }),
        )
    }
    if findings.length() > transaction_max_validator_findings {
      raise transaction_error(
        "office.transaction.invalid_contract",
        "validator '\{validator.name}' exceeds \{transaction_max_validator_findings} findings",
        details=Json::object({
          "validator": Json::string(validator.name),
          "limit": Json::number(transaction_max_validator_findings.to_double()),
          "actual": Json::number(findings.length().to_double()),
        }),
      )
    }
    if !findings.is_empty() {
      raise transaction_error(
        "office.transaction.validation_failed",
        "validator '\{validator.name}' reported \{findings.length()} finding(s)",
        details=Json::object({
          "validator": Json::string(validator.name),
          "findings": findings_json(findings),
        }),
      )
    }
    summaries.push({ name: validator.name, passed: true, finding_count: 0 })
  }
  (summaries, archive)
}

///|
async fn create_temp(policy : ResolvedPolicy) -> PublicationTemp {
  @async.pause()
  let stamp = @env.now()
  for attempt in 0..<transaction_temp_attempts {
    let leaf = ".office-tmp-\{stamp}-\{attempt}"
    match
      publication_temp_try_create(
        policy.destination_directory,
        leaf,
        policy.output_path,
      ) {
      Some(temp) => return temp
      None => continue
    }
  }
  raise transaction_error(
    "office.transaction.temp_create_failed",
    "could not allocate a unique temporary file after \{transaction_temp_attempts} attempts",
    details=Json::object({
      "output": Json::string(bounded_text(policy.output_path, 160)),
    }),
  )
}

///|
async fn check_source_unchanged(
  source_directory : PublicationDirectory,
  source_leaf : String,
  original : Bytes,
) -> Unit {
  let matches = publication_named_file_matches(
    source_directory, source_leaf, original,
  ) catch {
    error if @async.is_being_cancelled() => raise error
    _ =>
      raise transaction_error(
        "office.transaction.source_changed", "input disappeared or became unreadable before the in-place commit",
      )
  }
  if !matches {
    raise transaction_error(
      "office.transaction.source_changed", "input changed after it was read; refusing to overwrite a concurrent writer",
    )
  }
}

///|
async fn publish_candidate(
  options : TransactionOptions,
  policy : ResolvedPolicy,
  original : Bytes,
  candidate : Bytes,
  faults : TransactionFaults,
  cleanup_release : String?,
) -> (Bool, Bool) {
  let temp = create_temp(policy)
  try {
    // Exclusive creation and staging chmod are cancellation-shielded so their
    // outcome is never ambiguous. Observe a cancellation before doing more
    // work; the surrounding catch then owns deterministic cleanup.
    @async.pause()
    match faults.relocate_parent_to {
      Some(target) =>
        @afs.rename(
          path_parent(policy.destination_target),
          filesystem_path(target),
          replace=false,
        ) catch {
          error if @async.is_being_cancelled() => raise error
          error =>
            raise transaction_error(
              "office.transaction.commit_failed",
              "could not inject the destination-parent relocation: \{bounded_text(error.to_string(), 240)}",
            )
        }
      None => ()
    }
    if faults.deny_cleanup {
      publication_temp_substitute(temp)
    }
    if faults.stall_after_temp {
      @async.sleep(60_000)
    }
    if faults.fail_write {
      raise transaction_error(
        "office.transaction.write_failed", "injected temporary-file write failure",
      )
    }
    publication_temp_write(
      temp,
      candidate,
      fail_after_bytes=faults.fail_write_after_bytes,
      stall_after_bytes=faults.stall_write_after_bytes,
    )
    publication_temp_sync(temp)
    if policy.mode is InPlace {
      match faults.concurrent_replacement {
        Some(replacement) => {
          match faults.relocate_parent_to {
            Some(_) =>
              @afs.mkdir(path_parent(policy.source_target)) catch {
                error if @async.is_being_cancelled() => raise error
                error =>
                  raise transaction_error(
                    "office.transaction.commit_failed",
                    "could not inject the replacement source parent: \{bounded_text(error.to_string(), 240)}",
                  )
              }
            None => ()
          }
          @afs.write_file(
            policy.source_target,
            replacement,
            create_mode=if faults.relocate_parent_to is Some(_) {
              CreateNew
            } else {
              CreateOrTruncate
            },
            permission=options.permission,
          ) catch {
            error if @async.is_being_cancelled() => raise error
            error =>
              raise transaction_error(
                "office.transaction.commit_failed",
                "could not inject the concurrent-source test replacement: \{bounded_text(error.to_string(), 240)}",
              )
          }
        }
        None => ()
      }
      check_source_unchanged(
        policy.source_directory,
        policy.source_leaf,
        original,
      ) catch {
        error if @async.is_being_cancelled() => raise error
        error => raise error
      }
    }
    if policy.mode is Output {
      match faults.concurrent_destination {
        Some(replacement) =>
          @afs.write_file(
            policy.destination_target,
            replacement,
            create_mode=CreateNew,
            permission=options.permission,
          ) catch {
            error if @async.is_being_cancelled() => raise error
            error =>
              raise transaction_error(
                "office.transaction.commit_failed",
                "could not inject the concurrent-destination test file: \{bounded_text(error.to_string(), 240)}",
              )
          }
        None => ()
      }
    }
    if faults.fail_rename {
      raise transaction_error(
        "office.transaction.commit_failed", "injected atomic-rename failure",
      )
    }
    let temp_clean = publication_temp_publish(
      temp,
      policy.destination_leaf,
      policy.replace,
      policy.output_path,
      options.permission,
    )
    publication_temp_close(temp)
    let parent_synced = @async.protect_from_cancel(
      () => {
        match faults.post_rename_release {
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
        publication_directory_sync(policy.destination_directory)
      },
      resume_on_cancel=true,
    ) catch {
      _ => false
    }
    (parent_synced, temp_clean)
  } catch {
    error => {
      match cleanup_release {
        Some(release) =>
          publication_temp_cleanup(
            temp,
            policy.output_path,
            cleanup_release=release,
          )
        None => publication_temp_cleanup(temp, policy.output_path)
      }
      if @async.is_being_cancelled() {
        @async.pause()
        raise error
      }
      raise error
    }
  }
}

///|
#cfg(target="native")
fn append_platform_warnings(
  warnings : Array[@office.ProtocolWarning],
  committed : Bool,
  parent_synced : Bool,
  temp_clean : Bool,
) -> Unit {
  if committed {
    warnings.push(
      @office.protocol_warning(
        "office.transaction.path_based_commit_semantics", "publication uses moonbitlang/async path APIs; atomic rename is guaranteed, but hostile concurrent directory-entry replacement is outside the portable contract",
      ),
    )
  }
  if committed && !parent_synced {
    warnings.push(
      @office.protocol_warning(
        "office.transaction.directory_sync_unavailable", "package bytes were atomically renamed, but the parent directory could not be synced on this host",
      ),
    )
  }
  if committed && !temp_clean {
    warnings.push(
      @office.protocol_warning(
        "office.transaction.committed_temp_cleanup_failed", "destination was committed, but a private staging link could not be removed",
      ),
    )
  }
}

///|
#cfg(target="wasm")
fn append_platform_warnings(
  warnings : Array[@office.ProtocolWarning],
  committed : Bool,
  _parent_synced : Bool,
  _temp_clean : Bool,
) -> Unit {
  if committed {
    warnings.push(
      @office.protocol_warning(
        "office.transaction.path_based_commit_semantics", "publication uses moonbitlang/async path APIs; atomic rename is guaranteed, but hostile concurrent directory-entry replacement is outside the portable contract",
      ),
    )
    warnings.push(
      @office.protocol_warning(
        "office.transaction.wasm_commit_semantics", "Wasm uses normalized paths and a same-directory rename, but host-independent realpath, symlink identity, and parent-directory durability are unavailable",
      ),
    )
  }
}

///|
async fn transact_with_identifier_and_faults(
  options : TransactionOptions,
  mutate : (@office.DocumentFormat, Bytes, @zip.Archive, TransactionBudget) -> TransactionMutation raise,
  validators : Array[TransactionValidator],
  identifier : TransactionIdentifier?,
  faults : TransactionFaults,
  post_read_release? : String,
  cleanup_release? : String,
  materialization_limit? : Int64 = transaction_max_live_materialized_bytes,
  materialization_reserve? : Int64 = transaction_materialization_working_reserve,
) -> TransactionReport {
  if materialization_limit <= 0L ||
    materialization_reserve < 0L ||
    materialization_reserve >= materialization_limit {
    raise transaction_error(
      "office.transaction.invalid_contract", "transaction materialization limit must exceed its nonnegative working reserve",
    )
  }
  let validators = validators.copy()
  validate_validator_set(validators, identifier)
  let policy = resolve_policy(options)
  defer publication_directory_close(policy.source_directory)
  defer publication_directory_close(policy.destination_directory)
  let original = read_original(
    options,
    policy.source_directory,
    policy.source_leaf,
  )
  match post_read_release {
    Some(release) => {
      @afs.write_file(
        release + ".ready",
        b"ready",
        create_mode=CreateNew,
        permission=0o600,
      )
      @async.protect_from_cancel(
        () => {
          while !@afs.exists(release) {
            @async.pause()
          }
        },
        resume_on_cancel=true,
      )
    }
    None => ()
  }
  // Regular-file reads may finish in a non-cancellable worker after a task was
  // cancelled. Make that pending cancellation observable before synchronous
  // parsing/mutation, including dry-run and byte-identical no-op paths.
  @async.pause()
  let (format, original_archive, original_archive_cost) = identify_input(
    options, original, identifier, materialization_reserve, materialization_limit,
  )
  let mutation_retained = materialization_reserve + original_archive_cost
  let budget = transaction_mutation_budget(
    mutation_retained, materialization_limit, materialization_reserve,
  )
  let mutation = mutate(format, original, original_archive.fork(), budget) catch {
    TransactionError(..) as error => raise normalize_mutation_error(error)
    error =>
      raise transaction_error(
        "office.transaction.mutation_failed",
        "mutation callback failed: \{bounded_text(error.to_string(), 240)}",
      )
  }
  let mutation = enforce_returned_candidate_budget(
    mutation, original, budget, mutation_retained, materialization_limit,
  )
  let (validations, candidate_archive) = validate_candidate(
    format,
    policy.destination_target,
    original,
    original_archive,
    mutation,
    validators,
    identifier,
    mutation_retained,
    materialization_limit,
  )
  let preservation = preservation_report_archives(
    original, mutation, original_archive, candidate_archive,
  )
  let changed = original != mutation.bytes
  let should_commit = !options.dry_run && (policy.mode is Output || changed)
  let (parent_synced, temp_clean) = if should_commit {
    publish_candidate(
      options,
      policy,
      original,
      mutation.bytes,
      faults,
      cleanup_release,
    )
  } else {
    (true, true)
  }
  let warnings = []
  for warning in mutation.warnings {
    warnings.push(warning)
  }
  append_platform_warnings(warnings, should_commit, parent_synced, temp_clean)
  {
    format,
    input_path: options.input_path,
    output_path: policy.output_path,
    mode: policy.mode,
    dry_run: options.dry_run,
    changed,
    committed: should_commit,
    original_size: original.length(),
    result_size: mutation.bytes.length(),
    validations: ReadOnlyArray::from_array(validations),
    preservation,
    warnings: ReadOnlyArray::from_array(warnings),
  }
}

///|
async fn transact_with_faults(
  options : TransactionOptions,
  mutate : (@office.DocumentFormat, Bytes, @zip.Archive, TransactionBudget) -> TransactionMutation raise,
  validators : Array[TransactionValidator],
  faults : TransactionFaults,
  post_read_release? : String,
  cleanup_release? : String,
) -> TransactionReport {
  transact_with_identifier_and_faults(
    options,
    mutate,
    validators,
    None,
    faults,
    post_read_release?,
    cleanup_release?,
  )
}

///|
/// Runs one fail-closed Office package transaction. The mutation callback owns
/// an independently mutable shallow fork of the already bounded input archive,
/// may return `transaction_reuse_original*` for a no-op, and must apply the
/// supplied `TransactionBudget` before allocating serialized candidate bytes.
/// Mandatory validation, preservation checks, source conflict detection, and
/// atomic publication remain in this function.
pub async fn transact(
  options : TransactionOptions,
  mutate : (@office.DocumentFormat, Bytes, @zip.Archive, TransactionBudget) -> TransactionMutation raise,
  validators? : Array[TransactionValidator] = [],
  identifier? : TransactionIdentifier,
) -> TransactionReport {
  match identifier {
    Some(identifier) =>
      transact_with_identifier_and_faults(
        options,
        mutate,
        validators,
        Some(identifier),
        no_transaction_faults(),
      )
    None =>
      transact_with_faults(options, mutate, validators, no_transaction_faults())
  }
}
