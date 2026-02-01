///|
priv struct RegexRange {
  start : Char
  end : Char
}

///|
priv enum RegexTokenKind {
  Literal(Char)
  Any
  Class(Array[RegexRange])
}

///|
priv struct RegexToken {
  kind : RegexTokenKind
  repeat : Bool
}

///|
fn regex_is_escaped(chars : Array[Char], index : Int) -> Bool {
  let mut count = 0
  for i in index>..0 {
    if chars[i] == '\\' {
      count = count + 1
    } else {
      break
    }
  }
  count % 2 == 1
}

///|
fn parse_regex_tokens(pattern : StringView) -> (Array[RegexToken], Bool, Bool) {
  let chars = pattern.to_array()
  let mut start = 0
  let mut anchor_start = false
  if chars.length() > 0 && chars[0] == '^' {
    anchor_start = true
    start = 1
  }
  let mut end = chars.length()
  let mut anchor_end = false
  if end > start && chars[end - 1] == '$' && !regex_is_escaped(chars, end - 1) {
    anchor_end = true
    end = end - 1
  }
  let tokens : Array[RegexToken] = []
  let mut i = start
  while i < end {
    let ch = chars[i]
    if ch == '\\' {
      if i + 1 < end {
        tokens.push({ kind: Literal(chars[i + 1]), repeat: false })
        i = i + 2
        continue
      }
      tokens.push({ kind: Literal(ch), repeat: false })
      i = i + 1
      continue
    }
    let mut kind = RegexTokenKind::Literal(ch)
    if ch == '.' {
      kind = Any
      i = i + 1
    } else if ch == '[' {
      let ranges : Array[RegexRange] = []
      let mut j = i + 1
      let mut closed = false
      while j < end {
        if chars[j] == ']' && j > i + 1 {
          closed = true
          break
        }
        let mut start_char = chars[j]
        if start_char == '\\' && j + 1 < end {
          start_char = chars[j + 1]
          j = j + 2
        } else {
          j = j + 1
        }
        if j + 1 < end && chars[j] == '-' && chars[j + 1] != ']' {
          let end_char = chars[j + 1]
          ranges.push({ start: start_char, end: end_char })
          j = j + 2
        } else {
          ranges.push({ start: start_char, end: start_char })
        }
      }
      if closed {
        kind = Class(ranges)
        i = j + 1
      } else {
        kind = Literal(ch)
        i = i + 1
      }
    } else {
      i = i + 1
    }
    let mut repeat = false
    if i < end && chars[i] == '*' {
      repeat = true
      i = i + 1
    }
    tokens.push({ kind, repeat })
  }
  (tokens, anchor_start, anchor_end)
}

///|
fn regex_token_matches(token : RegexTokenKind, ch : Char) -> Bool {
  match token {
    Literal(value) => value == ch
    Any => true
    Class(ranges) => {
      for range in ranges {
        if ch >= range.start && ch <= range.end {
          return true
        }
      }
      false
    }
  }
}

///|
fn sheet_regex_match_from(
  text : Array[Char],
  tokens : Array[RegexToken],
  i : Int,
  j : Int,
  memo : Map[(Int, Int), Bool],
  require_end : Bool,
) -> Bool {
  match memo.get((i, j)) {
    Some(result) => return result
    None => ()
  }
  let result = if j == tokens.length() {
    if require_end {
      i == text.length()
    } else {
      true
    }
  } else {
    let token = tokens[j]
    if token.repeat {
      if sheet_regex_match_from(text, tokens, i, j + 1, memo, require_end) {
        true
      } else if i < text.length() && regex_token_matches(token.kind, text[i]) {
        sheet_regex_match_from(text, tokens, i + 1, j, memo, require_end)
      } else {
        false
      }
    } else if i < text.length() && regex_token_matches(token.kind, text[i]) {
      sheet_regex_match_from(text, tokens, i + 1, j + 1, memo, require_end)
    } else {
      false
    }
  }
  memo[(i, j)] = result
  result
}

///|
fn regex_search(text : StringView, pattern : StringView) -> Bool {
  let (tokens, anchor_start, anchor_end) = parse_regex_tokens(pattern)
  let chars = text.to_array()
  if anchor_start {
    let memo : Map[(Int, Int), Bool] = {}
    return sheet_regex_match_from(chars, tokens, 0, 0, memo, anchor_end)
  }
  let mut start = 0
  while start <= chars.length() {
    let memo : Map[(Int, Int), Bool] = {}
    if sheet_regex_match_from(chars, tokens, start, 0, memo, anchor_end) {
      return true
    }
    start = start + 1
  }
  false
}

///|
pub fn Workbook::search_sheet(
  self : Workbook,
  sheet_name : StringView,
  value : String,
  reg? : Bool = false,
) -> Array[String] raise XlsxError {
  check_sheet_name(sheet_name)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  let use_regex = reg
  let results : Array[String] = []
  let cells = sheet.sorted_cells()
  for cell in cells {
    let matched = if use_regex {
      regex_search(cell.value, value)
    } else {
      cell.value == value
    }
    if matched {
      results.push(cell.reference)
    }
  }
  results
}
