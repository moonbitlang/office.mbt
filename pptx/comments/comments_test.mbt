// Modified for office.mbt: follow the workspace warning conventions.
// Comments parser tests.

///|
let pml_ns : String = "http://schemas.openxmlformats.org/presentationml/2006/main"

// --- commentAuthors.xml ---

///|
fn typical_authors() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"Alice\" initials=\"A\" lastIdx=\"3\" clrIdx=\"0\"/>" +
    "<p:cmAuthor id=\"1\" name=\"Bob\" initials=\"BB\" lastIdx=\"1\" clrIdx=\"1\">" +
    "<p:extLst><p:ext uri=\"{ABC}\"/></p:extLst>" +
    "</p:cmAuthor>" +
    "</p:cmAuthorLst>"
  @oxml.string_to_bytes(xml)
}

///|
test "CommentAuthorList::parse: count + first author fields" {
  let list = @comments.CommentAuthorList::parse(typical_authors())
  debug_inspect(list.authors.length(), content="2")
  let alice = list.authors[0]
  debug_inspect(alice.id, content="0")
  debug_inspect(alice.name, content="\"Alice\"")
  debug_inspect(alice.initials, content="\"A\"")
  debug_inspect(alice.last_idx, content="3")
  debug_inspect(alice.clr_idx, content="0")
  debug_inspect(alice.extension.length(), content="0")
}

///|
test "CommentAuthorList::parse: per-author extLst is preserved" {
  let list = @comments.CommentAuthorList::parse(typical_authors())
  let bob = list.authors[1]
  debug_inspect(bob.id, content="1")
  debug_inspect(bob.name, content="\"Bob\"")
  debug_inspect(bob.initials, content="\"BB\"")
  debug_inspect(bob.extension.length(), content="1")
  debug_inspect(bob.extension[0].name.local_name, content="\"extLst\"")
}

///|
test "CommentAuthorList::parse: empty list" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" + pml_ns + "\"/>"
  let list = @comments.CommentAuthorList::parse(@oxml.string_to_bytes(xml))
  debug_inspect(list.authors.length(), content="0")
  debug_inspect(list.extension.length(), content="0")
}

///|
test "CommentAuthorList::parse: top-level extLst rides on list extension" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"A\" initials=\"A\" lastIdx=\"0\" clrIdx=\"0\"/>" +
    "<p:extLst><p:ext uri=\"{X}\"/></p:extLst>" +
    "</p:cmAuthorLst>"
  let list = @comments.CommentAuthorList::parse(@oxml.string_to_bytes(xml))
  debug_inspect(list.authors.length(), content="1")
  debug_inspect(list.extension.length(), content="1")
  debug_inspect(list.extension[0].name.local_name, content="\"extLst\"")
}

///|
test "CommentAuthorList::parse: missing required attribute raises Malformed" {
  // `clrIdx` is required by the schema; omit it and confirm we raise.
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cmAuthor id=\"0\" name=\"A\" initials=\"A\" lastIdx=\"0\"/>" +
    "</p:cmAuthorLst>"
  try @comments.CommentAuthorList::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "CommentAuthorList::parse: wrong root element raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" + pml_ns + "\"/>"
  try @comments.CommentAuthorList::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

// --- commentsN.xml ---

///|
fn typical_comments() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" dt=\"2026-05-21T10:30:00\" idx=\"1\">" +
    "<p:pos x=\"1828800\" y=\"914400\"/>" +
    "<p:text>Looks good to me.</p:text>" +
    "</p:cm>" +
    "<p:cm authorId=\"1\" idx=\"2\">" +
    // No dt — older PowerPoint versions omitted this.
    "<p:pos x=\"3657600\" y=\"2743200\"/>" +
    "<p:text>Needs a citation.</p:text>" +
    "<p:extLst><p:ext uri=\"{XYZ}\"/></p:extLst>" +
    "</p:cm>" +
    "</p:cmLst>"
  @oxml.string_to_bytes(xml)
}

///|
test "CommentList::parse: count + first comment fields" {
  let list = @comments.CommentList::parse(typical_comments())
  debug_inspect(list.comments.length(), content="2")
  let first = list.comments[0]
  debug_inspect(first.author_id, content="0")
  debug_inspect(first.dt.unwrap(), content="\"2026-05-21T10:30:00\"")
  debug_inspect(first.idx, content="1")
  debug_inspect(first.pos.x, content="Emu(1828800)")
  debug_inspect(first.pos.y, content="Emu(914400)")
  debug_inspect(first.text, content="\"Looks good to me.\"")
  debug_inspect(first.extension.length(), content="0")
}

///|
test "CommentList::parse: dt is optional" {
  let list = @comments.CommentList::parse(typical_comments())
  let second = list.comments[1]
  debug_inspect(second.author_id, content="1")
  debug_inspect(second.dt is None, content="true")
  debug_inspect(second.idx, content="2")
  debug_inspect(second.text, content="\"Needs a citation.\"")
}

///|
test "CommentList::parse: per-comment extLst is preserved" {
  let list = @comments.CommentList::parse(typical_comments())
  let second = list.comments[1]
  debug_inspect(second.extension.length(), content="1")
  debug_inspect(second.extension[0].name.local_name, content="\"extLst\"")
}

///|
test "CommentList::parse: empty list" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" + pml_ns + "\"/>"
  let list = @comments.CommentList::parse(@oxml.string_to_bytes(xml))
  debug_inspect(list.comments.length(), content="0")
  debug_inspect(list.extension.length(), content="0")
}

///|
test "CommentList::parse: missing <p:pos> raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\"><p:text>oops</p:text></p:cm>" +
    "</p:cmLst>"
  try @comments.CommentList::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "CommentList::parse: nested element inside <p:text> raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text><p:foo/></p:text>" +
    "</p:cm></p:cmLst>"
  try @comments.CommentList::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "CommentList::parse: unknown child of <p:cm> is preserved" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text>hi</p:text>" +
    "<p:futureSibling foo=\"bar\"/>" +
    "</p:cm></p:cmLst>"
  let list = @comments.CommentList::parse(@oxml.string_to_bytes(xml))
  let c = list.comments[0]
  debug_inspect(c.extension.length(), content="1")
  debug_inspect(c.extension[0].name.local_name, content="\"futureSibling\"")
}

///|
test "CommentList::parse: wrong root element raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><p:cmAuthorLst xmlns:p=\"" + pml_ns + "\"/>"
  try @comments.CommentList::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "CommentList::parse: text with entity references decodes" {
  let xml = "<?xml version=\"1.0\"?><p:cmLst xmlns:p=\"" +
    pml_ns +
    "\">" +
    "<p:cm authorId=\"0\" idx=\"1\">" +
    "<p:pos x=\"0\" y=\"0\"/>" +
    "<p:text>a &amp; b &lt; c</p:text>" +
    "</p:cm></p:cmLst>"
  let list = @comments.CommentList::parse(@oxml.string_to_bytes(xml))
  debug_inspect(list.comments[0].text, content="\"a & b < c\"")
}
