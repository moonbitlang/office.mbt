///|
let transaction_max_validators = 32

///|
let transaction_temp_attempts = 32

///|
priv struct ResolvedPolicy {
  source_target : String
  destination_target : String
  output_path : String
  mode : TransactionMode
  replace : Bool
}

///|
priv struct TransactionFaults {
  fail_write : Bool
  fail_rename : Bool
  concurrent_replacement : Bytes?
}

///|
fn no_transaction_faults() -> TransactionFaults {
  { fail_write: false, fail_rename: false, concurrent_replacement: None }
}

///|
fn path_text(path : @path.Path) -> String {
  "\{path}"
}

///|
fn path_parent(path : String) -> String {
  let parent = path_text(@path.Path(path).dirname())
  if parent.length() == 0 {
    "."
  } else {
    parent
  }
}

///|
fn path_leaf(path : String) -> String {
  @path.Path(path).basename().to_owned()
}

///|
fn join_path(parent : String, leaf : String) -> String {
  path_text(@path.Path(parent).join(Path(leaf)))
}

///|
#cfg(target="native")
async fn canonical_existing_path(path : String) -> String {
  @afs.realpath(path)
}

///|
#cfg(target="wasm")
async fn canonical_existing_path(path : String) -> String {
  let _ = @afs.kind(path)
  path_text(@path.Path(path).resolve())
}

///|
async fn resolve_source(path : String) -> String raise TransactionError {
  canonical_existing_path(path) catch {
    error =>
      raise transaction_error(
        "office.transaction.file_read_failed",
        "could not resolve input file '\{bounded_text(path, 160)}': \{bounded_text(error.to_string(), 240)}",
        details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
      )
  }
}

///|
async fn path_exists_checked(path : String) -> Bool raise TransactionError {
  @afs.exists(path) catch {
    error =>
      raise transaction_error(
        "office.transaction.destination_check_failed",
        "could not inspect destination '\{bounded_text(path, 160)}': \{bounded_text(error.to_string(), 240)}",
        details=Json::object({ "file": Json::string(bounded_text(path, 160)) }),
      )
  }
}

