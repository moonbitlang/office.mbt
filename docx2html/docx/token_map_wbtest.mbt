// N0 lexical-map oracle and splice trials. These tests intentionally stay
// white-box until the paragraph/story walker proves the complete N0 contract.

///|
fn map_of(source : String) -> WtContentMap raise TokenMapError {
  let bytes = @utf8.encode(source)
  let budget = token_map_budget(bytes.length(), bytes.length() + 1)
  map_wt_content(bytes, 0, bytes.length(), budget)
}

///|
fn reader_projection_of(source : String) -> String raise {
  @xml.read_xml_string("<t>" + source + "</t>").text()
}

///|
fn assert_reader_oracle(source : String) -> Unit raise {
  // Public DOCX projection is tolerant, while mutation planning separately
  // requires strict well-formedness. Accepted matrix entries satisfy both.
  let mapped = map_of(source)
  assert_eq(mapped.projection, reader_projection_of(source))
  try @xml.read_xml_string_strict("<t>" + source + "</t>") |> ignore catch {
    error => fail("strict oracle rejected accepted source: \{to_repr(error)}")
  } noraise {
    _ => ()
  }
}

///|
fn assert_refuses_bytes(
  source : Bytes,
  start : Int,
  end : Int,
  fragment : String,
) -> Unit raise {
  let budget = token_map_budget(source.length(), source.length() + 1)
  try map_wt_content(source, start, end, budget) |> ignore catch {
    TokenMapError(message) => assert_true(message.contains(fragment))
  } noraise {
    _ => fail("expected token-map refusal containing: " + fragment)
  }
}

///|
fn assert_refuses(source : String, fragment : String) -> Unit raise {
  let bytes = @utf8.encode(source)
  assert_refuses_bytes(bytes, 0, bytes.length(), fragment)
}

///|
fn splice_content(
  source : String,
  mapped : WtContentMap,
  edits : Array[(Int, Int, String)],
) -> String raise {
  let bytes = @utf8.encode(source)
  let output = Buffer()
  let mut cursor = mapped.byte_start
  for edit in edits {
    let (start, end, replacement) = edit
    guard mapped.range_is_lexically_mutable(start, end) else {
      fail("test requested a non-mutable lexical range")
    }
    guard mapped.byte_offset_at(start) is Some(byte_start) &&
      mapped.byte_offset_at(end) is Some(byte_end) else {
      fail("test edit did not resolve to source boundaries")
    }
    guard byte_start >= cursor && byte_end >= byte_start else {
      fail("test edits must be sorted and non-overlapping")
    }
    output.write_bytes(bytes[cursor:byte_start])
    output.write_string_utf8(replacement)
    cursor = byte_end
  }
  output.write_bytes(bytes[cursor:mapped.byte_end])
  @utf8.decode(output.to_bytes())
}

///|
test "token map: raw UTF-8 scalars map UTF-16 offsets to absolute bytes" {
  let content = @utf8.encode("Aé😀B")
  let prefix = @utf8.encode("xx")
  let suffix = @utf8.encode("yy")
  let part = Buffer()
  part.write_bytes(prefix)
  part.write_bytes(content)
  part.write_bytes(suffix)
  let bytes = part.to_bytes()
  let budget = token_map_budget(content.length(), content.length() + 1)
  let mapped = map_wt_content(bytes, 2, 2 + content.length(), budget)
  assert_eq(mapped.projection, "Aé😀B")
  assert_eq(mapped.byte_start, 2)
  assert_eq(mapped.byte_end, 10)
  assert_eq(mapped.tokens.length(), 1)
  assert_true(mapped.tokens[0].kind is RawText)
  assert_eq(mapped.tokens[0].projection_start, 0)
  assert_eq(mapped.tokens[0].projection_end, 5)
  assert_eq(mapped.tokens[0].byte_start, 2)
  assert_eq(mapped.tokens[0].byte_end, 10)
  assert_eq(mapped.byte_offset_at(0), Some(2))
  assert_eq(mapped.byte_offset_at(1), Some(3))
  assert_eq(mapped.byte_offset_at(2), Some(5))
  // UTF-16 offset 3 is the interior of 😀's surrogate pair.
  assert_eq(mapped.byte_offset_at(3), None)
  assert_eq(mapped.byte_offset_at(4), Some(9))
  assert_eq(mapped.byte_offset_at(5), Some(10))
}

///|
test "token map: entities are atomic and reader-exact" {
  let source = "a&amp;&#x1F600;b"
  assert_reader_oracle(source)
  let mapped = map_of(source)
  assert_eq(mapped.projection, "a&😀b")
  assert_eq(mapped.tokens.length(), 4)
  assert_true(mapped.tokens[1].kind is EntityRef)
  assert_true(mapped.tokens[2].kind is NumericCharRef)
  assert_eq(mapped.byte_offset_at(0), Some(0))
  assert_eq(mapped.byte_offset_at(1), Some(1))
  assert_eq(mapped.byte_offset_at(2), Some(6))
  // No cut may land inside the astral character reference's scalar.
  assert_eq(mapped.byte_offset_at(3), None)
  assert_eq(mapped.byte_offset_at(4), Some(15))
  assert_eq(mapped.byte_offset_at(5), Some(16))
  assert_true(mapped.range_is_lexically_mutable(1, 2))
  assert_true(!mapped.range_is_lexically_mutable(2, 3))
}

///|
test "token map: XML entities and numeric characters match the reader" {
  assert_reader_oracle("&lt;&gt;&quot;&apos;&amp;")
  assert_reader_oracle("caf&#233; caf&#xe9; &#x1F600;")
  // Character references are decoded before literal line handling, so this
  // remains CR just like the XML reader.
  assert_reader_oracle("a&#xD;b")
}

