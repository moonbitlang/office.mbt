///|
/// Immutable destination policy for creating one fresh Office package.
pub struct CreateTransactionOptions {
  output_path : String
  dry_run : Bool
  overwrite : Bool
  permission : Int
}

///|
/// Builds checked fresh-package transaction options. Creation is no-replace by
/// default; `overwrite=true` atomically replaces an existing regular-file
/// destination only after the complete candidate validation boundary passes.
pub fn create_transaction_options(
  output_path : String,
  dry_run? : Bool = false,
  overwrite? : Bool = false,
  permission? : Int = 0o600,
) -> CreateTransactionOptions raise TransactionError {
  checked_path(output_path, "output_path")
  if permission < 0 || permission > 0o777 {
    raise transaction_error(
      "office.transaction.invalid_options",
      "permission must be between 0000 and 0777",
      details=Json::object({ "field": Json::string("permission") }),
    )
  }
  { output_path, dry_run, overwrite, permission }
}

///|
/// Resolves and pins the destination parent through the same publication
/// policy used by existing-package transactions. The source fields are an
/// inert duplicate of the destination: `publish_candidate` never consults
/// them for `Output` mode, while retaining one cleanup path for both flows.
async fn resolve_create_policy(
  options : CreateTransactionOptions,
) -> ResolvedPolicy {
  reject_ambiguous_platform_path(options.output_path, "output_path")
  let destination_exists = path_exists_checked(options.output_path)
  let destination_target = if destination_exists {
    let kind = @afs.kind(filesystem_path(options.output_path)) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        raise transaction_error(
          "office.transaction.destination_check_failed",
          "could not inspect destination '\{bounded_text(options.output_path, 160)}': \{bounded_text(error.to_string(), 240)}",
          details=Json::object({
            "output": Json::string(bounded_text(options.output_path, 160)),
          }),
        )
    }
    if kind is Directory {
      raise transaction_error(
        "office.transaction.invalid_options", "output_path must name a file, not a directory",
      )
    }
    canonical_existing_path(options.output_path) catch {
      error if @async.is_being_cancelled() => raise error
      error =>
        raise transaction_error(
          "office.transaction.destination_check_failed",
          "could not resolve destination '\{bounded_text(options.output_path, 160)}': \{bounded_text(error.to_string(), 240)}",
          details=Json::object({
            "output": Json::string(bounded_text(options.output_path, 160)),
          }),
        )
    }
  } else {
    resolve_new_destination(options.output_path)
  }
  if destination_exists && !options.overwrite {
    raise transaction_error(
      "office.transaction.output_exists",
      "destination already exists; set overwrite=true to replace it",
      details=Json::object({
        "output": Json::string(bounded_text(options.output_path, 160)),
      }),
    )
  }
  let destination_directory = publication_directory_open(
    path_parent(destination_target),
    options.output_path,
  )
  try {
    let destination_leaf = path_leaf(destination_target)
    let pinned_kind = publication_entry_kind(
      destination_directory,
      destination_leaf,
      options.output_path,
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
    if pinned_kind == 1 && !options.overwrite {
      raise transaction_error(
        "office.transaction.output_exists",
        "destination already exists; set overwrite=true to replace it",
        details=Json::object({
          "output": Json::string(bounded_text(options.output_path, 160)),
        }),
      )
    }
    {
      source_target: destination_target,
      source_directory: publication_directory_duplicate(
        destination_directory,
        options.output_path,
      ),
      source_leaf: destination_leaf,
      destination_target,
      destination_directory,
      destination_leaf,
      output_path: options.output_path,
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

///|
/// A fresh package has no preservation baseline. Every candidate part is
/// therefore reported as added, while the policy text explicitly refuses to
/// imply payload or container preservation across an overwrite.
fn creation_preservation_report(
  candidate_archive : @zip.Archive,
) -> PreservationReport {
  let added = []
  for entry in candidate_archive.entries() {
    added.push(entry.name())
  }
  added.sort()
  {
    whole_file_identical: false,
    manifest_enforced: false,
    changed: readonly_strings([]),
    added: readonly_strings(added),
    removed: readonly_strings([]),
    unchanged: readonly_strings([]),
    zip_metadata_policy: "fresh package creation has no source preservation baseline; all candidate entries are reported as added",
  }
}

///|
/// Internal fault-injectable implementation shared with transaction wbtests.
async fn transact_create_with_faults(
  options : CreateTransactionOptions,
  format : @office.DocumentFormat,
  create : (TransactionBudget) -> TransactionMutation raise,
  validators : Array[TransactionValidator],
  identifier : TransactionIdentifier?,
  faults : TransactionFaults,
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
  let policy = resolve_create_policy(options)
  defer publication_directory_close(policy.source_directory)
  defer publication_directory_close(policy.destination_directory)
  // Make cancellation observable before the synchronous package builder and
  // its serializer begin allocating the candidate.
  @async.pause()
  let mutation_retained = materialization_reserve
  let budget = transaction_mutation_budget(
    mutation_retained, materialization_limit, materialization_reserve,
  )
  let pending = create(budget) catch {
    TransactionError(..) as error => raise normalize_mutation_error(error)
    error =>
      raise transaction_error(
        "office.transaction.mutation_failed",
        "creation callback failed: \{bounded_text(error.to_string(), 240)}",
      )
  }
  match pending.result {
    ReuseOriginal =>
      raise transaction_error(
        "office.transaction.invalid_contract", "fresh package creation must return a serialized candidate",
      )
    Serialized(_) => ()
  }
  let mutation = enforce_returned_candidate_budget(
    pending, b"", budget, mutation_retained, materialization_limit,
  )
  let (validations, candidate_archive) = validate_candidate(
    format,
    policy.destination_target,
    b"",
    @zip.Archive::new(),
    mutation,
    validators,
    identifier,
    mutation_retained,
    materialization_limit,
  )
  let preservation = creation_preservation_report(candidate_archive)
  let should_commit = !options.dry_run
  let publication_options : TransactionOptions = {
    input_path: options.output_path,
    output_path: Some(options.output_path),
    dry_run: options.dry_run,
    overwrite: options.overwrite,
    permission: options.permission,
  }
  let (parent_synced, temp_clean) = if should_commit {
    publish_candidate(
      publication_options,
      policy,
      b"",
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
    // `office.transaction/1` predates source-free creation and requires an
    // input path. Repeating the destination plus `original_size=0` keeps the
    // report deterministic; the enclosing create result names the operation.
    input_path: options.output_path,
    output_path: options.output_path,
    mode: Output,
    dry_run: options.dry_run,
    changed: true,
    committed: should_commit,
    original_size: 0,
    result_size: mutation.bytes.length(),
    validations: ReadOnlyArray::from_array(validations),
    preservation,
    warnings: ReadOnlyArray::from_array(warnings),
  }
}

///|
/// Builds, validates, and atomically publishes one fresh Office package. The
/// callback must serialize through `TransactionBudget::max_candidate_package_bytes`
/// before allocating its candidate. Validation and dry-run semantics are the
/// same as `transact`; no destination bytes are touched until every gate passes.
pub async fn transact_create(
  options : CreateTransactionOptions,
  format : @office.DocumentFormat,
  create : (TransactionBudget) -> TransactionMutation raise,
  validators? : Array[TransactionValidator] = [],
  identifier? : TransactionIdentifier,
) -> TransactionReport {
  transact_create_with_faults(
    options,
    format,
    create,
    validators,
    identifier,
    no_transaction_faults(),
  )
}
