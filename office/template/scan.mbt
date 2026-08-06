///|
/// The T1 placeholder grammar, shared by every format:
///
/// ```text
/// placeholder := "{{" key "}}"
/// key         := [A-Za-z_][A-Za-z0-9_.-]{0,63}   (opaque; dots carry no traversal)
/// escape      := "\{{"  ->  literal "{{" in the output
/// ```
///
/// The scan runs left to right over the CONCATENATION of the caller's
/// segments (a placeholder may span segment boundaries — Word splits text
/// runs freely), in a single pass with a caller-charged work budget. Any
/// `{{` that forms neither a well-formed placeholder nor an escape is
/// reported as malformed — strict, so a typo can never silently survive
/// into published output. A lone backslash and a stray `}}` are ordinary
/// text.

///|
/// Errors raised by the placeholder scanner.
pub suberror TemplateScanError {
  TemplateScanBudgetExceeded(String)
} derive(@debug.Debug)

///|
pub extend TemplateScanError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// A half-open region of the scanned text in segment coordinates:
/// `[start, end)` where each endpoint is (segment index, code-unit offset
/// within that segment). CANONICAL FORM: an end landing exactly on a
/// segment boundary is reported as (next segment, 0), not
/// (segment, length) — the two are the same logical position, and
/// callers rewriting per-segment ranges must treat an end at (i, 0) as
/// "nothing of segment i is covered". Only a span ending at the very end
/// of the text uses (last segment, its length).
pub(all) struct TemplateSpan {
  start_segment : Int
  start_offset : Int
  end_segment : Int
  end_offset : Int
} derive(Eq, @debug.Debug)

///|
pub extend TemplateSpan with Eq::{not_equal, equal}

///|
pub extend TemplateSpan with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// One well-formed placeholder occurrence.
pub(all) struct PlaceholderMatch {
  key : String
  span : TemplateSpan
} derive(Eq, @debug.Debug)

///|
pub extend PlaceholderMatch with Eq::{not_equal, equal}

///|
pub extend PlaceholderMatch with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// One `{{` that forms neither a placeholder nor an escape. The span
/// ends AT the offending unit (or at end of text), not past it.
pub(all) struct MalformedPlaceholder {
  span : TemplateSpan
  reason : String
} derive(Eq, @debug.Debug)

///|
pub extend MalformedPlaceholder with Eq::{not_equal, equal}

///|
pub extend MalformedPlaceholder with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// The complete result of scanning one hard-break-free region.
pub(all) struct TemplateScan {
  matches : Array[PlaceholderMatch]
  escapes : Array[TemplateSpan]
  malformed : Array[MalformedPlaceholder]
} derive(Eq, @debug.Debug)

///|
pub extend TemplateScan with Eq::{not_equal, equal}

///|
pub extend TemplateScan with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// The placeholder key grammar: `[A-Za-z_][A-Za-z0-9_.-]{0,63}`.
pub fn template_key_ok(key : String) -> Bool {
  let units = key.code_units()
  if units.length() == 0 || units.length() > 64 {
    return false
  }
  for index, unit in units {
    let ok = if index == 0 {
      unit is ('A'..='Z' | 'a'..='z' | '_')
    } else {
      unit is ('A'..='Z' | 'a'..='z' | '0'..='9' | '_' | '.' | '-')
    }
    if !ok {
      return false
    }
  }
  true
}

///|
/// Scans the segments' concatenated text for NON-OVERLAPPING occurrences
/// of a LITERAL needle, left to right, sharing the placeholder scanner's
/// segment cursor: a match may span segment boundaries exactly like a
/// placeholder, and the returned spans use the same canonical form. The
/// needle is never interpreted — there is no escaping, no wildcard, and
/// no regular-expression syntax, matching `query --text`.
///
/// Matching is over UTF-16 code units. A well-formed needle can neither
/// begin nor end inside a surrogate pair, so every returned endpoint is
/// a valid slicing boundary.
///
/// An empty needle matches nothing (callers must reject it earlier).
/// `budget` is charged the scanned length plus one unit per comparison,
/// so a pathological needle cannot buy unbounded work.
pub fn scan_literal(
  segments : Array[String],
  needle : String,
  budget : Ref[Int],
) -> Array[TemplateSpan] raise TemplateScanError {
  let needle_units = needle.code_units()
  let needle_length = needle_units.length()
  let starts : Array[Int] = []
  let mut total = 0
  for segment in segments {
    starts.push(total)
    total += segment.code_units().length()
  }
  budget.val -= total
  if budget.val < 0 {
    raise TemplateScanBudgetExceeded(
      "template scan work exceeds the configured ceiling",
    )
  }
  let spans : Array[TemplateSpan] = []
  guard needle_length > 0 && needle_length <= total else { return spans }
  let cursor : ScanCursor = { segments, starts, total }
  let mut position = 0
  while position + needle_length <= total {
    let mut probe = 0
    while probe < needle_length &&
          cursor.unit_at(position + probe) == needle_units[probe].to_int() {
      probe += 1
    }
    budget.val -= probe + 1
    if budget.val < 0 {
      raise TemplateScanBudgetExceeded(
        "template scan work exceeds the configured ceiling",
      )
    }
    if probe == needle_length {
      spans.push(cursor.span(position, position + needle_length))
      position += needle_length
    } else {
      position += 1
    }
  }
  spans
}

