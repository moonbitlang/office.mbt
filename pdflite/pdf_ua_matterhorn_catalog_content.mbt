///|
fn pdf_ua_matterhorn_test_01_003() -> PdfUAMatterhornTest {
  {
    name: "01-003",
    error: "Content marked as Artifact is present inside tagged content.",
    section: "UA1:7.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_01_004() -> PdfUAMatterhornTest {
  {
    name: "01-004",
    error: "Tagged content is present inside content marked as Artifact.",
    section: "UA1:7.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_01_005() -> PdfUAMatterhornTest {
  {
    name: "01-005",
    error: "Content is neither marked as Artifact nor tagged as real content.",
    section: "UA1:7-1-2",
  }
}

///|
fn pdf_ua_matterhorn_test_01_007() -> PdfUAMatterhornTest {
  {
    name: "01-007",
    error: "Suspects entry has a value of true.",
    section: "UA1:7-1-11",
  }
}

///|
fn pdf_ua_matterhorn_test_02_001() -> PdfUAMatterhornTest {
  {
    name: "02-001",
    error: "One or more non-standard tag’s mapping does not terminate with a standard type.",
    section: "UA1:7.1-3",
  }
}

///|
fn pdf_ua_matterhorn_test_02_003() -> PdfUAMatterhornTest {
  { name: "02-003", error: "A circular mapping exists.", section: "UA1:7.1-3" }
}

///|
fn pdf_ua_matterhorn_test_02_004() -> PdfUAMatterhornTest {
  {
    name: "02-004",
    error: "One or more standard types are remapped.",
    section: "UA1:7.1-4",
  }
}
