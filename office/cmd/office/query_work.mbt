///|
/// A command-wide linear-work ceiling independent of retained output. UTF-16
/// length is a conservative upper bound for Unicode-scalar iteration, so the
/// limit also covers supplementary characters without under-counting.
let office_cli_max_query_predicate_work_units : Int = 128 * 1024 * 1024

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
fn OfficeLinearPattern::is_in(
  self : OfficeLinearPattern,
  value : String,
  work : OfficeQueryWorkBudget,
) -> Bool raise CliFailure {
  if self.characters.is_empty() {
    return true
  }
  // KMP performs at most two pattern comparisons per scalar. The third unit
  // covers iteration/folding; UTF-16 length safely over-counts scalars.
  work.charge(value.length() * 3 + 1)
  let mut matched = 0
  for raw_character in value {
    let character = query_fold_character(raw_character, self.ignore_case)
    while matched > 0 && character != self.characters[matched] {
      matched = self.failure[matched - 1]
    }
    if character == self.characters[matched] {
      matched += 1
      if matched == self.characters.length() {
        return true
      }
    }
  }
  false
}
