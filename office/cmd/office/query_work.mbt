///|
/// A command-wide linear-work ceiling independent of retained output. UTF-16
/// length is a conservative upper bound for Unicode-scalar iteration, so the
/// limit also covers supplementary characters without under-counting.
let office_cli_max_query_predicate_work_units : Int = 128 * 1024 * 1024

///|
let office_cli_query_yield_work_units : Int = 4096

///|
struct OfficeQueryWorkBudget {
  format : String
  maximum : Int
  mut used : Int
}

///|
fn OfficeQueryWorkBudget::new(
  maximum : Int,
  format? : String = "docx",
) -> OfficeQueryWorkBudget {
  { format, maximum, used: 0 }
}

///|
fn OfficeQueryWorkBudget::charge(
  self : OfficeQueryWorkBudget,
  count : Int,
) -> Unit raise CliFailure {
  if count < 0 || count > self.maximum - self.used {
    let actual = if count < 0 { self.used } else { self.used + count }
    raise format_resource_failure(
      self.format,
      "query predicate work units",
      self.maximum,
      actual~,
    )
  }
  self.used += count
}

///|
/// A Knuth-Morris-Pratt literal pattern. The failure table is compiled once
/// per command, making every value match linear in the scanned text.
struct OfficeLinearPattern {
  characters : Array[Char]
  failure : Array[Int]
  ignore_case : Bool
}

///|
fn query_fold_character(character : Char, ignore_case : Bool) -> Char {
  if ignore_case {
    // Locale-independent Unicode simple lowercase mapping is one-to-one, so
    // it preserves substring boundaries and has a fixed bound per scalar.
    @unicode.to_simple_lowercase(character)
  } else {
    character
  }
}

///|
fn OfficeLinearPattern::compile(
  needle : String,
  ignore_case : Bool,
  work : OfficeQueryWorkBudget,
) -> OfficeLinearPattern raise CliFailure {
  // Four code-unit work units conservatively cover scalar iteration, simple
  // folding, and the amortized failure-table comparisons.
  work.charge(needle.length() * 4 + 1)
  let characters : Array[Char] = []
  for character in needle {
    characters.push(query_fold_character(character, ignore_case))
  }
  let failure = Array::make(characters.length(), 0)
  let mut matched = 0
  for at in 1..<characters.length() {
    while matched > 0 && characters[at] != characters[matched] {
      matched = failure[matched - 1]
    }
    if characters[at] == characters[matched] {
      matched += 1
    }
    failure[at] = matched
  }
  { characters, failure, ignore_case }
}

///|
async fn OfficeLinearPattern::compile_cooperative(
  needle : String,
  ignore_case : Bool,
  work : OfficeQueryWorkBudget,
) -> OfficeLinearPattern {
  // Reserve the complete conservative cost before retaining either index.
  work.charge(needle.length() * 4 + 1)
  let characters : Array[Char] = []
  let mut visited = 0
  for character in needle {
    if visited >= office_cli_query_yield_work_units {
      visited = 0
      @async.pause()
    }
    characters.push(query_fold_character(character, ignore_case))
    visited += 1
  }
  let failure = Array::make(characters.length(), 0)
  let mut matched = 0
  visited = 0
  for at in 1..<characters.length() {
    if visited >= office_cli_query_yield_work_units {
      visited = 0
      @async.pause()
    }
    while matched > 0 && characters[at] != characters[matched] {
      if visited >= office_cli_query_yield_work_units {
        visited = 0
        @async.pause()
      }
      matched = failure[matched - 1]
      visited += 1
    }
    if characters[at] == characters[matched] {
      matched += 1
    }
    failure[at] = matched
    visited += 1
  }
  { characters, failure, ignore_case }
}

///|
async fn query_strings_equal_cooperative(
  value : String,
  expected : String,
  work : OfficeQueryWorkBudget,
) -> Bool {
  if value.length() != expected.length() {
    // String lengths are already known, so unequal-length values require no
    // linear comparison even though the conservative work budget retains the
    // same upper-bound accounting as an equal-length comparison.
    work.charge(value.length().min(expected.length()) + 1)
    return false
  }
  let mut pending_work = 1
  for index in 0..<value.length() {
    if pending_work >= office_cli_query_yield_work_units {
      work.charge(pending_work)
      pending_work = 0
      @async.pause()
    }
    pending_work += 1
    if value[index] != expected[index] {
      work.charge(pending_work)
      return false
    }
  }
  work.charge(pending_work)
  true
}

///|
async fn query_string_has_prefix_cooperative(
  value : String,
  prefix : String,
  work : OfficeQueryWorkBudget,
) -> Bool {
  if value.length() < prefix.length() {
    work.charge(value.length() + 1)
    return false
  }
  let mut pending_work = 1
  for index in 0..<prefix.length() {
    if pending_work >= office_cli_query_yield_work_units {
      work.charge(pending_work)
      pending_work = 0
      @async.pause()
    }
    pending_work += 1
    if value[index] != prefix[index] {
      work.charge(pending_work)
      return false
    }
  }
  work.charge(pending_work)
  true
}

///|
async fn OfficeLinearPattern::is_in_cooperative(
  self : OfficeLinearPattern,
  value : String,
  work : OfficeQueryWorkBudget,
) -> Bool {
  if self.characters.is_empty() {
    return true
  }
  let mut matched = 0
  let mut pending_work = 1
  let mut scheduling_work = 0
  for raw_character in value {
    // Supplementary scalars occupy two UTF-16 units. This preserves the
    // conservative accounting while charging and yielding in small quanta.
    let scalar_work = if raw_character.to_int() > 0xffff { 6 } else { 3 }
    if pending_work > office_cli_query_yield_work_units - scalar_work {
      work.charge(pending_work)
      pending_work = 0
      @async.pause()
    }
    pending_work += scalar_work
    scheduling_work += 1
    let character = query_fold_character(raw_character, self.ignore_case)
    while matched > 0 && character != self.characters[matched] {
      if scheduling_work >= office_cli_query_yield_work_units {
        scheduling_work = 0
        @async.pause()
      }
      matched = self.failure[matched - 1]
      scheduling_work += 1
    }
    if character == self.characters[matched] {
      matched += 1
      if matched == self.characters.length() {
        work.charge(pending_work)
        return true
      }
    }
  }
  work.charge(pending_work)
  false
}
