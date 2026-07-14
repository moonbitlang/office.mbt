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
