///|
test "MCE projection selects fallback and preserves promoted namespaces" {
  let xml =
    #|<a:Root xmlns:a="urn:app" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"><v:Future/></mc:Choice><mc:Fallback xmlns:q="urn:app"><q:Item q:id="kept"/></mc:Fallback></mc:AlternateContent></a:Root>
  let projected = @ooxml.project_xml_markup_compatibility(xml, ["urn:app"])
  assert_false(projected.contains("AlternateContent"))
  assert_false(projected.contains("Future"))
  assert_true(projected.contains("q:Item"))
  let scanner = @ooxml.XmlStartTagScanner::new(projected)
  assert_true(scanner.next())
  assert_true(scanner.next())
  inspect(scanner.namespace_uri(), content="urn:app")
  inspect(scanner.local_name(), content="Item")
  debug_inspect(scanner.attribute("urn:app", "id"), content="Some(\"kept\")")
  assert_false(scanner.next())
}

///|
test "MCE projection selects the first understood Choice" {
  let xml =
    #|<a:Root xmlns:a="urn:app" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="a"><a:Selected/></mc:Choice><mc:Fallback><a:Fallback/></mc:Fallback></mc:AlternateContent></a:Root>
  let projected = @ooxml.project_xml_markup_compatibility(xml, ["urn:app"])
  assert_true(projected.contains("<a:Selected"))
  assert_false(projected.contains("Fallback"))
}

///|
test "MCE projection unwraps ProcessContent and ignores opaque extensions" {
  let xml =
    #|<a:Root xmlns:a="urn:app" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Wrap"><v:Drop/><v:Wrap><a:Kept/></v:Wrap></a:Root>
  let projected = @ooxml.project_xml_markup_compatibility(xml, ["urn:app"])
  assert_false(projected.contains("v:Drop"))
  assert_false(projected.contains("<v:Wrap"))
  assert_true(projected.contains("a:Kept"))
}

///|
test "MCE projection does not enforce MustUnderstand on an unselected Choice" {
  let xml =
    #|<a:Root xmlns:a="urn:app" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v" mc:MustUnderstand="v"/><mc:Fallback><a:Kept/></mc:Fallback></mc:AlternateContent></a:Root>
  let projected = @ooxml.project_xml_markup_compatibility(xml, ["urn:app"])
  assert_true(projected.contains("a:Kept"))
}

///|
test "MCE projection output and cancellation are bounded" {
  let xml =
    #|<a:Root xmlns:a="urn:app" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor"><mc:AlternateContent><mc:Choice Requires="v"/><mc:Fallback><a:Kept/></mc:Fallback></mc:AlternateContent></a:Root>
  try
    @ooxml.project_xml_markup_compatibility(
      xml,
      ["urn:app"],
      max_output_chars=8,
    )
  catch {
    InvalidXml(msg~) =>
      inspect(msg, content="XML canonical output limit exceeded")
    _ => fail("unexpected MCE projection cancellation")
  } noraise {
    _ => fail("expected MCE projection output limit")
  }
  let checks = [0]
  try
    @ooxml.project_xml_markup_compatibility(
      "<a:Root xmlns:a=\"urn:app\">" + "x".repeat(32 * 1024) + "</a:Root>",
      ["urn:app"],
      cancelled=() => {
        checks[0] += 1
        checks[0] >= 8
      },
    )
  catch {
    ReadCancelled => assert_true(checks[0] >= 8)
    _ => fail("unexpected bounded MCE projection error")
  } noraise {
    _ => fail("expected MCE projection cancellation")
  }
}
