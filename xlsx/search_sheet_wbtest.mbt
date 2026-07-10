///|
test "search sheet wb: regex parser handles trailing escape and escaped class char" {
  inspect(regex_search("\\", "\\"), content="true")
  inspect(regex_search("-", "^[\\-]$"), content="true")
}

///|
test "search sheet wb: memoized match fast-return branch" {
  let memo : Map[(Int, Int), Bool] = Map([])
  memo[(1, 1)] = true
  let tokens : Array[RegexToken] = []
  let result = sheet_regex_match_from(
    "abc".to_array(),
    tokens,
    1,
    1,
    memo,
    false,
  )
  inspect(result, content="true")
}
