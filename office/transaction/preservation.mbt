///|
fn archive_payloads(archive : @zip.Archive) -> Map[String, BytesView] {
  let payloads : Map[String, BytesView] = Map([])
  for entry in archive.entries() {
    payloads[entry.name()] = entry.data()
  }
  payloads
}

///|
fn readonly_strings(values : Array[String]) -> ReadOnlyArray[String] {
  ReadOnlyArray::from_array(values)
}

///|
fn declared_contains(declared : ReadOnlyArray[String], part : String) -> Bool {
  for allowed in declared {
    if allowed == part {
      return true
    }
  }
  false
}

///|
fn preservation_report_archives(
  original : BytesView,
  mutation : ResolvedTransactionMutation,
  original_archive : @zip.Archive,
  candidate_archive : @zip.Archive,
) -> PreservationReport raise TransactionError {
  let before = archive_payloads(original_archive)
  let after = archive_payloads(candidate_archive)
  let names = []
  for name, _ in before {
    names.push(name)
  }
  for name, _ in after {
    if !before.contains(name) {
      names.push(name)
    }
  }
  names.sort()
  let changed = []
  let added = []
  let removed = []
  let unchanged = []
  for name in names {
    match (before.get(name), after.get(name)) {
      (Some(left), Some(right)) =>
        if left == right {
          unchanged.push(name)
        } else {
          changed.push(name)
        }
      (None, Some(_)) => added.push(name)
      (Some(_), None) => removed.push(name)
      (None, None) => ()
    }
  }
  match mutation.declared_parts {
    Some(declared) => {
      let violations = []
      for part in changed {
        if !declared_contains(declared, part) {
          violations.push(part)
        }
      }
      for part in added {
        if !declared_contains(declared, part) {
          violations.push(part)
        }
      }
      for part in removed {
        if !declared_contains(declared, part) {
          violations.push(part)
        }
      }
      violations.sort()
      if !violations.is_empty() {
        raise transaction_error(
          "office.transaction.preservation_violation",
          "candidate changes archive parts outside the declared preservation manifest",
          details=Json::object({
            "undeclared_parts": Json::array(
              violations.map(part => Json::string(part)),
            ),
          }),
        )
      }
    }
    None => ()
  }
  {
    whole_file_identical: original == mutation.bytes,
    manifest_enforced: mutation.declared_parts is Some(_),
    changed: readonly_strings(changed),
    added: readonly_strings(added),
    removed: readonly_strings(removed),
    unchanged: readonly_strings(unchanged),
    zip_metadata_policy: "entry payloads compared; ZIP headers, ordering, compression metadata, timestamps, and comments are not compared",
  }
}
