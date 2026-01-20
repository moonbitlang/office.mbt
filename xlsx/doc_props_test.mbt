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
