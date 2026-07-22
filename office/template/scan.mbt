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
/// A half-open region of the scanned text in segment coordinates:
/// `[start, end)` where each endpoint is (segment index, code-unit offset
/// within that segment). `end_offset` may equal the end segment's length.
pub(all) struct TemplateSpan {
  start_segment : Int
  start_offset : Int
  end_segment : Int
  end_offset : Int
} derive(Eq, @debug.Debug)

///|
/// One well-formed placeholder occurrence.
pub(all) struct PlaceholderMatch {
  key : String
  span : TemplateSpan
} derive(Eq, @debug.Debug)

///|
/// One `{{` that forms neither a placeholder nor an escape.
pub(all) struct MalformedPlaceholder {
  span : TemplateSpan
  reason : String
} derive(Eq, @debug.Debug)

///|
/// The complete result of scanning one hard-break-free region.
pub(all) struct TemplateScan {
  matches : Array[PlaceholderMatch]
  escapes : Array[TemplateSpan]
  malformed : Array[MalformedPlaceholder]
} derive(Eq, @debug.Debug)

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
  self.segments[low].code_units()[position - self.starts[low]].to_int()
}

///|
fn ScanCursor::point(self : ScanCursor, position : Int) -> (Int, Int) {
  if self.total == 0 {
    return (0, 0)
  }
  if position >= self.total {
    let last = self.segments.length() - 1
    return (last, self.segments[last].code_units().length())
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
