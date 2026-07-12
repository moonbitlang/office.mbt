// Contract tests for the shared XML escaping helpers (the single
// implementation used by both the ooxml packaging layer and the xlsx writer).

///|
test "escape_xml_text escapes only &, <, > (not quotes)" {
  inspect(@ooxml.escape_xml_text("&"), content="&amp;")
  inspect(@ooxml.escape_xml_text("<"), content="&lt;")
  inspect(@ooxml.escape_xml_text(">"), content="&gt;")
  // Text content leaves quotes and apostrophes untouched.
  inspect(@ooxml.escape_xml_text("\""), content="\"")
  inspect(@ooxml.escape_xml_text("'"), content="'")
  inspect(
    @ooxml.escape_xml_text("a<b>c&d\"e'f"),
    content="a&lt;b&gt;c&amp;d\"e'f",
  )
}

///|
test "escape_xml_attr escapes &, <, >, \", ' " {
  inspect(@ooxml.escape_xml_attr("&"), content="&amp;")
  inspect(@ooxml.escape_xml_attr("<"), content="&lt;")
  inspect(@ooxml.escape_xml_attr(">"), content="&gt;")
  inspect(@ooxml.escape_xml_attr("\""), content="&quot;")
  inspect(@ooxml.escape_xml_attr("'"), content="&apos;")
  inspect(
    @ooxml.escape_xml_attr("a<b>c&d\"e'f"),
    content="a&lt;b&gt;c&amp;d&quot;e&apos;f",
  )
}

///|
test "escape functions pass clean and empty input through unchanged" {
  inspect(@ooxml.escape_xml_text(""), content="")
  inspect(@ooxml.escape_xml_attr(""), content="")
  inspect(@ooxml.escape_xml_text("hello world 123"), content="hello world 123")
  inspect(@ooxml.escape_xml_attr("hello world 123"), content="hello world 123")
  // A quote is "clean" for text but not for attributes.
  inspect(@ooxml.escape_xml_text("say \"hi\""), content="say \"hi\"")
  inspect(@ooxml.escape_xml_attr("say \"hi\""), content="say &quot;hi&quot;")
}

///|
test "xml_needs_escape distinguishes text and attribute contexts" {
  // & < > always need escaping.
  assert_true(@ooxml.xml_needs_escape("a&b", attr=false))
  assert_true(@ooxml.xml_needs_escape("a<b", attr=false))
  assert_true(@ooxml.xml_needs_escape("a>b", attr=true))
  // Quotes need escaping only in attribute context.
  assert_false(@ooxml.xml_needs_escape("a\"b", attr=false))
  assert_false(@ooxml.xml_needs_escape("a'b", attr=false))
  assert_true(@ooxml.xml_needs_escape("a\"b", attr=true))
  assert_true(@ooxml.xml_needs_escape("a'b", attr=true))
  // Clean strings never need escaping.
  assert_false(@ooxml.xml_needs_escape("clean", attr=true))
  assert_false(@ooxml.xml_needs_escape("", attr=true))
}