///|
priv struct ScanCursor {
  segments : Array[String]
  // flattened (segment, offset) pairs are recomputed from a linear
  // position so the scanner itself works over one logical text
  starts : Array[Int]
  total : Int
}

///|
fn ScanCursor::unit_at(self : ScanCursor, position : Int) -> Int {
  // segments are typically few (runs of one paragraph region); a linear
  // segment lookup with a moving lower bound would complicate the caller
  // contract, so binary-search the owning segment
  let mut low = 0
  let mut high = self.starts.length() - 1
  while low < high {
    let mid = (low + high + 1) / 2
    if self.starts[mid] <= position {
      low = mid
    } else {
      high = mid - 1
    }
  }
  self.segments[low][position - self.starts[low]].to_int()
}

///|
fn ScanCursor::point(self : ScanCursor, position : Int) -> (Int, Int) {
  if self.total == 0 {
    return (0, 0)
  }
  if position >= self.total {
    let last = self.segments.length() - 1
    return (last, self.total - self.starts[last])
  }
  let mut low = 0
  let mut high = self.starts.length() - 1
  while low < high {
    let mid = (low + high + 1) / 2
    if self.starts[mid] <= position {
      low = mid
    } else {
      high = mid - 1
    }
  }
  (low, position - self.starts[low])
}

///|
fn ScanCursor::span(self : ScanCursor, start : Int, end : Int) -> TemplateSpan {
  let (start_segment, start_offset) = self.point(start)
  let (end_segment, end_offset) = self.point(end)
  { start_segment, start_offset, end_segment, end_offset }
}

///|
/// Scans the segments' concatenated text for placeholders, escapes, and
/// malformed sites. `budget` is decremented one unit per scanned code
/// unit; exhausting it raises, so callers bound total template work the
/// way the query surface bounds predicate work.
pub fn scan_placeholders(
  segments : Array[String],
  budget : Ref[Int],
) -> TemplateScan raise TemplateScanError {
  let starts : Array[Int] = []
  let mut total = 0
  for segment in segments {
    starts.push(total)
    total += segment.code_units().length()
  }
  let cursor : ScanCursor = { segments, starts, total }
  let matches : Array[PlaceholderMatch] = []
  let escapes : Array[TemplateSpan] = []
  let malformed : Array[MalformedPlaceholder] = []
  budget.val -= total
  if budget.val < 0 {
    raise TemplateScanBudgetExceeded(
      "template scan work exceeds the configured ceiling",
    )
  }
  let mut position = 0
  while position < total {
    let unit = cursor.unit_at(position)
    if unit == '\\'.to_int() &&
      position + 2 < total &&
      cursor.unit_at(position + 1) == '{'.to_int() &&
      cursor.unit_at(position + 2) == '{'.to_int() {
      escapes.push(cursor.span(position, position + 3))
      position += 3
      continue
    }
    if unit == '{'.to_int() &&
      position + 1 < total &&
      cursor.unit_at(position + 1) == '{'.to_int() {
      let open = position
      let mut probe = position + 2
      let key = StringBuilder::new()
      let mut reason = ""
      // first key unit
      if probe >= total {
        reason = "unterminated placeholder at end of text"
      } else {
        let first = cursor.unit_at(probe)
        if first is ('A'..='Z' | 'a'..='z' | '_') {
          key.write_char(first.unsafe_to_char())
          let mut key_units = 1
          probe += 1
          while reason == "" && probe < total {
            let next = cursor.unit_at(probe)
            if next is ('A'..='Z' | 'a'..='z' | '0'..='9' | '_' | '.' | '-') {
              if key_units >= 64 {
                reason = "placeholder key exceeds 64 characters"
              } else {
                key.write_char(next.unsafe_to_char())
                key_units += 1
                probe += 1
              }
            } else if next == '}'.to_int() {
              break
            } else {
              reason = "invalid character in placeholder key"
            }
          }
          if reason == "" {
            if probe + 1 < total &&
              cursor.unit_at(probe) == '}'.to_int() &&
              cursor.unit_at(probe + 1) == '}'.to_int() {
              matches.push({
                key: key.to_string(),
                span: cursor.span(open, probe + 2),
              })
              position = probe + 2
              continue
            } else {
              reason = "unterminated placeholder"
            }
          }
        } else {
          reason = "placeholder key is empty or starts with an invalid character"
        }
      }
      malformed.push({
        span: cursor.span(open, if probe < total { probe } else { total }),
        reason,
      })
      // resume after the braces so every later site is still reported
      position = open + 2
      continue
    }
    position += 1
  }
  { matches, escapes, malformed }
}
