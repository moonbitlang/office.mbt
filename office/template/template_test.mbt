///|
fn scan(segments : Array[String]) -> @template.TemplateScan raise {
  @template.scan_placeholders(segments, Ref(1_000_000))
}

///|
test "placeholders parse in a single segment" {
  let result = scan(["Dear {{customer}}, your total is {{total}}."])
  assert_eq(result.matches.length(), 2)
  assert_eq(result.matches[0].key, "customer")
  assert_eq(result.matches[0].span, {
    start_segment: 0,
    start_offset: 5,
    end_segment: 0,
    end_offset: 17,
  })
  assert_eq(result.matches[1].key, "total")
  assert_eq(result.escapes.length(), 0)
  assert_eq(result.malformed.length(), 0)
}

///|
test "placeholders span segment boundaries" {
  // Word splits runs freely: "{{cus" + "tom" + "er}}"
  let result = scan(["before {{cus", "tom", "er}} after"])
  assert_eq(result.matches.length(), 1)
  assert_eq(result.matches[0].key, "customer")
  assert_eq(result.matches[0].span, {
    start_segment: 0,
    start_offset: 7,
    end_segment: 2,
    end_offset: 4,
  })
}

///|
test "the escape sequence yields a literal and spans boundaries" {
  let result = scan(["a \\{{ b"])
  assert_eq(result.escapes.length(), 1)
  assert_eq(result.matches.length(), 0)
  assert_eq(result.malformed.length(), 0)
  let split = scan(["x \\", "{{ y"])
  assert_eq(split.escapes.length(), 1)
  assert_eq(split.escapes[0], {
    start_segment: 0,
    start_offset: 2,
    end_segment: 1,
    end_offset: 2,
  })
  // a lone backslash is ordinary text
  let lone = scan(["a \\ b \\{ c"])
  assert_eq(lone.escapes.length(), 0)
  assert_eq(lone.malformed.length(), 0)
}

///|
test "malformed sites are all reported with reasons" {
  let result = scan([
    "{{}} then {{9bad}} then {{sp ace}} then {{open then {{fine}}",
  ])
  assert_eq(result.matches.length(), 1)
  assert_eq(result.matches[0].key, "fine")
  assert_eq(result.malformed.length(), 4)
  assert_true(result.malformed[0].reason.contains("empty or starts"))
  assert_true(result.malformed[1].reason.contains("empty or starts"))
  assert_true(result.malformed[2].reason.contains("invalid character"))
  assert_true(result.malformed[3].reason.contains("invalid character"))
  // unterminated at end of text
  let tail = scan(["closing {{customer"])
  assert_eq(tail.malformed.length(), 1)
  assert_true(tail.malformed[0].reason.contains("unterminated"))
  let brace = scan(["{{key} x"])
  assert_eq(brace.malformed.length(), 1)
  assert_true(brace.malformed[0].reason.contains("unterminated"))
  // 65-unit key
  let long = scan([
    "{{a2345678901234567890123456789012345678901234567890123456789012345}}",
  ])
  assert_eq(long.malformed.length(), 1)
  assert_true(long.malformed[0].reason.contains("64"))
}

///|
test "adjacent and boundary placeholders" {
  let result = scan(["{{a}}{{b}}"])
  assert_eq(result.matches.length(), 2)
  assert_eq(result.matches[0].key, "a")
  assert_eq(result.matches[1].key, "b")
  // a placeholder that IS the whole text
  let whole = scan(["{{only}}"])
  assert_eq(whole.matches.length(), 1)
  assert_eq(whole.matches[0].span, {
    start_segment: 0,
    start_offset: 0,
    end_segment: 0,
    end_offset: 8,
  })
  // stray closers and single braces are ordinary text
  let stray = scan(["a }} b { c } d"])
  assert_eq(stray.matches.length(), 0)
  assert_eq(stray.malformed.length(), 0)
}

///|
test "the scan budget is charged and enforced" {
  let budget = Ref(10)
  ignore(@template.scan_placeholders(["12345"], budget))
  assert_eq(budget.val, 5)
  try @template.scan_placeholders(["123456"], budget) |> ignore catch {
    TemplateScanBudgetExceeded(_) => ()
  } noraise {
    _ => fail("expected the budget to reject")
  }
}

