///|
test "ooxml read_parse: internal relationships support self-closing and expanded tags" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="urn:t1" Target="a.xml"/>
    #|  <Relationship Id="rId2" Type="urn:t2" Target="b.xml"></Relationship>
    #|  <Relationship Id="rId3" Type="urn:t1" Target="c.xml"/>
    #|</Relationships>
    #|
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:t1")
  debug_inspect(
    targets,
    content=(
      #|{ "rId1": "a.xml", "rId3": "c.xml" }
    ),
  )
}

///|
test "ooxml read_parse: internal relationships report missing id/target and malformed tag" {
  let missing_id =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Type="urn:t1" Target="a.xml"/>
    #|</Relationships>
    #|
  try @ooxml.parse_internal_relationship_targets(missing_id, "urn:t1") catch {
    InvalidXml(msg~) => inspect(msg, content="relationship id missing")
    _ => fail("unexpected relationship parse cancellation")
  } noraise {
    _ => fail("expected relationship id missing")
  }

  let missing_target =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="urn:t1"/>
    #|</Relationships>
    #|
  try
    @ooxml.parse_internal_relationship_targets(missing_target, "urn:t1")
  catch {
    InvalidXml(msg~) => inspect(msg, content="relationship target missing")
    _ => fail("unexpected relationship parse cancellation")
  } noraise {
    _ => fail("expected relationship target missing")
  }

  let malformed =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship 
    #|</Relationships>
    #|
  try @ooxml.parse_internal_relationship_targets(malformed, "urn:t1") catch {
    InvalidXml(msg~) => inspect(msg, content="XML start tag is not closed")
    _ => fail("unexpected relationship parse cancellation")
  } noraise {
    _ => fail("expected relationship tag not closed")
  }
}

///|
test "ooxml read_parse: prefixed relationships decode entities exactly once" {
  let xml =
    #|<pkg:Relationships xmlns:pkg="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <pkg:Relationship Id="r&#x31;" Type="urn:type&#x31;" Target="custom/a&amp;#x20;b.xml"/>
    #|</pkg:Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:type1")
  debug_inspect(
    targets,
    content=(
      #|{ "r1": "custom/a&#x20;b.xml" }
    ),
  )
}

///|
test "ooxml read_parse: uppercase-X character references never change relationship identity" {
  for
    xml in [
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r&#X31;" Type="urn:wanted" Target="a.xml"/></Relationships>
      ),
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="urn:wanted" Target="a&#X2f;b.xml"/></Relationships>
      ),
    ] {
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(msg~) => inspect(msg, content="XML entity is invalid")
      _ => fail("unexpected uppercase-X entity error")
    } noraise {
      _ => fail("expected uppercase-X entity rejection")
    }
  }
}

///|
test "ooxml read_parse: relationship identifiers and URIs fail closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r 1" Type="urn:wanted" Target="inside.xml"/></Relationships>
      ),
      "relationship id is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="relative" Target="inside.xml"/></Relationships>
      ),
      "relationship type is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="r1" Type="urn:wanted" Target="inside file.xml"/></Relationships>
      ),
      "relationship target is invalid",
    ),
  ]
  for case in cases {
    let (xml, expected) = case
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected relationship grammar error")
    } noraise {
      _ => fail("expected invalid relationship grammar")
    }
  }
}

///|
test "ooxml read_parse: enumerates validated relationship records" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="inside" Type="urn:inside" Target="parts/a.xml"/>
    #|  <Relationship Id="outside" Type="urn:outside" Target="https://example.invalid/a?x=1&amp;y=2" TargetMode="External"/>
    #|</Relationships>
  let records = @ooxml.parse_package_relationships(xml)
  inspect(records.length(), content="2")
  inspect(records[0].id, content="inside")
  inspect(records[0].rel_type, content="urn:inside")
  inspect(records[0].target, content="parts/a.xml")
  inspect(records[0].external, content="false")
  inspect(records[1].id, content="outside")
  inspect(records[1].target, content="https://example.invalid/a?x=1&y=2")
  inspect(records[1].external, content="true")
}

