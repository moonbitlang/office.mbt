///|
test "part enumeration cannot corrupt package storage or its index" {
  let pkg = @opc.Package::new()
  pkg.add_part(
    @opc.Part::new("/a.xml", "application/xml", @fzip.str_to_u8("a")),
  )
  let parts = pkg.parts()
  parts.clear()
  parts.push(@opc.Part::new("/b.xml", "application/xml", @fzip.str_to_u8("b")))
  debug_inspect(pkg.parts().map(part => part.name), content="[\"/a.xml\"]")
  debug_inspect(pkg.part_by_name("/b.xml") is None, content="true")
  debug_inspect(pkg.require_part("/a.xml").text(), content="\"a\"")
  debug_inspect(
    pkg.replace_part(
      @opc.Part::new("/a.xml", "application/xml", @fzip.str_to_u8("new")),
    ),
    content="true",
  )
  debug_inspect(pkg.require_part("/a.xml").text(), content="\"new\"")
}

///|
test "content type enumerations cannot mutate the catalog" {
  let catalog = @opc.ContentTypes::new()
    .with_default("xml", "application/xml")
    .with_override("/a.xml", "custom/a")
  let defaults = catalog.defaults()
  let overrides = catalog.overrides()
  defaults.clear()
  overrides.clear()
  debug_inspect(catalog.resolve("/a.xml"), content="Some(\"custom/a\")")
  debug_inspect(catalog.resolve("/b.xml"), content="Some(\"application/xml\")")
}

///|
test "relationship enumeration cannot bypass duplicate ID validation" {
  let relationship : @opc.Relationship = {
    id: "rId1",
    rel_type: @opc.rt_slide,
    target: "slide1.xml",
    target_mode: Internal,
  }
  let rels = @opc.Relationships::new("/ppt/presentation.xml").with_relationship(
    relationship,
  )
  rels.items().clear()
  debug_inspect(rels.by_id("rId1") is Some(_), content="true")
  try rels.with_relationship(relationship) catch {
    MalformedPackage(_) => ()
    _ => fail("expected duplicate relationship ID rejection")
  } noraise {
    _ => fail("snapshot mutation must not remove the stored relationship")
  }
}
