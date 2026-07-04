///|
fn pdf_ua_matterhorn_test_06_001() -> PdfUAMatterhornTest {
  {
    name: "06-001",
    error: "Document does not contain an XMP metadata stream",
    section: "UA1:7.1-8",
  }
}

///|
fn pdf_ua_matterhorn_test_06_002() -> PdfUAMatterhornTest {
  {
    name: "06-002",
    error: "The XMP metadata stream in the Catalog dictionary does not include the PDF/UA identifier.",
    section: "UA1:5",
  }
}

///|
fn pdf_ua_matterhorn_test_06_003() -> PdfUAMatterhornTest {
  {
    name: "06-003",
    error: "XMP metadata stream does not contain dc:title",
    section: "UA1:7.1-8",
  }
}

///|
fn pdf_ua_matterhorn_test_07_001() -> PdfUAMatterhornTest {
  {
    name: "07-001",
    error: "ViewerPreferences dictionary of the Catalog dictionary does not contain a DisplayDocTitle entry",
    section: "UA1:7.1-9",
  }
}

///|
fn pdf_ua_matterhorn_test_07_002() -> PdfUAMatterhornTest {
  {
    name: "07-002",
    error: "ViewerPreferences dictionary of the Catalog dictionary contains a DisplayDocTitle entry with a value of false",
    section: "UA1:7.1-9",
  }
}