///|
test "token map: literal line endings remain in the public read projection" {
  let source = "a\r\nb\rc\n"
  assert_reader_oracle(source)
  let mapped = map_of(source)
  assert_eq(mapped.projection, source)
  for offset in 0..<=source.length() {
    assert_eq(mapped.byte_offset_at(offset), Some(offset))
  }
}

///|
test "token map: CDATA projects but refuses every mutation" {
  let source = "<![CDATA[b & <c> \r\nd]]>"
  assert_reader_oracle(source)
  let mapped = map_of(source)
  assert_eq(mapped.projection, "b & <c> \r\nd")
  assert_eq(mapped.tokens.length(), 1)
  assert_true(mapped.tokens[0].kind is CData)
  assert_true(!mapped.range_is_lexically_mutable(0, 8))
  assert_true(!mapped.range_is_lexically_mutable(0, 0))
  assert_true(
    !mapped.range_is_lexically_mutable(
      mapped.projection.length(),
      mapped.projection.length(),
    ),
  )
  assert_eq(mapped.byte_offset_at(1), None)
  // An empty CDATA section contributes no projection. Its before/after source
  // positions differ, so the shared projection offset is ambiguous.
  let empty = map_of("<![CDATA[]]>")
  assert_eq(empty.projection, "")
  assert_eq(empty.byte_offset_at(0), None)
  assert_true(!empty.range_is_lexically_mutable(0, 0))
}

///|
test "token map: caller-owned budget refuses before unbounded retention" {
  let bytes = @utf8.encode("a&amp;b")
  let short_source = token_map_budget(bytes.length() - 1, 10)
  try map_wt_content(bytes, 0, bytes.length(), short_source) |> ignore catch {
    TokenMapError(message) =>
      assert_true(message.contains("source byte budget"))
  } noraise {
    _ => fail("expected the source-byte budget to refuse")
  }
  // raw 'a', entity '&amp;', and raw 'b' are three retained tokens.
  let short_tokens = token_map_budget(bytes.length(), 2)
  try map_wt_content(bytes, 0, bytes.length(), short_tokens) |> ignore catch {
    TokenMapError(message) => assert_true(message.contains("token budget"))
  } noraise {
    _ => fail("expected the token budget to refuse")
  }
  // One shared budget is cumulative across calls, as the future story walker
  // requires; a node cannot reset the transaction allowance.
  let shared = token_map_budget(2, 2)
  map_wt_content(b"a", 0, 1, shared) |> ignore
  map_wt_content(b"b", 0, 1, shared) |> ignore
  try map_wt_content(b"c", 0, 1, shared) |> ignore catch {
    TokenMapError(message) =>
      assert_true(message.contains("source byte budget"))
  } noraise {
    _ => fail("expected cumulative source-byte exhaustion")
  }
}

///|
test "token map: multiple scalar-safe splices preserve untouched source" {
  let source = "Aé😀B&amp;C"
  let mapped = map_of(source)
  assert_eq(mapped.projection, "Aé😀B&C")
  let spliced = splice_content(source, mapped, [
    (1, 2, "E"),
    (4, 5, "bee"),
    (5, 6, "and"),
  ])
  // Two edits land in one raw token and one consumes an entity token. Exact
  // source equality pins every byte outside the three declared cuts.
  assert_eq(spliced, "AE😀beeandC")
  assert_eq(reader_projection_of(spliced), "AE😀beeandC")
  assert_true(!mapped.range_is_lexically_mutable(3, 4))
}

///|
test "token map: empty content has one unambiguous insertion boundary" {
  let mapped = map_of("")
  assert_eq(mapped.projection, "")
  assert_eq(mapped.tokens.length(), 0)
  assert_eq(mapped.byte_offset_at(0), Some(0))
  assert_true(mapped.range_is_lexically_mutable(0, 0))
}

///|
test "token map: malformed or mutation-unsafe XML refuses exactly" {
  assert_refuses("a&amp", "unterminated entity")
  assert_refuses("a&nbsp;b", "unsupported named entity")
  assert_refuses("a&#zz;b", "invalid digit")
  assert_refuses("a&#;b", "empty numeric")
  // Uppercase X is accepted by the tolerant reader but rejected by the strict
  // mutation identity gate; the lexical map follows the mutation-safe subset.
  assert_refuses("a&#XE9;b", "invalid digit")
  assert_refuses("a&#0;b", "not an XML character")
  assert_refuses("a&#xB;b", "not an XML character")
  assert_refuses("a&#xD800;b", "not an XML character")
  assert_refuses("a&#x110000;b", "out of range")
  assert_refuses("a&#999999999999999999999999999999999999999;b", "out of range")
  assert_refuses("a<![CDATA[unterminated", "unterminated CDATA")
  assert_refuses("a<![CDATA[b]]>c", "no simple-text reader projection")
  assert_refuses("a<w:br/>b", "only text and CDATA")
  assert_refuses("a]]>b", "not allowed")
  assert_refuses_bytes([b'a', 0, b'b'], 0, 3, "illegal XML character")
  assert_refuses_bytes([b'a', 0xC3, 0x28], 0, 3, "not valid UTF-8")
}

///|
test "token map: invalid byte ranges refuse instead of indexing" {
  let bytes = @utf8.encode("abc")
  assert_refuses_bytes(bytes, -1, 2, "invalid w:t content byte range")
  assert_refuses_bytes(bytes, 2, 1, "invalid w:t content byte range")
  assert_refuses_bytes(bytes, 0, 4, "invalid w:t content byte range")
}
