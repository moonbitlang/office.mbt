///|
test "doc properties roundtrip" {
  let workbook = Workbook::new()
  let core = CoreProperties::with_values(
    title="Title",
    creator="Creator",
    last_modified_by="Modifier",
    created="2024-01-01T00:00:00Z",
    modified="2024-01-02T00:00:00Z",
  )
  workbook.set_core_properties(core)
  let app = AppProperties::with_values(
    application="MyApp",
    company="Acme",
    doc_security=2,
    scale_crop=true,
    links_up_to_date=false,
    hyperlinks_changed=true,
    app_version="16.0000",
  )
  workbook.set_app_properties(app)
  let parsed = read(write(workbook))
  let parsed_core = parsed.core_properties()
  inspect(parsed_core.title, content="Title")
  inspect(parsed_core.creator, content="Creator")
  inspect(parsed_core.last_modified_by, content="Modifier")
  inspect(parsed_core.created, content="2024-01-01T00:00:00Z")
  inspect(parsed_core.modified, content="2024-01-02T00:00:00Z")
  let parsed_app = parsed.app_properties()
  inspect(parsed_app.application, content="MyApp")
  inspect(parsed_app.company, content="Acme")
  inspect(parsed_app.doc_security, content="Some(2)")
  inspect(parsed_app.scale_crop, content="Some(true)")
  inspect(parsed_app.links_up_to_date, content="Some(false)")
  inspect(parsed_app.hyperlinks_changed, content="Some(true)")
  inspect(parsed_app.app_version, content="16.0000")
}

///|
test "doc properties defaults" {
  let workbook = Workbook::new()
  let core = workbook.core_properties()
  inspect(core.creator, content="mbtexcel")
  inspect(core.last_modified_by, content="mbtexcel")
  let app = workbook.app_properties()
  inspect(app.application, content="mbtexcel")
}

///|
test "custom properties roundtrip" {
  let workbook = Workbook::new()
  workbook.set_custom_props(CustomProperty::new("Text", Some(Text("hello"))))
  workbook.set_custom_props(CustomProperty::new("Bool", Some(Boolean(true))))
  workbook.set_custom_props(CustomProperty::new("Number", Some(Float(12.5))))
  workbook.set_custom_props(CustomProperty::new("Int", Some(Integer(-7))))
  workbook.set_custom_props(
    CustomProperty::new("Date", Some(DateTime("2024-01-01T00:00:00Z"))),
  )
  workbook.set_custom_props(CustomProperty::new("Remove", Some(Text("gone"))))
  workbook.set_custom_props(CustomProperty::new("Remove", None))
  let parsed = read(write(workbook))
  let props = parsed.get_custom_props()
  inspect(
    props.map(prop => prop.name),
    content="[\"Text\", \"Bool\", \"Number\", \"Int\", \"Date\"]",
  )
  inspect(props[0].value, content="Some(Text(\"hello\"))")
  inspect(props[1].value, content="Some(Boolean(true))")
  inspect(props[2].value, content="Some(Float(12.5))")
  inspect(props[3].value, content="Some(Integer(-7))")
  inspect(props[4].value, content="Some(DateTime(\"2024-01-01T00:00:00Z\"))")
}

///|
test "doc props get/set aliases" {
  let workbook = Workbook::new()
  let core = CoreProperties::with_values(
    title="Title",
    creator="Creator",
    last_modified_by="Modifier",
    created="2024-01-01T00:00:00Z",
    modified="2024-01-02T00:00:00Z",
  )
  workbook.set_doc_props(core)
  let got = workbook.get_doc_props()
  inspect(got.title, content="Title")
  inspect(got.creator, content="Creator")
  inspect(got.last_modified_by, content="Modifier")
  inspect(got.created, content="2024-01-01T00:00:00Z")
  inspect(got.modified, content="2024-01-02T00:00:00Z")
}

///|
test "app props get/set aliases" {
  let workbook = Workbook::new()
  let app = AppProperties::with_values(
    application="MyApp",
    company="Acme",
    doc_security=2,
    scale_crop=true,
    links_up_to_date=false,
    hyperlinks_changed=true,
    app_version="16.0000",
  )
  workbook.set_app_props(app)
  let got = workbook.get_app_props()
  inspect(got.application, content="MyApp")
  inspect(got.company, content="Acme")
  inspect(got.doc_security, content="Some(2)")
  inspect(got.scale_crop, content="Some(true)")
  inspect(got.links_up_to_date, content="Some(false)")
  inspect(got.hyperlinks_changed, content="Some(true)")
  inspect(got.app_version, content="16.0000")
}