///|
test "ooxml scanner enumerates relationship namespace attributes" {
  let xml =
    #|<root xmlns:r="urn:relationships" xmlns:q="urn:relationships" plain="ignored" r:id="first" q:future="second&amp;value"/>
  let scanner = @ooxml.XmlStartTagScanner::new(xml)
  assert_true(scanner.next())
  debug_inspect(
    scanner.attribute_values_in_namespace("urn:relationships"),
    content="[\"first\", \"second&value\"]",
  )
}

///|
test "ooxml read_parse: relationship target modes are explicit and filtered" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="default" Type="urn:wanted" Target="inside.xml"/>
    #|  <Relationship Id="internal" Type="urn:wanted" Target="also-inside.xml" TargetMode="Internal"/>
    #|  <Relationship Id="external" Type="urn:wanted" Target="https://example.invalid" TargetMode="External"/>
    #|</Relationships>
  debug_inspect(
    @ooxml.parse_internal_relationship_targets(xml, "urn:wanted"),
    content=(
      #|{ "default": "inside.xml", "internal": "also-inside.xml" }
    ),
  )
  let padded =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="bad" Type="urn:wanted" Target="inside.xml" TargetMode=" Internal "/></Relationships>
  try @ooxml.parse_internal_relationship_targets(padded, "urn:wanted") catch {
    InvalidXml(msg~) => inspect(msg, content="relationship target mode invalid")
    _ => fail("unexpected padded relationship target mode error")
  } noraise {
    _ => fail("expected padded relationship target mode rejection")
  }
  debug_inspect(
    @ooxml.parse_external_relationship_targets(xml, "urn:wanted"),
    content=(
      #|{ "external": "https://example.invalid" }
    ),
  )
}

///|
test "ooxml read_parse: relationships apply OPC Markup Compatibility" {
  let process_content =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Wrapper"><v:Ignored/><v:Wrapper><Relationship Id="processed" Type="urn:wanted" Target="processed.xml"/></v:Wrapper></Relationships>
  let selected_choice =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Unsupported/></mc:Choice><mc:Choice Requires="r"><Relationship Id="choice" Type="urn:wanted" Target="choice.xml"/></mc:Choice><mc:Fallback><Relationship Id="fallback" Type="urn:wanted" Target="fallback.xml"/></mc:Fallback></mc:AlternateContent></Relationships>
  let selected_fallback =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Unsupported/></mc:Choice><mc:Fallback><Relationship Id="fallback" Type="urn:wanted" Target="fallback.xml"/></mc:Fallback></mc:AlternateContent></Relationships>
  let wildcard_process_content =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:*"><v:Wrapper><Relationship Id="wildcard" Type="urn:wanted" Target="wildcard.xml"/></v:Wrapper></Relationships>
  let empty_directives =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="" mc:MustUnderstand="" mc:ProcessContent="" mc:PreserveElements="" mc:PreserveAttributes=""><Relationship Id="empty" Type="urn:wanted" Target="empty.xml"/></Relationships>
  let understood_ignorable =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="r"><r:Relationship Id="understood" Type="urn:wanted" Target="understood.xml"/></Relationships>
  let processed = @ooxml.parse_internal_relationship_targets(
    process_content, "urn:wanted",
  )
  assert_eq(processed.get("processed"), Some("processed.xml"))
  assert_eq(processed.length(), 1)
  let choice = @ooxml.parse_internal_relationship_targets(
    selected_choice, "urn:wanted",
  )
  assert_eq(choice.get("choice"), Some("choice.xml"))
  assert_eq(choice.length(), 1)
  let fallback = @ooxml.parse_internal_relationship_targets(
    selected_fallback, "urn:wanted",
  )
  assert_eq(fallback.get("fallback"), Some("fallback.xml"))
  assert_eq(fallback.length(), 1)
  let wildcard = @ooxml.parse_internal_relationship_targets(
    wildcard_process_content, "urn:wanted",
  )
  assert_eq(wildcard.get("wildcard"), Some("wildcard.xml"))
  assert_eq(wildcard.length(), 1)
  let empty = @ooxml.parse_internal_relationship_targets(
    empty_directives, "urn:wanted",
  )
  assert_eq(empty.get("empty"), Some("empty.xml"))
  assert_eq(empty.length(), 1)
  let understood = @ooxml.parse_internal_relationship_targets(
    understood_ignorable, "urn:wanted",
  )
  assert_eq(understood.get("understood"), Some("understood.xml"))
  assert_eq(understood.length(), 1)
}

