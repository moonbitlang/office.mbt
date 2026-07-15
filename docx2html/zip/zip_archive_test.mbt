///|
test "archive-backed DOCX view rejects duplicate entry names" {
  let archive = @mbtzip.Archive::new()
  archive.add("word/document.xml", b"first")
  archive.add("word/document.xml", b"second")
  try {
    let _ = @zip.open_zip_archive(archive)
    fail("expected duplicate ZIP entry rejection")
  } catch {
    @core.InvalidZip(message~) =>
      inspect(message, content="duplicate ZIP entry name: word/document.xml")
    _ => fail("expected InvalidZip")
  }
}

///|
test "DOCX view resolves case-equivalent names to exact archive spelling" {
  let archive = @zip.zip_archive({ "CUSTOM/MAIN.XML": b"document" })
  assert_true(archive.exists("custom/main.xml"))
  debug_inspect(
    archive.resolve_path("custom/main.xml"),
    content="Some(\"CUSTOM/MAIN.XML\")",
  )
  guard archive.read_bytes("custom/main.xml") is Some(bytes) else {
    fail("expected case-equivalent lookup to resolve")
  }
  assert_eq(bytes, b"document")
}

///|
test "DOCX view resolves logical Unicode names to physical ZIP spellings" {
  let archive = @zip.zip_archive({ "word/%C3%A9.xml": b"document" })
  assert_eq(archive.resolve_path("word/é.xml"), Some("word/%C3%A9.xml"))
  assert_eq(archive.logical_path("word/%C3%A9.xml"), Some("word/é.xml"))
  assert_eq(archive.logical_path("WORD/é.XML"), Some("word/é.xml"))
  assert_eq(archive.logical_path("word/É.xml"), None)
  assert_eq(archive.read_bytes("word/é.xml"), Some(b"document"))
}

///|
test "DOCX view rejects physical names that bypass OPC ZIP mapping" {
  try {
    let _ = @zip.zip_archive({ "word/é.xml": b"document" })
    fail("expected a non-ASCII physical name to be rejected")
  } catch {
    @core.InvalidZip(message~) =>
      assert_true(message.contains("does not map to a canonical OPC part name"))
    _ => fail("expected InvalidZip")
  }
}

///|
test "DOCX view rejects case-equivalent aliases at construction" {
  try {
    let _ = @zip.zip_archive({
      "word/document.xml": b"first",
      "WORD/DOCUMENT.XML": b"second",
    })
    fail("expected constructor alias rejection")
  } catch {
    @core.InvalidZip(message~) =>
      assert_true(
        message.has_prefix(
          "duplicate ZIP entry names after case normalization:",
        ),
      )
    _ => fail("expected InvalidZip")
  }
}

///|
test "DOCX view ignores explicit directory records and their aliases" {
  let archive = @mbtzip.Archive::new()
  archive.add("word/", b"")
  archive.add("WORD/", b"")
  archive.add("word/document.xml", b"document")
  let view = @zip.open_zip_archive(archive)
  assert_false(view.exists("word/"))
  assert_true(view.exists("word/document.xml"))
}

///|
test "DOCX view rejects derivable names and inexact content-types spelling" {
  try {
    let _ = @zip.zip_archive({ "a": b"ancestor", "a/b.xml": b"descendant" })
    fail("expected derivable PartNames to be rejected")
  } catch {
    @core.InvalidZip(message~) =>
      assert_true(message.contains("must not be derivable"))
    _ => fail("expected InvalidZip")
  }
  try {
    let _ = @zip.zip_archive({ "[CONTENT_TYPES].XML": b"types" })
    fail("expected inexact reserved spelling to be rejected")
  } catch {
    @core.InvalidZip(message~) =>
      assert_true(message.contains("must use exact spelling"))
    _ => fail("expected InvalidZip")
  }
}