///|
test "key grammar" {
  assert_true(@template.template_key_ok("customer"))
  assert_true(@template.template_key_ok("_a.b-c9"))
  assert_false(@template.template_key_ok(""))
  assert_false(@template.template_key_ok("9lead"))
  assert_false(@template.template_key_ok(".lead"))
  assert_false(@template.template_key_ok("sp ace"))
  assert_false(
    @template.template_key_ok(
      "a2345678901234567890123456789012345678901234567890123456789012345",
    ),
  )
}

///|
test "template data parses and types values" {
  let values = @template.parse_template_data(
    (
      #|{
      #|  "schema": "office.template.data/1",
      #|  "values": { "customer": "Ada", "total": 1234.5, "count": 42, "paid": true }
      #|}
    ),
  )
  assert_eq(values.length(), 4)
  assert_eq(values.get("customer"), Some(TextValue("Ada")))
  assert_eq(values.get("total"), Some(NumberValue(1234.5)))
  assert_eq(values.get("paid"), Some(BoolValue(true)))
  // deterministic rendering
  assert_eq(@template.TemplateValue::render(TextValue("x")), "x")
  assert_eq(@template.TemplateValue::render(NumberValue(42.0)), "42")
  assert_eq(@template.TemplateValue::render(NumberValue(1234.5)), "1234.5")
  assert_eq(@template.TemplateValue::render(BoolValue(false)), "false")
}

///|
test "template data rejections" {
  let reject = (text : String, needle : String) => {
    try @template.parse_template_data(text) |> ignore catch {
      TemplateDataError(reason) =>
        if !reason.contains(needle) {
          fail("expected reason containing '\{needle}', got: " + reason)
        }
    } noraise {
      _ => fail("expected rejection for needle '\{needle}'")
    }
  }
  reject("not json", "not valid JSON")
  reject("[1]", "must be a JSON object")
  reject("{\"values\":{}}", "needs \"schema\"")
  reject(
    "{\"schema\":\"office.template.data/2\",\"values\":{}}", "unsupported data schema",
  )
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{},\"extra\":1}", "unknown top-level member",
  )
  reject("{\"schema\":\"office.template.data/1\"}", "needs a \"values\"")
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":null}}", "null",
  )
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":[1]}}", "not a scalar",
  )
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":{\"b\":1}}}", "not a scalar",
  )
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{\"bad key\":\"x\"}}", "key grammar",
  )
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":\"x\",\"a\":\"y\"}}",
    "duplicate key",
  )
  // a control character in a value is rejected at parse time
  reject(
    "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":\"x\\u0007y\"}}", "cannot represent",
  )
}

///|
test "template data bounds" {
  try
    @template.parse_template_data(
      "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":\"xy\"}}",
      max_value_units=1,
    )
    |> ignore
  catch {
    TemplateDataError(reason) =>
      assert_true(reason.contains("exceeds"))
  } noraise {
    _ => fail("expected the value bound to reject")
  }
  try
    @template.parse_template_data(
      "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":1,\"b\":2}}",
      max_keys=1,
    )
    |> ignore
  catch {
    TemplateDataError(reason) => assert_true(reason.contains("limit"))
  } noraise {
    _ => fail("expected the key bound to reject")
  }
}

///|
/// Kimi #205 round-1 findings: escape-spelled keys cannot bypass the
/// duplicate gate, and overflowing numerals cannot smuggle "Infinity"
/// into published documents.
test "escaped keys and non-finite numbers are rejected" {
  try
    @template.parse_template_data(
      "{\"schema\":\"office.template.data/1\",\"values\":{\"a\":1,\"\\u0061\":2}}",
    )
    |> ignore
  catch {
    TemplateDataError(reason) =>
      assert_true(reason.contains("escape sequences"))
  } noraise {
    _ => fail("a \\u-spelled duplicate key must not parse")
  }
  try
    @template.parse_template_data(
      "{\"schema\":\"office.template.data/1\",\"values\":{\"n\":1e309}}",
    )
    |> ignore
  catch {
    TemplateDataError(reason) =>
      assert_true(reason.contains("finite"))
  } noraise {
    _ => fail("an overflowing numeral must not parse")
  }
  try
    @template.parse_template_data(
      "{\"schema\":\"office.template.data/1\",\"values\":{\"n\":-1e309}}",
    )
    |> ignore
  catch {
    TemplateDataError(_) => ()
  } noraise {
    _ => fail("a negative overflowing numeral must not parse")
  }
}