///|
test "ooxml read_parse: nested Ignorable resets and restores ProcessContent" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Outer v:Scope"><v:Outer><Relationship Id="before" Type="urn:wanted" Target="before.xml"/></v:Outer><v:Scope mc:Ignorable="v" mc:ProcessContent="v:Scope v:Inner"><v:Outer><Relationship Id="blocked" Type="urn:wanted" Target="blocked.xml"/></v:Outer><v:Inner><Relationship Id="inside" Type="urn:wanted" Target="inside.xml"/></v:Inner></v:Scope><v:Outer><Relationship Id="after" Type="urn:wanted" Target="after.xml"/></v:Outer></Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:wanted")
  assert_eq(targets.get("before"), Some("before.xml"))
  assert_eq(targets.get("inside"), Some("inside.xml"))
  assert_eq(targets.get("after"), Some("after.xml"))
  assert_eq(targets.get("blocked"), None)
  assert_eq(targets.length(), 3)
}

///|
test "ooxml read_parse: MCE names retain one copy of a long namespace URI" {
  let names = StringBuilder::new()
  for index in 0..<4096 {
    if index > 0 {
      names.write_char(' ')
    }
    names.write_string("v:n\{index}")
  }
  let namespace_uri = "urn:" + "v".repeat(100_000)
  let xml = "<Relationships xmlns=\"" +
    "http://schemas.openxmlformats.org/package/2006/relationships" +
    "\" xmlns:mc=\"" +
    "http://schemas.openxmlformats.org/markup-compatibility/2006" +
    "\" xmlns:v=\"" +
    namespace_uri +
    "\" mc:Ignorable=\"v\" mc:ProcessContent=\"" +
    names.to_string() +
    "\"/>"
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:wanted")
  assert_eq(targets.length(), 0)
}

///|
test "ooxml read_parse: invalid relationship MCE fails closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Fallback/></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent has no Choice element",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"/><mc:Fallback/><mc:Choice Requires="v"/></mc:AlternateContent></Relationships>
      ),
      "MCE Choice follows Fallback",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"/><mc:Fallback/><mc:Fallback/></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent has multiple Fallback elements",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:MustUnderstand="v"/>
      ),
      "MCE MustUnderstand namespace is unsupported",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires=""/></mc:AlternateContent></Relationships>
      ),
      "MCE Choice Requires is empty",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="mc"/>
      ),
      "MCE Ignorable namespace is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="mc" mc:ProcessContent="mc:AlternateContent"/>
      ),
      "MCE Ignorable namespace is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="mc" mc:PreserveElements="mc:AlternateContent"/>
      ),
      "MCE Ignorable namespace is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="mc" mc:PreserveAttributes="mc:Ignorable"/>
      ),
      "MCE Ignorable namespace is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="mc"/></mc:AlternateContent></Relationships>
      ),
      "MCE Choice Requires namespace is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Wrapper"><v:Wrapper xml:base="elsewhere"><Relationship Id="bad" Type="urn:wanted" Target="bad.xml"/></v:Wrapper></Relationships>
      ),
      "MCE ProcessContent element has an unsafe xml attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Unknown/></Relationships>
      ),
      "relationships effective content is invalid",
    ),
  ]
  for case in cases {
    let (xml, expected) = case
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship MCE")
    }
  }
}

///|
test "ooxml read_parse: unselected MCE choices remain opaque" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Unsupported mc:MustUnderstand="missing"><Relationship/></v:Unsupported></mc:Choice><mc:Choice Requires="r"><Relationship Id="selected" Type="urn:wanted" Target="selected.xml"/></mc:Choice></mc:AlternateContent></Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:wanted")
  assert_eq(targets.get("selected"), Some("selected.xml"))
  assert_eq(targets.length(), 1)
}

