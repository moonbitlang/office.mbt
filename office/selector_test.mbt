///|
fn selector_stability_name(stability : @office.SelectorStability) -> String {
  match stability {
    Stable => "stable"
    SnapshotRelative => "snapshot-relative"
  }
}

///|
fn selector_error_summary(input : String) -> String {
  try @office.parse_selector(input) catch {
    SelectorError(code~, offset~, input=echo, message~) =>
      "\{code}@\{offset}:\{echo}:\{message}"
  } noraise {
    selector => "ok:" + selector.render()
  }
}

///|
test "canonical selectors parse, normalize, render, and classify" {
  let inputs = [
    "/docx/body", "/docx/body/p[1]/r[2]", "/docx/header[1]/p[1]", "/docx/footer[1]/tbl[1]/tr[2]/tc[1]/p[1]",
    "/docx/footnotes/note[id=\"7\"]/p[1]", "/docx/comments/comment[id=\"review/one]=\\\"ready\\\"\"]",
    "/xlsx/sheet[name=\"Data\"]", "/xlsx/sheet[name=\"Data\"]/cell[A1]", "/xlsx/sheet[name=\"O'Brien / Q1\"]/range[c12:a1]",
    "/xlsx/sheet[name=\"财务/一季度\"]/cell[xfd1048576]", "/xlsx/sheet[2]",
  ]
  let rendered : Array[String] = []
  for input in inputs {
    let selector = @office.parse_selector(input)
    rendered.push(
      "\{selector.render()} | \{selector_stability_name(selector.stability)}",
    )
    assert_eq(
      @office.parse_selector(selector.render()).render(),
      selector.render(),
    )
  }
  inspect(
    rendered.join("\n"),
    content=(
      #|/docx/body | stable
      #|/docx/body/p[1]/r[2] | snapshot-relative
      #|/docx/header[1]/p[1] | snapshot-relative
      #|/docx/footer[1]/tbl[1]/tr[2]/tc[1]/p[1] | snapshot-relative
      #|/docx/footnotes/note[id="7"]/p[1] | snapshot-relative
      #|/docx/comments/comment[id="review/one]=\"ready\""] | stable
      #|/xlsx/sheet[name="Data"] | stable
      #|/xlsx/sheet[name="Data"]/cell[A1] | snapshot-relative
      #|/xlsx/sheet[name="O'Brien / Q1"]/range[A1:C12] | snapshot-relative
      #|/xlsx/sheet[name="财务/一季度"]/cell[XFD1048576] | snapshot-relative
      #|/xlsx/sheet[2] | snapshot-relative
    ),
  )
}

///|
test "selector AST exposes adapter-ready segments, keys, and coordinates" {
  let docx = @office.parse_selector(
    "/docx/comments/comment[id=\"review/one]=\\\"ready\\\"\"]",
  )
  assert_eq(docx.format.name(), "docx")
  assert_eq(docx.segments.length(), 2)
  assert_eq(docx.segments[0].name, "comments")
  assert_eq(docx.segments[1].name, "comment")
  assert_eq(docx.segments[1].key_value("id"), Some("review/one]=\"ready\""))
  assert_true(docx.coordinate is None)
  let xlsx = @office.parse_selector("/xlsx/sheet[name=\"Data\"]/range[C12:A1]")
  assert_eq(xlsx.segments[0].key_value("name"), Some("Data"))
  guard xlsx.coordinate is Some(Range(start, finish)) else {
    fail("expected an XLSX range coordinate")
  }
  assert_eq(start.render(), "A1")
  assert_eq(finish.render(), "C12")
}

