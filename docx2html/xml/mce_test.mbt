///|
fn mce_test_budget(source : String) -> @xml.XmlReadBudget {
  @xml.xml_read_budget(
    max_source_units=source.length() * 4 + 1024,
    max_tokens=4096,
    max_materialized_chars=source.length() * 8 + 4096,
    max_token_chars=source.length() + 1024,
  )
}

///|
fn read_mce_test_xml(
  source : String,
  understood : Array[String],
) -> @xml.XmlElement raise @core.DocxError {
  @xml.read_xml_bytes_strict_mce_limited(
    @utf8.encode(source),
    mce_test_budget(source),
    understood,
  )
}

///|
fn mce_test_error(
  source : String,
  understood? : Array[String] = ["urn:application"],
) -> String raise {
  try read_mce_test_xml(source, understood) catch {
    InvalidXml(message~) => message
    _ => fail("expected InvalidXml")
  } noraise {
    _ => fail("expected MCE processing to fail")
  }
}

///|
test "MCE drops Ignorable markup and unwraps ProcessContent" {
  let source =
    #|<a:Root xmlns:a="urn:application"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor"
    #| mc:Ignorable="v" mc:ProcessContent="v:unwrap" v:annotation="drop">
    #| <v:discard><a:Hidden/></v:discard>
    #| <v:unwrap><a:Kept/></v:unwrap>
    #|</a:Root>
  let root = read_mce_test_xml(source, ["urn:application"])
  assert_eq(root.name, "{urn:application}Root")
  assert_true(root.attributes.is_empty())
  let elements : Array[@xml.XmlElement] = []
  for child in root.children {
    match child {
      XmlText(value) => assert_true(value.trim() == "")
      XmlElement(element) => elements.push(element)
    }
  }
  assert_eq(elements.length(), 1)
  assert_eq(elements[0].name, "{urn:application}Kept")
}

///|
test "MCE AlternateContent selects the first understood Choice" {
  let source =
    #|<mc:AlternateContent
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:a="urn:application" xmlns:v="urn:vendor">
    #| <mc:Choice Requires="v"><v:Root/></mc:Choice>
    #| <mc:Choice Requires="a"><a:Root selected="choice"/></mc:Choice>
    #| <mc:Fallback><a:Root selected="fallback"/></mc:Fallback>
    #|</mc:AlternateContent>
  let root = read_mce_test_xml(source, ["urn:application"])
  assert_eq(root.name, "{urn:application}Root")
  assert_eq(root.attributes.get("selected"), Some("choice"))
}

///|
test "MCE AlternateContent selects Fallback when no Choice is understood" {
  let source =
    #|<mc:AlternateContent
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:a="urn:application" xmlns:v="urn:vendor">
    #| <mc:Choice Requires="v"><v:Root/></mc:Choice>
    #| <mc:Fallback><a:Root/></mc:Fallback>
    #|</mc:AlternateContent>
  let root = read_mce_test_xml(source, ["urn:application"])
  assert_eq(root.name, "{urn:application}Root")
}

///|
test "MCE tracks namespace identity across prefix rebinding" {
  let source =
    #|<a:Root xmlns:a="urn:application"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor:one" mc:Ignorable="v">
    #| <a:Container xmlns:v="urn:vendor:two"><v:Kept/></a:Container>
    #|</a:Root>
  let root = read_mce_test_xml(source, ["urn:application"])
  guard root.first("{urn:application}Container") is Some(container) else {
    fail("expected application container")
  }
  assert_true(container.first("{urn:vendor:two}Kept") is Some(_))
}

///|
test "MCE does not confuse brace-bearing namespaces with xmlns" {
  let source =
    #|<a:Root xmlns:a="urn:application"
    #| xmlns:x="http://www.w3.org/2000/xmlns/}attacker" x:value="kept"/>
  let root = read_mce_test_xml(source, ["urn:application"])
  assert_eq(
    root.attributes.get("{http://www.w3.org/2000/xmlns/}attacker}value"),
    Some("kept"),
  )
}

///|
test "MCE strips only processing attributes from application elements" {
  let source =
    #|<a:Root xmlns:a="urn:application"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor" mc:Ignorable="v" mc:Bogus="retained"/>
  let root = read_mce_test_xml(source, ["urn:application"])
  assert_false(
    root.attributes.contains(
      "{http://schemas.openxmlformats.org/markup-compatibility/2006}Ignorable",
    ),
  )
  assert_eq(
    root.attributes.get(
      "{http://schemas.openxmlformats.org/markup-compatibility/2006}Bogus",
    ),
    Some("retained"),
  )
}

///|
test "MCE validates directives and AlternateContent grammar" {
  let mc = "http://schemas.openxmlformats.org/markup-compatibility/2006"
  assert_true(
    mce_test_error(
      "<a:Root xmlns:a=\"urn:application\" xmlns:mc=\"\{mc}\" mc:Ignorable=\"missing\"/>",
    ).contains("Ignorable contains an unbound namespace prefix"),
  )
  assert_true(
    mce_test_error(
      "<a:Root xmlns:a=\"urn:application\" xmlns:mc=\"\{mc}\" xmlns:v=\"urn:vendor\" mc:ProcessContent=\"v:*\"/>",
    ).contains("ProcessContent names a namespace that is not ignorable"),
  )
  assert_true(
    mce_test_error(
      "<a:Root xmlns:a=\"urn:application\" xmlns:mc=\"\{mc}\" xmlns:v=\"urn:vendor\" mc:MustUnderstand=\"v\"/>",
    ).contains("MustUnderstand names an unsupported namespace"),
  )
  assert_true(
    mce_test_error(
      "<mc:AlternateContent xmlns:mc=\"\{mc}\" xmlns:a=\"urn:application\"><mc:Fallback><a:Root/></mc:Fallback></mc:AlternateContent>",
    ).contains("AlternateContent has no Choice element"),
  )
  assert_true(
    mce_test_error(
      "<mc:AlternateContent xmlns:mc=\"\{mc}\" xmlns:a=\"urn:application\"><mc:Choice><a:Root/></mc:Choice></mc:AlternateContent>",
    ).contains("Choice is missing Requires"),
  )
  assert_true(
    mce_test_error(
      "<mc:AlternateContent xmlns:mc=\"\{mc}\" xmlns:a=\"urn:application\" mc:Ignorable=\"xml\" xml:lang=\"en\"><mc:Choice Requires=\"a\"><a:Root/></mc:Choice></mc:AlternateContent>",
    ).contains("AlternateContent has a disallowed attribute"),
  )
}

///|
test "MCE rejects non-ignorable AlternateContent children and unsafe unwraps" {
  let mc = "http://schemas.openxmlformats.org/markup-compatibility/2006"
  assert_true(
    mce_test_error(
      "<mc:AlternateContent xmlns:mc=\"\{mc}\" xmlns:a=\"urn:application\" xmlns:v=\"urn:vendor\"><v:extension/><mc:Choice Requires=\"a\"><a:Root/></mc:Choice></mc:AlternateContent>",
    ).contains("AlternateContent has a non-ignorable foreign child"),
  )
  assert_true(
    mce_test_error(
      "<a:Root xmlns:a=\"urn:application\" xmlns:mc=\"\{mc}\" xmlns:v=\"urn:vendor\" mc:Ignorable=\"v\" mc:ProcessContent=\"v:unwrap\"><v:unwrap xml:base=\"https://example.test/\"><a:Child/></v:unwrap></a:Root>",
    ).contains("an unwrapped ProcessContent element has xml:base"),
  )
}