///|
test "ooxml read_parse: unselected Choice does not enforce MustUnderstand" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:v"><mc:AlternateContent><mc:Choice Requires="v" mc:MustUnderstand="v"/><mc:Fallback><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></mc:Fallback></mc:AlternateContent></Relationships>
  let targets = @ooxml.parse_internal_relationship_targets(xml, "urn:wanted")
  assert_eq(targets.get("ok"), Some("ok.xml"))
  assert_eq(targets.length(), 1)
}

///|
test "ooxml read_parse: MCE container grammar fails closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:v" mc:Ignorable="v" mc:ProcessContent="v:1bad"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></Relationships>
      ),
      "MCE ProcessContent name is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:v" mc:Ignorable="v" mc:ProcessContent="v:**"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></Relationships>
      ),
      "MCE ProcessContent name is invalid",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent bogus="x"><mc:Choice Requires="r"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></mc:Choice></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent has a disallowed attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:Choice Requires="r" bogus="x"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></mc:Choice></mc:AlternateContent></Relationships>
      ),
      "MCE Choice has a disallowed attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent mc:Typo="x"><mc:Choice Requires="r"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></mc:Choice></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent has a disallowed attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:v"><mc:AlternateContent><mc:Choice Requires="v"/><mc:Fallback bogus="x"/></mc:AlternateContent></Relationships>
      ),
      "MCE Fallback has a disallowed attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:v" mc:Ignorable="v" mc:ProcessContent="v:Wrap"><mc:AlternateContent><v:Wrap/><mc:Choice Requires="r"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></mc:Choice></mc:AlternateContent></Relationships>
      ),
      "MCE AlternateContent child is invalid",
    ),
  ]
  for case in cases {
    let (xml, expected) = case
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship MCE")
    }
  }
}

///|
test "ooxml read_parse: relationship schema attributes are closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" bogus="x"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml"/></Relationships>
      ),
      "relationships document element has a disallowed attribute",
    ),
    (
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="ok" Type="urn:wanted" Target="ok.xml" bogus="x"/></Relationships>
      ),
      "relationships record has a disallowed attribute",
    ),
  ]
  for case in cases {
    let (xml, expected) = case
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected relationship attribute error")
    } noraise {
      _ => fail("expected relationship attribute rejection")
    }
  }
}

///|
test "ooxml read_parse: invalid target modes fail closed" {
  let xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="bad" Type="urn:wanted" Target="inside.xml" TargetMode="Remote"/></Relationships>
  for external in [false, true] {
    try {
      if external {
        ignore(@ooxml.parse_external_relationship_targets(xml, "urn:wanted"))
      } else {
        ignore(@ooxml.parse_internal_relationship_targets(xml, "urn:wanted"))
      }
    } catch {
      InvalidXml(msg~) =>
        inspect(msg, content="relationship target mode invalid")
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship target mode")
    }
  }
}

///|
test "ooxml read_parse: unwanted relationships remain schema-valid and ids stay unique" {
  for
    xml in [
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="bad" Type="urn:other"/></Relationships>
      ),
      (
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="same" Type="urn:other" Target="a"/><Relationship Id="same" Type="urn:wanted" Target="b"/></Relationships>
      ),
    ] {
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(_) => ()
      _ => fail("unexpected relationship parse cancellation")
    } noraise {
      _ => fail("expected invalid relationship document")
    }
  }
}

///|
test "ooxml read_parse: relationship IRIs follow OPC component grammar" {
  let unicode_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="unicode" Type="https://example.com/类型" Target="路径/文件.xml?键=值"/></Relationships>
  let unicode_targets = @ooxml.parse_internal_relationship_targets(
    unicode_xml, "https://example.com/类型",
  )
  assert_eq(unicode_targets.get("unicode"), Some("路径/文件.xml?键=值"))
  let external_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="ipv6" Type="https://[2001:db8::1]/type" Target="https://[::1]:443/book.xlsx" TargetMode="External"/><Relationship Id="windows" Type="urn:windows-file" Target="file:///C:\Temp\book.xlsx" TargetMode="External"/></Relationships>
  let ipv6_targets = @ooxml.parse_external_relationship_targets(
    external_xml, "https://[2001:db8::1]/type",
  )
  assert_eq(ipv6_targets.get("ipv6"), Some("https://[::1]:443/book.xlsx"))
  let windows_targets = @ooxml.parse_external_relationship_targets(
    external_xml, "urn:windows-file",
  )
  assert_eq(windows_targets.get("windows"), Some("file:///C:\\Temp\\book.xlsx"))
}