///|
async fn resolve_new_destination(
  path : String,
) -> String raise TransactionError {
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
async fn resolve_policy(
  options : TransactionOptions,
) -> ResolvedPolicy raise TransactionError {
  let source_target = resolve_source(options.input_path)
  match options.output_path {
    None =>
      {
        source_target,
        destination_target: source_target,
        output_path: options.input_path,
        mode: InPlace,
        replace: true,
      }
    Some(output_path) => {
      let destination_exists = path_exists_checked(output_path)
      let destination_target = if destination_exists {
        let kind = @afs.kind(output_path) catch {
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
      {
        source_target,
        destination_target,
        output_path,
        mode: Output,
        replace: options.overwrite,
      }
    }
  }
}

///|
async fn read_original(
  options : TransactionOptions,
  source_target : String,
) -> Bytes raise TransactionError {
  @afs.read_file(source_target).binary() catch {
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
fn identify_input(
  options : TransactionOptions,
  original : BytesView,
) -> @office.DocumentFormat raise TransactionError {
  @office.detect_format(options.input_path, original) catch {
    error =>
      raise transaction_error(
        "office.transaction.invalid_input",
        bounded_text(Show::to_string(error), 320),
        details=Json::object({
          "file": Json::string(bounded_text(options.input_path, 160)),
        }),
      )
  }
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
) -> Unit raise TransactionError {
  if validators.length() > transaction_max_validators {
    raise transaction_error(
      "office.transaction.invalid_contract",
      "transaction exceeds \{transaction_max_validators} validators",
    )
  }
  let names = []
  for validator in validators {
    if names.contains(validator.name) {
      raise transaction_error(
        "office.transaction.invalid_contract",
        "duplicate validator name '\{validator.name}'",
      )
    }
    names.push(validator.name)
  }
}

///|
fn validate_candidate(
  format : @office.DocumentFormat,
  validation_path : String,
  mutation : TransactionMutation,
  validators : Array[TransactionValidator],
) -> Array[ValidationSummary] raise TransactionError {
  let candidate_format = @office.detect_format(validation_path, mutation.bytes) catch {
    error =>
      raise transaction_error(
        "office.transaction.validation_failed",
        "portable Office validation failed: \{bounded_text(Show::to_string(error), 320)}",
        details=Json::object({
          "validator": Json::string("office-portable-opc"),
        }),
      )
  }
  if candidate_format != format {
    raise transaction_error(
      "office.transaction.format_changed",
      "candidate format \{candidate_format.name()} does not match input format \{format.name()}",
      details=Json::object({
        "input_format": Json::string(format.name()),
        "candidate_format": Json::string(candidate_format.name()),
      }),
    )
  }
  let summaries : Array[ValidationSummary] = [
    { name: "office-portable-opc", passed: true, finding_count: 0 },
  ]
  for validator in validators {
    let findings = validator.run(format, mutation.bytes) catch {
      error =>
        raise transaction_error(
          "office.transaction.validation_failed",
          "validator '\{validator.name}' failed: \{bounded_text(error.to_string(), 240)}",
          details=Json::object({ "validator": Json::string(validator.name) }),
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
  summaries
}

///|
async fn cleanup_temp(path : String) -> Unit noraise {
  @afs.remove(path) catch {
    _ => ()
  }
}

///|
async fn create_temp(
  destination : String,
  permission : Int,
) -> (String, @afs.File) raise TransactionError {
  let stamp = @env.now()
  for attempt in 0..<transaction_temp_attempts {
    let candidate = "\{destination}.office-tmp-\{stamp}-\{attempt}"
    let file = @afs.open(
      candidate,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission~,
      sync=NoSync,
    ) catch {
      @os_error.OSError(_) as error if error.is_EEXIST() => continue
      error =>
        raise transaction_error(
          "office.transaction.temp_create_failed",
          "could not create a temporary file next to the destination: \{bounded_text(error.to_string(), 240)}",
          details=Json::object({
            "output": Json::string(bounded_text(destination, 160)),
          }),
        )
    }
    return (candidate, file)
  }
  raise transaction_error(
    "office.transaction.temp_create_failed",
    "could not allocate a unique temporary file after \{transaction_temp_attempts} attempts",
    details=Json::object({
      "output": Json::string(bounded_text(destination, 160)),
    }),
  )
}

///|
async fn sync_parent_directory(destination : String) -> Bool noraise {
  let parent = path_parent(destination)
  let directory = @afs.open(parent, mode=ReadOnly) catch { _ => return false }
  let synced = try directory.sync() catch {
    _ => false
  } noraise {
    _ => true
  }
  directory.close()
  synced
}

///|
async fn check_source_unchanged(
  source_target : String,
  original : Bytes,
) -> Unit raise TransactionError {
  let current = @afs.read_file(source_target).binary() catch {
    _ =>
      raise transaction_error(
        "office.transaction.source_changed", "input disappeared or became unreadable before the in-place commit",
      )
  }
  if current != original {
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
) -> Bool raise TransactionError {
  let (temp, file) = create_temp(policy.destination_target, options.permission)
  if faults.fail_write {
    file.close()
    cleanup_temp(temp)
    raise transaction_error(
      "office.transaction.write_failed", "injected temporary-file write failure",
    )
  }
  file.write(candidate) catch {
    error => {
      file.close()
      cleanup_temp(temp)
      raise transaction_error(
        "office.transaction.write_failed",
        "could not write temporary package: \{bounded_text(error.to_string(), 240)}",
      )
    }
  }
  file.sync() catch {
    error => {
      file.close()
      cleanup_temp(temp)
      raise transaction_error(
        "office.transaction.sync_failed",
        "could not sync temporary package: \{bounded_text(error.to_string(), 240)}",
      )
    }
  }
  file.close()
  if policy.mode is InPlace {
    match faults.concurrent_replacement {
      Some(replacement) =>
        @afs.write_file(
          policy.source_target,
          replacement,
          create_mode=CreateOrTruncate,
          permission=options.permission,
        ) catch {
          error => {
            cleanup_temp(temp)
            raise transaction_error(
              "office.transaction.commit_failed",
              "could not inject the concurrent-source test replacement: \{bounded_text(error.to_string(), 240)}",
            )
          }
        }
      None => ()
    }
    check_source_unchanged(policy.source_target, original) catch {
      error => {
        cleanup_temp(temp)
        raise error
      }
    }
  }
  if faults.fail_rename {
    cleanup_temp(temp)
    raise transaction_error(
      "office.transaction.commit_failed", "injected atomic-rename failure",
    )
  }
  @afs.rename(temp, policy.destination_target, replace=policy.replace) catch {
    error => {
      cleanup_temp(temp)
      let code = if policy.mode is Output && !policy.replace {
        "office.transaction.output_exists"
      } else {
        "office.transaction.commit_failed"
      }
      raise transaction_error(
        code,
        "could not atomically publish destination: \{bounded_text(error.to_string(), 240)}",
        details=Json::object({
          "output": Json::string(bounded_text(policy.output_path, 160)),
        }),
      )
    }
  }
  sync_parent_directory(policy.destination_target)
}

///|
#cfg(target="native")
fn append_platform_warnings(
  warnings : Array[@office.ProtocolWarning],
  committed : Bool,
  parent_synced : Bool,
) -> Unit {
  if committed && !parent_synced {
    warnings.push(
      @office.protocol_warning(
        "office.transaction.directory_sync_unavailable", "package bytes were atomically renamed, but the parent directory could not be synced on this host",
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
) -> Unit {
  if committed {
    warnings.push(
      @office.protocol_warning(
        "office.transaction.wasm_commit_semantics", "Wasm uses normalized paths and a same-directory rename, but host-independent realpath, symlink identity, and parent-directory durability are unavailable",
      ),
    )
  }
}

///|
async fn transact_with_faults(
  options : TransactionOptions,
  mutate : (@office.DocumentFormat, BytesView) -> TransactionMutation raise,
  validators : Array[TransactionValidator],
  faults : TransactionFaults,
) -> TransactionReport raise TransactionError {
  validate_validator_set(validators)
  let policy = resolve_policy(options)
  let original = read_original(options, policy.source_target)
  let format = identify_input(options, original)
  let mutation = mutate(format, original) catch {
    TransactionError(..) as error => raise error
    error =>
      raise transaction_error(
        "office.transaction.mutation_failed",
        "mutation callback failed: \{bounded_text(error.to_string(), 240)}",
      )
  }
  let validations = validate_candidate(
    format,
    policy.output_path,
    mutation,
    validators,
  )
  let preservation = preservation_report(original, mutation)
  let changed = original != mutation.bytes
  let should_commit = !options.dry_run && (policy.mode is Output || changed)
  let parent_synced = if should_commit {
    publish_candidate(options, policy, original, mutation.bytes, faults)
  } else {
    true
  }
  let warnings = []
  for warning in mutation.warnings {
    warnings.push(warning)
  }
  append_platform_warnings(warnings, should_commit, parent_synced)
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
/// Runs one fail-closed Office package transaction. The mutation callback owns
/// only in-memory transformation; mandatory validation, preservation checks,
/// source conflict detection, and atomic publication remain in this function.
pub async fn transact(
  options : TransactionOptions,
  mutate : (@office.DocumentFormat, BytesView) -> TransactionMutation raise,
  validators? : Array[TransactionValidator] = [],
) -> TransactionReport raise TransactionError {
  transact_with_faults(options, mutate, validators, no_transaction_faults())
}
