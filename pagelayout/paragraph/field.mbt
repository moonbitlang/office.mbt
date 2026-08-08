///|
// Fields. Word stores a computed value — a page number, a cross
// reference, a date — as a *field*: an instruction plus the result
// cached when the document was last saved. Rendering the cache is why
// every page of a document can show the same page number.
//
// A run therefore carries what kind of field produced it, so the layout
// can substitute the real value at the moment it knows one.

///|
/// The field instructions this engine evaluates. Everything else keeps
/// its cached result, which is the best available answer for a field
/// whose value this engine cannot compute (a cross reference, a
/// citation, a merge field).
pub(all) enum FieldKind {
  /// Not a field: ordinary text.
  NotAField
  /// `PAGE` — the number of the page the run lands on.
  PageNumber
  /// `NUMPAGES` — the document's total page count.
  PageCount
} derive(Eq, Debug, ToJson)

///|
/// Classify a field instruction such as `" PAGE \\* MERGEFORMAT "`. Only
/// the leading keyword matters; switches after it are formatting
/// directives this engine does not apply.
pub fn field_kind(instruction : String) -> FieldKind {
  let trimmed = instruction.trim(chars=" \t\r\n")
  // the keyword runs to the first space
  let keyword = match trimmed.find(" ") {
    Some(i) => trimmed[0:i].to_owned()
    None => trimmed.to_owned()
  }
  match keyword.to_upper() {
    "PAGE" => PageNumber
    "NUMPAGES" => PageCount
    _ => NotAField
  }
}

///|
/// Substitute a run's text for a known page number and count. Runs that
/// are not fields, and fields this engine does not evaluate, are
/// unchanged.
pub fn RunInput::evaluate(
  self : RunInput,
  page_number : Int,
  page_count : Int,
) -> RunInput {
  match self.field {
    NotAField => self
    PageNumber => { ..self, text: page_number.to_string() }
    PageCount => { ..self, text: page_count.to_string() }
  }
}

///|
/// Whether any run of this paragraph needs a page number to render
/// correctly — so callers can lay furniture out once when none does.
pub fn ParagraphInput::has_fields(self : ParagraphInput) -> Bool {
  for run in self.runs {
    if !(run.field is NotAField) {
      return true
    }
  }
  false
}
