// Modified for office.mbt: follow the workspace warning conventions.
// AppProperties (docProps/app.xml) tests.

///|
test "app_properties: reads the template's Application, absent fields None" {
  let prs = @presentation.Presentation::new()
  let props = prs.app_properties()
  debug_inspect(props.application.unwrap(), content="\"moon-pptx\"")
  debug_inspect(props.company is None, content="true")
  debug_inspect(props.manager is None, content="true")
}

///|
test "set_app_properties_mut: merges without disturbing other fields" {
  let prs = @presentation.Presentation::new()
  prs.set_app_properties_mut(
    @presentation.AppProperties::new()
    .with_company("ACME 株式会社")
    .with_manager("Coyote"),
  )
  let props = prs.app_properties()
  debug_inspect(props.company.unwrap(), content="\"ACME 株式会社\"")
  debug_inspect(props.manager.unwrap(), content="\"Coyote\"")
  // Untouched fields survive the merge.
  debug_inspect(props.application.unwrap(), content="\"moon-pptx\"")
  let xml = saved_part_xml(prs, "/docProps/app.xml")
  debug_inspect(
    xml.contains(
      "<PresentationFormat>On-screen Show (4:3)</PresentationFormat>",
    ),
    content="true",
  )
  debug_inspect(xml.contains("<Slides>0</Slides>"), content="true")
  // Emitted with the extended-properties namespace as the default —
  // bare element names, no generated prefixes.
  debug_inspect(
    xml.contains("<Properties xmlns=\"" + @oxml.extended_properties_ns + "\""),
    content="true",
  )
  debug_inspect(
    xml.contains("<Company>ACME 株式会社</Company>"),
    content="true",
  )
  debug_inspect(!xml.contains("ext0:"), content="true")
}

///|
test "set_app_properties_mut: setting an existing field replaces it once" {
  let prs = @presentation.Presentation::new()
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_application("my-tool 1.0"),
  )
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_application("my-tool 2.0"),
  )
  debug_inspect(
    prs.app_properties().application.unwrap(),
    content="\"my-tool 2.0\"",
  )
  let xml = saved_part_xml(prs, "/docProps/app.xml")
  let first = xml.find("<Application>").unwrap()
  let rest = xml[first + 1:].to_owned()
  debug_inspect(rest.find("<Application>") is None, content="true")
}

///|
test "app properties survive save -> reopen" {
  let prs = @presentation.Presentation::new()
  prs.set_app_properties_mut(
    @presentation.AppProperties::new().with_company("Initech"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(
    reopened.app_properties().company.unwrap(),
    content="\"Initech\"",
  )
}

///|
test "set_app_properties_mut: recreates a missing part with its package rel" {
  let prs = @presentation.Presentation::new()
  // Simulate a package without docProps/app.xml.
  debug_inspect(prs.pkg.remove_part("/docProps/app.xml"), content="true")
  prs.set_app_properties_mut(
    @presentation.AppProperties::new()
    .with_company("Globex")
    .with_app_version("16.0000"),
  )
  let props = prs.app_properties()
  debug_inspect(props.company.unwrap(), content="\"Globex\"")
  debug_inspect(props.app_version.unwrap(), content="\"16.0000\"")
  // Exactly one extended-properties relationship on the package.
  let rels = prs.pkg.relationships_for("/")
  debug_inspect(rels.by_type(@opc.rt_extended_properties).length(), content="1")
  // And the whole thing still opens.
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(
    reopened.app_properties().company.unwrap(),
    content="\"Globex\"",
  )
}

///|
test "with_app_properties: immutable counterpart leaves the original untouched" {
  let prs = @presentation.Presentation::new()
  let edited = prs.with_app_properties(
    @presentation.AppProperties::new().with_company("Hooli"),
  )
  debug_inspect(prs.app_properties().company is None, content="true")
  debug_inspect(edited.app_properties().company.unwrap(), content="\"Hooli\"")
}

///|
test "app_properties: a malformed app.xml raises instead of guessing" {
  let prs = @presentation.Presentation::new()
  debug_inspect(prs.pkg.remove_part("/docProps/app.xml"), content="true")
  // A part whose root is not <Properties> in the ep namespace.
  prs.pkg.add_part(
    @opc.Part::new(
      "/docProps/app.xml",
      @oxml.ct_extended_properties,
      @oxml.string_to_bytes("<?xml version=\"1.0\"?><wrong/>"),
    ),
  )
  try prs.app_properties() |> ignore catch {
    Malformed(_) => ()
    _ => fail("expected Malformed for a non-Properties root")
  } noraise {
    _ => fail("expected Malformed for a non-Properties root")
  }
}
