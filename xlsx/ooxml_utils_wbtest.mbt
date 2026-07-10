///|
test "ooxml_utils: tag_attributes_in finds first open tag" {
  let xml = "<root><a b=\"c\"/><a b=\"d\"/></root>"
  debug_inspect(tag_attributes_in(xml, "a"), content="Some(\"a b=\\\"c\\\"/\")")
}

///|
test "ooxml_utils: tag_attributes_in returns None when missing" {
  let xml = "<root/>"
  debug_inspect(tag_attributes_in(xml, "a"), content="None")
}

///|
test "ooxml_utils: extract_tag_body_from extracts body" {
  let xml = "<root><a>hello</a><a>world</a></root>"
  debug_inspect(extract_tag_body_from(xml, "a"), content="Some(\"hello\")")
}

///|
test "ooxml_utils: extract_tag_body_from returns None when missing" {
  let xml = "<root/>"
  debug_inspect(extract_tag_body_from(xml, "a"), content="None")
}

///|
test "ooxml_utils: replace_attr_value_in_open_tag rewrites attribute and escapes" {
  let xml = "<a sqref=\"A1\">x</a>"
  let updated = replace_attr_value_in_open_tag(xml, "sqref", "B2 & \"<\"")
  debug_inspect(
    updated,
    content="Some(\"<a sqref=\\\"B2 &amp; &quot;&lt;&quot;\\\">x</a>\")",
  )
}

///|
test "ooxml_utils: replace_attr_value_in_open_tag returns None when attribute missing" {
  let xml = "<a>nope</a>"
  debug_inspect(
    replace_attr_value_in_open_tag(xml, "sqref", "B2"),
    content="None",
  )
}
