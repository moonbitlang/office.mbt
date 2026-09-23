// Tests for typed document core properties (`docProps/core.xml`).

///|
test "core_properties: blank deck reads the template defaults" {
  let prs = @presentation.Presentation::new()
  let cp = prs.core_properties()
  debug_inspect(cp.creator.unwrap(), content="\"moon-pptx\"")
  debug_inspect(cp.last_modified_by.unwrap(), content="\"moon-pptx\"")
  debug_inspect(cp.revision.unwrap(), content="\"1\"")
  debug_inspect(cp.title.unwrap(), content="\"\"") // blank emits an empty <dc:title>
  debug_inspect(cp.subject is None, content="true")
}

///|
test "core_properties: set then read round-trips every field" {
  let prs = @presentation.Presentation::new()
  let props = @presentation.CoreProperties::new()
    .with_title("Q3 Review")
    .with_author("Ada Lovelace")
    .with_subject("Finance")
    .with_keywords("q3, finance")
    .with_description("Quarterly numbers")
    .with_category("Reports")
    .with_content_status("Final")
    .with_created("2026-06-16T09:30:00Z")
    .with_modified("2026-06-16T10:00:00Z")
    .with_last_printed("2026-06-15T08:00:00Z")
    .with_last_modified_by("Grace Hopper")
    .with_revision("3")
    .with_identifier("doc-123")
    .with_language("en-US")
    .with_version("1.2")
  prs.set_core_properties_mut(props)
  debug_inspect(prs.core_properties() == props, content="true")
}

///|
test "core_properties: read → edit → write preserves untouched fields, survives save → open" {
  let prs = @presentation.Presentation::new()
  // The lossless idiom: start from the current properties so unset fields
  // (here the template's revision="1") survive the rewrite.
  prs.set_core_properties_mut(
    prs.core_properties().with_title("Saved").with_author("Ada"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  let cp = reopened.core_properties()
  debug_inspect(cp.title.unwrap(), content="\"Saved\"")
  debug_inspect(cp.creator.unwrap(), content="\"Ada\"")
  // the untouched template field survived because we edited from a read
  debug_inspect(cp.revision.unwrap(), content="\"1\"")
}

///|
test "core_properties: with_core_properties is immutable" {
  let prs = @presentation.Presentation::new()
  let prs2 = prs.with_core_properties(
    @presentation.CoreProperties::new().with_title("New"),
  )
  debug_inspect(prs2.core_properties().title.unwrap(), content="\"New\"")
  // the original is untouched (still the blank template's empty title)
  debug_inspect(prs.core_properties().title.unwrap(), content="\"\"")
}

///|
test "core_properties: with_author aliases with_creator" {
  let a = @presentation.CoreProperties::new().with_author("X")
  let b = @presentation.CoreProperties::new().with_creator("X")
  debug_inspect(a == b, content="true")
  debug_inspect(a.creator.unwrap(), content="\"X\"")
}

///|
test "core_properties: to_xml emits prefixes + xsi:type, omits None fields" {
  let xml = @presentation.CoreProperties::new()
    .with_title("Hi")
    .with_keywords("k")
    .with_created("2026-01-01T00:00:00Z")
    .to_xml()
  debug_inspect(xml.contains("<dc:title>Hi</dc:title>"), content="true")
  debug_inspect(xml.contains("<cp:keywords>k</cp:keywords>"), content="true")
  debug_inspect(xml.contains("<dcterms:created"), content="true")
  debug_inspect(xml.contains("xsi:type=\"dcterms:W3CDTF\""), content="true")
  // a None field is omitted entirely
  debug_inspect(xml.contains("<dc:subject"), content="false")
}

///|
test "core_properties: empty new() emits the root but no field elements" {
  let xml = @presentation.CoreProperties::new().to_xml()
  debug_inspect(xml.contains("coreProperties"), content="true")
  debug_inspect(xml.contains("<dc:title"), content="false")
  debug_inspect(xml.contains("<cp:revision"), content="false")
}

///|
test "core_properties: special characters are XML-escaped + decode back" {
  let prs = @presentation.Presentation::new()
  prs.set_core_properties_mut(
    @presentation.CoreProperties::new().with_title("R&D <plan>"),
  )
  // parse decodes the entities back to the original string
  debug_inspect(prs.core_properties().title.unwrap(), content="\"R&D <plan>\"")
  // the serialised form carries the escaped entity
  let raw = @presentation.CoreProperties::new().with_title("R&D").to_xml()
  debug_inspect(raw.contains("R&amp;D"), content="true")
}
