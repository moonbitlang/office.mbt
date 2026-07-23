// N0 increment 1 — the w:t content lexical tokenizer, oracle-style unit tests.
// The concatenated token projection must equal what the reader projects for a
// w:t carrying that exact source content, and the token kinds/byte spans must
// be exact so surgery can splice on scalar/edge boundaries.

///|
/// Tokenizes `source` as a w:t element's raw content and returns the tokens.
fn tokens_of(source : String) -> Array[SourceToken] raise TokenMapError {
  let bytes = @utf8.encode(source)
  tokenize_wt_content(bytes[:], 0, bytes.length())
}

///|
/// The concatenated projection the tokens produce.
fn projection_of(source : String) -> String raise TokenMapError {
  let builder = StringBuilder::new()
  for token in tokens_of(source) {
    builder.write_string(token.projection)
  }
  builder.to_string()
}

///|
test "content tokenizer: raw text projects verbatim as one token" {
  let tokens = tokens_of("Hello, world")
  assert_eq(tokens.length(), 1)
  assert_eq(tokens[0].kind, RawText)
  assert_eq(tokens[0].byte_start, 0)
  assert_eq(tokens[0].byte_end, 12)
  assert_eq(tokens[0].projection, "Hello, world")
}

///|
test "content tokenizer: the five named entities decode, atomic spans" {
  // "a&amp;b&lt;c&gt;d&quot;e&apos;f"
  let source = "a&amp;b&lt;c&gt;d&quot;e&apos;f"
  assert_eq(projection_of(source), "a&b<c>d\"e'f")
  let tokens = tokens_of(source)
  // raw a, ent &, raw b, ent <, raw c, ent >, raw d, ent ", raw e, ent ', raw f
  let kinds = tokens.map(t => t.kind)
  assert_eq(kinds, [
    RawText,
    EntityRef,
    RawText,
    EntityRef,
    RawText,
    EntityRef,
    RawText,
    EntityRef,
    RawText,
    EntityRef,
    RawText,
  ])
  // the first entity span covers exactly "&amp;" (5 bytes at offset 1)
  assert_eq(tokens[1].byte_start, 1)
  assert_eq(tokens[1].byte_end, 6)
  assert_eq(tokens[1].projection, "&")
}

///|
test "content tokenizer: numeric character references, decimal and hex" {
  // decimal é = &#233; ; hex é = &#xe9; ; hex uppercase X and digits
  assert_eq(projection_of("caf&#233;"), "café")
  assert_eq(projection_of("caf&#xe9;"), "café")
  assert_eq(projection_of("caf&#XE9;"), "café")
  let tokens = tokens_of("&#233;")
  assert_eq(tokens.length(), 1)
  assert_eq(tokens[0].kind, NumericCharRef)
  assert_eq(tokens[0].byte_start, 0)
  assert_eq(tokens[0].byte_end, 6)
  assert_eq(tokens[0].projection, "é")
}

///|
test "content tokenizer: astral character reference and raw emoji agree" {
  // U+1F600 GRINNING FACE both as a hex reference and raw UTF-8 project equally
  assert_eq(projection_of("x&#x1F600;y"), "x😀y")
  assert_eq(projection_of("x😀y"), "x😀y")
  // the raw form is one RawText token; the reference form is three tokens
  assert_eq(tokens_of("x😀y").length(), 1)
  assert_eq(tokens_of("x&#x1F600;y").length(), 3)
}

///|
test "content tokenizer: CDATA projects its inner bytes verbatim" {
  let source = "a<![CDATA[b & <c> ]]>d"
  // CDATA inner is literal: "b & <c> " with no entity decoding
  assert_eq(projection_of(source), "ab & <c> d")
  let tokens = tokens_of(source)
  assert_eq(tokens.map(t => t.kind), [RawText, CData, RawText])
  assert_eq(tokens[1].projection, "b & <c> ")
  // the CDATA span includes the framing
  assert_eq(tokens[1].byte_start, 1)
}

///|
test "content tokenizer: empty content yields no tokens" {
  assert_eq(tokens_of("").length(), 0)
}

///|
test "content tokenizer: malformed input refuses, never silently drops" {
  fn refuses(source : String, fragment : String) -> Unit raise {
    try tokens_of(source) |> ignore catch {
      TokenMapError(message) => assert_true(message.contains(fragment))
    } noraise {
      _ => fail("expected refusal for: " + source)
    }
  }

  refuses("a&amp", "unterminated entity")
  refuses("a&nbsp;b", "unsupported named entity")
  refuses("a&#zz;b", "invalid digit")
  refuses("a&#;b", "empty numeric")
  refuses("a<![CDATA[unterminated", "unterminated CDATA")
  refuses("a<w:br/>b", "only text and CDATA")
  refuses("a&#x110000;b", "out of range")
}