///|
test "invalid selector forms have deterministic structured errors" {
  let cases = [
    "", "docx/body", "/ppt/body", "/docx", "/docx/", "/docx//p[1]", "/docx/body/p[0]",
    "/docx/body/p[1234567890]", "/docx/body/p", "/docx/header/p[1]", "/docx/comments/comment[@id=7]",
    "/docx/comments/comment[class=\"x\"]", "/docx/body/p[1", "/docx/comments/comment[id=\"unterminated]",
    "/docx/sheet[name=\"Data\"]/cell[A1]", "/xlsx/body/p[1]", "/xlsx/sheet", "/xlsx/sheet[id=\"Data\"]",
    "/xlsx/sheet[name=\"\"]/cell[A1]", "/xlsx/sheet[name=\"Data\"]/cell[A0]", "/xlsx/sheet[name=\"Data\"]/cell[A01]",
    "/xlsx/sheet[name=\"Data\"]/cell[XFE1]", "/xlsx/sheet[name=\"Data\"]/cell[A1048577]",
    "/xlsx/sheet[name=\"Data\"]/cell[$A$1]", "/xlsx/sheet[name=\"Data\"]/range[A1]",
    "/xlsx/sheet[name=\"Data\"]/range[A1:B2:C3]", "/xlsx/sheet[name=\"Data\"]/cell[A1]/range[A1:B2]",
    "/xlsx/sheet[name=\"Data\"]//cell[A1]",
  ]
  let summaries = cases.map(selector_error_summary)
  inspect(
    summaries.join("\n"),
    content=(
      #|office.selector.invalid_root@0::selector must start with '/docx/' or '/xlsx/'
      #|office.selector.invalid_root@0:docx/body:selector must start with '/docx/' or '/xlsx/'
      #|office.selector.invalid_format@1:/ppt/body:unsupported selector format 'ppt' (expected docx or xlsx)
      #|office.selector.invalid_root@5:/docx:format root must be followed by '/' and a segment
      #|office.selector.empty_segment@6:/docx/:selector contains an empty segment
      #|office.selector.empty_segment@6:/docx//p[1]:selector contains an empty segment
      #|office.selector.zero_index@13:/docx/body/p[0]:positional selectors are 1-based
      #|office.selector.index_overflow@13:/docx/body/p[1234567890]:positional index exceeds 9 digits
      #|office.selector.invalid_shape@12:/docx/body/p:DOCX descendant 'p' requires [index] or [id="value"]
      #|office.selector.invalid_shape@6:/docx/header/p[1]:DOCX story 'header' requires a 1-based positional selector
      #|office.selector.unsupported_predicate@23:/docx/comments/comment[@id=7]:expected a positive index or key="value" selection
      #|office.selector.unsupported_predicate@33:/docx/comments/comment[class="x"]:DOCX named selectors use the 'id' key, not 'class'
      #|office.selector.unclosed_selection@14:/docx/body/p[1:expected ']' after segment selection
      #|office.selector.unclosed_string@26:/docx/comments/comment[id="unterminated]:unterminated JSON string in named selector
      #|office.selector.unsupported_predicate@30:/docx/sheet[name="Data"]/cell[A1]:expected a positive index or key="value" selection
      #|office.selector.invalid_shape@15:/xlsx/body/p[1]:XLSX selectors require exactly one sheet segment before an optional cell/range leaf
      #|office.selector.invalid_shape@11:/xlsx/sheet:XLSX sheet requires [index] or [name="value"]
      #|office.selector.unsupported_predicate@22:/xlsx/sheet[id="Data"]:XLSX sheet selectors use the 'name' key, not 'id'
      #|office.selector.empty_value@17:/xlsx/sheet[name=""]/cell[A1]:named selector values cannot be empty
      #|office.selector.invalid_coordinate@31:/xlsx/sheet[name="Data"]/cell[A0]:A1 rows are 1-based and cannot have leading zeroes
      #|office.selector.invalid_coordinate@31:/xlsx/sheet[name="Data"]/cell[A01]:A1 rows are 1-based and cannot have leading zeroes
      #|office.selector.invalid_coordinate@30:/xlsx/sheet[name="Data"]/cell[XFE1]:A1 column is outside A:XFD
      #|office.selector.invalid_coordinate@31:/xlsx/sheet[name="Data"]/cell[A1048577]:A1 row is outside 1:1048576
      #|office.selector.invalid_coordinate@30:/xlsx/sheet[name="Data"]/cell[$A$1]:invalid A1 coordinate '$A$1'
      #|office.selector.invalid_coordinate@31:/xlsx/sheet[name="Data"]/range[A1]:range selectors require two A1 coordinates separated by ':'
      #|office.selector.invalid_coordinate@31:/xlsx/sheet[name="Data"]/range[A1:B2:C3]:range selectors require two A1 coordinates separated by ':'
      #|office.selector.invalid_shape@34:/xlsx/sheet[name="Data"]/cell[A1]/range[A1:B2]:selector contains more than one coordinate leaf
      #|office.selector.empty_segment@25:/xlsx/sheet[name="Data"]//cell[A1]:selector contains an empty segment
    ),
  )
}

///|
test "selector resource limits bound work and diagnostic amplification" {
  let too_deep = "/docx/body" + "/p[1]".repeat(32)
  let depth = selector_error_summary(too_deep)
  assert_true(depth.has_prefix("office.selector.depth_limit@"))
  let long_value = "x".repeat(@office.SELECTOR_MAX_VALUE_LENGTH + 1)
  let value_error = selector_error_summary(
    "/docx/comments/comment[id=\"\{long_value}\"]",
  )
  assert_true(value_error.has_prefix("office.selector.value_too_long@"))
  let long_input = "/docx/body/" + "x".repeat(@office.SELECTOR_MAX_LENGTH)
  try @office.parse_selector(long_input) catch {
    SelectorError(code~, offset~, input~, message~) => {
      assert_eq(code, "office.selector.too_long")
      assert_eq(offset, @office.SELECTOR_MAX_LENGTH)
      assert_eq(input.to_array().length(), 161)
      assert_true(input.has_suffix("…"))
      assert_true(message.length() < 100)
    }
  } noraise {
    _ => fail("expected an overlong selector to fail")
  }
}

///|
test "stable key values with delimiter characters round-trip" {
  let values = [
    "simple", "slash/value", "right]bracket", "equals=value", "quote\"value", "backslash\\value",
    "line\nfeed", "财务/一季度]=\"完成\"",
  ]
  for value in values {
    let path = "/docx/comments/comment[id=\{Json::string(value).stringify()}]"
    let selector = @office.parse_selector(path)
    assert_eq(selector.render(), path)
    assert_eq(selector.segments[1].key_value("id"), Some(value))
  }
}

///|
test "bounded selector parser does not panic on deterministic fuzz input" {
  let alphabet = "/[]=_-\"\\:Aaz09财".to_array()
  let mut state : UInt = 0xC0FFEE
  for _ in 0..<500 {
    state = state * 1664525 + 1013904223
    let length = (state % 96).reinterpret_as_int()
    let text = StringBuilder::new()
    for _ in 0..<length {
      state = state * 1664525 + 1013904223
      text.write_char(
        alphabet[(state % alphabet.length().reinterpret_as_uint()).reinterpret_as_int()],
      )
      |> ignore
    }
    try @office.parse_selector(text.to_string()) catch {
      SelectorError(input~, message~, ..) => {
        assert_true(input.to_array().length() <= 161)
        assert_true(message.to_array().length() <= 321)
      }
    } noraise {
      selector =>
        assert_eq(
          @office.parse_selector(selector.render()).render(),
          selector.render(),
        )
    }
  }
}
