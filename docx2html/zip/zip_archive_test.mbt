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