///|
test "ooxml read_parse: malformed relationship IRIs fail closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Relationship Id="bad" Type="relative-type" Target="ok.xml"/>
      ),
      "relationship type is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="urn:type#fragment" Target="ok.xml"/>
      ),
      "relationship type is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="http://[broken/type" Target="ok.xml"/>
      ),
      "relationship type is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="http://host]/type" Target="ok.xml"/>
      ),
      "relationship type is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="urn:other" Target="http://[broken/path" TargetMode="External"/>
      ),
      "relationship target is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="urn:other" Target="http://[::1]:port/path" TargetMode="External"/>
      ),
      "relationship target is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="urn:other" Target="path#one#two"/>
      ),
      "relationship target is invalid",
    ),
    (
      (
        #|<Relationship Id="bad" Type="urn:other" Target="bad%escape"/>
      ),
      "relationship target is invalid",
    ),
  ]
  for case in cases {
    let (record, expected) = case
    let xml = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
      record +
      "</Relationships>"
    try @ooxml.parse_internal_relationship_targets(xml, "urn:wanted") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected malformed relationship IRI error")
    } noraise {
      _ => fail("expected malformed relationship IRI rejection")
    }
  }
}

///|
test "ooxml read_parse: relationship limits accept writer boundaries" {
  let xml = StringBuilder::new()
  xml.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for index in 0..<16_385 {
    xml.write_string(
      "<Relationship Id=\"r\{index}\" Type=\"urn:other\" Target=\"x\"/>",
    )
  }
  let long_target = "x".repeat(4097)
  xml.write_string(
    "<Relationship Id=\"wanted\" Type=\"urn:wanted\" Target=\"\{long_target}\"/>",
  )
  xml.write_string("</Relationships>")
  let targets = @ooxml.parse_internal_relationship_targets(
    xml.to_string(),
    "urn:wanted",
  )
  assert_eq(targets.get("wanted"), Some(long_target))
}

///|
test "ooxml read_parse: relationship scans poll cancellation internally" {
  let xml = StringBuilder::new()
  xml.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for index in 0..<2048 {
    xml.write_string(
      "<Relationship Id=\"r\{index}\" Type=\"urn:other\" Target=\"x\"/>",
    )
  }
  xml.write_string("</Relationships>")
  let checks = [0]
  try
    @ooxml.parse_internal_relationship_targets(xml.to_string(), "urn:wanted", cancelled=() => {
      checks[0] += 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("expected relationship scan cancellation")
  } noraise {
    _ => fail("expected relationship scan cancellation")
  }
}

///|
test "ooxml read_parse: parse_content_type_overrides and find workbook part" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    #|  <Default Extension="xml" ContentType="application/xml"/>
    #|  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>
    #|  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    #|</Types>
    #|
  debug_inspect(
    @ooxml.find_override_part_by_content_types(xml, [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
      "application/vnd.ms-excel.sheet.macroEnabled.main+xml",
    ]),
    content="Some(\"/xl/workbook.xml\")",
  )
}

///|
test "ooxml read_parse: parse_content_type_overrides reports malformed override tags" {
  let malformed =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/xl/workbook.xml" 
    #|</Types>
    #|
  try
    @ooxml.find_override_part_by_content_types(malformed, [
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
    ])
  catch {
    InvalidXml(msg~) => inspect(msg, content="XML start tag is not closed")
    _ => fail("unexpected content type parse cancellation")
  } noraise {
    _ => fail("expected content type override tag not closed")
  }
}

///|
test "ooxml read_parse: prefixed content types decode names and media types" {
  let xml =
    #|<ct:Types xmlns:ct="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <ct:Override PartName="/xl/a&amp;b.xml" ContentType="application/vnd.example&#43;xml"/>
    #|</ct:Types>
  debug_inspect(
    @ooxml.find_override_part_by_content_types(xml, [
      "application/vnd.example+xml",
    ]),
    content="Some(\"/xl/a&b.xml\")",
  )
}

///|
test "ooxml read_parse: content type lookup honors part identity then default" {
  let xml =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="XML" ContentType="application/default+xml"/>
    #|  <Override PartName="/custom/book.xml" ContentType="application/workbook+xml"/>
    #|</Types>
  assert_eq(
    @ooxml.find_part_content_type(xml, "CUSTOM/BOOK.XML"),
    Some("application/workbook+xml"),
  )
  assert_eq(
    @ooxml.find_part_content_type(xml, "custom/other.Xml"),
    Some("application/default+xml"),
  )
}

///|
test "ooxml read_parse: content type lexical grammar is preserved" {
  let xml =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Default Extension="x%2F" ContentType="application/example ; charset=&quot;café&quot;"/>
    #|  <Default Extension="a(b)" ContentType="application/parenthesized"/>
    #|</Types>
  assert_eq(
    @ooxml.find_part_content_type(xml, "custom/file.x%2f"),
    Some("application/example ; charset=\"café\""),
  )
  assert_eq(
    @ooxml.find_part_content_type(xml, "custom/file.A(B)"),
    Some("application/parenthesized"),
  )
}

///|
test "ooxml read_parse: content type scans poll cancellation internally" {
  let xml = StringBuilder::new()
  xml.write_string(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
  )
  for index in 0..<2048 {
    xml.write_string(
      "<Override PartName=\"/custom/p\{index}.xml\" ContentType=\"application/xml\"/>",
    )
  }
  xml.write_string("</Types>")
  let checks = [0]
  try
    @ooxml.find_part_content_type(xml.to_string(), "custom/missing.xml", cancelled=() => {
      checks[0] += 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("expected content type scan cancellation")
  } noraise {
    _ => fail("expected content type scan cancellation")
  }
}

///|
test "ooxml read_parse: content type overrides reject case-variant duplicates" {
  let xml =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|  <Override PartName="/custom/book.xml" ContentType="application/first+xml"/>
    #|  <Override PartName="/CUSTOM/BOOK.XML" ContentType="application/second+xml"/>
    #|</Types>
  try @ooxml.find_part_content_type(xml, "custom/book.xml") catch {
    InvalidXml(msg~) => inspect(msg, content="duplicate content type override")
    _ => fail("unexpected content type parse cancellation")
  } noraise {
    _ => fail("expected case-variant duplicate override rejection")
  }
}

///|
test "ooxml read_parse: content type grammar fails closed" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types" bogus="x"><Default Extension="xml" ContentType="application/xml"/></Types>
      ),
      "content types document element has a disallowed attribute",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml" bogus="x"/></Types>
      ),
      "content types default has a disallowed attribute",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".xml" ContentType="application/xml"/></Types>
      ),
      "content type default extension is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="not a media type"/></Types>
      ),
      "content type default media type is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml; charset =utf-8"/></Types>
      ),
      "content type default media type is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml; charset= utf-8"/></Types>
      ),
      "content type default media type is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml "/></Types>
      ),
      "content type default media type is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/xl/workbook.xml" ContentType=" application/xml"/></Types>
      ),
      "content type override media type is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=" xml" ContentType="application/xml"/></Types>
      ),
      "content type default extension is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="é" ContentType="application/xml"/></Types>
      ),
      "content type default extension is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="x%GG" ContentType="application/xml"/></Types>
      ),
      "content type default extension is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="xl/workbook.xml" ContentType="application/xml"/></Types>
      ),
      "content type override part name is invalid",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml">payload</Default></Types>
      ),
      "content type declaration is not empty",
    ),
    (
      (
        #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>
      ),
      "content types document has no declarations",
    ),
  ]
  for index, case in cases {
    let (xml, expected) = case
    try @ooxml.find_part_content_type(xml, "xl/workbook.xml") catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected content type grammar error")
    } noraise {
      _ => fail("expected content type grammar rejection for case \{index}")
    }
}
